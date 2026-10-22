#!/usr/bin/env python3
"""Initialize or rotate Tekton Dashboard BasicAuth credentials in Secret Manager.

Run after applying terraform/layers/05-gcp. The password and htpasswd record
travel only over subprocess stdin and never enter Terraform state or argv.
"""

from __future__ import annotations

import argparse
import json
import secrets
import subprocess


SECRET_ID = "tekton-dashboard-basic-auth"


def _run(command: list[str], *, input_text: str | None = None) -> str:
    try:
        result = subprocess.run(
            command,
            input=input_text,
            text=True,
            capture_output=True,
            check=True,
        )
    except FileNotFoundError as error:
        raise RuntimeError(f"required executable not found: {command[0]}") from error
    except (OSError, subprocess.CalledProcessError) as error:
        # In particular, never display gcloud stderr or the subprocess input:
        # either may contain credentials on an error path.
        raise RuntimeError(f"{command[0]} failed; check credentials, permissions, and project") from error
    return result.stdout


def _project(explicit: str | None) -> str:
    if explicit:
        return explicit
    project = _run(["gcloud", "config", "get-value", "project"]).strip()
    if not project or project == "(unset)":
        raise RuntimeError("specify --project or configure an active gcloud project")
    return project


def _enabled_version_exists(project: str) -> bool:
    versions_json = _run(
        ["gcloud", "secrets", "versions", "list", SECRET_ID, f"--project={project}", "--format=json"]
    )
    try:
        versions = json.loads(versions_json)
    except json.JSONDecodeError as error:
        raise RuntimeError("gcloud returned invalid Secret Manager version metadata") from error
    if not isinstance(versions, list) or any(not isinstance(version, dict) for version in versions):
        raise RuntimeError("gcloud returned unexpected Secret Manager version metadata")
    return any(version.get("state") == "ENABLED" for version in versions)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", help="GCP project; defaults to the active gcloud project")
    parser.add_argument("--username", default="tekton", help="BasicAuth username (default: tekton)")
    parser.add_argument("--rotate", action="store_true", help="add a new version when credentials already exist")
    args = parser.parse_args()

    if not args.username or ":" in args.username or "\r" in args.username or "\n" in args.username:
        parser.error("username must be non-empty and cannot contain a colon or newline")

    try:
        project = _project(args.project)
        # Fail before generating a password if Terraform has not created the container.
        _run(["gcloud", "secrets", "describe", SECRET_ID, f"--project={project}", "--format=value(name)"])
        if _enabled_version_exists(project) and not args.rotate:
            raise RuntimeError("an enabled version already exists; use --rotate to replace credentials")

        password = secrets.token_urlsafe(32)
        record = _run(["htpasswd", "-nBi", "-C", "12", args.username], input_text=f"{password}\n").strip()
        if not record.startswith(f"{args.username}:$2") or "\n" in record:
            raise RuntimeError("htpasswd did not return a single bcrypt record")
        payload = json.dumps({"username": args.username, "password": password, "users": record})
        _run(
            ["gcloud", "secrets", "versions", "add", SECRET_ID, f"--project={project}", "--data-file=-"],
            input_text=payload,
        )
    except RuntimeError as error:
        parser.exit(1, f"error: {error}\n")

    print(f"Added a new version of {SECRET_ID} in {project}; credentials are in Secret Manager.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
