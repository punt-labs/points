#!/usr/bin/env python3
"""Validate the complete gstack-implementer shell permission policy."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


APPROVED_RULES = [
    ("*", "*", "deny"),
    ("read", "*", "allow"),
    ("glob", "*", "allow"),
    ("grep", "*", "allow"),
    ("shell", "git status *", "allow"),
    ("shell", "git diff *", "allow"),
    ("shell", "git log *", "allow"),
    ("shell", "git show *", "allow"),
    ("shell", "go test *", "allow"),
    ("shell", "go vet *", "allow"),
    ("shell", "go list *", "allow"),
    ("shell", "make", "allow"),
    ("shell", "make build", "allow"),
    ("shell", "make check", "allow"),
    ("shell", "make check-dev", "allow"),
    ("shell", "make coverage", "allow"),
    ("shell", "make spec", "allow"),
    ("shell", "make spec-prob", "allow"),
    ("shell", "make test", "allow"),
    ("shell", "./points *", "allow"),
    ("shell", "fuzz *", "allow"),
    ("external_directory", "*", "allow"),
    ("edit", "*", "allow"),
]

APPROVED_METADATA = {
    "description": "Implements approved points changes completely with tests; use after architecture and acceptance criteria are settled.",
    "mode": "subagent",
    "model": "bifrost/openai/gpt-5.6-sol",
    "variant": "high",
    "color": '"#16a34a"',
    "steps": "64",
}


class PolicyError(ValueError):
    pass


def scalar(value: str) -> str:
    value = value.strip(" \t")
    if value.startswith('"'):
        if not value.endswith('"'):
            raise PolicyError("unterminated double-quoted scalar")
        try:
            parsed = json.loads(value)
        except json.JSONDecodeError as exc:
            raise PolicyError("invalid double-quoted scalar") from exc
        if not isinstance(parsed, str):
            raise PolicyError("permission scalar is not a string")
        return parsed
    if value.startswith("'"):
        if not value.endswith("'"):
            raise PolicyError("unterminated single-quoted scalar")
        # YAML single quotes preserve backslashes; only doubled single quotes
        # encode a quote. Python literal parsing would incorrectly decode \xNN.
        inner = value[1:-1]
        if "'" in inner.replace("''", ""):
            raise PolicyError("invalid single-quoted scalar")
        return inner.replace("''", "'")
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_-]*", value):
        raise PolicyError("unsupported unquoted scalar")
    return value


def rules(text: str) -> list[tuple[str, str, str]]:
    if not text.startswith("---\n"):
        raise PolicyError("agent frontmatter is missing")
    end = text.find("\n---\n", 4)
    if end < 0:
        raise PolicyError("agent frontmatter is unterminated")
    frontmatter = text[4:end]
    for character in frontmatter:
        codepoint = ord(character)
        printable = (
            codepoint in {0x09, 0x0A, 0x0D}
            or 0x20 <= codepoint <= 0x7E
            or codepoint == 0x85
            or 0xA0 <= codepoint <= 0xD7FF
            or 0xE000 <= codepoint <= 0xFFFD
            or 0x10000 <= codepoint <= 0x10FFFF
        )
        if not printable:
            raise PolicyError(f"forbidden frontmatter control U+{codepoint:04X}")
    lines = frontmatter.split("\n")

    found: list[tuple[str, str, str]] = []
    current: dict[str, str] | None = None
    in_permissions = False
    permissions_keys = 0
    top_keys: set[str] = set()
    allowed_top_keys = {
        "description",
        "mode",
        "model",
        "variant",
        "color",
        "steps",
        "permissions",
    }

    def finish() -> None:
        nonlocal current
        if current is None:
            return
        if set(current) != {"action", "resource", "effect"}:
            raise PolicyError(f"incomplete permission rule: {current}")
        found.append((current["action"], current["resource"], current["effect"]))
        current = None

    for line in lines:
        if not line.strip(" \t") or line.lstrip(" \t").startswith("#"):
            continue
        if line.startswith("? ") or line.startswith(": "):
            raise PolicyError("explicit YAML mapping syntax is unsupported")
        if not line[0].isspace():
            if ":" not in line:
                raise PolicyError(f"unsupported top-level syntax: {line!r}")
            key = line.split(":", 1)[0]
            if key not in allowed_top_keys:
                raise PolicyError(f"unsupported top-level key syntax: {line!r}")
            if key in top_keys:
                raise PolicyError(f"duplicate top-level key: {key}")
            if in_permissions:
                raise PolicyError("permissions must be the final top-level section")
            top_keys.add(key)
            if key == "permissions":
                permissions_keys += 1
                if permissions_keys != 1 or line != "permissions:":
                    raise PolicyError(
                        "permissions key must appear once in canonical form"
                    )
            else:
                expected = f"{key}: {APPROVED_METADATA[key]}"
                if line != expected:
                    raise PolicyError(f"metadata line differs: {line!r}")
                continue
        if line == "permissions:":
            in_permissions = True
            continue
        if not in_permissions:
            raise PolicyError(f"unsupported metadata continuation: {line!r}")
        if line.startswith("  - action: "):
            finish()
            current = {"action": scalar(line.removeprefix("  - action: "))}
        elif current is not None and line.startswith("    resource: "):
            if "resource" in current:
                raise PolicyError("duplicate resource key")
            current["resource"] = scalar(line.removeprefix("    resource: "))
        elif current is not None and line.startswith("    effect: "):
            if "effect" in current:
                raise PolicyError("duplicate effect key")
            current["effect"] = scalar(line.removeprefix("    effect: "))
        elif line.strip(" \t"):
            raise PolicyError(f"unsupported permission syntax: {line!r}")
    finish()
    if top_keys != allowed_top_keys:
        raise PolicyError(f"top-level metadata keys differ: {sorted(top_keys)!r}")
    if permissions_keys != 1:
        raise PolicyError("agent must contain exactly one permissions key")
    if not found:
        raise PolicyError("agent has no permission rules")
    return found


def validate(text: str) -> None:
    found = rules(text)
    if found != APPROVED_RULES:
        raise PolicyError(f"ordered permission policy differs: {found!r}")


def add_rule(
    text: str, action: str, resource: str, effect: str, quote: str = '"'
) -> str:
    marker = "\n---\n"
    if marker not in text:
        raise AssertionError("fixture frontmatter missing")
    rendered = (
        f"  - action: {action}\n"
        f"    resource: {quote}{resource}{quote}\n"
        f"    effect: {effect}\n"
    )
    return text.replace(marker, "\n" + rendered + "---\n", 1)


def self_test(text: str) -> None:
    validate(text)
    rejected = [
        add_rule(text, "shell", "python3*", "allow"),
        add_rule(text, "shell", "p*", "allow", quote="'"),
        add_rule(text, "shell", "python3 ?", "allow"),
        add_rule(text, "shell", "python3 -c 'print(1)'", "allow"),
        add_rule(text, "shell", "python3 .tmp/other.py", "allow"),
        add_rule(text, "shell", "make --eval 'escape: ; true' escape", "allow"),
        add_rule(text, "shell", "make check", "deny"),
        add_rule(text, "*", "*", "allow"),
        add_rule(text, "s*", "python3*", "allow"),
        add_rule(text, "*", "python3*", "ask"),
        add_rule(text, "*", "python3*", "deny"),
        text.replace(
            "\n---\n",
            '\n  - {action: shell, resource: "python3*", effect: allow}\n---\n',
            1,
        ),
        text.replace(
            "\n---\n",
            '\n  - resource: "python3*"\n    action: shell\n    effect: allow\n---\n',
            1,
        ),
        text.replace(
            "\n---\n",
            '\n  - action: shell\n    resource: "python3*"\n'
            '    resource: "p*"\n    effect: allow\n---\n',
            1,
        ),
        text.replace(
            '  - action: edit\n    resource: "*"\n    effect: allow',
            "  - action: edit\n    resource: '\\x2a'\n    effect: allow",
            1,
        ),
        text.replace('  - action: "*"\n', "  - action: '\\x2a'\n", 1),
        text.replace('    resource: "*"\n', "    resource: '\\x2a'\n", 1),
        text.replace('  - action: "*"\n', "  - action: *\n", 1),
        text.replace('    resource: "*"\n', "    resource: *\n", 1),
        text.replace("  - action: read\n", '  - action: "re""ad"\n', 1),
        text.replace("\n---\n", "\npermissions:\n---\n", 1),
        text.replace("permissions:\n", '"permissions": []\npermissions:\n', 1),
        text.replace(
            "\n---\n",
            "\n'permissions': []\n---\n",
            1,
        ),
        text.replace(
            "permissions:\n",
            "? permissions\n: []\npermissions:\n",
            1,
        ),
        text.replace(
            "permissions:\n",
            "!!str permissions: []\npermissions:\n",
            1,
        ),
        text.replace(
            "permissions:\n",
            "&policy permissions: []\npermissions:\n",
            1,
        ),
        text.replace(
            "permissions:\n",
            '"\\x70ermissions": []\npermissions:\n',
            1,
        ),
        text.replace(
            "description: " + APPROVED_METADATA["description"],
            'description: "unterminated',
            1,
        ),
        text.replace(
            "description: " + APPROVED_METADATA["description"],
            "description: 'unterminated\n#'",
            1,
        ),
        text.replace("steps: 64\n", "", 1),
        text.replace("variant: high\n", "", 1),
        text.replace("steps: 64\n", "", 1).replace(
            "\n---\n",
            "\nsteps: 64\n---\n",
            1,
        ),
        text.replace("permissions:\n", "\x0bpermissions:\n", 1),
        text.replace("permissions:\n", "permissions:\x0c\n", 1),
        text.replace("\n---\n", "\x1c\n---\n", 1),
        text.replace("\n---\n", "\n\u00a0\n---\n", 1),
        text.replace('    resource: "*"\n', '    resource: \u00a0"*"\n', 1),
        text.replace("\n---\n", "\n# forbidden \u0080 control\n---\n", 1),
        text.replace("steps: 64\n", "", 1).replace(
            '  - action: "*"\n    resource: "*"',
            '  - action: "*"\nsteps: 64\n    resource: "*"',
            1,
        ),
    ]
    for fixture in rejected:
        try:
            validate(fixture)
        except PolicyError:
            continue
        raise AssertionError("invalid permission fixture was accepted")


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {Path(sys.argv[0]).name} <agent-file>", file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    text = path.read_text(encoding="utf-8")
    try:
        self_test(text)
    except (OSError, SyntaxError, PolicyError, AssertionError) as exc:
        print(f"agent permissions: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
