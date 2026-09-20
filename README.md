<div align="center">

# Codna GitHub Action

**Run [Codna](https://codna.ai) in GitHub Actions. `fix`, `review` or `secure` a repository with the same `codna` command you run on your machine.**

[![ci](https://github.com/thyn-ai/codna-action/actions/workflows/ci.yml/badge.svg)](https://github.com/thyn-ai/codna-action/actions/workflows/ci.yml)
[![CodeQL](https://github.com/thyn-ai/codna-action/actions/workflows/codeql.yml/badge.svg)](https://github.com/thyn-ai/codna-action/actions/workflows/codeql.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/thyn-ai/codna-action/badge)](https://scorecard.dev/viewer/?uri=github.com/thyn-ai/codna-action)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](./LICENSE)

[Codna docs](https://docs.codna.ai) · [Contributing](./CONTRIBUTING.md) · [Support](./SUPPORT.md) · [Security](./SECURITY.md)

</div>

---

Codna maps your repository before it spends a token, then sends an agent in with the exact
context it needs. A fix arrives as a pull request with the root cause, the changed symbols and a
confidence score. You review. You merge. Your key. Your infra. Your code stays yours.

This is the public wrapper for Codna's GitHub Action channel. The action installs the published
`codna` package from PyPI and runs it. One install: the agent runtime ships inside the package,
so the action adds no Node, Bun or second runtime to your job.

## Fix mode

```yaml
permissions:
  contents: write
  pull-requests: write

jobs:
  codna:
    runs-on: ubuntu-latest
    env:
      OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
    steps:
      - uses: thyn-ai/codna-action@v1
        with:
          mode: fix
          issue: "CI failed on checkout tests"
          model: openai/gpt-5
          github-token: ${{ github.token }}
```

Model calls run through the provider named in `model` (`<provider>/<model-id>`) and read that
provider's key from the job environment — for example `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`,
`GEMINI_API_KEY` or `OPENROUTER_API_KEY`; any provider in the bundled catalog works. When `model`
is omitted (or carries no `<provider>/` prefix) the default provider is Anthropic, so
`ANTHROPIC_API_KEY` must be set in that case. `api-key` is the Codna engine API key (exported as
`CODNA_API_KEY`). It is only needed when the run is pointed at a remote Codna engine via
`CODNA_ENGINE_URL`; the default local run does not use it.

## Review mode

```yaml
permissions:
  contents: read
  pull-requests: write
  checks: write

on:
  pull_request:

jobs:
  codna_review:
    runs-on: ubuntu-latest
    env:
      OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: thyn-ai/codna-action@v1
        with:
          mode: review
          post: "true"
          model: openai/gpt-5
```

On `pull_request` events the action fetches the PR base branch and reviews
`origin/<base>...HEAD`. For non-PR events, set `diff` explicitly, for example
`diff: origin/main...HEAD`.

What a review posts:

- One inline comment per finding: severity (`high`, `medium`, `low`), category (`correctness`,
  `security`, `performance`), an explanation and a `suggestion` block when the fix is a plain
  replacement. Findings at confidence 0.75 or higher, ten at most; `min-confidence` and `effort`
  adjust this.
- One check run named `codna review`: `success` with no findings, `neutral` with findings, and
  `failure` only with `blocking: "true"` and a finding at a blocking severity.
- A verdict. Approve when the pass has no medium or high finding and no earlier Codna medium or high
  thread is unresolved; otherwise Comment, with the reason. Never Request changes. Set
  `review.approve: false` in the repository's `codna.yaml` to turn approvals off.
- A red-head note when a required check is failing at review time: the verdict is about the diff,
  not a merge go-ahead.
- Dependency claims checked against npm and PyPI before posting. A contradicted claim is dropped;
  an uncheckable one is posted as low and marked Unverified.
- Re-reviews cover the commits pushed since Codna's last review.

## Secure mode

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: thyn-ai/codna-action@v1
    with:
      mode: secure
      from-sarif: results.sarif
      reachability-engine: local
      verification: codna-security.yaml
```

Secure mode is read-only in this wrapper: it classifies each SARIF 2.1.0 finding as reachable or
not and opens no pull request. Opening security PRs uses Codna's privilege-separated evidence and
writer workflow ([Security Autofix](https://docs.codna.ai/guides/security-autofix)).

## What fix mode opens

`mode: fix` runs `codna fix <repo> --ref <sha> --open-pr`. When Codna finds a fix it pushes a
`codna/…` branch and opens a pull request titled `codna: fix …` whose body states the issue, the
root cause, the changed symbols and Codna's confidence, and ends with `Review before merging.` The
step exposes the URL as `pull-request-url`. Codna opens pull requests. It never merges.

## Limits

- The runner needs Python 3.10 or newer and a platform with a published wheel: Linux x86_64 or
  macOS on Apple silicon. The install is wheel-only, so other platforms fail at the install step.
- `mode: fix` opens the pull request once. It does not re-run your tests after the patch; your CI
  and your reviewers verify the PR. The test-and-re-fix loop is the CLI's `codna fix --tests --apply`.
- `mode: review` needs the PR base in the checkout (`fetch-depth: 0`) or an explicit `diff`.
- `mode: secure` is read-only and always leaves `pull-request-url` empty.

## Pinning

By default the action installs the latest published `codna` package:

```yaml
with:
  package-spec: codna
```

For deterministic CI, pin the package:

```yaml
with:
  package-spec: codna==0.2.76
```

Either way the step installs `codna` as a wheel only (`--only-binary=codna`): pip will not build
the package from a source distribution, so the runtime that executes is the one published to PyPI.
The step does not install with `--require-hashes`. A hash lock names every distribution in the
resolved set — `codna` and each of its dependencies, at one version — so a lock shipped inside this
action would either fix the `codna` version, breaking the default that follows the latest release, or
fall out of date with every `codna` release. Reproducibility is the caller's choice, made with two
pins: `package-spec: codna==X.Y.Z` fixes the package, and the commit SHA below fixes the wrapper.

### Pin the action

`@v1` is a floating tag that maintainers move to each vetted change of the wrapper (see
[CONTRIBUTING.md](./CONTRIBUTING.md#releases-and-the-v1-tag)). For a reproducible workflow, pin
the full commit SHA and let Dependabot move it:

```yaml
- uses: thyn-ai/codna-action@<full commit SHA> # v1
```

## Contributing

Bug reports and pull requests for the wrapper are welcome — [CONTRIBUTING.md](./CONTRIBUTING.md)
explains how to check and smoke-test the action locally, and [SUPPORT.md](./SUPPORT.md) says
where each kind of question goes. Bugs in what Codna itself did (the fix PR, the review
findings, a `secure` classification) are triaged at
[thyn-ai/feedback](https://github.com/thyn-ai/feedback). Security issues: [SECURITY.md](./SECURITY.md),
never a public issue.

## Related repositories

Open-source tooling around Algenta, from the Algenta team. The Algenta engine itself is proprietary; everything listed here is Apache-2.0. Issues and discussions are welcome in whichever repository owns the code.

- [thyn-ai/algenta-sdk](https://github.com/thyn-ai/algenta-sdk) — Python and TypeScript SDKs for Algenta: self-hosted building blocks for AI applications, 6,000+ deterministic functions on custom Mojo kernels behind one API, SDK and MCP surface.
- [thyn-ai/algenta-integrations](https://github.com/thyn-ai/algenta-integrations) — Framework integrations for Algenta: LangChain, LlamaIndex, pydantic-ai, MAF, Haystack, LiteLLM, Ray Serve, vLLM, Vercel AI SDK and n8n.
- [thyn-ai/mojo-kernels](https://github.com/thyn-ai/mojo-kernels) — Clean-room Mojo kernels as drop-in accelerators for popular Python/TypeScript libraries, with bit-exact parity and pure-language fallbacks.
- [thyn-ai/security-toolchain](https://github.com/thyn-ai/security-toolchain) — The pinned, checksum-verified security toolchain (Gitleaks, Opengrep, OSV-Scanner, Trivy config, actionlint) that every thyn-ai repository runs locally and in CI.
- [thyn-ai/feedback](https://github.com/thyn-ai/feedback) — Public issue intake for the open-source tooling around Algenta and for the Codna GitHub App.
- [thyn-ai/codna-action](https://github.com/thyn-ai/codna-action) (this repository) — GitHub Action for Codna: fix, review or secure a repository in CI with the same `codna` command you run on your machine.

## License

This action wrapper is licensed under [Apache-2.0](./LICENSE). The `codna` package it installs
is a separate product with its own license terms; see [NOTICE](./NOTICE).
