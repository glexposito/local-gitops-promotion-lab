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

`seed/pulse-api/` is a version-one source snapshot tracked by this lab's
GitHub repository. On first boot it is copied to `workspace/pulse-api/`, where
the setup creates an independent Git repository and its first commit. Gitea
then hosts that repository as `local/pulse-api`; the lab's own Git history and
the application's Git history are separate from that point on.

These similarly named paths have distinct purposes:

| Path | Purpose | Git history |
| --- | --- | --- |
| `apps/pulse-api/` | Kustomize deployment manifests | lab / GitOps repository |
| `seed/pulse-api/` | version-one application source distributed with the lab | lab repository only |
| `workspace/pulse-api/` | editable application worktree created at first boot | independent local `pulse-api` repository |

## Start

Prerequisites: Docker with Compose, `git`, `curl`, and `perl`. This profile is
deliberately local and insecure:
Gitea listens on `localhost:3000` with the seeded `local` / `local-123`
account, and the registry is plain HTTP on `localhost:5000`.

```bash
./local/up.sh
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

Edit and commit a change in the generated application worktree, then run:

```bash
cd workspace/pulse-api
git add . && git commit -m 'Change pulse-api'
cd ../..
./local/publish-pulse-api.sh
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
