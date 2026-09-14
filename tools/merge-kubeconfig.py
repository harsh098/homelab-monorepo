#!/usr/bin/env python3
"""Merge the homelab browser-authenticated Kubernetes entry into kubeconfig.

The utility owns only entries carrying its management marker. New entries use
the deterministic ``homelab-oidc`` name; if that name collides with an
unmanaged entry, the next available suffix (``homelab-oidc-2``, then ``-3``,
and so on) is selected. Every other kubeconfig entry is retained. The
destination is replaced atomically with mode 0600; no backup is created
because kubeconfigs may contain credentials and a backup would duplicate them.
"""

from __future__ import annotations

import argparse
import os
import tempfile
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError as error:  # pragma: no cover - exercised by deployment
    raise SystemExit("merge-kubeconfig.py requires PyYAML (provided by Ansible)") from error


OIDC_NAME = "homelab-oidc"
OWNER_EXTENSION = "homelab.platform.home.arpa/oidc"
OWNER_VALUE = {"managed-by": "merge-kubeconfig.py"}


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--kubeconfig", type=Path, required=True, help="Kubeconfig to create or update")
    parser.add_argument("--server", required=True, help="Kubernetes API server URL")
    parser.add_argument("--cluster-ca-data", required=True, help="Base64-encoded Kubernetes API CA")
    parser.add_argument("--helper-path", required=True, help="kubectl exec helper path")
    parser.add_argument("--issuer", required=True, help="OIDC issuer URL")
    parser.add_argument("--ca-file", required=True, help="Public CA bundle used by the OIDC helper")
    return parser


def _config(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"apiVersion": "v1", "kind": "Config", "clusters": [], "contexts": [], "users": []}
    if not path.is_file():
        raise ValueError(f"kubeconfig path is not a regular file: {path}")
    with path.open("r", encoding="utf-8") as stream:
        loaded = yaml.safe_load(stream)
    if loaded is None:
        loaded = {}
    if not isinstance(loaded, dict):
        raise ValueError("kubeconfig must contain a YAML mapping at the top level")
    result = dict(loaded)
    for key in ("clusters", "contexts", "users"):
        value = result.get(key, [])
        if not isinstance(value, list):
            raise ValueError(f"kubeconfig field {key!r} must be a YAML list")
        result[key] = list(value)
    result.setdefault("apiVersion", "v1")
    result.setdefault("kind", "Config")
    return result


def _is_owned(entry: Any) -> bool:
    if not isinstance(entry, dict):
        return False
    extensions = entry.get("extensions")
    if not isinstance(extensions, list):
        return False
    return any(
        isinstance(extension, dict)
        and extension.get("name") == OWNER_EXTENSION
        and extension.get("extension") == OWNER_VALUE
        for extension in extensions
    )


def _strip_owned(entries: list[Any]) -> tuple[list[Any], set[str]]:
    owned_names: set[str] = set()
    retained: list[Any] = []
    for entry in entries:
        if _is_owned(entry):
            name = entry.get("name") if isinstance(entry, dict) else None
            if isinstance(name, str):
                owned_names.add(name)
        else:
            retained.append(entry)
    return retained, owned_names


def _next_name(config: dict[str, Any]) -> str:
    entries = [entry for key in ("clusters", "users", "contexts") for entry in config[key]]
    used = {
        entry["name"]
        for entry in entries
        if isinstance(entry, dict) and isinstance(entry.get("name"), str)
    }
    suffix = 1
    while True:
        candidate = OIDC_NAME if suffix == 1 else f"{OIDC_NAME}-{suffix}"
        if candidate not in used:
            return candidate
        suffix += 1

def _marker() -> list[dict[str, Any]]:
    return [{"name": OWNER_EXTENSION, "extension": dict(OWNER_VALUE)}]

def merge_kubeconfig(
    path: Path,
    *,
    server: str,
    cluster_ca_data: str,
    helper_path: str,
    issuer: str,
    ca_file: str,
) -> bool:
    """Parse, merge, and atomically write one kubeconfig.

    Return whether the destination was changed. Existing ``current-context`` is
    retained unless it pointed at a previously managed OIDC entry.
    """
    path = path.expanduser()
    config = _config(path)
    had_current_context = "current-context" in config
    current_context = config.get("current-context")
    all_owned_names: set[str] = set()
    for key in ("clusters", "users", "contexts"):
        config[key], owned_names = _strip_owned(config[key])
        all_owned_names.update(owned_names)
    name = _next_name(config)

    config["clusters"].append(
        {
            "name": name,
            "extensions": _marker(),
            "cluster": {
                "server": server,
                "certificate-authority-data": cluster_ca_data,
            },
        }
    )
    config["users"].append(
        {
            "name": name,
            "extensions": _marker(),
            "user": {
                "exec": {
                    "apiVersion": "client.authentication.k8s.io/v1",
                    "command": helper_path,
                    "interactiveMode": "Never",
                    "args": [
                        "--issuer",
                        issuer,
                        "--client-id",
                        "kubernetes",
                        "--ca-file",
                        ca_file,
                        "--listen-host",
                        "127.0.0.1",
                        "--listen-port",
                        "18000",
                    ],
                }
            },
        }
    )
    config["contexts"].append(
        {
            "name": name,
            "extensions": _marker(),
            "context": {"cluster": name, "user": name},
        }
    )
    if not had_current_context:
        config["current-context"] = name
    elif current_context in all_owned_names:
        config["current-context"] = name
    else:
        config["current-context"] = current_context
    return _atomic_dump(path, config)


def _atomic_dump(path: Path, config: dict[str, Any]) -> bool:
    rendered = yaml.safe_dump(config, default_flow_style=False, sort_keys=False).encode("utf-8")
    if path.exists() and (path.stat().st_mode & 0o777) == 0o600:
        try:
            if path.read_bytes() == rendered:
                return False
        except OSError:
            pass

    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    temporary = Path(temporary_name)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "wb") as stream:
            stream.write(rendered)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        # Keep the containing directory durable across a host interruption.
        directory_fd = os.open(path.parent, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0))
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    except BaseException:
        temporary.unlink(missing_ok=True)
        raise
    return True


def main() -> int:
    args = _parser().parse_args()
    try:
        changed = merge_kubeconfig(
            args.kubeconfig,
            server=args.server,
            cluster_ca_data=args.cluster_ca_data,
            helper_path=args.helper_path,
            issuer=args.issuer,
            ca_file=args.ca_file,
        )
        print("changed" if changed else "ok")
    except (OSError, TypeError, ValueError, yaml.YAMLError) as error:
        print(f"merge-kubeconfig: {error}", file=os.sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
