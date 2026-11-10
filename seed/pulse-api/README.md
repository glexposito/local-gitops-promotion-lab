# pulse-api

`pulse-api` is a small proof of concept for health signals using Axum.

It currently exposes:

- `GET /`
- `GET /hello`
- `GET /live`
- `GET /ready`

The goal is to keep this service minimal and use it as a base for adding OpenTelemetry instrumentation next.

## Pipeline

`.github/workflows/pipeline.yml` only **builds**. Every push to `main` pushes
two images to GHCR with the same `sha-*` tag:

| Image | From | What |
|---|---|---|
| `ghcr.io/glexposito/pulse-api` | `Dockerfile` | The app |
| `ghcr.io/glexposito/pulse-api-e2e` | `e2e/` | Its Playwright tests |

**Promotion is Kargo's job**, in
[gitops-poc](https://github.com/glexposito/gitops-poc): it picks up each new
build, deploys it internal → stg → prod, and before each next stage runs the
e2e image against the pulse-api it just deployed there. Each stage promotes
automatically after the preceding stage's verification passes. See
[gitops-poc/docs/kargo.md](https://github.com/glexposito/gitops-poc/blob/main/docs/kargo.md).

## Local lab publishing

When this source is seeded by `local-gitops-promotion-lab`, GitHub Actions is
not used. Commit in `workspace/pulse-api/`, then run
`./local/publish-pulse-api.sh` from the lab root. It pushes this repository to
local Gitea and publishes the app and e2e images to the local registry for
Kargo to promote.

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
