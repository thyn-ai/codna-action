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
#      name, and passes shellcheck (each step's script is checked on its own).
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
python3 - "$tmp" <<'PY'
import re
import sys

import yaml

out = sys.argv[1]
with open("action.yml", encoding="utf-8") as fh:
    action = yaml.safe_load(fh)

problems = []
for key in ("name", "description", "inputs", "runs"):
    if key not in action:
        problems.append(f"action.yml: missing top-level `{key}`")
runs = action.get("runs", {})
if runs.get("using") != "composite":
    problems.append(f"action.yml: runs.using is {runs.get('using')!r}, expected 'composite'")
steps = runs.get("steps") or []
if not steps:
    problems.append("action.yml: runs.steps is empty")
for i, step in enumerate(steps):
    label = step.get("name") or step.get("id") or f"step {i}"
    if not step.get("name"):
        problems.append(f"action.yml: step {i} has no name")
    if "run" not in step:
        problems.append(f"action.yml: {label}: composite steps here must be `run:` steps")
        continue
    if step.get("shell") != "bash":
        problems.append(f"action.yml: {label}: shell is {step.get('shell')!r}, expected 'bash'")
    if "${{" in step["run"]:
        problems.append(f"action.yml: {label}: `${{{{ }}}}` inside run: -- pass it through env: instead")
    slug = re.sub(r"[^A-Za-z0-9]+", "-", label).strip("-").lower()
    with open(f"{out}/step-{i}-{slug}.sh", "w", encoding="utf-8") as fh:
        fh.write("#!/usr/bin/env bash\n")
        fh.write(step["run"])
for name, spec in (action.get("inputs") or {}).items():
    if not spec.get("description"):
        problems.append(f"action.yml: input `{name}` has no description")
for name, spec in (action.get("outputs") or {}).items():
    if not spec.get("description"):
        problems.append(f"action.yml: output `{name}` has no description")

if problems:
    print("\n".join(problems), file=sys.stderr)
    sys.exit(1)
print(f"  action.yml: {action['name']!r}, composite, {len(steps)} bash steps, "
      f"{len(action.get('inputs') or {})} inputs, {len(action.get('outputs') or {})} outputs")
PY
step_scripts=("$tmp"/*.sh)
shellcheck -s bash "${step_scripts[@]}"
echo "  shellcheck: clean on ${#step_scripts[@]} step scripts ($(shellcheck --version | sed -n 's/^version: //p'))"

echo "OK"
