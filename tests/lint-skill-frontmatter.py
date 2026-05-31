#!/usr/bin/env python3
"""Lint every SKILL.md's YAML frontmatter with a strict parser.

Why: Codex CLI parses SKILL.md frontmatter with a strict YAML parser, while
Claude Code is lenient. A `: ` (colon-space) inside an unquoted scalar (e.g. a
`description:` value) is read as a nested mapping and makes Codex reject the
*whole* skill — silently, so the skill just never loads. With ~a dozen skills
carrying long, comma- and colon-rich descriptions, this is the most likely way
to break the Codex surface without noticing. This lint reproduces that
strictness (`yaml.safe_load`) so the bug can't regress.

Checks, per `**/SKILL.md`:
  1. A frontmatter block exists (`---` ... `---` at the top).
  2. It parses as strict YAML.
  3. It is a mapping with non-empty string `name` and `description`.

Exit 0 if all skills pass, 1 otherwise, 2 if PyYAML is unavailable.
Requires PyYAML.
"""
import pathlib
import re
import sys

try:
    import yaml
except ImportError:
    print("SKIP: PyYAML not installed (pip install pyyaml)", file=sys.stderr)
    sys.exit(2)

FRONTMATTER = re.compile(r"^---\n(.*?)\n---\n", re.DOTALL)


def check(path: pathlib.Path) -> list:
    errors = []
    text = path.read_text()
    m = FRONTMATTER.match(text)
    if not m:
        return [f"{path}: no `---` frontmatter block at top of file"]
    try:
        data = yaml.safe_load(m.group(1))
    except yaml.YAMLError as e:
        return [f"{path}: invalid YAML frontmatter: {e}"]
    if not isinstance(data, dict):
        return [f"{path}: frontmatter is not a mapping"]
    for key in ("name", "description"):
        val = data.get(key)
        if not isinstance(val, str) or not val.strip():
            errors.append(f"{path}: frontmatter `{key}` missing or not a non-empty string")
    return errors


def main() -> int:
    root = pathlib.Path(__file__).resolve().parent.parent
    skills = sorted(root.glob("**/SKILL.md"))
    if not skills:
        print("no SKILL.md files found", file=sys.stderr)
        return 0
    all_errors = []
    for path in skills:
        errs = check(path)
        rel = path.relative_to(root)
        if errs:
            all_errors.extend(errs)
            print(f"[FAIL] {rel}")
        else:
            print(f"[ok]   {rel}")
    if all_errors:
        print("\n" + "\n".join(all_errors), file=sys.stderr)
        print(f"\n{len(all_errors)} problem(s) across {len(skills)} skill(s)", file=sys.stderr)
        return 1
    print(f"\nall {len(skills)} SKILL.md frontmatter blocks are strict-YAML clean")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
