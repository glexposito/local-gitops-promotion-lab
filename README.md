# local-gitops-promotion-lab

An entirely local GitOps promotion lab. It simulates two repositories that
would exist separately in a real setup. Gitea plays the role of GitHub, so the
complete flow runs without external services.

```text
local-gitops-promotion-lab/       # this repository (GitHub)
├── seed/                         # tracked: starting files, the template
│   ├── gitops/
│   └── pulse-api/
└── repos/                        # gitignored: your working repos (Gitea)
    ├── gitops/                   # → Gitea local/gitops
    └── pulse-api/                # → Gitea local/pulse-api
```

**`seed/` vs `repos/`.** Each folder belongs to exactly one Git history:

| Folder | Owned by | You edit it to... |
|---|---|---|
| `seed/` | this repository (GitHub) | change the lab's starting state for everyone |
| `repos/` | Gitea (`local/gitops`, `local/pulse-api`) | work in the running lab: release, promote, experiment |

On first startup `local-bootstrap` copies `seed/gitops` and `seed/pulse-api`
into `repos/`, runs `git init` in each, rewrites the GitOps URLs to point at
Gitea and the local registry, and pushes both to Gitea. `repos/` is never
overwritten after that, so your commits and Kargo's promotion commits stay
there and never show up as changes in this repository.

## What happens

1. Edit and commit in `repos/pulse-api/`.
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
docker compose up -d --build --wait
```

`--wait` returns only when the lab actually works, which takes about 5
minutes on a first start. Healthy containers are not enough: after they are
up, Argo CD still installs Kargo, Gitea Actions builds the first image, and
Kargo promotes it. The `lab-ready` service follows those phases and turns
healthy once pulse-api runs on internal. To watch progress, in another
terminal:

```bash
docker compose logs -f lab-ready
```

```text
10:01:12 Argo CD is installing Kargo...
10:03:40 Creating the pulse-api Kargo project (Warehouse and Stages)...
10:03:52 Waiting for the first pulse-api build to reach the registry ...
10:04:30 Kargo is promoting the first build to internal...
10:05:10 Lab ready. pulse-api runs on internal; Kargo promotes it on to stg and prod.
```

Until then, Argo CD showing the pulse-api apps as OutOfSync / Missing and
Kargo showing an incomplete pipeline is normal. `docker compose ps lab-ready`
shows `health: starting`, `healthy`, or, after 20 minutes without success,
`unhealthy`; the last log line then says where it got stuck.

Under the hood, `local-bootstrap` copies `seed/` into `repos/`, initializes
`repos/gitops/` and `repos/pulse-api/` as separate Git repositories, creates
their Gitea remotes, and starts the local Gitea Actions runner. No host shell
script, Git, curl, or Perl is required. Open Gitea at http://localhost:3000
(`local` / `local-123`), Argo CD at https://localhost:9000, and Kargo at
https://localhost:9001. Argo CD and Kargo both use `admin` / `123`; accept
their self-signed certificate.

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

This erases the local clusters, Gitea data, registry images, and your working
repositories. The next `docker compose up -d` copies a fresh set from `seed/`.

```bash
docker compose down -v
rm -rf repos
```

Always reset both together: deleting only `repos/` leaves Gitea with a history
the new copies cannot push to, and wiping only Gitea leaves `repos/` pointing
at repositories that no longer exist.

The Docker Compose project is intentionally fixed, so this lab cannot run at
the same time as the earlier `gitops-poc` stack using the same ports and
container names.
