# Contributing to codna-action

Thank you for your interest in contributing. This repository is the public
GitHub Action wrapper for [Codna](https://codna.ai): a composite action
(`action.yml`) that installs the published `codna` package from PyPI and runs
the same packaged local runtime users run from the CLI — in `fix`, `review`
or `secure` mode — inside a GitHub Actions job.

The wrapper is Apache-2.0 and meant to be read, forked and improved by
anyone. Codna itself — the `codna` package, the CLI, the GitHub App and the
MCP server — and the Algenta Engine are proprietary and live in private
repositories; nothing in this repository contains or changes them. What you
can change here is how a GitHub Actions job installs and invokes `codna`:
the inputs, the argument mapping, the install step, the output, the
workflows, and the documentation.

## Repository layout

| Path | What it is |
|---|---|
| `action.yml` | The action: metadata, inputs and outputs, and two composite `bash` steps — **Install codna** (pipx or `pip --user`, wheels only) and **codna fix / review / secure** (maps the inputs onto a `codna` command line and captures the PR URL) |
| `README.md` | The user-facing documentation: one section per mode, plus pinning guidance |
| `scripts/check.sh` | The lint CI runs and you run locally: actionlint, YAML parse, pinned `uses:`, no `${{ }}` inside `run:`, action.yml structure, shellcheck on every step with only the step's `env:` names and the runner's own variables declared, plus a negative check that an undeclared variable still fails |
| `scripts/smoke-install.sh` | Runs the action's own install step against PyPI on both of its branches — pipx, and `pip install --user` with pipx hidden from PATH — and requires each to end in a working `codna --version` |
| `.github/workflows/ci.yml` | Runs the two scripts on every pull request and push to `main` |
| `.github/workflows/` (rest) | CodeQL (`actions` language), OpenSSF Scorecard, the security gate, stale and first-interaction housekeeping |
| `.github/requirements/` | Hash-locked Python tooling for the scripts (PyYAML) |

## Development setup

Prerequisites: bash, `python3` with [PyYAML](https://pypi.org/project/PyYAML/),
[shellcheck](https://www.shellcheck.net/), and
[actionlint](https://github.com/rhysd/actionlint) 1.7.12 (the version CI
runs). Nothing here needs a Codna key or a provider key.

```bash
git clone https://github.com/thyn-ai/codna-action
cd codna-action
python3 -m pip install --require-hashes -r .github/requirements/check.txt   # PyYAML, hash-locked
```

### Testing the action locally

A composite action has no unit tests of its own. What CI checks — and what
you can check before pushing — is that the action is well-formed and that its
install step works against the real package index:

```bash
scripts/check.sh            # actionlint, YAML parse, action.yml validation, shellcheck per step, negative check
scripts/smoke-install.sh    # runs the "Install codna" step as written, pipx branch and pip fallback
```

`scripts/smoke-install.sh` installs `codna` exactly as the action does on a
runner, twice: once through pipx, as on GitHub-hosted runners (skipped if you
have no pipx; CI fails without it), and once through `pip install --user` on a
PATH with pipx hidden and `PYTHONUSERBASE` pointed at a scratch directory. The
second run passes only if the step puts the user scripts directory on its own
PATH before `codna --version` and writes it to `GITHUB_PATH` for later steps.
Set `CODNA_ACTION_PACKAGE_SPEC=codna==X.Y.Z` to pin, as the `package-spec`
input does.

To exercise a mode end to end, run it the way users will: push your branch
and reference it from a workflow in a scratch repository you own, with the
provider key in that repository's secrets:

```yaml
- uses: <your-fork>/codna-action@<branch-or-sha>
  with:
    mode: review
    post: "false"
```

`review` with `post: "false"` computes findings without writing anything;
`fix` opens a pull request in the scratch repository. The job log shows the
`codna --version` the install step printed, and the step summary shows what
`codna` returned. [nektos/act](https://github.com/nektos/act) can run
composite actions too, but provider keys and the GitHub token still have to
be real for anything past the install step.

### Pre-commit and the security gate

The repository's [pre-commit](./.pre-commit-config.yaml) configuration is
managed by [thyn-ai/security-toolchain](https://github.com/thyn-ai/security-toolchain):
secret scanning (gitleaks), Opengrep, actionlint, dependency vulnerability
(OSV) and IaC checks run at commit and push time, and the same policy re-runs
on a clean checkout in CI (`.github/workflows/security.yml`).

```bash
uv tool install pre-commit   # or: pipx install pre-commit
pre-commit install            # installs both the pre-commit and pre-push hooks
```

## What a change to the action needs

- **Same behaviour as the CLI.** The wrapper exposes what `codna fix`,
  `codna review` and `codna secure` already do, with the same semantics. A
  new input maps onto an existing CLI flag; a new mode is one the CLI already
  has. Do not add behaviour to the wrapper that the CLI lacks — request it at
  [thyn-ai/feedback](https://github.com/thyn-ai/feedback/issues/new/choose)
  so it lands in Codna first.
- **Inputs travel through `env:`.** Every input and every `github.*` value a
  step needs is set in the step's `env:` block and read as a shell variable.
  No `${{ }}` inside `run:` — `scripts/check.sh` fails on it. Every variable a
  step reads is either in its `env:` map or one GitHub sets on every runner:
  `scripts/check.sh` runs shellcheck with `check-unassigned-uppercase` on and
  fails on anything else, `$GITHUB_TOKEN` included.
- **Install nothing but `codna`.** The install step stays `--only-binary`,
  installs the one distribution named by `package-spec`, and never fetches a
  script to execute. The action does not install Node, Bun or a second
  runtime.
- **Document it.** Every input has a `description:` in `action.yml`, and the
  README's mode sections and examples reflect any input, output or default
  you change.
- **Pinned and least-privilege.** Every `uses:` in a workflow is pinned to a
  full 40-character commit SHA with a `# vX.Y.Z` comment; the top-level
  `permissions:` block is `contents: read`, and a job that needs more
  declares it on the job.
- **No credentials, no network in the checks.** `scripts/check.sh` runs
  offline; `scripts/smoke-install.sh` talks to PyPI and nothing else. Nothing
  in this repository carries a token or a key.

## Releases and the `v1` tag

There is no release workflow, versioned tag series, GitHub Release or
Marketplace listing today; the action is consumed by git ref.

- **`v1` is a floating tag.** Users reference `thyn-ai/codna-action@v1`.
  After a change to the action's behaviour has been merged to `main` and
  exercised against a real repository, a maintainer moves the tag to that
  commit:

  ```bash
  git fetch origin
  git tag -f v1 <commit-sha>
  git push --force origin refs/tags/v1
  ```

  Commits that touch only documentation or repository automation do not
  move the tag; today `v1` points at the last commit that changed
  `action.yml`.
- **Breaking changes get a new major tag.** Renaming or removing an input,
  changing a default, or changing what a mode does for the same inputs is
  released as `v2`, announced in an issue, and `v1` keeps its contract.
- **Users who want reproducibility pin the SHA.** The README's pinning
  section recommends `uses: thyn-ai/codna-action@<full commit SHA> # v1`,
  which Dependabot moves for them, and `package-spec: codna==X.Y.Z` for the
  package.

## Commit messages and pull requests

We follow [Conventional Commits](https://www.conventionalcommits.org/), with
the scope naming what you changed:

```
feat(action): add a `timeout` input mapped onto `codna --timeout`
fix(action): fetch the PR base branch with the same refspec the CLI uses
docs(readme): document `diff` for non-PR events
ci(check): fail on an unpinned uses:
```

- Branch from `main` as `feat/short-description`, `fix/short-description`
  or `docs/short-description`.
- Keep the diff focused on one change; unrelated refactors go in their own
  pull request.
- All CI checks must pass, including on forked-repository pull requests —
  CI runs with no secrets and a read-only token, so it is safe to run
  automatically on every PR. Review follows
  [`CODEOWNERS`](./.github/CODEOWNERS): `action.yml`, the scripts and
  anything under `.github/` always get deliberate maintainer review.
- `.github/workflows/security.yml` and the toolchain block in
  `.pre-commit-config.yaml` are managed by
  [thyn-ai/security-toolchain](https://github.com/thyn-ai/security-toolchain)'s
  propagate step, which moves both pins together. Do not bump them by hand.

## Reporting issues and getting help

- **Security vulnerabilities** → see [SECURITY.md](./SECURITY.md) (do NOT
  open a public issue)
- **Bugs in the wrapper** → [GitHub Issues](https://github.com/thyn-ai/codna-action/issues)
  with the workflow snippet (secrets removed), the action ref and the `codna`
  version from the job log
- **Bugs in what Codna did** (the fix PR, the review findings, a `secure`
  classification, an error from the CLI) →
  [thyn-ai/feedback](https://github.com/thyn-ai/feedback/issues/new/choose),
  product `codna`
- **Questions** → [GitHub Discussions](https://github.com/thyn-ai/codna-action/discussions)
  or [Discord](https://discord.gg/w8NDsph9an)

## Licensing

This repository is licensed under [Apache-2.0](./LICENSE). Contributions
are inbound = outbound: by submitting a pull request, you license your
contribution under the project's existing license, consistent with
section D.6 of the [GitHub Terms of
Service](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service#6-contributions-under-repository-license).
There is no Contributor License Agreement (CLA) to sign and no DCO sign-off
is required. Please only contribute work you have the right to submit under
these terms.

## Code of conduct

This project follows the [Contributor Covenant](./CODE_OF_CONDUCT.md).
Reports go to `conduct@algenta.ai`.
