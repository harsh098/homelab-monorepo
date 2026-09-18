#!/usr/bin/env python3
"""Initialize, unseal, and bootstrap the persistent single-node OpenBao."""

from __future__ import annotations

import argparse
import base64
import json
import subprocess
from pathlib import Path
from typing import Any


def run(command: list[str], *, input_text: str | None = None, check: bool = True) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(command, input=input_text, text=True, capture_output=True, check=check)
    except FileNotFoundError as error:
        raise RuntimeError(f"required command not found: {command[0]}") from error
    except subprocess.CalledProcessError as error:
        detail = error.stderr.strip() or error.stdout.strip() or "command failed"
        raise RuntimeError(f"{command[0]} failed: {detail}") from error


def parser() -> argparse.ArgumentParser:
    value = argparse.ArgumentParser(description=__doc__)
    value.add_argument("--kubeconfig", type=Path, default=Path("terraform/layers/03-compute/kubeconfig"))
    value.add_argument("--project", required=True, help="GCP project holding OpenBao recovery secrets")
    value.add_argument(
        "--bootstrap-manifest",
        type=Path,
        default=Path("clusters/platform/keycloak-gitops/openbao-database-bootstrap.yaml"),
    )
    return value


def bao(kubeconfig: Path, *arguments: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return run(
        [
            "kubectl",
            "--kubeconfig",
            str(kubeconfig),
            "-n",
            "openbao",
            "exec",
            "openbao-0",
            "--",
            "env",
            "BAO_ADDR=http://127.0.0.1:8200",
            "bao",
            *arguments,
        ],
        check=check,
    )


def gcp_secret(project: str, name: str) -> str:
    result = run(["gcloud", "secrets", "versions", "access", "latest", f"--secret={name}", f"--project={project}"])
    return result.stdout.strip()


def add_gcp_version(project: str, name: str, value: str) -> None:
    run(
        ["gcloud", "secrets", "versions", "add", name, f"--project={project}", "--data-file=-"],
        input_text=value,
    )


def apply_bootstrap_secret(kubeconfig: Path, root_token: str) -> None:
    manifest: dict[str, Any] = {
        "apiVersion": "v1",
        "kind": "Secret",
        "metadata": {"name": "openbao-bootstrap-token", "namespace": "external-secrets"},
        "type": "Opaque",
        "data": {"token": base64.b64encode(root_token.encode()).decode()},
    }
    run(
        ["kubectl", "--kubeconfig", str(kubeconfig), "apply", "-f", "-"],
        input_text=json.dumps(manifest),
    )


def main() -> int:
    args = parser().parse_args()
    kubeconfig = args.kubeconfig.expanduser()
    if not kubeconfig.is_file():
        raise RuntimeError(f"kubeconfig does not exist: {kubeconfig}")
    if not args.bootstrap_manifest.is_file():
        raise RuntimeError(f"bootstrap manifest does not exist: {args.bootstrap_manifest}")

    status_result = bao(kubeconfig, "status", "-format=json", check=False)
    if status_result.returncode not in (0, 2):
        raise RuntimeError(status_result.stderr.strip() or "cannot read OpenBao status")
    status = json.loads(status_result.stdout)

    if not status["initialized"]:
        initialized = json.loads(
            bao(kubeconfig, "operator", "init", "-format=json", "-key-shares=1", "-key-threshold=1").stdout
        )
        unseal_key = initialized["unseal_keys_b64"][0]
        root_token = initialized["root_token"]
        add_gcp_version(args.project, "openbao-unseal-key", unseal_key)
        add_gcp_version(args.project, "openbao-root-token", root_token)
    else:
        unseal_key = gcp_secret(args.project, "openbao-unseal-key")
        root_token = gcp_secret(args.project, "openbao-root-token")

    status_result = bao(kubeconfig, "status", "-format=json", check=False)
    status = json.loads(status_result.stdout)
    if status["sealed"]:
        bao(kubeconfig, "operator", "unseal", unseal_key)

    apply_bootstrap_secret(kubeconfig, root_token)
    run(
        [
            "kubectl",
            "--kubeconfig",
            str(kubeconfig),
            "-n",
            "external-secrets",
            "delete",
            "job",
            "keycloak-db-credentials-bootstrap",
            "--ignore-not-found",
        ]
    )
    run(["kubectl", "--kubeconfig", str(kubeconfig), "apply", "-f", str(args.bootstrap_manifest)])
    run(
        [
            "kubectl",
            "--kubeconfig",
            str(kubeconfig),
            "-n",
            "external-secrets",
            "wait",
            "job/keycloak-db-credentials-bootstrap",
            "--for=condition=Complete",
            "--timeout=300s",
        ]
    )
    run(
        [
            "kubectl",
            "--kubeconfig",
            str(kubeconfig),
            "-n",
            "external-secrets",
            "delete",
            "secret",
            "openbao-bootstrap-token",
        ]
    )
    print("OpenBao is initialized, unsealed, and bootstrapped; recovery material remains only in GCP Secret Manager")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, json.JSONDecodeError) as error:
        raise SystemExit(str(error)) from error
