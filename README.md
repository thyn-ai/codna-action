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

Use `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, or `GEMINI_API_KEY` in the job environment for
model-backed local planning. `api-key` is optional for local packaged runs and can carry a Codna
license / metering key when your deployment requires one.

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
  package-spec: codna==0.1.43
```

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

Open-source repositories from the Algenta team. The Algenta engine itself is proprietary; everything listed here is Apache-2.0. Issues and discussions are welcome in whichever repository owns the code.

- [thyn-ai/algenta-sdk](https://github.com/thyn-ai/algenta-sdk) — Python & TypeScript SDKs for the Algenta decision engine: governed tool profiles, execution receipts, approvals.
- [thyn-ai/algenta-integrations](https://github.com/thyn-ai/algenta-integrations) — Framework integrations for Algenta: LangChain, LlamaIndex, pydantic-ai, MAF, Haystack, LiteLLM, Ray Serve, vLLM, Vercel AI SDK and n8n.
- [thyn-ai/mojo-kernels](https://github.com/thyn-ai/mojo-kernels) — Clean-room Mojo kernels as drop-in accelerators for popular Python/TypeScript libraries, with bit-exact parity and pure-language fallbacks.
- [thyn-ai/security-toolchain](https://github.com/thyn-ai/security-toolchain) — The pinned, checksum-verified security toolchain (Gitleaks, Opengrep, OSV-Scanner, Trivy config, actionlint) that every thyn-ai repository runs locally and in CI.
- [thyn-ai/feedback](https://github.com/thyn-ai/feedback) — Public issue intake for the Algenta family and the Codna GitHub App.
- [thyn-ai/codna-action](https://github.com/thyn-ai/codna-action) (this repository) — Public GitHub Action wrapper for Codna.

## License

This action wrapper is licensed under [Apache-2.0](./LICENSE). The `codna` package it installs
is a separate product with its own license terms; see [NOTICE](./NOTICE).
