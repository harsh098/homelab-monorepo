# Keep the official backend and bundled plugins unchanged; only replace the
# frontend with v0.45.0 rebuilt from tools/headlamp-oidc-popup.patch.
FROM ghcr.io/headlamp-k8s/headlamp@sha256:db3f0e0fc58d358d41daa3fe7fc852437552c7ee873c3645470f7b86a8e0db49
LABEL org.opencontainers.image.source="https://github.com/harsh098/homelab-monorepo"
COPY --chown=headlamp:headlamp frontend/build/ /headlamp/frontend/
