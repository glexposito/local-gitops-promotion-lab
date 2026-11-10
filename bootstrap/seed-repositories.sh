#!/usr/bin/env bash
# Seed Gitea with the two independent local worktrees.
set -Eeuo pipefail

gitops_dir="${1:?Usage: seed-repositories.sh <gitops-dir> <pulse-api-dir>}"
app_dir="${2:?Usage: seed-repositories.sh <gitops-dir> <pulse-api-dir>}"
gitea_host="http://localhost:3000"
gitea_user="local"
gitea_password="local-123"
gitea_repo="gitops"
gitea_git_url="http://gitea.local:3000/$gitea_user/$gitea_repo.git"
gitea_push_url="http://$gitea_user:$gitea_password@localhost:3000/$gitea_user/$gitea_repo.git"

if [ ! -d "$gitops_dir/.git" ] || [ ! -d "$app_dir/.git" ]; then
  echo "Expected initialized Git repositories in $gitops_dir and $app_dir" >&2
  exit 1
fi

until curl --fail --silent --output /dev/null "$gitea_host/api/healthz"; do
  sleep 2
done

docker compose -f "$gitops_dir/cluster/docker-compose.yaml" \
  -f "$gitops_dir/cluster/docker-compose.local.yaml" --profile local \
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
git clone "$gitops_dir" "$work_dir/gitops"

# The Gitea copy is intentionally self-contained: no GitHub URLs or GHCR
# image references survive in the repository Argo CD and Kargo will consume.
find "$work_dir/gitops" -path '*/.git' -prune -o -type f -print0 \
  | xargs -0 perl -pi -e 's#git\@github\.com:glexposito/local-gitops-promotion-lab\.git#http://gitea.local:3000/local/gitops.git#g; s#https://github\.com/glexposito/local-gitops-promotion-lab\.git#http://gitea.local:3000/local/gitops.git#g; s#ghcr\.io/glexposito/pulse-api-e2e#registry.local:5000/pulse-api-e2e#g; s#ghcr\.io/glexposito/pulse-api#registry.local:5000/pulse-api#g'
perl -0pi -e 's#(e2eImage: registry\.local:5000/pulse-api-e2e\n)#$1registryInsecure: true\n#' "$work_dir/gitops/kargo/apps/pulse-api.yaml"

git -C "$work_dir/gitops" config user.name local-bootstrap
git -C "$work_dir/gitops" config user.email local-bootstrap@localhost
git -C "$work_dir/gitops" add -A
git -C "$work_dir/gitops" commit -m 'Configure the local Gitea and registry' >/dev/null
git -C "$work_dir/gitops" remote add local "$gitea_push_url"
git -C "$work_dir/gitops" push local main

if git -C "$gitops_dir" remote get-url local >/dev/null 2>&1; then
  git -C "$gitops_dir" remote set-url local "$gitea_push_url"
else
  git -C "$gitops_dir" remote add local "$gitea_push_url"
fi
git -C "$gitops_dir" fetch local main
git -C "$gitops_dir" reset --hard local/main >/dev/null

git -C "$app_dir" remote get-url local >/dev/null 2>&1 \
  || git -C "$app_dir" remote add local "http://$gitea_user:$gitea_password@localhost:3000/$gitea_user/pulse-api.git"
git -C "$app_dir" push local main

echo "Seeded $gitea_git_url and http://gitea.local:3000/local/pulse-api.git"
