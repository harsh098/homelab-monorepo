#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project="${1:-learninggcp-470023}"
region="${2:-us-central1}"
registry="${region}-docker.pkg.dev"
patch="${repo_dir}/tools/headlamp-oidc-popup.patch"
tag="0.45.0-oidc-$(sha256sum "$patch" | cut -c1-12)"
image="${registry}/${project}/homelab-headlamp/headlamp:${tag}"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

# Pin source and backend separately; a changed release or patch produces a new
# immutable image tag rather than silently changing a running deployment.
git clone --depth 1 --branch v0.45.0 https://github.com/kubernetes-sigs/headlamp.git "$work_dir/headlamp"
test "$(git -C "$work_dir/headlamp" rev-parse HEAD)" = 0e9fe810cb618964172f420666727c9a67fd6ebf
git -C "$work_dir/headlamp" apply --check "$patch"
git -C "$work_dir/headlamp" apply "$patch"

podman run --rm --userns=keep-id \
  --env npm_config_cache=/tmp/npm-cache \
  --volume "$work_dir/headlamp:/headlamp:Z" \
  --workdir /headlamp/frontend \
  docker.io/library/node:22@sha256:0557ac14e0d45d02ed563067b82856ca5e7aa3437fa28d98d4350ea9c3d9494a \
  sh -ec 'npm ci --no-audit --no-fund && npm test -- --run src/components/oidcauth/OauthPopup.test.tsx && npm run build'

podman build --format=oci -f "$repo_dir/tools/headlamp-oidc.Containerfile" -t "$image" "$work_dir/headlamp"
gcloud auth print-access-token --project="$project" | \
  podman login --authfile "$work_dir/auth.json" --username oauth2accesstoken --password-stdin "$registry"
podman push --authfile "$work_dir/auth.json" "$image"
printf 'Published %s\n' "$image"
