#!/usr/bin/env python3
"""
update-ledger.py — Append stdin content under a named section of audit-evidence.md.

Reading content from stdin avoids shell variable interpolation into Python string
literals, which breaks when content contains triple-quotes or backslash sequences.

Usage:
    printf '%s\n' "$content" | python3 update-ledger.py --ledger <path> --section <header>
"""
import argparse
import re
import sys


def parse_args():
    p = argparse.ArgumentParser(description="Append stdin under a ledger section")
    p.add_argument("--ledger", required=True, help="Path to audit-evidence.md")
    p.add_argument("--section", required=True, help="Section header text (without ##)")
    return p.parse_args()


def main():
    args = parse_args()
    content = sys.stdin.read()

    with open(args.ledger, "r", encoding="utf-8") as f:
        text = f.read()

    pattern = re.compile(
        rf"(## {re.escape(args.section)}\n)(.*?)((?=\n## )|\Z)",
        re.DOTALL,
    )
    m = pattern.search(text)
    if not m:
        print(f"Warning: section '{args.section}' not found in ledger.", file=sys.stderr)
        sys.exit(1)

    existing = m.group(2)
    new_body = existing.rstrip("\n") + "\n" + content.strip("\n") + "\n"
    text = text[: m.start(2)] + new_body + text[m.end(2) :]

    with open(args.ledger, "w", encoding="utf-8") as f:
        f.write(text)


if __name__ == "__main__":
    main()
