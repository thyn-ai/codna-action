#!/usr/bin/env bash
# Runs the action's own "Install codna" step, exactly as written in action.yml,
# against PyPI -- the `smoke` job in .github/workflows/ci.yml, and the closest
# thing to running the action locally without provider keys or a pull request.
#
# It installs the `codna` package on this machine the way the action does on a
# runner (pipx when present, otherwise `pip install --user`) and ends with the
# step's own `codna --version`. Set CODNA_ACTION_PACKAGE_SPEC to pin, exactly
# like the action's `package-spec` input:
#
#   scripts/smoke-install.sh                                   # latest codna
#   CODNA_ACTION_PACKAGE_SPEC=codna==0.2.53 scripts/smoke-install.sh
#
# Requirements: bash, python3 with PyYAML, and pipx or pip.
set -euo pipefail
cd "$(dirname "$0")/.."

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

python3 - "$tmp/install.sh" <<'PY'
import sys

import yaml

with open("action.yml", encoding="utf-8") as fh:
    action = yaml.safe_load(fh)
step = next(s for s in action["runs"]["steps"] if s.get("name") == "Install codna")
with open(sys.argv[1], "w", encoding="utf-8") as fh:
    fh.write(step["run"])
print(f"extracted step {step['name']!r} ({len(step['run'].splitlines())} lines) from action.yml")
PY

# The step reads its input from the same environment variable the action's
# `env:` block sets, and appends to $GITHUB_PATH on the pip fallback branch.
export CODNA_ACTION_PACKAGE_SPEC="${CODNA_ACTION_PACKAGE_SPEC:-codna}"
export GITHUB_PATH="${GITHUB_PATH:-$tmp/github_path}"
echo "running the step with CODNA_ACTION_PACKAGE_SPEC=$CODNA_ACTION_PACKAGE_SPEC"
bash "$tmp/install.sh"
