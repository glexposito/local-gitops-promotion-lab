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

`e2e/` holds Playwright tests (API checks plus one Chromium check). The image
takes the base URL as its argument and exits 0 when every test passes. Run
them yourself against a deployed pulse-api:

```bash
cd e2e && npm ci && npx playwright install chromium
BASE_URL=http://localhost:8081 npx playwright test   # internal
```

The `/hostname` test expects a pod name, so it fails against a local
`cargo run`.
