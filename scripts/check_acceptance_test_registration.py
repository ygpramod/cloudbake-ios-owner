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
TARGET_NAME = "CloudBakeOwnerUITests"


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


def target_source_files(project_file: pathlib.Path) -> set[str]:
    project = project_file.read_text(encoding="utf-8")
    native_targets_match = re.search(
        r"/\* Begin PBXNativeTarget section \*/(?P<section>.*?)/\* End PBXNativeTarget section \*/",
        project,
        re.DOTALL,
    )
    if native_targets_match is None:
        raise ValueError("Could not find the PBXNativeTarget section")

    target_match = re.search(
        rf"""
        ^\s*[A-Fa-f0-9]+\s+/\*\s+{TARGET_NAME}\s+\*/\s+=\s+\{{
        .*?
        buildPhases\s+=\s+\(
        (?P<phases>.*?)
        \);
        .*?
        ^\s*\}};
        """,
        native_targets_match.group("section"),
        re.MULTILINE | re.DOTALL | re.VERBOSE,
    )
    if target_match is None:
        raise ValueError(f"Could not find the {TARGET_NAME} native target")

    sources_phase_match = re.search(
        r"([A-Fa-f0-9]+)\s+/\*\s+Sources\s+\*/",
        target_match.group("phases"),
    )
    if sources_phase_match is None:
        raise ValueError(f"Could not find the {TARGET_NAME} Sources build phase")

    sources_phase_id = sources_phase_match.group(1)
    sources_phases_match = re.search(
        r"/\* Begin PBXSourcesBuildPhase section \*/(?P<section>.*?)/\* End PBXSourcesBuildPhase section \*/",
        project,
        re.DOTALL,
    )
    if sources_phases_match is None:
        raise ValueError("Could not find the PBXSourcesBuildPhase section")

    phase_match = re.search(
        rf"""
        ^\s*{re.escape(sources_phase_id)}\s+/\*\s+Sources\s+\*/\s+=\s+\{{
        .*?
        files\s+=\s+\(
        (?P<files>.*?)
        \);
        .*?
        ^\s*\}};
        """,
        sources_phases_match.group("section"),
        re.MULTILINE | re.DOTALL | re.VERBOSE,
    )
    if phase_match is None:
        raise ValueError(f"Could not read the {TARGET_NAME} Sources build phase")

    return set(
        re.findall(
            r"/\*\s+([^*/]+\.swift)\s+in\s+Sources\s+\*/",
            phase_match.group("files"),
        )
    )


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
    parser.add_argument(
        "--project",
        type=pathlib.Path,
        default=pathlib.Path("CloudBakeOwner.xcodeproj/project.pbxproj"),
        help="Xcode project file containing the acceptance-test target.",
    )
    arguments = parser.parse_args()

    try:
        discovered = discover_tests(arguments.tests)
        registrations = registered_tests(arguments.workflow)
        target_sources = target_source_files(arguments.project)
    except (OSError, ValueError) as error:
        print(f"Acceptance registration check failed: {error}", file=sys.stderr)
        return 1

    disk_sources = {source.name for source in arguments.tests.glob("*.swift")}
    sources_missing_from_target = sorted(disk_sources - target_sources)
    target_sources_missing_from_disk = sorted(target_sources - disk_sources)
    registration_counts = collections.Counter(registrations)
    missing = sorted(discovered - registration_counts.keys())
    unknown = sorted(registration_counts.keys() - discovered)
    duplicates = sorted(
        name for name, count in registration_counts.items() if count > 1
    )

    if (
        sources_missing_from_target
        or target_sources_missing_from_disk
        or missing
        or unknown
        or duplicates
    ):
        print("Acceptance registration check failed:", file=sys.stderr)
        if sources_missing_from_target:
            print(
                "  Swift files missing from the Xcode UI-test target: "
                + ", ".join(sources_missing_from_target),
                file=sys.stderr,
            )
        if target_sources_missing_from_disk:
            print(
                "  UI-test target sources missing from disk: "
                + ", ".join(target_sources_missing_from_disk),
                file=sys.stderr,
            )
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
        f"across CI shards, and all {len(disk_sources)} Swift sources belong "
        f"to the {TARGET_NAME} target."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
