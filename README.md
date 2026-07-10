# codna GitHub Action

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
