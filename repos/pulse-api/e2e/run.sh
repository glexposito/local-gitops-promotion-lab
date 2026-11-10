#!/bin/sh
# Entrypoint of the e2e image. Kargo's verification passes the base URL as
# the only argument (and as BASE_URL); Playwright would read a bare argument
# as a test filter, so turn it into BASE_URL here.
set -eu
export BASE_URL="${1:-${BASE_URL:?usage: run.sh <base-url>}}"
echo "Running pulse-api e2e against $BASE_URL"
exec npx playwright test
