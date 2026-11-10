# Promotion with Kargo

Kargo promotes pulse-api through internal → stg → prod. Each environment runs
one `pulse-api` deployment (`pulse-api-<stage>`, namespace `pulse-api`, port
30080). Kargo deploys a build, then runs that build's Playwright tests against
that deployment. Only a verified build may move to the next stage.

Kargo UI: **https://localhost:9001** (`admin` / `123`).

## How it works

```text
repos/pulse-api commit
  │
  ├─ bootstrap/publish-pulse-api.sh pushes local/pulse-api to Gitea
  └─ builds and pushes the matching app + e2e images to registry.local:5000
       │
       ▼
Warehouse creates Freight from the matching sha-<commit> pair
       │
       ▼
internal deploy + test → stg deploy + test → prod deploy + test
       │
       ▼
Kargo commits each promoted digest to local/gitops; Argo CD syncs that commit
```

The tests run as a Job on the management cluster (Argo Rollouts analysis).
`e2e-playwright` receives `http://k3s-<stage>:30080` and succeeds only when
the just-deployed build passes. Nothing else is deployed for testing.

## Layout: written once, one file per app

```text
kargo/
  shared/                        # every app uses these, cluster-wide
    promote-kustomize-app.yaml   # set digest, commit, push, argocd-update
    e2e-basic.yaml               # small pod (bash/curl tests)
    e2e-playwright.yaml          # Playwright verification Job
  chart/                         # renders one app's Project, Warehouse, Stages
  apps/
    pulse-api.yaml               # the only per-app Kargo config
```

| Argo CD (`argocd/`)                 | Creates                                                   |
| ----------------------------------- | --------------------------------------------------------- |
| `kargo/shared.yaml`                 | `kargo/shared/` on management                             |
| `kargo/apps.yaml`                   | `kargo-<project>`: one chart instance per app file        |
| `appsets/kargo-apps-workloads.yaml` | `<app>-<stage>` per app and workload cluster              |

The Git credential is shared in `kargo-shared-resources`, which every Kargo
Project falls back to.

## Local profile setup

There is no GitHub deploy key, GitHub package, or external image registry in
this profile. `bootstrap/up.sh` creates Gitea's `local` user and repositories,
and the Compose override gives the bootstrap container Gitea HTTP credentials.
It creates Kargo's `gitops-poc-git` credential from those values.

The registry is intentionally plain HTTP within this disposable Docker
network. `cluster/registries.yaml` configures the k3s nodes and
`registryInsecure: true` lets the Kargo Warehouse discover images from it.
Neither setting is suitable for a shared environment.

## Adding an app

1. Add its Kustomize manifests: `apps/<app>/base` plus `overlays/<stage>`.
2. Add its namespace on each cluster and an Argo CD AppProject that permits
   it.
3. Ensure the publisher creates `<image>:sha-*` and `<image>-e2e:sha-*`.
4. Add `kargo/apps/<app>.yaml`:

```yaml
project: orders
app: orders-api
argocdProject: orders
image: registry.local:5000/orders-api
e2eImage: registry.local:5000/orders-api-e2e
port: 30082
verification: [e2e-basic]
registryInsecure: true
```

Every option and default is documented in `kargo/chart/values.yaml`.

## Choosing how an app is tested

The e2e image owns the test implementation: its entrypoint takes the base URL
and exits 0 when every test passes. Bash, Playwright, and `dotnet test` are
different images with the same Kargo integration. Choose the templates per
app or per stage:

```yaml
verification: [e2e-playwright]

verification:
  internal: [e2e-basic]
  stg: [e2e-basic, e2e-playwright]
  prod: [e2e-basic]
```

A new type of test (load tests, or a Prometheus error-rate check) is a new
template in `kargo/shared/`. The test source for pulse-api is in its separate
`repos/pulse-api/e2e/` repository. Results remain in the verification Job's
logs; this POC has no artifact storage.

## Try it

1. Commit a change in `repos/pulse-api/`.
2. From the outer template root, run `./bootstrap/publish-pulse-api.sh`.
3. Within a few minutes a new Freight appears in the Kargo UI and moves
   through internal, stg, and prod automatically.
4. Each promotion creates a `pulse-api: promote sha-… to <stage>` commit in
   Gitea's `local/gitops` repository.

On a fresh cluster the `pulse-api-*` applications are Missing/OutOfSync until
their first promotion: auto-sync is off, so only Kargo deploys them.

```bash
# What Kargo knows on the management cluster
docker exec k3s-management kubectl -n pulse-api get freight,stages
# E2E logs of the latest verification
docker exec k3s-management kubectl -n pulse-api get jobs
docker exec k3s-management kubectl -n pulse-api logs job/<name>
# pulse-api on prod
curl localhost:8083/hostname
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| No Freight | Confirm both images were pushed with the same `sha-*` tag; click **Refresh** on the Warehouse rather than waiting for its poll. |
| `kargo` app keeps retrying | Normal on a fresh cluster until cert-manager is up. |
| `kargo-shared` / `kargo-<project>` retrying | Normal until the Kargo and Rollouts CRDs exist. |
| Promotion fails at `git-push` | Confirm the generated GitOps repo still has the local Gitea remote and the `gitops-poc-git` secret exists in `kargo-shared-resources`. |
| `argocd-update` not authorized | The Application needs `kargo.akuity.io/authorized-stage: <project>:<stage>` in `argocd/appsets/kargo-apps-workloads.yaml`. |
| Verification fails | Read the Job logs; Playwright prints one line per test. |
| Playwright Job OOMKilled | Raise memory in `kargo/shared/e2e-playwright.yaml`. |
