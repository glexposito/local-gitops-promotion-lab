#!/usr/bin/env bash
# Replaces the GitHub Actions build for the local-only profile.
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_dir="${1:-"$repo_root/../pulse-api"}"
registry="localhost:5000"

if [ ! -d "$app_dir/.git" ]; then
  echo "pulse-api checkout not found at $app_dir" >&2
  exit 1
fi
if [ -n "$(git -C "$app_dir" status --porcelain)" ]; then
  echo "Commit or discard pulse-api changes before publishing." >&2
  exit 1
fi

git -C "$app_dir" push local main
tag="sha-$(git -C "$app_dir" rev-parse --short=7 HEAD)"

docker build -t "$registry/pulse-api:$tag" "$app_dir"
docker build -t "$registry/pulse-api-e2e:$tag" "$app_dir/e2e"
docker push "$registry/pulse-api:$tag"
docker push "$registry/pulse-api-e2e:$tag"

echo "Published $tag. Kargo will discover it as registry.local:5000/pulse-api."
