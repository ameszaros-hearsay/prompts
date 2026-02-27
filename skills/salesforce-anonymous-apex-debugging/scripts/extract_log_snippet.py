"""Extract a focused snippet from a Salesforce debug log.

Usage:
  python extract_log_snippet.py --log /path/to/log.txt --token MYBUG --context 80

What it does:
  - Prints lines around the first occurrence of the token.
  - Also prints the first occurrence of EXCEPTION_THROWN or FATAL_ERROR if present.

Notes:
  - This is a convenience tool for humans and agents.
  - It does not parse log structure beyond simple string matching.
"""

from __future__ import annotations

import argparse
from pathlib import Path


def _find_first_index(lines: list[str], needle: str) -> int | None:
    for i, line in enumerate(lines):
        if needle in line:
            return i
    return None


def _print_window(lines: list[str], center: int, context: int) -> None:
    start = max(0, center - context)
    end = min(len(lines), center + context + 1)
    for i in range(start, end):
        prefix = f"{i+1:>6}: "
        print(prefix + lines[i].rstrip("\n"))


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--log", required=True, help="Path to the debug log text file")
    p.add_argument("--token", required=True, help="Token to locate, example: MYBUG")
    p.add_argument("--context", type=int, default=80, help="Lines before and after the match")
    args = p.parse_args()

    path = Path(args.log)
    if not path.exists():
        raise SystemExit(f"Log file not found: {path}")

    lines = path.read_text(errors="replace").splitlines(True)

    print("\n=== Token window ===")
    token_index = _find_first_index(lines, args.token)
    if token_index is None:
        print(f"Token not found: {args.token}")
    else:
        _print_window(lines, token_index, args.context)

    print("\n=== Exception window ===")
    ex_index = (
        _find_first_index(lines, "EXCEPTION_THROWN")
        or _find_first_index(lines, "FATAL_ERROR")
        or _find_first_index(lines, "System.")
    )
    if ex_index is None:
        print("No EXCEPTION_THROWN or FATAL_ERROR found")
    else:
        _print_window(lines, ex_index, args.context)


if __name__ == "__main__":
    main()
