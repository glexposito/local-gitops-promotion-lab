#!/usr/bin/env bash
# Bring up the complete local-only lab. It is intentionally a two-phase boot:
# Gitea must contain the repositories before Argo CD starts reading Git.
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_dir="${1:-"$repo_root/workspace/pulse-api"}"
compose=(docker compose -f "$repo_root/cluster/docker-compose.yaml" -f "$repo_root/cluster/docker-compose.local.yaml" --profile local)

"${compose[@]}" up -d gitea registry
"$repo_root/local/seed-repositories.sh" "$app_dir"
"${compose[@]}" up -d
