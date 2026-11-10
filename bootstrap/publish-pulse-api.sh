#!/bin/sh
# Runs inside the Compose publisher container, never on the host.
set -eu

app_dir=/lab/repos/pulse-api
gitea_push_url=http://local:local-123@gitea:3000/local/pulse-api.git
registry=localhost:5000

if [ ! -d "$app_dir/.git" ]; then
  echo 'pulse-api checkout not found. Start the lab first.' >&2
  exit 1
fi

git config --global --add safe.directory "$app_dir"
if [ -n "$(git -C "$app_dir" status --porcelain)" ]; then
  echo 'Commit or discard pulse-api changes before publishing.' >&2
  exit 1
fi

git -C "$app_dir" push "$gitea_push_url" main
tag="sha-$(git -C "$app_dir" rev-parse --short=7 HEAD)"

docker build -t "$registry/pulse-api:$tag" "$app_dir"
docker build -t "$registry/pulse-api-e2e:$tag" "$app_dir/e2e"
docker push "$registry/pulse-api:$tag"
docker push "$registry/pulse-api-e2e:$tag"

echo "Published $tag. Kargo will discover it as registry.local:5000/pulse-api."
