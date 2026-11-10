#!/usr/bin/env bash
# Seed Gitea with independent Git remotes for this lab and pulse-api.
# Run via local/up.sh; do not run it again after Kargo has made promotions.
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_seed="$repo_root/seed/pulse-api"
app_dir="${1:-"$repo_root/workspace/pulse-api"}"
gitea_host="http://localhost:3000"
gitea_user="local"
gitea_password="local-123"
gitea_repo="local-gitops-promotion-lab"
gitea_git_url="http://gitea.local:3000/$gitea_user/$gitea_repo.git"
gitea_push_url="http://$gitea_user:$gitea_password@localhost:3000/$gitea_user/$gitea_repo.git"

if [ ! -f "$app_seed/Cargo.toml" ]; then
  echo "pulse-api seed is missing from $app_seed" >&2
  exit 1
fi

# GitHub distributes the source snapshot as part of this lab. On first boot,
# make a real, independent Git worktree that Gitea will host as pulse-api.
if [ ! -d "$app_dir/.git" ]; then
  if [ -e "$app_dir" ]; then
    echo "Expected a Git worktree at $app_dir, but found a non-Git directory." >&2
    exit 1
  fi
  mkdir -p "$(dirname "$app_dir")"
  cp -a "$app_seed/." "$app_dir"
  git -C "$app_dir" init --initial-branch=main >/dev/null
  git -C "$app_dir" config user.name local-bootstrap
  git -C "$app_dir" config user.email local-bootstrap@localhost
  git -C "$app_dir" add -A
  git -C "$app_dir" commit -m 'Initial pulse-api release' >/dev/null
fi

until curl --fail --silent --output /dev/null "$gitea_host/api/healthz"; do
  sleep 2
done

docker compose -f "$repo_root/cluster/docker-compose.yaml" \
  -f "$repo_root/cluster/docker-compose.local.yaml" --profile local \
  exec -T gitea gitea admin user create \
  --admin --username "$gitea_user" --password "$gitea_password" \
  --email local@example.test --must-change-password=false 2>/dev/null || true

create_repo() {
  local name="$1"
  local status
  status="$(curl --silent --output /dev/null --write-out '%{http_code}' \
    --user "$gitea_user:$gitea_password" \
    --header 'Content-Type: application/json' \
    --data "{\"name\":\"$name\",\"private\":false}" \
    "$gitea_host/api/v1/user/repos")"
  if [ "$status" != 201 ]; then
    echo "Unable to create Gitea repository $name (HTTP $status)." >&2
    exit 1
  fi
}

create_repo "$gitea_repo"
create_repo pulse-api

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
git clone "$repo_root" "$work_dir/gitops"

# The Gitea copy is intentionally self-contained: no GitHub URLs or GHCR
# image references survive in the repository Argo CD and Kargo will consume.
find "$work_dir/gitops" -path '*/.git' -prune -o -type f -print0 \
  | xargs -0 perl -pi -e 's#git\@github\.com:glexposito/local-gitops-promotion-lab\.git#http://gitea.local:3000/local/local-gitops-promotion-lab.git#g; s#https://github\.com/glexposito/local-gitops-promotion-lab\.git#http://gitea.local:3000/local/local-gitops-promotion-lab.git#g; s#ghcr\.io/glexposito/pulse-api-e2e#registry.local:5000/pulse-api-e2e#g; s#ghcr\.io/glexposito/pulse-api#registry.local:5000/pulse-api#g'
perl -0pi -e 's#(e2eImage: registry\.local:5000/pulse-api-e2e\n)#$1registryInsecure: true\n#' "$work_dir/gitops/kargo/apps/pulse-api.yaml"

git -C "$work_dir/gitops" config user.name local-bootstrap
git -C "$work_dir/gitops" config user.email local-bootstrap@localhost
git -C "$work_dir/gitops" add -A
git -C "$work_dir/gitops" commit -m 'Configure the local Gitea and registry' >/dev/null
git -C "$work_dir/gitops" remote add local "$gitea_push_url"
git -C "$work_dir/gitops" push local main

git -C "$app_dir" remote get-url local >/dev/null 2>&1 \
  || git -C "$app_dir" remote add local "http://$gitea_user:$gitea_password@localhost:3000/$gitea_user/pulse-api.git"
git -C "$app_dir" push local main

echo "Seeded $gitea_git_url and http://gitea.local:3000/local/pulse-api.git"
