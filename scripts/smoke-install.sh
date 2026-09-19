#!/usr/bin/env bash
# Runs the action's own "Install codna" step, exactly as written in action.yml,
# against PyPI -- the `smoke` job in .github/workflows/ci.yml, and the closest
# thing to running the action locally without provider keys or a pull request.
#
# The step has two branches and this script runs both. Each run must end in
# the step's own `codna --version`:
#
#   pipx          -- the step as it runs on GitHub-hosted runners, where pipx is
#                    on PATH. It must leave GITHUB_PATH untouched.
#   pip fallback  -- the same step on a PATH from which pipx (and any codna) is
#                    absent: every directory offering either is replaced by a
#                    shadow directory of symlinks to everything else in it, so
#                    the step takes `pip install --user`. PYTHONUSERBASE points
#                    at a fresh directory that is on nobody's PATH, so the
#                    step's `codna --version` can only succeed if the step put
#                    the user scripts directory on its own PATH -- and it must
#                    also have written that directory to GITHUB_PATH for the
#                    steps that follow it.
#
# Set CODNA_ACTION_PACKAGE_SPEC to pin, exactly like the action's `package-spec`
# input:
#
#   scripts/smoke-install.sh                                   # latest codna
#   CODNA_ACTION_PACKAGE_SPEC=codna==0.2.53 scripts/smoke-install.sh
#
# Requirements: bash, python3 with PyYAML and pip, and pipx. Without pipx the
# pipx run is skipped on a developer machine and fails under GitHub Actions,
# where it is the branch real users take.
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
# `env:` block sets.
export CODNA_ACTION_PACKAGE_SPEC="${CODNA_ACTION_PACKAGE_SPEC:-codna}"
echo "running the step with CODNA_ACTION_PACKAGE_SPEC=$CODNA_ACTION_PACKAGE_SPEC"

# run_step <label> <GITHUB_PATH file> [NAME=value ...]
# Runs the extracted step once, with an empty GITHUB_PATH file and the given
# environment settings for that run only, and requires the step's final
# `codna --version` line on its stdout.
run_step() {
  local label="$1" github_path="$2"
  shift 2
  : > "$github_path"
  echo "==> $label"
  env "$@" GITHUB_PATH="$github_path" "$BASH" "$tmp/install.sh" | tee "$tmp/step.out"
  if ! tail -n 1 "$tmp/step.out" | grep -Eq 'codna.*[0-9]'; then
    echo "smoke: $label: the step's last line is not the output of codna --version" >&2
    exit 1
  fi
}

pipx_github_path="$tmp/github_path.pipx"
if command -v pipx >/dev/null 2>&1; then
  run_step "pipx branch: pipx on PATH, as on GitHub-hosted runners" "$pipx_github_path"
  if [ -s "$pipx_github_path" ]; then
    echo "smoke: pipx branch: GITHUB_PATH must stay empty, but the step wrote: $(tr '\n' ' ' < "$pipx_github_path")" >&2
    exit 1
  fi
  echo "  pipx branch: codna --version succeeded; GITHUB_PATH untouched"
elif [ "${GITHUB_ACTIONS:-}" = "true" ]; then
  echo "smoke: pipx is not on PATH on this runner; the pipx branch is the one GitHub-hosted runners take." >&2
  exit 1
else
  echo "==> pipx branch: skipped, pipx is not on PATH here (GitHub-hosted runners have it)"
fi

# A PATH identical to the current one except that no directory on it offers
# pipx or codna: each directory that does is replaced by a shadow directory
# of symlinks to everything else in it, so python3 and the rest stay reachable.
no_pipx_path=""
shadows=0
IFS=: read -r -a path_dirs <<<"$PATH"
for dir in "${path_dirs[@]}"; do
  [ -n "$dir" ] || continue
  if [ -x "$dir/pipx" ] || [ -x "$dir/codna" ]; then
    shadows=$((shadows + 1))
    shadow="$tmp/no-pipx/$shadows"
    mkdir -p "$shadow"
    for entry in "$dir"/*; do
      [ -e "$entry" ] || continue
      case "${entry##*/}" in
        pipx|codna) ;;
        *) ln -s "$entry" "$shadow/${entry##*/}" ;;
      esac
    done
    dir="$shadow"
  fi
  no_pipx_path="${no_pipx_path:+$no_pipx_path:}$dir"
done
for hidden in pipx codna; do
  if env PATH="$no_pipx_path" "$BASH" -c "command -v $hidden" >/dev/null 2>&1; then
    echo "smoke: could not build a PATH without $hidden" >&2
    exit 1
  fi
done

user_base="$tmp/userbase"   # fresh, empty, and on nobody's PATH
fallback_github_path="$tmp/github_path.pip"
run_step "pip fallback: pipx and codna hidden from PATH, PYTHONUSERBASE=$user_base" \
  "$fallback_github_path" PATH="$no_pipx_path" PYTHONUSERBASE="$user_base"
expected_bin="$user_base/bin"
if [ "$(cat "$fallback_github_path")" != "$expected_bin" ]; then
  echo "smoke: pip fallback: GITHUB_PATH should hold exactly $expected_bin for later steps, but holds: $(tr '\n' ' ' < "$fallback_github_path")" >&2
  exit 1
fi
if [ ! -x "$expected_bin/codna" ]; then
  echo "smoke: pip fallback: $expected_bin/codna does not exist, so codna --version above ran some other codna" >&2
  exit 1
fi
echo "  pip fallback: codna --version succeeded from $expected_bin; GITHUB_PATH holds it for later steps"

echo "OK"
