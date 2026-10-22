#!/usr/bin/env python3
"""Exchange the GCP-held OpenBao recovery token for a short-lived read-only app token.

Only the scoped child token reaches Terraform. Its temporary file must be
removed by the caller, including when Terraform fails.
"""

import argparse
import json
import os
import ssl
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path


POLICY_NAME = "trilium-cloudflare-reader"
POLICY = '''path "platform/data/apps/cloudflare" {
  capabilities = ["read"]
}
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
'''


def request(context: ssl.SSLContext, token: str, method: str, path: str,
            body: dict | None = None) -> dict:
    payload = json.dumps(body).encode() if body is not None else None
    headers = {"X-Vault-Token": token}
    if payload is not None:
        headers["Content-Type"] = "application/json"
    endpoint = "https://openbao.platform.home.arpa/v1/" + path
    try:
        with urllib.request.urlopen(
            urllib.request.Request(endpoint, data=payload, headers=headers, method=method),
            context=context, timeout=25,
        ) as response:
            return json.load(response) if response.status != 204 else {}
    except urllib.error.HTTPError as error:
        raise RuntimeError(f"OpenBao {method} /v1/{path} returned HTTP {error.code}") from None


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", default="learninggcp-470023")
    parser.add_argument("--ca-file", type=Path,
                        default=Path.home() / ".config/homelab/keycloak-ca.crt")
    parser.add_argument("--gcloud-bin", default="gcloud")
    args = parser.parse_args()
    os.umask(0o077)
    token_file = None
    try:
        context = ssl.create_default_context(cafile=str(args.ca_file.expanduser()))
        result = subprocess.run(
            [args.gcloud_bin, "secrets", "versions", "access", "latest",
             "--secret=openbao-recovery", f"--project={args.project}"],
            check=True, capture_output=True,
        )
        root_token = json.loads(result.stdout)["root_token"]
        if not root_token:
            raise ValueError("OpenBao recovery token is empty")
        request(context, root_token, "PUT", f"sys/policies/acl/{POLICY_NAME}",
                {"policy": POLICY})
        child = request(context, root_token, "POST", "auth/token/create-orphan", {
            "policies": [POLICY_NAME],
            "no_default_policy": True,
            "ttl": "30m",
            "explicit_max_ttl": "30m",
            "renewable": False,
        })["auth"]["client_token"]
        if not child or child == root_token:
            raise ValueError("OpenBao returned an invalid scoped token")
        descriptor, token_file = tempfile.mkstemp(prefix="trilium-vault-")
        with os.fdopen(descriptor, "w", encoding="utf-8") as destination:
            destination.write(child + "\n")
        print(token_file)
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError,
            urllib.error.URLError, RuntimeError) as error:
        if token_file is not None:
            Path(token_file).unlink(missing_ok=True)
        print(f"Cannot mint scoped Trilium Vault token: {type(error).__name__}"
              + (f" ({error})" if isinstance(error, RuntimeError) else ""),
              file=sys.stderr)
        raise SystemExit(1) from None


if __name__ == "__main__":
    main()
