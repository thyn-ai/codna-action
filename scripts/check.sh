#!/usr/bin/env bash
# Lints this repository the way the `check` job in .github/workflows/ci.yml does.
#
#   1. actionlint over .github/workflows/ (workflow syntax, expression types,
#      and a shellcheck pass over every workflow `run:` block).
#   2. Every YAML file in the repository parses (PyYAML, safe loader).
#   3. Every `uses:` in a workflow is pinned: `owner/repo@<40-hex sha> # vX.Y.Z`,
#      a `docker://image:tag@sha256:<digest>`, or a local `./` path.
#   4. No `${{ }}` expression inside any `run:` block -- inputs and context
#      reach a shell through `env:`, never by string interpolation.
#   5. action.yml is a composite action whose every step runs in bash, has a
#      name, and passes shellcheck. Each step's script is checked on its own
#      with only the names from its `env:` map and the variables GitHub sets
#      on every runner declared, and check-unassigned-uppercase on: a variable
#      the step reads without declaring fails SC2154, no suppressions anywhere.
#   6. A negative check: a step that reads three undeclared variables is
#      rejected by exactly that shellcheck run, so the check has teeth.
#
# Requirements: bash, python3 with PyYAML, shellcheck, and actionlint on PATH.
# CI runs actionlint from its container image in the step before this script,
# so the script only skips actionlint when the binary is absent *and* it is
# running under GitHub Actions.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> actionlint"
if command -v actionlint >/dev/null 2>&1; then
  actionlint -color
  echo "actionlint: clean ($(actionlint --version | head -1))"
elif [ "${GITHUB_ACTIONS:-}" = "true" ]; then
  echo "actionlint is not on PATH; the workflow ran it from its container image in the preceding step."
else
  echo "actionlint is not on PATH. Install 1.7.12 (https://github.com/rhysd/actionlint/releases) and re-run." >&2
  exit 1
fi

echo "==> YAML parse, pinned uses:, no expressions inside run:"
python3 - <<'PY'
import re
import subprocess
import sys

import yaml

files = subprocess.run(
    # Tracked and untracked-but-not-ignored files alike, so a new workflow is
    # checked before it is ever staged.
    ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard",
     "*.yml", "*.yaml", ".*.yml", ".*.yaml"],
    check=True, capture_output=True,
).stdout.decode().split("\0")
files = sorted(f for f in files if f)
if not files:
    sys.exit("no YAML files found via git ls-files")

# A pinned `uses:` is a local path, a container image pinned by digest, or an
# action pinned to a full-length commit SHA followed by its version comment.
pinned = re.compile(
    r"""^\s*-?\s*uses:\s*(?:"|')?(?:
        \./\S*
      | docker://\S+@sha256:[0-9a-f]{64}
      | [\w.-]+/[\w./-]+@[0-9a-f]{40}(?:"|')?\s+\#\s*v\d+(?:\.\d+)*
    )""",
    re.VERBOSE,
)
problems = []
for path in files:
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    try:
        docs = list(yaml.safe_load_all(text))
    except yaml.YAMLError as exc:
        problems.append(f"{path}: does not parse: {exc}")
        continue
    if not path.startswith(".github/workflows/"):
        continue
    for lineno, line in enumerate(text.splitlines(), 1):
        if re.match(r"^\s*-?\s*uses:", line) and not pinned.match(line):
            problems.append(f"{path}:{lineno}: uses: is not pinned to a full commit SHA with a # vX.Y.Z comment: {line.strip()}")

    def walk(node, where):
        if isinstance(node, dict):
            for key, value in node.items():
                if key == "run" and isinstance(value, str) and "${{" in value:
                    problems.append(f"{path}: {where}: `${{{{ }}}}` inside run: -- pass it through env: instead")
                walk(value, f"{where}.{key}")
        elif isinstance(node, list):
            for i, item in enumerate(node):
                walk(item, f"{where}[{i}]")

    for doc in docs:
        walk(doc, path)

for path in files:
    print(f"  parsed {path}")
if problems:
    print("\n".join(problems), file=sys.stderr)
    sys.exit(1)
PY

echo "==> action.yml: composite, bash steps, no expressions inside run:, shellcheck per step"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# extract_steps <action.yml> <dir>
# Validates the composite action and writes one bash script per step into
# <dir> for shellcheck. Each script opens with an `export NAME=` line for every
# name in the step's `env:` map and for every variable GitHub sets on a runner
# (RUNNER_VARIABLES below), then carries the step's `run:` block verbatim.
# The shellcheck_steps function below then runs with check-unassigned-uppercase
# on, so a step that reads a variable its `env:` does not provide -- a misspelt
# input variable, a misspelt GITHUB_* -- fails SC2154 exactly as an unassigned
# lowercase local does. No directive or disable is written into the scripts.
extract_steps() {
  python3 - "$1" "$2" <<'PY'
import re
import sys

import yaml

src, out = sys.argv[1:]

# Variables GitHub sets for every step of every job, from
# https://docs.github.com/en/actions/reference/workflows-and-actions/variables
# and the workflow-command files (GITHUB_STATE). GITHUB_TOKEN is deliberately
# absent: it is a secret, and a step that needs it declares it in `env:`.
RUNNER_VARIABLES = """
CI GITHUB_ACTION GITHUB_ACTIONS GITHUB_ACTION_PATH GITHUB_ACTION_REPOSITORY
GITHUB_ACTOR GITHUB_ACTOR_ID GITHUB_API_URL GITHUB_ARTIFACTS GITHUB_ARTIFACTS_LIST
GITHUB_BASE_REF GITHUB_ENV GITHUB_EVENT_NAME GITHUB_EVENT_PATH GITHUB_GRAPHQL_URL
GITHUB_HEAD_REF GITHUB_JOB GITHUB_OUTPUT GITHUB_PATH GITHUB_REF GITHUB_REF_NAME
GITHUB_REF_PROTECTED GITHUB_REF_TYPE GITHUB_REPOSITORY GITHUB_REPOSITORY_ID
GITHUB_REPOSITORY_OWNER GITHUB_REPOSITORY_OWNER_ID GITHUB_RETENTION_DAYS
GITHUB_RUN_ATTEMPT GITHUB_RUN_ID GITHUB_RUN_NUMBER GITHUB_SERVER_URL GITHUB_SHA
GITHUB_STATE GITHUB_STEP_SUMMARY GITHUB_TRIGGERING_ACTOR GITHUB_WORKFLOW
GITHUB_WORKFLOW_REF GITHUB_WORKFLOW_SHA GITHUB_WORKSPACE
RUNNER_ARCH RUNNER_DEBUG RUNNER_ENVIRONMENT RUNNER_NAME RUNNER_OS RUNNER_TEMP
RUNNER_TOOL_CACHE
""".split()
IDENTIFIER = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")

with open(src, encoding="utf-8") as fh:
    action = yaml.safe_load(fh)

problems = []
for key in ("name", "description", "inputs", "runs"):
    if key not in action:
        problems.append(f"{src}: missing top-level `{key}`")
runs = action.get("runs", {})
if runs.get("using") != "composite":
    problems.append(f"{src}: runs.using is {runs.get('using')!r}, expected 'composite'")
steps = runs.get("steps") or []
if not steps:
    problems.append(f"{src}: runs.steps is empty")
for i, step in enumerate(steps):
    label = step.get("name") or step.get("id") or f"step {i}"
    if not step.get("name"):
        problems.append(f"{src}: step {i} has no name")
    if "run" not in step:
        problems.append(f"{src}: {label}: composite steps here must be `run:` steps")
        continue
    if step.get("shell") != "bash":
        problems.append(f"{src}: {label}: shell is {step.get('shell')!r}, expected 'bash'")
    if "${{" in step["run"]:
        problems.append(f"{src}: {label}: `${{{{ }}}}` inside run: -- pass it through env: instead")
    env_names = sorted(step.get("env") or {})
    for name in env_names:
        if not IDENTIFIER.fullmatch(name):
            problems.append(f"{src}: {label}: env: name {name!r} is not a shell identifier")
    declared = list(dict.fromkeys(env_names + RUNNER_VARIABLES))
    slug = re.sub(r"[^A-Za-z0-9]+", "-", label).strip("-").lower()
    with open(f"{out}/step-{i}-{slug}.sh", "w", encoding="utf-8") as fh:
        fh.write("#!/usr/bin/env bash\n")
        fh.write(f"# {src}, step {label!r}: {len(env_names)} env: names and "
                 f"{len(RUNNER_VARIABLES)} runner variables declared for shellcheck;\n")
        fh.write(f"# the step's run: block starts at line {len(declared) + 4}.\n")
        for name in declared:
            fh.write(f"export {name}=\n")
        fh.write(step["run"])
for name, spec in (action.get("inputs") or {}).items():
    if not spec.get("description"):
        problems.append(f"{src}: input `{name}` has no description")
for name, spec in (action.get("outputs") or {}).items():
    if not spec.get("description"):
        problems.append(f"{src}: output `{name}` has no description")

if problems:
    print("\n".join(problems), file=sys.stderr)
    sys.exit(1)
print(f"  {src}: {action['name']!r}, composite, {len(steps)} bash steps, "
      f"{len(action.get('inputs') or {})} inputs, {len(action.get('outputs') or {})} outputs")
PY
}

# Usage: shellcheck_steps <dir> [shellcheck options]
shellcheck_steps() {
  local dir="$1"
  shift
  local scripts=("$dir"/*.sh)
  shellcheck -s bash -o check-unassigned-uppercase "$@" "${scripts[@]}"
}

mkdir "$tmp/steps"
extract_steps action.yml "$tmp/steps"
shellcheck_steps "$tmp/steps"
step_scripts=("$tmp/steps"/*.sh)
echo "  shellcheck: clean on ${#step_scripts[@]} step scripts ($(shellcheck --version | sed -n 's/^version: //p')), check-unassigned-uppercase on:" \
     "every variable a step reads is in its env: or set by the runner"

echo "==> negative check: a step that reads a variable its env: does not provide must fail shellcheck"
mkdir -p "$tmp/negative/steps"
cat > "$tmp/negative/action.yml" <<'YAML'
name: negative
description: One step reading three undeclared variables; extract_steps + shellcheck_steps must reject it.
inputs: {}
runs:
  using: composite
  steps:
    - name: reads undeclared variables
      shell: bash
      env:
        CODNA_ACTION_DECLARED: declared
      run: |
        set -euo pipefail
        echo "$CODNA_ACTION_DECLARED" "$GITHUB_OUTPUT" "$HOME"
        echo "$CODNA_ACTION_NOT_IN_ENV" "$GITHUB_OUTPTU" "$never_assigned"
YAML
extract_steps "$tmp/negative/action.yml" "$tmp/negative/steps" >/dev/null
if negative_out="$(shellcheck_steps "$tmp/negative/steps" -f gcc 2>&1)"; then
  { echo "negative check: shellcheck accepted a step that reads undeclared variables:"; echo "$negative_out"; } >&2
  exit 1
fi
for name in CODNA_ACTION_NOT_IN_ENV GITHUB_OUTPTU never_assigned; do
  if ! grep -Eq "warning: $name is referenced but not assigned" <<<"$negative_out"; then
    { echo "negative check: expected SC2154 for $name; shellcheck said:"; echo "$negative_out"; } >&2
    exit 1
  fi
done
for name in CODNA_ACTION_DECLARED GITHUB_OUTPUT HOME; do
  if grep -Eq "warning: $name is referenced" <<<"$negative_out"; then
    { echo "negative check: $name is declared and must not be reported; shellcheck said:"; echo "$negative_out"; } >&2
    exit 1
  fi
done
echo "  negative check: SC2154 for CODNA_ACTION_NOT_IN_ENV, GITHUB_OUTPTU and never_assigned; nothing for the declared names"

echo "OK"
