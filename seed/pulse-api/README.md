# pulse-api

`pulse-api` is a small proof of concept for health signals using Axum.

It currently exposes:

- `GET /`
- `GET /hello`
- `GET /live`
- `GET /ready`

The goal is to keep this service minimal and use it as a base for adding
OpenTelemetry instrumentation next.

## E2E tests

`e2e/` holds Playwright tests (API checks plus one Chromium check). They run
as a Docker image, so you don't need Node or Playwright installed. The image
takes the base URL as its only argument and exits 0 when every test passes.
Run them yourself against a deployed pulse-api:

```bash
docker build -t pulse-api-e2e e2e
docker run --rm --network local-gitops-promotion-lab_k8s-management \
  pulse-api-e2e http://k3s-internal:30080   # or k3s-stg / k3s-prod
```

The `/hostname` test expects a pod name, so it fails against a local
`cargo run`.
