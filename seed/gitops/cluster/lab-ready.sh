#!/bin/sh
# Lab readiness: the containers can all be healthy while the lab is still
# minutes from working (Argo CD installing Kargo, Kargo finding the first
# build, the first promotion). This follows those phases, logs each one in
# plain words (docker compose logs -f lab-ready), and touches /tmp/ready once
# pulse-api is deployed and healthy on internal. The Compose healthcheck
# watches that file, so `docker compose up -d --wait` returns only then.
set -u

management() { kubectl --kubeconfig=/kubeconfigs/management/k3s.yaml --server=https://k3s-management:6443 "$@" 2>/dev/null; }

last=""
say() {
  # Log only when the message changes, so the output reads like a timeline.
  if [ "$1" != "$last" ]; then
    echo "$(date +%H:%M:%S) $1"
    last="$1"
  fi
}

app_state() {
  management get application "$1" -n argocd \
    -o jsonpath='{.status.sync.status}/{.status.health.status}'
}

rm -f /tmp/ready
while :; do
  if [ "$(app_state kargo)" != "Synced/Healthy" ]; then
    say "Argo CD is installing Kargo..."
  elif ! management get warehouse pulse-api -n pulse-api >/dev/null; then
    say "Creating the pulse-api Kargo project (Warehouse and Stages)..."
  elif [ -z "$(management get freight -n pulse-api -o name)" ]; then
    reason="$(management get warehouse pulse-api -n pulse-api \
      -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}')"
    say "Waiting for the first pulse-api build to reach the registry (Gitea -> local/pulse-api -> Actions). Kargo: ${reason:-discovering}"
  elif [ "$(app_state pulse-api-internal)" != "Synced/Healthy" ]; then
    failed="$(management get promotions -n pulse-api \
      -o jsonpath='{range .items[?(@.status.phase=="Errored")]}{.status.message}{"\n"}{end}' | tail -1)"
    if [ -n "$failed" ]; then
      say "Promotion to internal failed, Kargo will retry: $failed"
    else
      say "Kargo is promoting the first build to internal..."
    fi
  else
    if [ ! -f /tmp/ready ]; then
      touch /tmp/ready
      say "Lab ready. pulse-api runs on internal; Kargo promotes it on to stg and prod."
      echo "  Gitea:   http://localhost:3000  (local / local-123)"
      echo "  Argo CD: https://localhost:9000 (admin / 123)"
      echo "  Kargo:   https://localhost:9001 (admin / 123)"
    fi
  fi
  sleep 5
done
