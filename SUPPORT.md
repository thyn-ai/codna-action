# Support

## Where to get help

| What you need | Where to go |
| --- | --- |
| A bug in this action wrapper — the install step, an input that does not reach `codna` the way the README says, the `pull-request-url` output, the diff range chosen in `review` mode | [GitHub Issues](https://github.com/thyn-ai/codna-action/issues) here, with the `bug` label — include the action ref, the `codna` version from the job log, the runner, and the workflow snippet with secrets removed |
| A bug in what Codna itself did — the fix PR it opened, the review findings it posted, a `secure` classification, an error from the `codna` CLI | [thyn-ai/feedback](https://github.com/thyn-ai/feedback/issues/new/choose), Codna's public issue intake, with the product set to `codna` |
| A new input, output or mode for the wrapper | [GitHub Issues](https://github.com/thyn-ai/codna-action/issues) here, with the `enhancement` label — the flag or mode must already exist in the `codna` CLI (see [CONTRIBUTING.md](./CONTRIBUTING.md)); a capability Codna lacks is a [feedback](https://github.com/thyn-ai/feedback/issues/new/choose) request |
| Usage questions, ideas, show-and-tell | [GitHub Discussions](https://github.com/thyn-ai/codna-action/discussions) |
| Real-time chat with the community | [Discord](https://discord.gg/w8NDsph9an) |
| Documentation | The [README](./README.md) for the action's inputs and modes; [docs.codna.ai](https://docs.codna.ai) for Codna itself |

Before filing an issue, please search existing issues and discussions — your
question may already have an answer. If a run fails, first check whether the
same `codna` command succeeds from a terminal with the same package version
(the install step prints the version it installed; `pipx install codna==<version>`
reproduces it), and say so in the report: it tells us whether the problem is
in the wrapper or in Codna.

## Security issues

**Never report a security vulnerability in a public issue, discussion, or
pull request.** Follow [SECURITY.md](./SECURITY.md): use GitHub Security
Advisories or email `security@algenta.ai` — for the wrapper and for Codna
itself.

## Response expectations

Community support is provided on a best-effort basis by maintainers and other
community members. **There is no SLA for community support** — we triage
issues as time permits, prioritizing security reports (which have their own
response commitments in [SECURITY.md](./SECURITY.md)), a wrapper bug that
changes what runs or where it posts, and regressions on the current `v1`
tag.

Enterprise customers with a commercial agreement should use their contracted
support channel or the [accounts portal](https://accounts.thyn.ai/account),
or contact community@algenta.ai to be routed.
