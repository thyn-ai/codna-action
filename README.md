# codna GitHub Action

Public wrapper for Codna's GitHub Action channel. The action installs the published `codna` package from PyPI, then runs the same CLI users run locally.

Users install one product: `codna`. Telys is bundled inside the Codna package; there is no separate Telys install or publishing path for Codna users.

## Fix mode

```yaml
permissions:
  contents: write
  pull-requests: write

steps:
  - uses: actions/checkout@v4
  - uses: thyn-ai/codna-action@v1
    with:
      mode: fix
      issue: "CI failed on checkout tests"
      model: openai/gpt-5.5
      github-token: ${{ secrets.CODNA_GITHUB_TOKEN || github.token }}
```

Set `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, or `GEMINI_API_KEY` in the job environment for local-runtime model use, or pass `api-key` plus `engine-url` for hosted/engine-behind runs.

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

Secure mode is read-only in this wrapper. Opening security PRs should use Codna's privilege-separated evidence/writer workflow.
