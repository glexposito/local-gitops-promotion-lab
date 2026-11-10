#!/bin/sh
# Entrypoint of the e2e image. Kargo's verification passes the base URL as
# the only argument (and as BASE_URL); Playwright would read a bare argument
# as a test filter, so turn it into BASE_URL here.
#
# When Kargo also passes COMMIT_STATUS_URL, STAGE and COMMIT (sha-<short>),
# the result is reported as the commit status deploy/<stage> on the commit
# this build came from, so the source repo shows whether each deployment
# passed. Without them (e.g. a manual docker run) nothing is reported.
set -eu
export BASE_URL="${1:-${BASE_URL:?usage: run.sh <base-url>}}"

report() {
  [ -n "${COMMIT_STATUS_URL:-}" ] && [ -n "${STAGE:-}" ] && [ -n "${COMMIT:-}" ] || return 0
  curl -fsS -o /dev/null -X POST -H 'Content-Type: application/json' \
    -d "{\"state\":\"$1\",\"context\":\"deploy/$STAGE\",\"description\":\"$2\",\"target_url\":\"$BASE_URL\"}" \
    "$COMMIT_STATUS_URL/${COMMIT#sha-}" \
    || echo "warning: could not report deploy/$STAGE commit status" >&2
}

echo "Running pulse-api e2e against $BASE_URL"
report pending "Deployed to ${STAGE:-?}, running e2e"
if npx playwright test; then
  report success "Deployed to ${STAGE:-?}, e2e passed"
else
  rc=$?
  report failure "Deployed to ${STAGE:-?}, e2e failed"
  exit "$rc"
fi
