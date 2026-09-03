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

## Docs

- [docs/workflows.md](docs/workflows.md) — every reusable workflow: what
  it does, its inputs, the thin-caller shape a consuming repo carries,
  and how to cut a release tag.
