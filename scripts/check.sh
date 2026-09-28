#!/usr/bin/env bash
# Repo verification gate: run locally before committing; CI runs the same script.
# cribs has no build or test suite (it is one SKILL.md plus docs), so this checks
# the two things that can silently break an install or a reader:
#   1. every skills/<name>/SKILL.md has frontmatter whose `name` matches <name>
#      and a non-empty `description` (Claude Code needs both to load the skill)
#   2. every relative link in a tracked Markdown file points at a file that exists
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

python3 - <<'PY'
import re, subprocess, sys
from pathlib import Path

errors = []
tracked = subprocess.run(["git", "ls-files", "-co", "--exclude-standard"],
                         capture_output=True, text=True, check=True).stdout.split()

skills = [Path(p) for p in tracked if re.fullmatch(r"skills/[^/]+/SKILL\.md", p)]
if not skills:
    errors.append("no skills/<name>/SKILL.md found")
for skill in skills:
    text = skill.read_text()
    m = re.match(r"---\n(.*?)\n---\n", text, re.S)
    if not m:
        errors.append(f"{skill}: missing YAML frontmatter")
        continue
    fields = dict(re.findall(r"^(\w+):\s*(.*)$", m.group(1), re.M))
    if fields.get("name") != skill.parent.name:
        errors.append(f"{skill}: name {fields.get('name')!r} != directory {skill.parent.name!r}")
    if not fields.get("description", "").strip():
        errors.append(f"{skill}: empty description")

link = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
for p in (Path(p) for p in tracked if p.endswith(".md")):
    in_fence = False
    for n, line in enumerate(p.read_text().splitlines(), 1):
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
        if in_fence:
            continue
        for target in link.findall(line):
            if re.match(r"[a-z]+:", target) or target.startswith("#"):
                continue  # external URL, mailto, or in-page anchor
            path = target.split("#")[0]
            if path and not (p.parent / path).exists():
                errors.append(f"{p}:{n}: broken link -> {target}")

for e in errors:
    print(f"FAIL {e}")
print(f"checked {len(skills)} skill(s); {len(errors)} problem(s)")
sys.exit(1 if errors else 0)
PY
