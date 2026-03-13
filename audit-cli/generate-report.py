#!/usr/bin/env python3
"""
generate-report.py — Standalone report generator (zero LLM).

Reads audit-evidence.md and produces compliance_report_YYYY-MM-DD.md.

Usage:
    python3 generate-report.py --ledger <path> --output-dir <path>
"""
import argparse
import datetime
import os
import re
import sys


# ── Section parser ────────────────────────────────────────────────────────────

def parse_sections(text):
    """Return dict: section_title → body text (stripped)."""
    parts = re.split(r"\n(?=## )", text)
    sections = {}
    for part in parts:
        m = re.match(r"## (.+?)\n(.*)", part, re.DOTALL)
        if m:
            title = m.group(1).strip()
            body  = m.group(2).strip()
            sections[title] = body
    return sections


# ── Table builders ────────────────────────────────────────────────────────────

def make_table(headers, rows):
    """Return a GitHub-flavoured Markdown table string."""
    sep = "| " + " | ".join("---" for _ in headers) + " |"
    head = "| " + " | ".join(headers) + " |"
    body = "\n".join("| " + " | ".join(str(c) for c in row) + " |" for row in rows)
    return "\n".join([head, sep, body]) if rows else head + "\n" + sep + "\n_No entries._"


# ── Evidence line parsers ─────────────────────────────────────────────────────

_DEP_LINE = re.compile(
    r"^-\s+(.+?)\s+(\S+)\s*\|\s*License:\s*(.+?)\s*\|\s*Source:\s*(.+)$"
)


def parse_dep_lines(body):
    rows = []
    for line in body.splitlines():
        m = _DEP_LINE.match(line.strip())
        if m:
            pkg, ver, lic, src = m.groups()
            rows.append([pkg, ver, lic, src])
    return rows


_BINARY_SECTION = re.compile(
    r"### (.+?)\n- Path: (.+?)\n- Linkage: (.+?)\n- Signature Check: (.+?)\n",
    re.DOTALL,
)


def parse_binary_sections(body):
    rows = []
    for m in _BINARY_SECTION.finditer(body):
        fname, path, linkage, sig = m.group(1), m.group(2), m.group(3), m.group(4)
        sig_short = "MATCH" if "MATCH_FOUND" in sig else ("NO_MATCH" if "NO_MATCH" in sig else sig[:60])
        rows.append([fname, path, linkage, sig_short])
    return rows


_RISK_LINE = re.compile(
    r"^-\s+(.+?)\s*\|\s*License:\s*(.+?)\s*\|\s*Linkage:\s*(.+?)\s*\|\s*Risk:\s*(.+?)\s*\|\s*Reason:\s*(.+)$"
)


def parse_risk_lines(body):
    rows = []
    for line in body.splitlines():
        m = _RISK_LINE.match(line.strip())
        if m:
            rows.append(list(m.groups()))
    return rows


# ── Executive summary ─────────────────────────────────────────────────────────

def executive_summary(dep_rows, risk_rows, binary_rows):
    total_deps = len(dep_rows)
    risk_counts = {}
    for r in risk_rows:
        level = r[3].strip()
        risk_counts[level] = risk_counts.get(level, 0) + 1

    lines = [
        f"- **Total dependencies identified:** {total_deps}",
        f"- **Binaries analysed:** {len(binary_rows)}",
    ]
    for level in ("High", "Medium", "Low", "Informational"):
        if level in risk_counts:
            lines.append(f"- **{level} risk:** {risk_counts[level]} package(s)")

    if risk_counts.get("High", 0) > 0:
        lines.append("")
        lines.append("> **Action required:** High-risk packages require legal review before distribution.")

    return "\n".join(lines)


# ── Main ──────────────────────────────────────────────────────────────────────

def parse_args():
    p = argparse.ArgumentParser(description="Generate compliance report from audit-evidence.md")
    p.add_argument("--ledger", required=True, help="Path to audit-evidence.md")
    p.add_argument("--output-dir", required=True, help="Directory to write the report into")
    return p.parse_args()


def main():
    args = parse_args()
    ledger_path = os.path.abspath(args.ledger)
    output_dir  = os.path.abspath(args.output_dir)

    if not os.path.isfile(ledger_path):
        print(f"Error: ledger not found: {ledger_path}", file=sys.stderr)
        sys.exit(1)

    with open(ledger_path, "r", encoding="utf-8") as f:
        text = f.read()

    sections = parse_sections(text)

    # ── Validate required sections ────────────────────────────────────────────
    REQUIRED = [
        "1. Direct Dependencies",
        "2. Transitive Dependencies",
        "3. Binary & Linkage Evidence",
        "4. License Review & Risk Assessment",
    ]
    empty = [s for s in REQUIRED if not sections.get(s, "").strip()]
    if empty:
        print(
            f"Error: the following required sections are empty — cannot generate report:\n"
            + "\n".join(f"  - {s}" for s in empty),
            file=sys.stderr,
        )
        sys.exit(1)

    # ── Parse sections ────────────────────────────────────────────────────────
    sec1_body = sections.get("1. Direct Dependencies", "")
    sec2_body = sections.get("2. Transitive Dependencies", "")
    sec3_body = sections.get("3. Binary & Linkage Evidence", "")
    sec4_body = sections.get("4. License Review & Risk Assessment", "")
    sec5_body = sections.get("5. SBOM Cross-Validation", "")
    sec6_body = sections.get("6. GPL/LGPL Checkpoint Audit", "")

    dep_rows    = parse_dep_lines(sec1_body) + parse_dep_lines(sec2_body)
    binary_rows = parse_binary_sections(sec3_body)
    risk_rows   = parse_risk_lines(sec4_body)

    # ── Build report ──────────────────────────────────────────────────────────
    date_str    = datetime.date.today().isoformat()
    report_name = f"compliance_report_{date_str}.md"
    os.makedirs(output_dir, exist_ok=True)
    report_path = os.path.join(output_dir, report_name)

    # Extract project name from ledger header comment
    project_name = "Unknown"
    header_m = re.search(r"<!-- Project: (.+?) \|", text)
    if header_m:
        project_name = os.path.basename(header_m.group(1).rstrip("/"))

    dep_table = make_table(
        ["Package", "Version", "License", "Source"],
        dep_rows,
    )
    binary_table = make_table(
        ["Binary", "Path", "Linkage", "Signature Match"],
        binary_rows,
    )
    risk_table = make_table(
        ["Package", "License", "Linkage", "Risk Level", "Reasoning"],
        risk_rows,
    )

    report_lines = [
        f"# Compliance Report — {project_name}",
        f"_Generated: {date_str}_",
        "",
        "## Executive Summary",
        "",
        executive_summary(dep_rows, risk_rows, binary_rows),
        "",
        "---",
        "",
        "## 1. Dependency Inventory",
        "",
        dep_table,
        "",
        "---",
        "",
        "## 2. Binary & Linkage Evidence",
        "",
        binary_table,
        "",
        "---",
        "",
        "## 3. Risk Assessment",
        "",
        risk_table,
        "",
    ]

    # Optional: Section 5 (SBOM)
    sec5_has_data = sec5_body and "_N/A" not in sec5_body and sec5_body.strip()
    if sec5_has_data:
        report_lines += [
            "---",
            "",
            "## 4. SBOM Cross-Validation",
            "",
            sec5_body,
            "",
        ]

    # Optional: Section 6 (GPL/LGPL)
    sec6_has_data = sec6_body and "_N/A" not in sec6_body and sec6_body.strip()
    if sec6_has_data:
        report_lines += [
            "---",
            "",
            "## 5. GPL/LGPL Checkpoint Audit",
            "",
            sec6_body,
            "",
        ]

    report_lines += [
        "---",
        "",
        f"_Ledger source: {ledger_path}_",
        f"_Report generated by audit-cli generate-report.py_",
    ]

    with open(report_path, "w", encoding="utf-8") as f:
        f.write("\n".join(report_lines) + "\n")

    print(f"Report written: {report_path}")


if __name__ == "__main__":
    main()
