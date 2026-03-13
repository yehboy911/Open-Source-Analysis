#!/usr/bin/env python3
"""
init-ledger.py — Create a blank audit-evidence.md with 6 section headers.

Usage:
    python3 init-ledger.py --project-dir <path> --output <path> --mode <full|sbom|license|binary|report>
"""
import argparse
import datetime
import os
import sys


def parse_args():
    p = argparse.ArgumentParser(description="Initialise audit-evidence.md")
    p.add_argument("--project-dir", required=True, help="Absolute path to the target project")
    p.add_argument("--output", required=True, help="Path to write audit-evidence.md")
    p.add_argument(
        "--mode",
        required=True,
        choices=["full", "sbom", "license", "binary", "report"],
        help="Audit mode",
    )
    return p.parse_args()


def main():
    args = parse_args()

    project_dir = os.path.abspath(args.project_dir)
    if not os.path.isdir(project_dir):
        print(f"Error: project-dir '{project_dir}' does not exist.", file=sys.stderr)
        sys.exit(1)

    output_path = os.path.abspath(args.output)
    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)

    date_str = datetime.date.today().isoformat()

    content = f"""# Audit Evidence Ledger
<!-- Project: {project_dir} | Date: {date_str} | Mode: {args.mode} -->

## 1. Direct Dependencies

## 2. Transitive Dependencies

## 3. Binary & Linkage Evidence

## 4. License Review & Risk Assessment

## 5. SBOM Cross-Validation

## 6. GPL/LGPL Checkpoint Audit
"""

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(content)

    print(f"Ledger initialised: {output_path}")


if __name__ == "__main__":
    main()
