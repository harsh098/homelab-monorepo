#!/usr/bin/env python3
"""Obtain a Kubernetes ExecCredential from a Keycloak browser login.

This helper intentionally uses authorization-code + PKCE flow. It never accepts
or stores a Keycloak password, and it never disables TLS certificate validation.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import http.server
import json
import os
import queue
import secrets
import ssl
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


class OIDCError(RuntimeError):
    """A user-actionable OIDC or local callback error."""


def _b64url(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode("ascii")


def _ssl_context(ca_file: str | None) -> ssl.SSLContext:
    if ca_file:
        path = Path(ca_file).expanduser()
        if not path.is_file():
            raise OIDCError(f"CA file does not exist: {path}")
        return ssl.create_default_context(cafile=str(path))
    return ssl.create_default_context()


def _issuer(value: str) -> str:
    value = value.rstrip("/")
    parsed = urllib.parse.urlsplit(value)
    if parsed.scheme != "https" or not parsed.netloc or parsed.query or parsed.fragment:
        raise OIDCError("issuer must be an https URL without query or fragment")
    return value


def _json_request(
    url: str,
    *,
    context: ssl.SSLContext,
    data: dict[str, str] | None = None,
) -> dict[str, Any]:
    body = None
    headers = {"Accept": "application/json"}
    if data is not None:
        body = urllib.parse.urlencode(data).encode("ascii")
        headers["Content-Type"] = "application/x-www-form-urlencoded"
    request = urllib.request.Request(url, data=body, headers=headers, method="POST" if body else "GET")
    try:
        with urllib.request.urlopen(request, context=context, timeout=20) as response:
            result = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        detail = error.read(512).decode("utf-8", "replace")
        raise OIDCError(f"OIDC endpoint returned HTTP {error.code}: {detail}") from error
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
        raise OIDCError(f"OIDC endpoint is unavailable: {error}") from error
    if not isinstance(result, dict):
        raise OIDCError("OIDC endpoint returned a non-object JSON response")
    return result


def _metadata(issuer: str, context: ssl.SSLContext) -> dict[str, Any]:
    metadata = _json_request(f"{issuer}/.well-known/openid-configuration", context=context)
    for field in ("authorization_endpoint", "token_endpoint"):
        endpoint = metadata.get(field)
        if not isinstance(endpoint, str) or not endpoint.startswith("https://"):
            raise OIDCError(f"OIDC metadata has no verified HTTPS {field}")
    discovered_issuer = metadata.get("issuer")
    if discovered_issuer and discovered_issuer.rstrip("/") != issuer:
        raise OIDCError("OIDC discovery issuer does not match the configured issuer")
    return metadata


def _load_cache(path: Path, issuer: str, client_id: str) -> dict[str, Any] | None:
    try:
        with path.open(encoding="utf-8") as stream:
            cache = json.load(stream)
    except (FileNotFoundError, OSError, json.JSONDecodeError):
        return None
    if cache.get("issuer") != issuer or cache.get("client_id") != client_id:
        return None
    return cache


def _save_cache(path: Path, cache: dict[str, Any]) -> None:
    path = path.expanduser()
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(path.parent, 0o700)
    with tempfile.NamedTemporaryFile("w", dir=path.parent, delete=False, encoding="utf-8") as stream:
        os.chmod(stream.fileno(), 0o600)
        json.dump(cache, stream, separators=(",", ":"))
        stream.write("\n")
        temporary = Path(stream.name)
    os.replace(temporary, path)
    os.chmod(path, 0o600)


def _expiration_timestamp(expires_at: float) -> str:
    return datetime.fromtimestamp(expires_at, timezone.utc).isoformat().replace("+00:00", "Z")


def _refresh(
    metadata: dict[str, Any],
    cache: dict[str, Any],
    *,
    client_id: str,
    context: ssl.SSLContext,
) -> dict[str, Any] | None:
    refresh_token = cache.get("refresh_token")
    if not isinstance(refresh_token, str) or not refresh_token:
        return None
    try:
        response = _json_request(
            metadata["token_endpoint"],
            context=context,
            data={
                "grant_type": "refresh_token",
                "refresh_token": refresh_token,
                "client_id": client_id,
            },
        )
    except OIDCError:
        return None
    return _token_cache(response, cache["issuer"], client_id, refresh_token)


def _token_cache(
    response: dict[str, Any], issuer: str, client_id: str, old_refresh_token: str | None = None
) -> dict[str, Any]:
    access_token = response.get("access_token")
    if not isinstance(access_token, str) or not access_token:
        raise OIDCError("OIDC token response did not contain an access token")
    expires_in = response.get("expires_in", 300)
    try:
        expires_at = time.time() + max(30, int(expires_in))
    except (TypeError, ValueError) as error:
        raise OIDCError("OIDC token response contained an invalid expiry") from error
    refresh_token = response.get("refresh_token") or old_refresh_token
    cache = {
        "issuer": issuer,
        "client_id": client_id,
        "access_token": access_token,
        "expires_at": expires_at,
    }
    if isinstance(refresh_token, str) and refresh_token:
        cache["refresh_token"] = refresh_token
    return cache


def _jwt_payload(token: str) -> dict[str, Any] | None:
    parts = token.split(".")
    if len(parts) != 3:
        return None
    try:
        padding = "=" * (-len(parts[1]) % 4)
        payload = json.loads(base64.urlsafe_b64decode(parts[1] + padding).decode("utf-8"))
    except (ValueError, TypeError, json.JSONDecodeError):
        return None
    return payload if isinstance(payload, dict) else None


def _validate_id_token(token: str, issuer: str, client_id: str, nonce: str) -> None:
    claims = _jwt_payload(token)
    if claims is None:
        raise OIDCError("OIDC returned an unreadable ID token")
    if claims.get("iss", "").rstrip("/") != issuer:
        raise OIDCError("OIDC ID token issuer does not match the configured issuer")
    audience = claims.get("aud")
    if not (audience == client_id or isinstance(audience, list) and client_id in audience):
        raise OIDCError("OIDC ID token audience does not match the configured client")
    if claims.get("nonce") != nonce:
        raise OIDCError("OIDC ID token nonce did not match the login request")


class _CallbackHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, _format: str, *_args: object) -> None:
        return

    def do_GET(self) -> None:  # noqa: N802 - stdlib handler API
        parsed = urllib.parse.urlsplit(self.path)
        if parsed.path != "/callback":
            self.send_error(404)
            return
        query = urllib.parse.parse_qs(parsed.query)
        self.server.callback_queue.put(query)  # type: ignore[attr-defined]
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.end_headers()
        self.wfile.write(b"Login complete. You may close this browser tab.\n")


def _browser_login(
    metadata: dict[str, Any],
    *,
    issuer: str,
    client_id: str,
    listen_host: str,
    listen_port: int,
    context: ssl.SSLContext,
    open_browser: bool,
) -> dict[str, Any]:
    if listen_host not in {"127.0.0.1", "::1", "localhost"}:
        raise OIDCError("callback listener must bind to loopback")
    state = _b64url(secrets.token_bytes(32))
    nonce = _b64url(secrets.token_bytes(32))
    verifier = _b64url(secrets.token_bytes(32))
    challenge = _b64url(hashlib.sha256(verifier.encode("ascii")).digest())
    redirect_uri = f"http://{listen_host}:{listen_port}/callback"
    authorization_url = metadata["authorization_endpoint"] + "?" + urllib.parse.urlencode(
        {
            "client_id": client_id,
            "response_type": "code",
            "scope": "openid profile email",
            "redirect_uri": redirect_uri,
            "state": state,
            "nonce": nonce,
            "code_challenge": challenge,
            "code_challenge_method": "S256",
        }
    )

    callback_queue: queue.Queue[dict[str, list[str]]] = queue.Queue()
    try:
        server = http.server.HTTPServer((listen_host, listen_port), _CallbackHandler)
    except OSError as error:
        raise OIDCError(f"cannot bind callback listener {redirect_uri}: {error}") from error
    server.callback_queue = callback_queue  # type: ignore[attr-defined]
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        if open_browser and not webbrowser.open(authorization_url):
            print("Open this URL in a browser:", authorization_url, file=sys.stderr)
        else:
            print(f"Waiting for browser login at {redirect_uri}", file=sys.stderr)
        try:
            query = callback_queue.get(timeout=300)
        except queue.Empty as error:
            raise OIDCError("timed out waiting for the browser callback") from error
    finally:
        server.shutdown()
        server.server_close()

    if query.get("state", [None])[0] != state:
        raise OIDCError("OIDC callback state did not match")
    if query.get("error"):
        raise OIDCError(f"OIDC authorization failed: {query['error'][0]}")
    code = query.get("code", [None])[0]
    if not code:
        raise OIDCError("OIDC callback did not contain an authorization code")
    response = _json_request(
        metadata["token_endpoint"],
        context=context,
        data={
            "grant_type": "authorization_code",
            "code": code,
            "client_id": client_id,
            "redirect_uri": redirect_uri,
            "code_verifier": verifier,
        },
    )
    id_token = response.get("id_token")
    if not isinstance(id_token, str):
        raise OIDCError("OIDC token response did not contain an ID token")
    _validate_id_token(id_token, issuer, client_id, nonce)
    return _token_cache(response, issuer, client_id)


def _credential(cache: dict[str, Any]) -> dict[str, Any]:
    return {
        "apiVersion": "client.authentication.k8s.io/v1",
        "kind": "ExecCredential",
        "status": {
            "token": cache["access_token"],
            "expirationTimestamp": _expiration_timestamp(float(cache["expires_at"])),
        },
    }


def _arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--issuer", default="https://keycloak.platform.home.arpa/realms/Platform")
    parser.add_argument("--client-id", default="kubernetes")
    parser.add_argument("--ca-file", help="PEM CA bundle used to verify Keycloak TLS")
    parser.add_argument("--cache-file", default="~/.cache/kubectl-keycloak-oidc.json")
    parser.add_argument("--listen-host", default="127.0.0.1")
    parser.add_argument("--listen-port", type=int, default=18000)
    parser.add_argument("--no-browser", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = _arguments()
    try:
        issuer = _issuer(args.issuer)
        context = _ssl_context(args.ca_file)
        metadata = _metadata(issuer, context)
        cache_path = Path(args.cache_file).expanduser()
        cache = _load_cache(cache_path, issuer, args.client_id)
        if not cache or float(cache.get("expires_at", 0)) <= time.time() + 60:
            cache = _refresh(metadata, cache, client_id=args.client_id, context=context) if cache else None
        if not cache or float(cache.get("expires_at", 0)) <= time.time() + 60:
            cache = _browser_login(
                metadata,
                issuer=issuer,
                client_id=args.client_id,
                listen_host=args.listen_host,
                listen_port=args.listen_port,
                context=context,
                open_browser=not args.no_browser,
            )
        _save_cache(cache_path, cache)
        print(json.dumps(_credential(cache), separators=(",", ":")))
        return 0
    except (OIDCError, OSError, ValueError) as error:
        print(f"kubectl-keycloak-login: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
