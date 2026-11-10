# local-gitops-promotion-lab

An entirely local GitOps promotion lab. The GitHub repository only distributes
the bootstrap and version-one templates. At runtime it creates two separate
local Git repositories and hosts them in Gitea:

```text
local-gitops-promotion-lab/       # this template repository
├── gitops/                       # independent Git repo → Gitea local/gitops
└── repos/
    └── pulse-api/                # independent Git repo → Gitea local/pulse-api
```

`repos/` is just a folder, not a Git repository. The outer repository ignores
both generated worktrees, so their histories and commits cannot leak into the
template repository.

## What happens

1. Edit and commit `repos/pulse-api/`.
2. `bootstrap/publish-pulse-api.sh` pushes that commit to Gitea and builds the
   app plus its Playwright test image into the local registry.
3. Kargo discovers the paired images, promotes the same build through
   internal → stg → prod, and commits each promoted digest to `local/gitops`.
4. Argo CD sees those GitOps commits and deploys them. Each stage's tests run
   from the management cluster before Kargo promotes to the next stage.

```text
repos/pulse-api → Gitea + registry → Kargo → gitops → Argo CD → clusters
```

## First start

Prerequisites: Docker Compose, Git, curl, and Perl. The local account is
deliberately insecure and only for this disposable lab: `local` / `local-123`.

```bash
./bootstrap/up.sh
```

The first startup takes a few minutes. Open Gitea at http://localhost:3000,
Argo CD at https://localhost:9000, and Kargo at https://localhost:9001. Argo
CD and Kargo both use `admin` / `123`; accept their self-signed certificate.

## Trigger a release

```bash
cd repos/pulse-api
git add README.md
git commit -m 'Document the first local release'
cd ../..
./bootstrap/publish-pulse-api.sh
```

The publisher requires a clean, committed worktree so the image tag always
matches the commit Kargo promotes. It replaces GitHub Actions for this POC;
adding a Gitea Actions runner later is a swap at this one build/publish step,
not a change to the GitOps or promotion flow.

## Reset

This erases the local clusters, Gitea data, registry images, and the generated
worktrees. Remove the worktrees only when you intentionally want new local Git
histories.

```bash
cd gitops/cluster
docker compose -f docker-compose.yaml -f docker-compose.local.yaml --profile local down -v
cd ../..
rm -rf gitops repos
```

The Docker Compose project is intentionally fixed, so this lab cannot run at
the same time as the earlier `gitops-poc` stack using the same ports and
container names.
