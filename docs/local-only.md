# Local-only lab

This profile removes GitHub from the promotion loop. It runs Gitea as the Git
server and Docker Distribution as the image registry on the same Docker
network as the four k3s clusters.

```
pulse-api checkout
  |  local/publish-pulse-api.sh
  v
registry.local:5000 <-- Kargo Warehouse
  |
  v
Gitea <--- Kargo promotion commits
  |
  v
Argo CD deploys internal -> stg -> prod
```

`pulse-api` remains a separate Git repository. The first boot copies its
`main` branch and this lab's `main` branch into Gitea, where they become the
two local remotes. Subsequent calls to the publisher push the committed
`pulse-api` revision to Gitea before building its matching app and e2e images.

## Start

Prerequisites: Docker with Compose, `git`, `curl`, `perl`, and a sibling
`../pulse-api` checkout. This profile is deliberately local and insecure:
Gitea listens on `localhost:3000` with the seeded `local` / `local-123`
account, and the registry is plain HTTP on `localhost:5000`.

```bash
./local/up.sh ../pulse-api
```

The script starts Gitea and the registry, seeds both repositories, then starts
the clusters. First startup takes a few minutes. Argo CD is at
`https://localhost:9000` and Kargo is at `https://localhost:9001`.

Do not rerun `local/seed-repositories.sh` after promotions have begun: it is a
one-time initializer and intentionally refuses to overwrite an existing local
repository. To reset the lab entirely:

```bash
cd cluster
docker compose -f docker-compose.yaml -f docker-compose.local.yaml --profile local down -v
```

## Publish a build

Commit a change in `pulse-api`, then run:

```bash
./local/publish-pulse-api.sh ../pulse-api
```

The script pushes that commit to local Gitea, builds the app and Playwright
images, tags both `sha-<commit>`, and pushes both to the local registry.
Kargo discovers the pair and promotes it automatically through all stages.

The publisher pushes via `localhost:5000`; Kargo and the k3s nodes use the
same registry through `registry.local:5000`. The local registry is configured
as insecure only inside this disposable Docker network.

## Scope

This removes the need for GitHub repositories, GHCR, and GitHub Actions. The
initial installation still downloads Kargo and other public controller images.
For a fully air-gapped lab, mirror those charts and images into a registry you
control as a separate follow-up.
