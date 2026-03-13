#!/usr/bin/env python3
import sys
import re
import json
import os

LICENSE_PATTERN = re.compile(
    r'(Copyright|License|Licensed|GPL|MIT|ISC|Apache|BSD|LGPL|MPL|CDDL|EPL|Dual\s+licensed)',
    re.IGNORECASE
)

def extract(path):
    headers = []
    try:
        with open(path, 'r', errors='replace') as f:
            for i, line in enumerate(f):
                if i >= 50:
                    break
                if LICENSE_PATTERN.search(line):
                    headers.append(line.rstrip('\n'))
    except OSError as e:
        print(json.dumps({"found": False, "error": str(e)}))
        sys.exit(1)

    if headers:
        print(json.dumps({"file": os.path.basename(path), "found": True, "headers": headers}, separators=(',', ':')))
    else:
        print(json.dumps({"found": False}, separators=(',', ':')))

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print(json.dumps({"found": False, "error": "Usage: extract-license-headers.py <file_path>"}))
        sys.exit(1)
    extract(sys.argv[1])
