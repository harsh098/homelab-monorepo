#!/usr/bin/env python3
"""Create or update the Platform realm Google identity provider.

Credentials are read directly from Google Secret Manager through ``gcloud`` and
kept in process memory. The utility talks to the Keycloak Admin REST API over
the homelab private CA; it does not require a Kubernetes kubeconfig.
"""

from __future__ import annotations

import argparse
import json
import ssl
import subprocess
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


DEFAULT_KEYCLOAK_URL = "https://keycloak.platform.home.arpa"
DEFAULT_CA_FILE = Path.home() / ".config/homelab/keycloak-ca.crt"


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--keycloak-url", default=DEFAULT_KEYCLOAK_URL)
    parser.add_argument("--realm", default="Platform")
    parser.add_argument("--admin-realm", default="master")
    parser.add_argument("--admin-secret", default="keycloak-admin-recovery")
    parser.add_argument("--google-secret", default="keycloak-google-oauth")
    parser.add_argument("--project", help="GCP project; defaults to the active gcloud project")
    parser.add_argument("--ca-file", type=Path, default=DEFAULT_CA_FILE)
    parser.add_argument("--hosted-domain", help="Restrict Google login to this Workspace domain")
    parser.add_argument("--dry-run", action="store_true", help="Authenticate and inspect without changing Keycloak")
    return parser


def _secret(name: str, project: str | None) -> dict[str, Any]:
    command = ["gcloud", "secrets", "versions", "access", "latest", f"--secret={name}"]
    if project:
        command.append(f"--project={project}")
    try:
        result = subprocess.run(command, check=True, capture_output=True, text=True)
    except FileNotFoundError as error:
        raise RuntimeError("gcloud is required but was not found") from error
    except subprocess.CalledProcessError as error:
        detail = error.stderr.strip() or "gcloud secret access failed"
        raise RuntimeError(f"cannot access Secret Manager secret {name!r}: {detail}") from error
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError(f"Secret Manager secret {name!r} must contain a JSON object") from error
    if not isinstance(payload, dict):
        raise RuntimeError(f"Secret Manager secret {name!r} must contain a JSON object")
    return payload


def _required_string(payload: dict[str, Any], key: str, secret_name: str) -> str:
    value = payload.get(key)
    if not isinstance(value, str) or not value:
        raise RuntimeError(f"Secret Manager secret {secret_name!r} requires non-empty field {key!r}")
    return value


def _request(
    context: ssl.SSLContext,
    method: str,
    url: str,
    *,
    token: str | None = None,
    json_body: dict[str, Any] | None = None,
    form: dict[str, str] | None = None,
    allowed: tuple[int, ...] = (200,),
) -> tuple[int, bytes]:
    headers = {"Accept": "application/json"}
    body: bytes | None = None
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if json_body is not None:
        headers["Content-Type"] = "application/json"
        body = json.dumps(json_body, separators=(",", ":")).encode("utf-8")
    elif form is not None:
        headers["Content-Type"] = "application/x-www-form-urlencoded"
        body = urllib.parse.urlencode(form).encode("utf-8")
    request = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, context=context, timeout=30) as response:
            status = response.status
            response_body = response.read()
    except urllib.error.HTTPError as error:
        status = error.code
        response_body = error.read()
    except urllib.error.URLError as error:
        raise RuntimeError(f"request to {url} failed: {error.reason}") from error
    if status not in allowed:
        detail = ""
        try:
            decoded = json.loads(response_body)
            if isinstance(decoded, dict):
                candidate = decoded.get("errorMessage") or decoded.get("error")
                if isinstance(candidate, str):
                    detail = f": {candidate}"
        except (UnicodeDecodeError, json.JSONDecodeError):
            pass
        raise RuntimeError(f"Keycloak returned HTTP {status} for {method} {url}{detail}")
    return status, response_body


def _json_object(body: bytes, description: str) -> dict[str, Any]:
    try:
        value = json.loads(body)
    except json.JSONDecodeError as error:
        raise RuntimeError(f"Keycloak returned invalid JSON for {description}") from error
    if not isinstance(value, dict):
        raise RuntimeError(f"Keycloak returned a non-object for {description}")
    return value


def main() -> int:
    args = _parser().parse_args()
    ca_file = args.ca_file.expanduser()
    if not ca_file.is_file():
        raise RuntimeError(f"Keycloak CA file does not exist: {ca_file}")

    admin_secret = _secret(args.admin_secret, args.project)
    google_secret = _secret(args.google_secret, args.project)
    username = _required_string(admin_secret, "username", args.admin_secret)
    password = _required_string(admin_secret, "password", args.admin_secret)
    client_id = _required_string(google_secret, "client_id", args.google_secret)
    client_secret = _required_string(google_secret, "client_secret", args.google_secret)

    base_url = args.keycloak_url.rstrip("/")
    context = ssl.create_default_context(cafile=str(ca_file))
    token_url = f"{base_url}/realms/{urllib.parse.quote(args.admin_realm, safe='')}/protocol/openid-connect/token"
    _, token_body = _request(
        context,
        "POST",
        token_url,
        form={
            "grant_type": "password",
            "client_id": "admin-cli",
            "username": username,
            "password": password,
        },
    )
    access_token = _required_string(_json_object(token_body, "admin token"), "access_token", "admin token response")

    realm = urllib.parse.quote(args.realm, safe="")
    provider_url = f"{base_url}/admin/realms/{realm}/identity-provider/instances/google"
    status, provider_body = _request(context, "GET", provider_url, token=access_token, allowed=(200, 404))

    config = {
        "clientId": client_id,
        "clientSecret": client_secret,
        "defaultScope": "openid profile email",
        "syncMode": "IMPORT",
    }
    if args.hosted_domain:
        config["hostedDomain"] = args.hosted_domain

    desired: dict[str, Any] = {
        "alias": "google",
        "displayName": "Google",
        "providerId": "google",
        "enabled": True,
        "trustEmail": True,
        "storeToken": False,
        "addReadTokenRoleOnCreate": False,
        "authenticateByDefault": False,
        "linkOnly": False,
        "firstBrokerLoginFlowAlias": "first broker login",
        "config": config,
    }

    action = "create"
    if status == 200:
        action = "update"
        current = _json_object(provider_body, "Google identity provider")
        current_config = current.get("config")
        if isinstance(current_config, dict):
            desired["config"] = {**current_config, **config}

    if args.dry_run:
        print(f"Would {action} Google identity provider in realm {args.realm}")
        return 0

    if action == "create":
        collection_url = f"{base_url}/admin/realms/{realm}/identity-provider/instances"
        _request(context, "POST", collection_url, token=access_token, json_body=desired, allowed=(201, 204))
    else:
        _request(context, "PUT", provider_url, token=access_token, json_body=desired, allowed=(204,))

    _, verified_body = _request(context, "GET", provider_url, token=access_token)
    verified = _json_object(verified_body, "Google identity provider verification")
    if verified.get("providerId") != "google" or verified.get("enabled") is not True:
        raise RuntimeError("Google identity provider verification failed")
    print(f"Google identity provider {action}d and verified in realm {args.realm}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as error:
        raise SystemExit(str(error)) from error
