# local-gitops-promotion-lab

An entirely local GitOps promotion lab. `repos/` deliberately mirrors the
two repositories that would exist separately in a real setup. They are kept
together here only so the lab can boot without external services; Gitea plays
the role of GitHub for the complete local flow.

```text
local-gitops-promotion-lab/       # this template repository
└── repos/
    ├── gitops/                   # independent Git repo → Gitea local/gitops
    └── pulse-api/                # independent Git repo → Gitea local/pulse-api
```

`repos/` itself is just a folder. On first startup, `local-bootstrap` runs
`git init` inside each child directory, creates its initial commit, and pushes
it to Gitea. From then on, `local/gitops` and `local/pulse-api` have separate
histories; the outer repository only supplies their starting files, never
their commits.

## What happens

1. Edit and commit `repos/pulse-api/`.
2. The Compose publisher pushes that commit to Gitea and builds the app plus
   its Playwright test image into the local registry.
3. Kargo discovers the paired images, promotes the same build through
   internal → stg → prod, and commits each promoted digest to `local/gitops`.
4. Argo CD sees those GitOps commits and deploys them. Each stage's tests run
   from the management cluster before Kargo promotes to the next stage.

```text
repos/pulse-api → Gitea + registry → Kargo → repos/gitops → Argo CD → clusters
```

## First start

Prerequisite: Docker Desktop or Docker Engine with modern Compose. Git is only
needed if you want to commit from a terminal; all setup tooling runs in
containers. The local account is deliberately insecure and only for this
disposable lab: `local` / `local-123`.

```bash
docker compose up -d
```

The first startup takes a few minutes. `local-bootstrap` runs inside Compose:
it initializes `repos/gitops/` and `repos/pulse-api/` as separate Git
repositories and creates their Gitea remotes before Argo CD's bootstrap can run. No host shell
script, Git, curl, or Perl is required. Open Gitea at http://localhost:3000,
Argo CD at https://localhost:9000, and Kargo at https://localhost:9001. Argo
CD and Kargo both use `admin` / `123`; accept their self-signed certificate.

## Trigger a release

```bash
cd repos/pulse-api
git add README.md
git commit -m 'Document the first local release'
cd ../..
docker compose --profile publish run --rm pulse-api-publisher
```

The publisher requires a clean, committed worktree so the image tag always
matches the commit Kargo promotes. It runs in a disposable Compose container
and uses Docker Desktop's/Engine's daemon to build and push. It replaces
GitHub Actions for this POC; adding a Gitea Actions runner later is a swap at
this one build/publish step, not a change to the GitOps or promotion flow.

## Reset

This erases the local clusters, Gitea data, and registry images. Remove the
nested Git metadata only when you intentionally want fresh local histories;
the visible starting files in `repos/` remain in place.

```bash
docker compose down -v
rm -rf repos/gitops/.git repos/pulse-api/.git
```

The Docker Compose project is intentionally fixed, so this lab cannot run at
the same time as the earlier `gitops-poc` stack using the same ports and
container names.
