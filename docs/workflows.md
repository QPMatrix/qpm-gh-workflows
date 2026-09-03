# Workflow reference

Five reusable `workflow_call` workflows live in `.github/workflows/`. Four
are per-language PR-only gates (ADR-031 a–e); the fifth is the CD image
publish (ADR-031 f). `self-test.yml` calls all five against the fixtures
in `fixtures/` on every PR that touches a workflow or a fixture — see
"Self-test" below.

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
| `private-deps` | string | `""` | Comma/newline QPMatrix repo names this repo fetches over git (the mandatory `qpsb-skills`/`qpsb-agents` pair included by the caller). Empty skips the App-token mint entirely. |
| `working-directory` | string | `"."` | Where the caller's project lives, relative to repo root. Real callers leave this alone; `self-test.yml` points it at a fixture. |

`rust-gate.yml` also takes `cargo-deny-version` (default `0.20.2`);
`python-gate.yml` also takes `python-version-file` (default
`.python-version`). Every job that mints a token needs
`secrets: inherit` from the caller so `QPASSISTANCE_CLIENT_ID`/
`QPASSISTANCE_PRIVATE_KEY` reach it without being re-declared.

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
      private-deps: qpm-rs-service,qpm-rs-auth,qpsb-contracts,qpsb-skills,qpsb-agents
    secrets: inherit
```

`repo-birth`'s `birth.py` and `repo-instructions`' `instructions.py
wire-gate` emit exactly this shape (substituting the language-appropriate
gate file and the repo's own derived `private-deps` list) — see those
skills for how the list is derived per language.

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

## Self-test

`self-test.yml` calls every workflow above against a real, tiny fixture
under `fixtures/`, via each gate's `working-directory` input:
`fixtures/rust-hello`, `fixtures/go-hello`, `fixtures/python-hello`,
`fixtures/ts-hello` (each a real crate/module/package with its own
`fmt`/`lint`/`test`/`image`-capable `./check`), and `fixtures/docker-hello`
(a 3-line Dockerfile) for `image-publish.yml`. This is what makes a broken
reusable workflow go red HERE, on this repo's own PR, before any real
consumer's PR ever calls it.

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
