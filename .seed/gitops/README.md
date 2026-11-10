# gitops

This is the GitOps repository used at runtime by the local promotion lab. It
is initially created from `.seed/gitops` in the outer
`local-gitops-promotion-lab` template, then pushed to local Gitea as
`local/gitops`.

Argo CD and Kargo consume this repository. Kargo commits the promoted image
digest here; Argo CD observes that commit and deploys it. The application
source lives in the separate `local/pulse-api` repository.

The source template's top-level README explains first boot, publishing a
build, and the relationship between the two repositories.

## Runtime endpoints

- Gitea: http://localhost:3000 (`local` / `local-123`)
- Argo CD: https://localhost:9000 (`admin` / `123`)
- Kargo: https://localhost:9001 (`admin` / `123`)

See [local-only.md](docs/local-only.md) for the local runtime profile, and
the other documents in `docs/` for the promotion and cluster design.
