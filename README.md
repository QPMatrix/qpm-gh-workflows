# qpm-gh-workflows

Reusable GitHub Actions workflows for the QPMatrix estate: a PR-only
quality gate per language (cached, parallel jobs) and a CD image publish
that never re-runs the gate — the estate's ONE place to fix or improve how
CI/CD runs, consumed by every service repo as a thin caller.

## Governing decisions

- [ADR-031 — CI/CD Shape](https://github.com/QPMatrix/qpsb-architecture/blob/main/docs/adr/ADR-031-ci-cd-shape.md) —
  why the gate is PR-only, why it splits into parallel jobs, why CD never
  re-gates, and why these workflows live here as `workflow_call` reusable
  workflows versioned by tag.
- [repo-gates-and-hooks](https://github.com/QPMatrix/qpsb-skills/blob/main/skills/repo-gates-and-hooks/SKILL.md) —
  the hook ⊆ CI parity rule every gate workflow here upholds, and the
  action-pin verification discipline every pin in this repo follows.

## Setup (every clone)

```sh
git config core.hooksPath .githooks
```

The gate is `./check`; the pre-commit hook and CI run exactly it
(repo-gates-and-hooks parity rule). `./check` fetches the pinned
qp-skills and qpsb-agents caches before running `instructions.py check`
— read `INSTRUCTIONS.md` for what this repo is, its governing ADRs, and
its mounted skills/agents.

## Runners

Every `runs-on:` in every workflow here is a flag, never a literal
(QPMSEC-630 — GitHub-hosted minutes ran out estate-wide on 2026-09-06):

| Flag | Read by | Meaning |
| --- | --- | --- |
| `runner` input / `QPM_RUNNER` variable | every job in every gate, `image-publish.yml`'s publish job as its last resort, and this repo's own `ci.yml` (variable only — it is not a `workflow_call` workflow, so it has no `inputs`) | The runner label for ordinary jobs. |
| `runner_heavy` input / `QPM_RUNNER_HEAVY` variable | `rust-gate.yml`'s `format-lint` (clippy), `test` and `image` jobs — everything that compiles the crate — and `image-publish.yml`'s publish job | A bigger runner for cargo and the image build; cheap jobs stay on `runner`. |

Precedence, exactly as written in the workflows:

```
ordinary job:  inputs.runner || vars.QPM_RUNNER || 'ubuntu-latest'
heavy job:     inputs.runner_heavy || vars.QPM_RUNNER_HEAVY || inputs.runner || vars.QPM_RUNNER || 'ubuntu-latest'
```

**Fallback rule: unset both variables and pass no input → `ubuntu-latest`**,
the GitHub-hosted runner every workflow ran on before the flag existed.
An input defaults to `""` and an unset variable reads as `""`, and both
are falsy to `||`, so each alternative falls through to the next —
`vars` is one of the contexts GitHub allows in `runs-on`, and a variable
holding the label is one of the documented shapes (`runs-on: ${{ vars.RUNNER }}`
is GitHub's own example). Both inputs are `type: string`, optional,
declared on every workflow that reads them; the `workflow_call` callers
`repo-birth`/`wire-gate` emit need no edit — the switch is a variable.

The account is a USER account (no organization-level variables), so the
switch is a per-repo Actions variable. The orchestrator sets it across
the estate with exactly:

```sh
gh variable set QPM_RUNNER --body ubicloud-standard-2 -R QPMatrix/<repo>
gh variable set QPM_RUNNER_HEAVY --body ubicloud-standard-4 -R QPMatrix/<repo>
```

and unsets it to fall back: `gh variable delete QPM_RUNNER -R QPMatrix/<repo>`
(same for `QPM_RUNNER_HEAVY`). Ubicloud's own label strings, from
<https://www.ubicloud.com/docs/github-actions-integration/runner-types>:
`ubicloud-standard-2` (2 vCPU x64), `ubicloud-standard-4` (4 vCPU x64),
`ubicloud-standard-4-arm` (4 vCPU arm64); the quickstart's instruction is
"change the `ubuntu-latest` runner label to `ubicloud-standard-2`".

What does NOT change when a job lands on Ubicloud:

- **Minutes.** Ubicloud minutes are billed by Ubicloud, not GitHub —
  a Ubicloud runner is a GitHub just-in-time self-hosted runner
  ("We use GitHub's REST API to create and receive a JIT config file
  from GitHub and pass on this file to the Ubicloud runner",
  <https://www.ubicloud.com/docs/github-actions-integration/security>),
  and "GitHub Actions usage is free for self-hosted runners"
  (<https://docs.github.com/en/billing/concepts/product-billing/github-actions>).
  The GitHub Pro quota is only consumed by jobs that still resolve to
  `ubuntu-latest`.
- **Identity.** cosign keyless in `image-publish.yml` signs with the
  job's OIDC token, and "every time your job runs, GitHub's OIDC provider
  auto-generates an OIDC token" for the job regardless of the machine
  (<https://docs.github.com/en/actions/concepts/security/openid-connect>) —
  the verified certificate identity, the GHCR push under `GITHUB_TOKEN`
  and the App merge flow are unchanged because the control plane stays
  GitHub.

`self-test.yml` proves both paths on this repo: its ordinary gate jobs
pass no `runner`, so they run wherever the fall-through lands
(`ubuntu-latest` until the orchestrator sets `QPM_RUNNER` here); the
`rust-gate-selftest-flagged-runner` job, guarded on
`vars.QPM_RUNNER != ''`, feeds the variables in as explicit inputs and
so proves the `inputs.runner` / `inputs.runner_heavy` path once the
variable exists.

## Docs

- [docs/workflows.md](docs/workflows.md) — every reusable workflow: what
  it does, its inputs, the thin-caller shape a consuming repo carries,
  and how to cut a release tag.
