# Security Policy

This repository contains the public GitHub Action wrapper for Codna: a
composite action (`action.yml`) that installs the published `codna` package
from PyPI and runs the same packaged local runtime users run from the CLI --
in `fix`, `review` or `secure` mode -- inside a GitHub Actions job. We take
the security of this wrapper seriously and appreciate responsible disclosure
from the community.

## Supported versions

The action is consumed by git ref. Fixes land on `main`, and the floating
`v1` tag is moved to the vetted commit that carries them: a workflow that
references `thyn-ai/codna-action@v1` picks a fix up on its next run, and a
workflow pinned to a full commit SHA picks it up when Dependabot (or you)
moves the pin.

| Channel | Supported |
| --- | --- |
| `main` / the current `v1` tag | :white_check_mark: |
| Older commits the `v1` tag has moved past | Best-effort; please move your pin forward |

## Reporting a vulnerability

**Please do not open a public issue, pull request, or discussion for
security problems.** Public disclosure before a fix is available puts other
users at risk.

Report privately through either channel:

1. **GitHub Security Advisories** (preferred) — open a private report from
   this repository's **Security → Report a vulnerability** tab.
2. **Email** — `security@algenta.ai`.

Please include, where possible: a description of the issue and its impact,
the affected part of the wrapper (the install step, the argument mapping for
`fix` / `review` / `secure`, token handling, a workflow file), steps to
reproduce or a proof of concept, and the action ref (`@v1`, or the commit
SHA) and the `codna` version you tested (the install step prints
`codna --version` in the job log).

## What to expect

- Acknowledgement within 3 business days.
- An initial assessment and severity triage within 7 business days.
- Regular updates as we work on a fix, and credit in the published advisory
  (unless you prefer to remain anonymous).
- Coordinated disclosure: we agree on a timeline with you and publish a
  GitHub Security Advisory once a fix is available.

## Scope

**In scope** — this repository's own contents:

- `action.yml`: how inputs and the triggering event reach the `codna`
  command line (every value travels through `env:`, never through `${{ }}`
  interpolation inside `run:`); how the GitHub token and the optional Codna
  key are handled (the wrapper only ever hands them to `codna` through the
  environment); the `pull-request-url` output; and any way a crafted input,
  ref, branch name or diff range could change what the wrapper executes or
  where it posts
- The install step: `--only-binary` enforcement, the `package-spec` input,
  and anything that would let the step install something other than the
  requested `codna` distribution from PyPI
- The workflow files under `.github/workflows/`: a permission broader than
  the job needs, an action that is not pinned to a full commit SHA or whose
  pin does not match its version comment, or a way to make a workflow act on
  untrusted input
- The scripts under `scripts/`, which CI and contributors run

**Vulnerabilities in Codna itself belong with Codna.** This repository holds
none of its code. The `codna` package (the CLI, its packaged local runtime,
the agent-core sidecar), the Codna GitHub App and MCP server, and the Algenta
Engine are proprietary and their source is not public, so please report them
privately through the same channels as above — this repository's **Security
→ Report a vulnerability** tab or `security@algenta.ai` — rather than in a
public issue anywhere. A vulnerability in one of the other open-source
repositories from the Algenta team goes to that repository's own
`SECURITY.md` ([algenta-sdk](https://github.com/thyn-ai/algenta-sdk/blob/main/SECURITY.md),
[algenta-integrations](https://github.com/thyn-ai/algenta-integrations/blob/main/SECURITY.md),
[mojo-kernels](https://github.com/thyn-ai/mojo-kernels/blob/main/SECURITY.md),
[security-toolchain](https://github.com/thyn-ai/security-toolchain/blob/main/SECURITY.md),
[feedback](https://github.com/thyn-ai/feedback/blob/main/SECURITY.md)).

We also want to be upfront about the trust model: the wrapper runs with the
permissions the calling workflow grants it, on the runner the caller chose,
and with the provider keys the caller placed in the job environment. A
report showing that a job granted `contents: write` can write to the
repository is a property of GitHub Actions, not a vulnerability in this
action; a report showing the wrapper *escalating* beyond what the caller
granted, or doing anything with the token or a key other than passing it to
`codna`, is.

**Also out of scope:** third-party dependencies (report those upstream; we
still want to hear how they affect this action), GitHub Actions and PyPI
themselves, and social-engineering, physical, or denial-of-service testing
against any hosted environment.

Thank you for helping keep Algenta and its users safe.
