# pulse-api

`pulse-api` is a small proof of concept for health signals using Axum.

It currently exposes:

- `GET /`
- `GET /hello`
- `GET /live`
- `GET /ready`

The goal is to keep this service minimal and use it as a base for adding
OpenTelemetry instrumentation next.

## Local lab publishing

On first start, the local bootstrap initializes this directory as the
independent `local/pulse-api` repository in Gitea. The local lab's publisher
builds two images with the same `sha-*` tag:

| Image | From | What |
|---|---|---|
| `registry.local:5000/pulse-api` | `Dockerfile` | The app |
| `registry.local:5000/pulse-api-e2e` | `e2e/` | Its Playwright tests |

Promotion is Kargo's job in the separate `local/gitops` repository: it picks
up each new build, deploys it internal → stg → prod, and before each next
stage runs the e2e image against the pulse-api it just deployed there. Each
stage promotes automatically after the preceding stage's verification passes.

Commit in `repos/pulse-api/`, then run
`docker compose --profile publish run --rm pulse-api-publisher` from the lab
root. The publisher container pushes this
repository to local Gitea and publishes the app and e2e images to the local
registry for Kargo to promote. It is intentionally the small local stand-in
for a CI runner; no GitHub account or GitHub Actions is involved.

## E2E tests

`e2e/` holds Playwright tests (API checks plus one Chromium check). The image
takes the base URL as its argument and exits 0 when every test passes. Run
them yourself against a deployed pulse-api:

```bash
cd e2e && npm ci && npx playwright install chromium
BASE_URL=http://localhost:8081 npx playwright test   # internal
```

The `/hostname` test expects a pod name, so it fails against a local
`cargo run`.

## Pipeline test

Test commit to build a new image and promote it internal → stg → prod.

- Local time: 2026-11-07 15:24:53 NZDT (+1300)
- Commit time: 2026-11-07 15:24:53 NZDT (+1300)
- Kargo test: Tue 10 Nov 2026 19:05:13 NZDT
- Kargo test: Tue 10 Nov 2026 19:52:09 NZDT
- Kargo test: Tue 10 Nov 2026 20:00:32 NZDT
