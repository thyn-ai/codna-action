## What does this change?

<!-- One or two sentences. A change to what Codna does belongs in Codna, not in
     this wrapper (see CONTRIBUTING.md); a bug in Codna's output goes to
     https://github.com/thyn-ai/feedback. -->

## Checklist

- [ ] `scripts/check.sh` passes: actionlint clean, every YAML file parses,
      action.yml validated, shellcheck clean on every step
- [ ] `action.yml` changes: inputs and `github.*` values reach the step through
      `env:`, never `${{ }}` inside `run:`; every input has a description; the
      behaviour matches the `codna` CLI for the same arguments
- [ ] README updated for any input, output, default or mode I changed
- [ ] Workflow changes: every `uses:` pinned to a full commit SHA with a `# vX.Y.Z`
      comment, top-level `permissions: contents: read`, write scopes on the job
- [ ] `.github/workflows/security.yml` and the toolchain block in
      `.pre-commit-config.yaml` are untouched — thyn-ai/security-toolchain manages
      those pins
- [ ] No hardcoded credentials or secrets
- [ ] I agree my contribution is licensed under the project's Apache-2.0
      license (inbound=outbound, GitHub Terms of Service §D.6)
