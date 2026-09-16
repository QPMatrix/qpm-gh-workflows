# Workflow reference

Seven reusable `workflow_call` workflows live in `.github/workflows/`:
four language gates, the generic `check-gate.yml`, `image-publish.yml`,
and `semver-tag.yml`. The gates are PR-only (ADR-031 a–e); callers own
the triggers and concurrency. `self-test.yml` exercises fixtures and
release helpers — see "Self-test" below.

## The gate workflows: `rust-gate.yml`, `go-gate.yml`, `python-gate.yml`, `ts-gate.yml`

Each declares three parallel jobs — `format-lint`, `test`, `image` — plus
a leading `changes` job that detects a docs-only diff (ADR-031 c) so every
downstream job's real-work steps can skip while the job itself still
reports success. Every job that does real work calls the caller repo's own
`./check <stage>` (`fmt`, `lint`, `test`, or `image`) — the reusable
workflow installs the language toolchain, its cache, and (when
`scripts/install-buf.sh` exists in the caller) buf/protoc-plugin binaries;
it never encodes repo-specific build logic itself, that stays in `./check`.

Common inputs:

| Input | Type | Default | Meaning |
| --- | --- | --- | --- |
| `private-deps` | string | `""` | Comma/newline QPMatrix repo names this repo fetches over git (the mandatory `qpai-skills` source included by the caller). Empty skips the App-token mint entirely. |
| `working-directory` | string | `"."` | Where the caller's project lives, relative to repo root. Real callers leave this alone; `self-test.yml` points it at a fixture. |
| `runner` | string | `""` | Runner label for every job; empty falls through to the caller repo's `QPM_RUNNER` variable, then `ubuntu-latest` — README "Runners". |

`rust-gate.yml` also takes `cargo-deny-version` (default `0.20.2`) and
`runner_heavy` (default `""`, the cargo jobs' runner — README "Runners");
`python-gate.yml` also takes `python-version-file` (default
`.python-version`).

### Caller secrets

**For every gate, a caller with non-empty `private-deps` must put
`secrets: inherit` on the calling job**, alongside `uses:` and `with:`
(as in the example below). The caller must have both
`QPASSISTANCE_CLIENT_ID` and `QPASSISTANCE_PRIVATE_KEY` available.
Alternatively, explicitly map those two names under the calling job's
`secrets:`. Without them, the App-token mint fails. Callers with empty
`private-deps` need no secrets; this is why the gates do not declare
unconditionally required secrets.

The local fixture calls use empty `private-deps`, so they do not test
cross-repository secret forwarding or the App-token mint. A green
self-test does not prove a consumer passed its secrets correctly.

A private git dependency can be spelled three ways —
`https://github.com/QPMatrix/<repo>.git`, `ssh://git@github.com/QPMatrix/<repo>.git`,
and the scp-like `git@github.com:QPMatrix/<repo>.git` — and a caller's
package manager does not always pick the form the caller wrote: Bun
resolves a `git+ssh://` dependency by trying an https clone first and
the ssh form second (reproduced 2026-09-16 against qpai-core's private
dependency), so an https-only rewrite authenticates the first attempt
and leaves the second to fail with `Permission denied (publickey)`.
Every "Configure git auth for QPMatrix" step in this repo's gate
workflows therefore rewrites all three forms to the same
`https://x-access-token:<tok>@github.com/QPMatrix/` target. A caller
that does its own git rewrite instead — a Dockerfile building with
BuildKit, for instance, which gets the token as a build secret rather
than an already-configured git — must cover the same three URL forms,
not just https, or it will fail the identical way for an ssh-form
dependency.

### The thin-caller `ci.yml` shape

```yaml
name: ci
on:
  pull_request:
  workflow_dispatch:
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
permissions:
  contents: read
jobs:
  gate:
    uses: QPMatrix/qpm-gh-workflows/.github/workflows/rust-gate.yml@v1
    with:
      private-deps: qpm-rs-service,qpm-rs-auth,qpsb-contracts,qpai-skills
    secrets: inherit
```

`repo-birth`'s `birth.py` and `repo-instructions`' `instructions.py
wire-gate` emit exactly this shape (substituting the language-appropriate
gate file and the repo's own derived `private-deps` list) — see those
skills for how the list is derived per language.

## `check-gate.yml` — generic gate

For repositories such as qpai-skills, qpai-architecture, and qpai-infra,
whose complete gate is `./check`. It takes the same `private-deps`,
`working-directory`, and `runner` inputs above. The `changes` job uses
the language gates' docs-only detection; the `check` job checks out the
caller, configures optional private-dependency git authentication, and
runs exactly `./check` with no arguments. Docs-only changes skip the
real-work steps while the job still reports success.

It installs no toolchain or CI tools and supplies no dependency cache.
The runner must already provide a POSIX shell, git, and **python3**;
`ubuntu-latest` includes them, and custom runners must be provisioned
accordingly. The caller's `./check` owns further setup and dependencies.

```yaml
name: ci
on:
  pull_request:
  workflow_dispatch:
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
permissions:
  contents: read
jobs:
  gate:
    uses: QPMatrix/qpm-gh-workflows/.github/workflows/check-gate.yml@v1
    with:
      private-deps: qpai-skills
    secrets: inherit
```

Use a release tag that contains `check-gate.yml`; the example requires
publishing this workflow in `v1` before consumers adopt it.

## `image-publish.yml` — CD

Called from a caller's `cd.yml` on `push: [main]` only, warm from the
gate's own `type=gha` BuildKit cache. Builds, pushes to GHCR, signs
KEYLESS with cosign (the job's own OIDC token as identity — no signing
key exists anywhere), verifies its own signature, and writes the digest
to the job summary and the `digest` workflow output.

| Input | Type | Default | Meaning |
| --- | --- | --- | --- |
| `image` | string | required | Full GHCR path, e.g. `ghcr.io/qpmatrix/qp-gateway`. |
| `dockerfile` | string | `Dockerfile` | Path to the Dockerfile. |
| `context` | string | `.` | Build context. |
| `platforms` | string | `linux/amd64` | Comma-separated buildx platform list. |
| `private-deps` | string | `""` | Same shape as the gate workflows — exposed to the build as BOTH `qpmatrix_token` and `qpsecondbrain_token` BuildKit secrets (both resolve to the same minted token since the QPMatrix org merge; an unreferenced id is simply unused). |
| `version` | string | `""` | Bare semver (no leading `v`, e.g. `"0.1.1"`) from `semver-tag.yml`'s `version` output — spec 002-versioned-auto-deploy T-001. Empty (every caller not yet migrated) renders `tags: main-{{sha}}` + `latest`, byte-identical to before this input existed. A non-empty value replaces that with `v<version>` + `latest` for that run only. |
| `runner` / `runner_heavy` | string | `""` | The publish job's runner: `runner_heavy`, then `QPM_RUNNER_HEAVY`, then `runner` / `QPM_RUNNER`, then `ubuntu-latest` — README "Runners". |

### The thin-caller `cd.yml` shape

```yaml
name: cd
on:
  push:
    branches: [main]
concurrency:
  group: cd-${{ github.ref }}
  cancel-in-progress: true
permissions:
  contents: read
  packages: write
  id-token: write
jobs:
  publish:
    uses: QPMatrix/qpm-gh-workflows/.github/workflows/image-publish.yml@v1
    with:
      image: ghcr.io/qpmatrix/qp-gateway
      private-deps: qpm-rs-service,qpm-rs-auth,qpsb-contracts
    secrets: inherit
```

A repo with no Dockerfile gets no `cd.yml` at all (`repo-birth`/wire-gate
only emit one when `Dockerfile` is present).

## `semver-tag.yml` — auto-tag on merge

Spec 002-versioned-auto-deploy T-001 (plan.md D1/D1a, QPMSEC-726/
QPMSEC-707). No release PR to click — on every invocation it reads the
CALLER repo's own git history (the same "checkout resolves to the
caller" behavior the gate workflows and `image-publish.yml` already
rely on) and, when the commits since the latest `v*` tag contain a
`feat`/`fix`/breaking change, creates and pushes an annotated tag
directly, with no PR and no human step.

**Precondition — seed `v0.1.0` first.** This workflow never guesses a
starting version: a caller repo with **no** `v*` tag reachable from
`HEAD` FAILs the job loud, on purpose (never a silent `v0.1.0`). A repo
must carry at least one `v*` tag before it ever calls `semver-tag.yml` —
spec 002-versioned-auto-deploy T-002 seeds `v0.1.0` once, per repo,
ahead of wiring this workflow in.

| Input | Type | Default | Meaning |
| --- | --- | --- | --- |
| `runner` | string | `""` | Runner label for the release job; empty falls through to the caller repo's `QPM_RUNNER` Actions variable, then `ubuntu-latest` — README "Runners". No `runner_heavy` variant — this job does no compilation. |

| Output | Meaning |
| --- | --- |
| `version` | The released version (`X.Y.Z`, no leading `v`). Empty when nothing was tagged. |
| `tag` | The released tag (`vX.Y.Z`). Empty when nothing was tagged. |

### The bump table

Every commit subject between the latest `v*` tag and `HEAD` is
classified against the Conventional Commits header grammar
(`<type>[optional scope][!]: <description>`), plus a `BREAKING CHANGE:`/
`BREAKING-CHANGE:` footer scanned anywhere in each commit's full body.
The HIGHEST bump found across all commits since the last tag wins:

| Signal | Bump |
| --- | --- |
| `BREAKING CHANGE:`/`BREAKING-CHANGE:` footer, or `!` before the header's `:` (e.g. `feat!:`) | major |
| `feat:` (no breaking marker) | minor |
| `fix:` (no breaking marker, no `feat`) | patch |
| anything else (`chore`, `ci`, `docs`, `refactor`, `test`, `build`, an unparseable subject, or no commits at all) | no release — `version`/`tag` outputs empty, nothing tagged |

### The thin-caller `cd.yml` shape (D3 — `release` gates `publish`)

```yaml
name: cd
on:
  push:
    branches: [main]
concurrency:
  group: cd-${{ github.ref }}
  cancel-in-progress: true
permissions:
  contents: write
  packages: write
  id-token: write
jobs:
  release:
    uses: QPMatrix/qpm-gh-workflows/.github/workflows/semver-tag.yml@v1
    secrets: inherit
  publish:
    needs: release
    if: needs.release.outputs.version != ''
    uses: QPMatrix/qpm-gh-workflows/.github/workflows/image-publish.yml@v1
    with:
      image: ghcr.io/qpmatrix/qp-gateway
      version: ${{ needs.release.outputs.version }}
      private-deps: qpm-rs-service,qpm-rs-auth,qpsb-contracts
    secrets: inherit
```

A merge whose commits are all `chore`/`ci`/`docs` (no `feat`/`fix`/
breaking) runs `release`, gets `version: ""`, and `publish` is
**skipped** — no new tag, no new image. This per-repo `cd.yml`
migration is spec 002-versioned-auto-deploy T-004, out of scope for
this repo's own change.

## Self-test

`self-test.yml` calls every workflow above against a real, tiny fixture
under `fixtures/`, via each gate's `working-directory` input:
`fixtures/check-hello` (a no-argument gate that uses runner-provided
python3 and reads a fixture-relative file), plus
`fixtures/rust-hello`, `fixtures/go-hello`, `fixtures/python-hello`,
`fixtures/ts-hello` (each a real crate/module/package with its own
`fmt`/`lint`/`test`/`image`-capable `./check`), and `fixtures/docker-hello`
(a 3-line Dockerfile) for `image-publish.yml`. This is what makes a broken
reusable workflow go red HERE, on this repo's own PR, before any real
consumer's PR ever calls it.

`semver-tag.yml` cannot be exercised the same way — git tags are
repository-wide, and a reusable workflow's own checkout always resolves
to the CALLING repo, so calling it from here would push a real tag onto
THIS repo on every self-test run. Instead `scripts/classify-bump.sh`,
`scripts/find-latest-tag.sh`, and `scripts/bump-version.sh` hold the same
logic `semver-tag.yml` embeds inline as the single source of truth:
`semver-tag-classify-selftest` feeds `fixtures/semver-tag/commits-
{major,minor,patch,none}.txt` straight to `classify-bump.sh`;
`semver-tag-find-tag-selftest` proves the "no `v*` tag -> FAIL loud" case
and the "highest tag wins" case against throwaway scratch repos, plus
`bump-version.sh`'s arithmetic; `semver-tag-inline-sync-selftest` diffs
`semver-tag.yml`'s inline BEGIN/END blocks against those same three
files so the running copy can never silently drift from what's tested.
`image-publish-tags-selftest` proves both `version` shapes (empty and
`"0.1.1"`) by calling the real, pinned `docker/metadata-action` directly
with the exact `tags:` templates `image-publish.yml`'s `meta` step now
renders — no image build/push needed, so it runs on every PR (unlike
`image-publish-selftest`, `workflow_dispatch`-only because it pushes a
real image).

## Cutting a release tag

Callers pin `@<tag>` (e.g. `@v1`), never `@main` — a moving ref would let
an in-progress change here reach every consumer mid-edit. After a change
merges to `main` and `self-test.yml` is green on it:

```sh
git tag -a v1.1.0 -m "qpm-gh-workflows v1.1.0"
git push origin v1.1.0
```

Semver by hand for now (no release-bot is wired for this repo yet — it is
config, not a package with a build artifact, so `release-and-publish`'s
tooling does not apply as-is). A breaking change to an existing input's
meaning or a job's name is a major bump; a new optional input or a new
workflow is minor; a comment/pin-only change is patch.
