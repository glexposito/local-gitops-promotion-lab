#!/bin/sh
# Runs inside the Compose bootstrap container, never on the host.
set -eu

# The bind-mounted worktrees belong to the host user, while this container
# runs as root. Without this, Git rejects them as dubious ownership.
git config --global --add safe.directory "*"

lab_root=/lab
gitops_dir="$lab_root/repos/gitops"
app_dir="$lab_root/repos/pulse-api"
gitea_api=http://gitea:3000
gitea_user=local
gitea_password=local-123
host_git_base="http://$gitea_user:$gitea_password@localhost:3000/$gitea_user"
container_git_base="http://$gitea_user:$gitea_password@gitea:3000/$gitea_user"

wait_for_gitea() {
  until curl --fail --silent --output /dev/null "$gitea_api/api/healthz"; do
    sleep 2
  done
}

create_repo() {
  name="$1"
  status="$(curl --silent --output /dev/null --write-out '%{http_code}' \
    --user "$gitea_user:$gitea_password" \
    --header 'Content-Type: application/json' \
    --data "{\"name\":\"$name\",\"private\":false}" \
    "$gitea_api/api/v1/user/repos")"
  case "$status" in
    201|409|422) ;;
    *) echo "Unable to create or find Gitea repository $name (HTTP $status)." >&2; exit 1 ;;
  esac
}

enable_actions() {
  name="$1"
  status="$(curl --silent --output /dev/null --write-out '%{http_code}' \
    --request PATCH \
    --user "$gitea_user:$gitea_password" \
    --header 'Content-Type: application/json' \
    --data '{"has_actions":true}' \
    "$gitea_api/api/v1/repos/$gitea_user/$name")"
  case "$status" in
    200) ;;
    *) echo "Unable to enable Gitea Actions for $name (HTTP $status)." >&2; exit 1 ;;
  esac
}

init_repo() {
  target="$1"
  message="$2"
  if [ ! -d "$target" ]; then
    echo "Expected repository directory $target is missing" >&2
    exit 1
  fi
  git -C "$target" init --initial-branch=main >/dev/null
  git -C "$target" config user.name local-bootstrap
  git -C "$target" config user.email local-bootstrap@localhost
  git -C "$target" add -A
  git -C "$target" commit -m "$message" >/dev/null
}

configure_gitops() {
  if git -C "$gitops_dir" remote get-url local >/dev/null 2>&1; then
    return
  fi

  find "$gitops_dir" -path '*/.git' -prune -o -type f -print0 \
    | xargs -0 perl -pi -e 's#git\@github\.com:glexposito/local-gitops-promotion-lab\.git#http://gitea.local:3000/local/gitops.git#g; s#https://github\.com/glexposito/local-gitops-promotion-lab\.git#http://gitea.local:3000/local/gitops.git#g; s#ghcr\.io/glexposito/pulse-api-e2e#registry.local:5000/pulse-api-e2e#g; s#ghcr\.io/glexposito/pulse-api#registry.local:5000/pulse-api#g'
  if ! grep -q '^registryInsecure: true$' "$gitops_dir/kargo/apps/pulse-api.yaml"; then
    perl -0pi -e 's#(e2eImage: registry\.local:5000/pulse-api-e2e\n)#$1registryInsecure: true\n#' "$gitops_dir/kargo/apps/pulse-api.yaml"
  fi
  git -C "$gitops_dir" add -A
  if ! git -C "$gitops_dir" diff --cached --quiet; then
    git -C "$gitops_dir" commit -m 'Configure the local Gitea and registry' >/dev/null
  fi
  git -C "$gitops_dir" remote add local "$host_git_base/gitops.git"
  git -C "$gitops_dir" push "$container_git_base/gitops.git" main
}

configure_app() {
  if git -C "$app_dir" remote get-url local >/dev/null 2>&1; then
    return
  fi
  git -C "$app_dir" remote add local "$host_git_base/pulse-api.git"
  git -C "$app_dir" push "$container_git_base/pulse-api.git" main
}

if [ ! -d "$gitops_dir/.git" ]; then
  init_repo "$gitops_dir" 'Initial GitOps state'
fi

if [ ! -d "$app_dir/.git" ]; then
  init_repo "$app_dir" 'Initial pulse-api release'
fi

if [ ! -d "$gitops_dir/.git" ] || [ ! -d "$app_dir/.git" ]; then
  echo "Both repos/gitops/.git and repos/pulse-api/.git must exist." >&2
  exit 1
fi

wait_for_gitea
create_repo gitops
create_repo pulse-api
enable_actions pulse-api
configure_gitops
configure_app

# Docker bind mounts would otherwise leave the generated worktrees owned by
# root on Linux. Docker Desktop handles this transparently on Windows/macOS.
owner="$(stat -c '%u:%g' "$lab_root")"
chown -R "$owner" "$gitops_dir" "$app_dir"

echo 'Local Gitea repositories are ready: local/gitops and local/pulse-api.'
