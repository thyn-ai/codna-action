<div align="center">

# Codna GitHub Action

**Run [Codna](https://codna.ai) in GitHub Actions — `fix`, `review` or `secure` a repository through the same packaged local runtime users run from the CLI.**

[![ci](https://github.com/thyn-ai/codna-action/actions/workflows/ci.yml/badge.svg)](https://github.com/thyn-ai/codna-action/actions/workflows/ci.yml)
[![CodeQL](https://github.com/thyn-ai/codna-action/actions/workflows/codeql.yml/badge.svg)](https://github.com/thyn-ai/codna-action/actions/workflows/codeql.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/thyn-ai/codna-action/badge)](https://scorecard.dev/viewer/?uri=github.com/thyn-ai/codna-action)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](./LICENSE)

[Codna docs](https://docs.codna.ai) · [Contributing](./CONTRIBUTING.md) · [Support](./SUPPORT.md) · [Security](./SECURITY.md)

</div>

---

Codna maps your repo deterministically, then sends an agent in with the exact context it
needs to fix bugs fast. Every fix is verified by your own tests before it lands. Your key.
Your infra. Your code stays yours.

Public wrapper for Codna's GitHub Action channel. The action installs the published `codna`
package from PyPI, then runs the same packaged local runtime users run from the CLI.

Users install one product: `codna`. The repository-intelligence SDK/core, Telys runtime/license,
and self-contained agent-core sidecar ship inside the package. The action does not install Node,
Bun, `node_modules`, or a separate Telys package.

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
`CODNA_ENGINE_URL`; the default packaged local runtime does not use it.

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

Secure mode is read-only in this wrapper. Opening security PRs should use Codna's
privilege-separated evidence/writer workflow.

## Pinning

By default the action installs the latest published `codna` package:

```yaml
with:
  package-spec: codna
```

For deterministic CI, pin the package:

```yaml
with:
  package-spec: codna==0.2.53
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

- [thyn-ai/algenta-sdk](https://github.com/thyn-ai/algenta-sdk) — Python and TypeScript SDKs for Algenta: governed data queries, simulations, decision memory with execution receipts, agent runs with approvals.
- [thyn-ai/algenta-integrations](https://github.com/thyn-ai/algenta-integrations) — Framework integrations for Algenta: LangChain, LlamaIndex, pydantic-ai, MAF, Haystack, LiteLLM, Ray Serve, vLLM, Vercel AI SDK and n8n.
- [thyn-ai/mojo-kernels](https://github.com/thyn-ai/mojo-kernels) — Clean-room Mojo kernels as drop-in accelerators for popular Python/TypeScript libraries, with bit-exact parity and pure-language fallbacks.
- [thyn-ai/security-toolchain](https://github.com/thyn-ai/security-toolchain) — The pinned, checksum-verified security toolchain (Gitleaks, Opengrep, OSV-Scanner, Trivy config, actionlint) that every thyn-ai repository runs locally and in CI.
- [thyn-ai/feedback](https://github.com/thyn-ai/feedback) — Public issue intake for the open-source tooling around Algenta and for the Codna GitHub App.
- [thyn-ai/codna-action](https://github.com/thyn-ai/codna-action) (this repository) — GitHub Action for Codna: fix, review or secure a repository in CI through the same packaged local runtime the CLI uses.

## License

This action wrapper is licensed under [Apache-2.0](./LICENSE). The `codna` package it installs
is a separate product with its own license terms; see [NOTICE](./NOTICE).
