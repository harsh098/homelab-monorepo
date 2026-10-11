#!/usr/bin/env python3
"""Apply OpenBao's Platform-realm OIDC and scoped Kubernetes publisher access.

Only non-secret configuration is in Git. The initial root token is read from
Secret Manager and the OIDC client credential from the in-cluster Crossplane
connection Secret; neither is written to disk, passed as an argument, or logged.
Run after the GitOps Keycloak client and OpenBao service account exist.
"""

from __future__ import annotations

import argparse
import base64
import json
import ssl
import subprocess
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


ISSUER = "https://keycloak.platform.home.arpa/realms/Platform"
OPENBAO = "https://openbao.platform.home.arpa"
CA_FILE = Path.home() / ".config/homelab/keycloak-ca.crt"


def _command(*args: str) -> bytes:
    try:
        return subprocess.run(args, check=True, capture_output=True).stdout
    except subprocess.CalledProcessError as error:
        raise RuntimeError(f"{args[0]} failed ({error.returncode}); check credentials and connectivity") from error


def _credentials(project: str, kubeconfig: str) -> tuple[str, str]:
    recovery = json.loads(_command(
        "gcloud", "secrets", "versions", "access", "latest",
        "--secret=openbao-recovery", f"--project={project}",
    ))
    root_token = recovery["root_token"]
    connection = json.loads(_command(
        "kubectl", "--kubeconfig", kubeconfig, "-n", "keycloak", "get", "secret",
        "openbao-oidc-client", "-o", "json",
    ))["data"]
    # provider-keycloak v3.0.1 publishes these camelCase connection keys.
    if base64.b64decode(connection["clientID"], validate=True).decode() != "openbao":
        raise RuntimeError("Keycloak connection secret belongs to a different client")
    client_secret = base64.b64decode(connection["clientSecret"], validate=True).decode()
    if not root_token or not client_secret:
        raise RuntimeError("OpenBao recovery token or Keycloak client secret is empty")
    return root_token, client_secret


def _request(
    context: ssl.SSLContext, base: str, token: str, method: str, path: str,
    body: dict[str, Any] | None = None, allowed: tuple[int, ...] = (200, 204),
) -> dict[str, Any]:
    payload = json.dumps(body).encode() if body is not None else None
    headers = {"X-Vault-Token": token}
    if payload is not None:
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(f"{base}/v1/{path}", payload, headers, method=method)
    try:
        with urllib.request.urlopen(request, context=context, timeout=25) as response:
            status, content = response.status, response.read()
    except urllib.error.HTTPError as error:
        status, content = error.code, error.read()
    if status not in allowed:
        raise RuntimeError(f"OpenBao returned HTTP {status} for {method} /v1/{path}")
    return json.loads(content) if content else {}


def _ensure_mounts(context: ssl.SSLContext, base: str, token: str) -> None:
    auth = _request(context, base, token, "GET", "sys/auth")
    for name, kind in (("oidc", "jwt"), ("kubernetes", "kubernetes")):
        mount = auth.get(f"{name}/")
        if mount is None:
            _request(context, base, token, "POST", f"sys/auth/{name}", {"type": kind})
        elif mount["type"] != kind:
            raise RuntimeError(f"auth/{name} is not a {kind} mount")
    secrets = _request(context, base, token, "GET", "sys/mounts")
    mount = secrets.get("platform/")
    if mount is None:
        _request(context, base, token, "POST", "sys/mounts/platform", {"type": "kv", "options": {"version": "2"}})
    elif mount["type"] != "kv" or mount.get("options", {}).get("version") != "2":
        raise RuntimeError("platform/ is not a KV v2 mount")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", default="learninggcp-470023")
    parser.add_argument("--kubeconfig", default="terraform/layers/03-compute/kubeconfig")
    parser.add_argument("--ca-file", type=Path, default=CA_FILE)
    parser.add_argument("--openbao-url", default=OPENBAO)
    args = parser.parse_args()
    ca_pem = args.ca_file.expanduser().read_text()
    context = ssl.create_default_context(cafile=str(args.ca_file.expanduser()))
    token, client_secret = _credentials(args.project, args.kubeconfig)
    base = args.openbao_url.rstrip("/")
    _ensure_mounts(context, base, token)

    publisher_policy = '''path "platform/data/keycloak/clients/openbao" {
  capabilities = ["create", "read", "update"]
}
path "platform/metadata/keycloak/clients/openbao" {
  capabilities = ["create", "read", "update"]
}
'''
    _request(context, base, token, "PUT", "sys/policies/acl/keycloak-client-publisher", {"policy": publisher_policy})
    headlamp_policy = '''path "platform/data/keycloak/clients/headlamp" {
  capabilities = ["create", "read", "update"]
}
path "platform/metadata/keycloak/clients/headlamp" {
  capabilities = ["create", "read", "update"]
}
'''
    _request(context, base, token, "PUT", "sys/policies/acl/headlamp-client-publisher", {"policy": headlamp_policy})
    backup_policy = '''path "sys/storage/raft/snapshot" {
  capabilities = ["read"]
}
'''
    _request(context, base, token, "PUT", "sys/policies/acl/openbao-snapshot-backup", {"policy": backup_policy})
    # This group is the sole human login role. The emergency root token stays
    # outside the cluster, independently of Keycloak's availability.
    admin_policy = '''path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo", "patch"]
}
'''
    _request(context, base, token, "PUT", "sys/policies/acl/platform-operators", {"policy": admin_policy})
    _request(context, base, token, "POST", "auth/oidc/config", {
        "oidc_discovery_url": ISSUER,
        "oidc_discovery_ca_pem": ca_pem,
        "oidc_client_id": "openbao",
        "oidc_client_secret": client_secret,
        "bound_issuer": ISSUER,
        "default_role": "platform-operators",
    })
    _request(context, base, token, "POST", "auth/oidc/role/platform-operators", {
        "role_type": "oidc",
        "user_claim": "sub",
        "oidc_scopes": ["profile", "email"],
        "bound_claims": {"groups": "openbao-admin"},
        "allowed_redirect_uris": [
            f"{base}/ui/vault/auth/oidc/oidc/callback",
            "http://localhost:8250/oidc/callback",
        ],
        "token_policies": ["platform-operators"],
        "token_ttl": "1h",
        "token_max_ttl": "4h",
    })
    _request(context, base, token, "POST", "auth/kubernetes/config", {
        "kubernetes_host": "https://kubernetes.default.svc:443",
    })
    _request(context, base, token, "POST", "auth/kubernetes/role/keycloak-client-publisher", {
        "bound_service_account_names": ["openbao-keycloak-publisher"],
        "bound_service_account_namespaces": ["keycloak"],
        "audience": "vault",
        "token_policies": ["keycloak-client-publisher"],
        "token_ttl": "15m",
        "token_max_ttl": "1h",
    })
    _request(context, base, token, "POST", "auth/kubernetes/role/headlamp-client-publisher", {
        "bound_service_account_names": ["openbao-keycloak-headlamp-publisher"],
        "bound_service_account_namespaces": ["keycloak"],
        "audience": "vault",
        "token_policies": ["headlamp-client-publisher"],
        "token_ttl": "15m",
        "token_max_ttl": "1h",
    })
    _request(context, base, token, "POST", "auth/kubernetes/role/openbao-snapshot-backup", {
        "bound_service_account_names": ["openbao-backup"],
        "bound_service_account_namespaces": ["openbao"],
        "audience": "vault",
        "token_policies": ["openbao-snapshot-backup"],
        "token_ttl": "15m",
        "token_max_ttl": "1h",
    })
    print("OpenBao Platform OIDC and scoped Kubernetes publisher configured")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, KeyError, OSError, ValueError) as error:
        raise SystemExit(str(error)) from error
