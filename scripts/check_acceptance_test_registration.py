#!/usr/bin/env python3

"""Verify that every owner-app acceptance test belongs to exactly one CI shard."""

from __future__ import annotations

import argparse
import collections
import pathlib
import re
import sys

TEST_DECLARATION = re.compile(r"^\s*func\s+(test[A-Za-z0-9_]+)\s*\(", re.MULTILINE)
SELECTOR_PREFIX = "CloudBakeOwnerUITests/CloudBakeOwnerUITests/"
REGISTERED_SELECTOR = re.compile(
    rf"^\s*{re.escape(SELECTOR_PREFIX)}(test[A-Za-z0-9_]+)\s*$",
    re.MULTILINE,
)


def discover_tests(test_directory: pathlib.Path) -> set[str]:
    discovered: set[str] = set()
    duplicate_declarations: set[str] = set()

    for source_file in sorted(test_directory.glob("*.swift")):
        for test_name in TEST_DECLARATION.findall(source_file.read_text(encoding="utf-8")):
            if test_name in discovered:
                duplicate_declarations.add(test_name)
            discovered.add(test_name)

    if duplicate_declarations:
        formatted = ", ".join(sorted(duplicate_declarations))
        raise ValueError(f"Acceptance test methods are declared more than once: {formatted}")

    return discovered


def registered_tests(workflow_file: pathlib.Path) -> list[str]:
    workflow = workflow_file.read_text(encoding="utf-8")
    malformed_selectors = [
        line.strip()
        for line in workflow.splitlines()
        if SELECTOR_PREFIX in line
        and REGISTERED_SELECTOR.fullmatch(f"{line}\n") is None
    ]

    if malformed_selectors:
        formatted = "\n  ".join(malformed_selectors)
        raise ValueError(f"Malformed acceptance selectors:\n  {formatted}")

    return REGISTERED_SELECTOR.findall(workflow)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--tests",
        type=pathlib.Path,
        default=pathlib.Path("CloudBakeOwnerUITests"),
        help="Directory containing acceptance-test Swift sources.",
    )
    parser.add_argument(
        "--workflow",
        type=pathlib.Path,
        default=pathlib.Path(".github/workflows/ci.yml"),
        help="GitHub Actions workflow containing acceptance selectors.",
    )
    arguments = parser.parse_args()

    try:
        discovered = discover_tests(arguments.tests)
        registrations = registered_tests(arguments.workflow)
    except (OSError, ValueError) as error:
        print(f"Acceptance registration check failed: {error}", file=sys.stderr)
        return 1

    registration_counts = collections.Counter(registrations)
    missing = sorted(discovered - registration_counts.keys())
    unknown = sorted(registration_counts.keys() - discovered)
    duplicates = sorted(
        name for name, count in registration_counts.items() if count > 1
    )

    if missing or unknown or duplicates:
        print("Acceptance registration check failed:", file=sys.stderr)
        if missing:
            print(f"  Missing from CI: {', '.join(missing)}", file=sys.stderr)
        if unknown:
            print(f"  Unknown CI selectors: {', '.join(unknown)}", file=sys.stderr)
        if duplicates:
            details = ", ".join(
                f"{name} ({registration_counts[name]} registrations)"
                for name in duplicates
            )
            print(f"  Registered more than once: {details}", file=sys.stderr)
        return 1

    print(
        f"All {len(discovered)} acceptance tests are registered exactly once "
        f"across CI shards."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
