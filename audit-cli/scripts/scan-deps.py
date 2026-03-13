#!/usr/bin/env python3
"""
scan-deps.py — Parse build manifests and write Sections 1 + 2 of audit-evidence.md.

Supported manifests:
  - CMakeLists.txt  (find_package, FetchContent_Declare, target_link_libraries)
  - package.json    (dependencies, devDependencies)
  - requirements.txt (pip packages)

Transitive resolution:
  - npm  : package-lock.json (full tree)
  - pip  : `pip show <pkg>` → Requires field
  - CMake: recursive subdirectory CMakeLists.txt scans

Usage:
    python3 scan-deps.py --project-dir <path> --ledger <path>
"""
import argparse
import json
import os
import re
import subprocess
import sys


# ── Helpers ───────────────────────────────────────────────────────────────────

def read_file(path):
    with open(path, "r", errors="replace") as f:
        return f.readlines()


def write_sections(ledger_path, updates):
    """Write multiple sections in a single file read+write cycle.

    updates: list of (section_header, content) pairs applied in order.
    """
    with open(ledger_path, "r", encoding="utf-8") as f:
        text = f.read()

    for section_header, content in updates:
        pattern = re.compile(
            rf"(## {re.escape(section_header)}\n)(.*?)((?=\n## )|\Z)",
            re.DOTALL,
        )
        m = pattern.search(text)
        if not m:
            print(f"Warning: section '{section_header}' not found in ledger.", file=sys.stderr)
            continue
        existing_body = m.group(2)
        new_body = existing_body.rstrip("\n") + "\n" + content.strip("\n") + "\n"
        text = text[: m.start(2)] + new_body + text[m.end(2) :]

    with open(ledger_path, "w", encoding="utf-8") as f:
        f.write(text)


# ── CMakeLists.txt parsing ────────────────────────────────────────────────────

_CMAKE_FIND_PKG = re.compile(r"^\s*find_package\s*\(\s*(\S+)", re.IGNORECASE)
_CMAKE_FETCH    = re.compile(r"^\s*FetchContent_Declare\s*\(\s*(\S+)", re.IGNORECASE)
_CMAKE_TLL      = re.compile(r"^\s*target_link_libraries\s*\(\s*\S+\s+(?:PUBLIC|PRIVATE|INTERFACE\s+)?(\S+)", re.IGNORECASE)


def scan_cmake(project_dir):
    """Return list of (package, version, source_file, line_no, kind)."""
    deps = []
    for root, dirs, files in os.walk(project_dir):
        # Skip common third-party trees
        dirs[:] = [d for d in dirs if d not in (".git", "build", "out", "_deps")]
        for fname in files:
            if fname != "CMakeLists.txt":
                continue
            fpath = os.path.join(root, fname)
            rel = os.path.relpath(fpath, project_dir)
            try:
                lines = read_file(fpath)
            except OSError:
                continue
            for lineno, line in enumerate(lines, 1):
                for pattern, kind in [(_CMAKE_FIND_PKG, "cmake-find_package"),
                                       (_CMAKE_FETCH, "cmake-FetchContent"),
                                       (_CMAKE_TLL, "cmake-target_link_libraries")]:
                    m = pattern.match(line)
                    if m:
                        pkg = m.group(1).rstrip(")")
                        deps.append((pkg, "UNKNOWN", rel, lineno, kind))
                        break
    return deps


# ── package.json parsing ──────────────────────────────────────────────────────

def scan_package_json(project_dir):
    pjson = os.path.join(project_dir, "package.json")
    if not os.path.isfile(pjson):
        return []
    try:
        with open(pjson, "r", encoding="utf-8") as f:
            data = json.load(f)
    except (json.JSONDecodeError, OSError) as e:
        print(f"Warning: could not parse package.json: {e}", file=sys.stderr)
        return []

    deps = []
    for field in ("dependencies", "devDependencies"):
        for pkg, ver in data.get(field, {}).items():
            deps.append((pkg, ver, "package.json", 0, field))
    return deps


# ── requirements.txt parsing ──────────────────────────────────────────────────

_REQ_LINE = re.compile(r"^([A-Za-z0-9_.\-]+)\s*([=><!]+\s*[\w.*]+)?")


def scan_requirements_txt(project_dir):
    req = os.path.join(project_dir, "requirements.txt")
    if not os.path.isfile(req):
        return []
    deps = []
    try:
        lines = read_file(req)
    except OSError:
        return []
    for lineno, line in enumerate(lines, 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        m = _REQ_LINE.match(line)
        if m:
            pkg = m.group(1)
            ver = (m.group(2) or "").strip() or "UNKNOWN"
            deps.append((pkg, ver, "requirements.txt", lineno, "pip"))
    return deps


# ── Transitive resolution ─────────────────────────────────────────────────────

def npm_transitive(project_dir):
    lock = os.path.join(project_dir, "package-lock.json")
    if not os.path.isfile(lock):
        return []
    try:
        with open(lock, "r", encoding="utf-8") as f:
            data = json.load(f)
    except (json.JSONDecodeError, OSError):
        return []

    trans = []
    # npm v2/v3 lock format uses "packages" key; v1 uses "dependencies"
    packages = data.get("packages", data.get("dependencies", {}))
    for name, info in packages.items():
        if not name:
            continue
        # Strip leading "node_modules/" prefix in v2 format
        # (use slicing, not lstrip — lstrip treats its arg as a character set)
        pkg_name = name[len("node_modules/"):] if name.startswith("node_modules/") else name
        ver = info.get("version", "UNKNOWN")
        trans.append((pkg_name, ver, "package-lock.json", 0, "npm-transitive"))
    return trans


def pip_transitive(direct_pkgs):
    trans = []
    for pkg, _ver, _src, _ln, _kind in direct_pkgs:
        if _kind != "pip":
            continue
        try:
            result = subprocess.run(
                ["pip", "show", pkg],
                capture_output=True, text=True, timeout=10,
            )
            for line in result.stdout.splitlines():
                if line.startswith("Requires:"):
                    requires = line.split(":", 1)[1].strip()
                    for req in requires.split(","):
                        req = req.strip()
                        if req:
                            cmd_repr = f"pip show {pkg} → Requires: {requires}"
                            trans.append((req, "UNKNOWN", f"$ {cmd_repr}", 0, "pip-transitive"))
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass
    return trans


# ── Evidence line formatter ───────────────────────────────────────────────────

def fmt(pkg, ver, source, lineno, license_id="UNKNOWN"):
    if source.startswith("$"):
        src_str = source
    elif lineno:
        src_str = f"{source}:{lineno}"
    else:
        src_str = source
    return f"- {pkg} {ver} | License: {license_id} | Source: {src_str}\n"


# ── Main ──────────────────────────────────────────────────────────────────────

def parse_args():
    p = argparse.ArgumentParser(description="Scan build manifests and populate ledger sections 1 + 2")
    p.add_argument("--project-dir", required=True)
    p.add_argument("--ledger", required=True)
    return p.parse_args()


def main():
    args = parse_args()
    project_dir = os.path.abspath(args.project_dir)
    ledger = os.path.abspath(args.ledger)

    if not os.path.isdir(project_dir):
        print(f"Error: project-dir '{project_dir}' not found.", file=sys.stderr)
        sys.exit(1)
    if not os.path.isfile(ledger):
        print(f"Error: ledger '{ledger}' not found.", file=sys.stderr)
        sys.exit(1)

    # Collect direct deps
    direct = []
    direct += scan_cmake(project_dir)
    direct += scan_package_json(project_dir)
    direct += scan_requirements_txt(project_dir)

    # Deduplicate by (pkg, source_kind)
    seen = set()
    direct_unique = []
    for d in direct:
        key = (d[0].lower(), d[4])
        if key not in seen:
            seen.add(key)
            direct_unique.append(d)

    # Collect transitive deps
    transitive = []
    transitive += npm_transitive(project_dir)
    transitive += pip_transitive(direct_unique)

    # Deduplicate transitive, removing any already in direct
    direct_names = {d[0].lower() for d in direct_unique}
    seen_trans = set()
    trans_unique = []
    for t in transitive:
        key = (t[0].lower(), t[4])
        if key not in seen_trans and t[0].lower() not in direct_names:
            seen_trans.add(key)
            trans_unique.append(t)

    # Build section content
    if direct_unique:
        sec1 = "".join(fmt(p, v, s, ln) for p, v, s, ln, _ in direct_unique)
    else:
        sec1 = "_No direct dependencies detected._\n"

    if trans_unique:
        sec2 = "".join(fmt(p, v, s, ln) for p, v, s, ln, _ in trans_unique)
    else:
        sec2 = "_No transitive dependencies detected._\n"

    write_sections(ledger, [
        ("1. Direct Dependencies", sec1),
        ("2. Transitive Dependencies", sec2),
    ])

    print(f"Section 1: {len(direct_unique)} direct dep(s) written.")
    print(f"Section 2: {len(trans_unique)} transitive dep(s) written.")


if __name__ == "__main__":
    main()
