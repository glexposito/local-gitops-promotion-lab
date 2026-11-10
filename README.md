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
2. Push that commit to Gitea. Its local Gitea Actions runner builds the app
   plus its Playwright test image into the local registry.
3. Kargo discovers the paired images, promotes the same build through
   internal → stg → prod, and commits each promoted digest to `local/gitops`.
4. Argo CD sees those GitOps commits and deploys them. Each stage's tests run
   from the management cluster before Kargo promotes to the next stage.

```text
repos/pulse-api → Gitea Actions + registry → Kargo → repos/gitops → Argo CD → clusters
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
repositories, creates their Gitea remotes, and starts the local Gitea Actions
runner. No host shell script, Git, curl, or Perl is required. Open Gitea at http://localhost:3000,
Argo CD at https://localhost:9000, and Kargo at https://localhost:9001. Argo
CD and Kargo both use `admin` / `123`; accept their self-signed certificate.

## Trigger a release

```bash
cd repos/pulse-api
git commit --allow-empty -m "Trigger local release"
git push local main
```

Git records the trigger time portably on Windows and Linux. View it with
`git show -s --format=%cI HEAD`. `--allow-empty` intentionally creates a new
commit even when no files changed; pushing that commit is the release trigger.
Gitea Actions runs the workflow—there is no per-release `docker compose`
command. Watch it in Gitea at **local/pulse-api → Actions**.

The workflow tags both images with `sha-<commit>`, so the image Kargo promotes
always maps to the pushed source commit.

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
