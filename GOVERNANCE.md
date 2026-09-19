# Governance

This document describes how decisions are made for `thyn-ai/codna-action`,
the public GitHub Action wrapper for Codna. It is intentionally lightweight
and will evolve as the contributor community grows.

## Roles

- **Contributors** — anyone who opens issues, participates in discussions, or
  submits pull requests.
- **Maintainers** — people with merge and tagging authority on this
  repository. The project currently has a single maintainer: the `thyn-ai`
  organization owner (see [CODEOWNERS](./.github/CODEOWNERS)), who also
  holds final decision authority on all matters not explicitly delegated.

## Decision-making

Day-to-day decisions are made by **lazy consensus**:

1. Propose the change as a GitHub issue or pull request.
2. Maintainers and contributors discuss in the open.
3. If no maintainer objects within 72 hours (three business days), the
   proposal is considered accepted and may proceed.

Maintainers may fast-track obvious, low-risk changes (typo fixes, CI repairs,
dependency security bumps) without waiting out the window. Any maintainer may
pause lazy consensus by raising an objection, in which case the change waits
until the objection is resolved in discussion. Where consensus cannot be
reached, the organization owner makes the final call.

One standing rule is not subject to lazy consensus, because it is the
guarantee the wrapper makes to its users: **the action installs the published
`codna` package and runs it. It never bundles, vendors or re-implements any
part of Codna, and every mode and flag it exposes is one the `codna` CLI
already has, invoked with the same semantics.** A change that would make the
action behave differently from the CLI for the same inputs is not mergeable.

## Becoming a maintainer

External contributors can become maintainers. The path:

1. **Sustained contribution** — a track record of merged pull requests,
   thoughtful reviews, and issue triage over several months.
2. **Nomination** — an existing maintainer nominates the contributor, citing
   specific contributions, in a GitHub discussion visible to all maintainers.
3. **Lazy consensus** — if no maintainer objects within 14 days, the
   nomination carries. The organization owner confirms and grants access.

Maintainers are expected to review pull requests, triage issues, uphold the
[Code of Conduct](./CODE_OF_CONDUCT.md), follow the
[security policy](./SECURITY.md), and keep CI green on `main`. Maintainers
who become inactive for more than a year may be moved to emeritus status by
the organization owner; emeritus maintainers can regain commit access on
request.

## Releases

- Users consume the action by git ref. `v1` is a floating tag that a
  maintainer moves to a vetted commit on `main` once a change to the
  action's behaviour has been reviewed and exercised against a real
  repository (see
  [CONTRIBUTING.md](./CONTRIBUTING.md#releases-and-the-v1-tag)). There are
  no per-version tags, GitHub Releases or Marketplace listing today.
- A change that breaks an existing input, output or mode is released under a
  new major tag (`v2`) and announced in an issue; `v1` keeps its contract.
- Release decisions — what the `v1` tag moves to, and when — are made by
  maintainers through lazy consensus as described above, with the
  organization owner holding final authority. Moving the tag currently rests
  solely with the organization owner.

## Changing this document

Amendments to this file follow the same lazy-consensus process as any other
change, with one difference: the review window is 14 days, and the
organization owner must approve the merged pull request.
