# Local-only lab

This profile removes GitHub from the promotion loop. It runs Gitea as the Git
server and Docker Distribution as the image registry on the same Docker
network as the four k3s clusters.

```
pulse-api checkout
  |  docker compose --profile publish run pulse-api-publisher
  v
registry.local:5000 <-- Kargo Warehouse
  |
  v
Gitea <--- Kargo promotion commits
  |
  v
Argo CD deploys internal -> stg -> prod
```

The outer `local-gitops-promotion-lab` template holds version-one source
snapshots. On first boot it creates this GitOps repository in `gitops/` and an
independent application repository in `repos/pulse-api/`. Gitea then hosts
them as `local/gitops` and `local/pulse-api`; their histories are separate
from that point on.

These similarly named paths have distinct purposes:

| Path | Purpose | Git history |
| --- | --- | --- |
| `apps/pulse-api/` | Kustomize deployment manifests | `local/gitops` |
| `../repos/pulse-api/` | editable application worktree | `local/pulse-api` |

## Start

Prerequisite: Docker Desktop or Docker Engine with modern Compose. Git is only
needed to commit from a terminal; the setup tooling stays in containers. This
profile is deliberately local and insecure:
Gitea listens on `localhost:3000` with the seeded `local` / `local-123`
account, and the registry is plain HTTP on `localhost:5000`.

```bash
docker compose up -d
```

The `local-bootstrap` Compose service creates the two local Git repositories,
seeds Gitea, and exits before Argo CD's bootstrap can start. First startup
takes a few minutes. Argo CD is at `https://localhost:9000` and Kargo is at
`https://localhost:9001`.

The bootstrap is idempotent after a successful first run: it keeps the
repositories, Gitea data, and promotion history. To reset the lab entirely:

```bash
docker compose down -v
```

## Publish a build

Edit and commit a change in the generated application worktree, then run:

```bash
cd repos/pulse-api
git add . && git commit -m 'Change pulse-api'
cd ../..
docker compose --profile publish run --rm pulse-api-publisher
```

The publisher service pushes that commit to local Gitea, builds the app and
Playwright images, tags both `sha-<commit>`, and pushes both to the local registry.
Kargo discovers the pair and promotes it automatically through all stages.

The publisher pushes via `localhost:5000`; Kargo and the k3s nodes use the
same registry through `registry.local:5000`. The local registry is configured
as insecure only inside this disposable Docker network.

## Scope

This removes the need for GitHub repositories, GHCR, and GitHub Actions. The
initial installation still downloads Kargo and other public controller images.
For a fully air-gapped lab, mirror those charts and images into a registry you
control as a separate follow-up.
