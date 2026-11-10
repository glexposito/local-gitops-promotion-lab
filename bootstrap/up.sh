#!/usr/bin/env bash
# Create the two local Git worktrees, seed Gitea, then start the lab.
set -Eeuo pipefail

template_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
gitops_dir="$template_root/gitops"
app_dir="$template_root/repos/pulse-api"

init_repo() {
  local source="$1" target="$2" message="$3"
  if [ -e "$target" ]; then
    echo "Refusing to overwrite existing $target" >&2
    exit 1
  fi
  cp -a "$source" "$target"
  git -C "$target" init --initial-branch=main >/dev/null
  git -C "$target" config user.name local-bootstrap
  git -C "$target" config user.email local-bootstrap@localhost
  git -C "$target" add -A
  git -C "$target" commit -m "$message" >/dev/null
}

if [ ! -d "$gitops_dir/.git" ]; then
  mkdir -p "$template_root/repos"
  init_repo "$template_root/.seed/gitops" "$gitops_dir" 'Initial GitOps state'
  init_repo "$template_root/.seed/repos/pulse-api" "$app_dir" 'Initial pulse-api release'
fi

if [ ! -d "$gitops_dir/.git" ] || [ ! -d "$app_dir/.git" ]; then
  echo "Both gitops/.git and repos/pulse-api/.git must exist." >&2
  exit 1
fi

compose=(docker compose -f "$gitops_dir/cluster/docker-compose.yaml" -f "$gitops_dir/cluster/docker-compose.local.yaml" --profile local)

if git -C "$gitops_dir" remote get-url local >/dev/null 2>&1; then
  "${compose[@]}" up -d
  exit 0
fi

"${compose[@]}" up -d gitea registry
"$template_root/bootstrap/seed-repositories.sh" "$gitops_dir" "$app_dir"
"${compose[@]}" up -d
