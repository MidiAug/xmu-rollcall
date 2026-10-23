"""Check the public changelog and extract the exact version's release notes."""

import argparse
from datetime import date
from pathlib import Path
import re

from artifacts import version


HEADING = re.compile(r"^## \[(Unreleased|\d+\.\d+\.\d+)\](?: - (\d{4}-\d{2}-\d{2}))?$")


def fence_after(line, fence):
    stripped = line.lstrip()
    if fence:
        closing = re.fullmatch(re.escape(fence[0]) + "{" + str(len(fence)) + r",}\s*", stripped)
        return None if closing else fence
    opening = re.match(r"(`{3,}|~{3,})", stripped)
    return opening[1] if opening else None


def sections(text):
    result = {}
    current = None
    fence = None
    for line in text.splitlines():
        previous_fence = fence
        fence = fence_after(line, fence)
        if previous_fence is None and fence is None:
            if line.startswith("## "):
                match = HEADING.fullmatch(line.rstrip())
                if not match:
                    raise ValueError(f"Invalid version heading: {line}")
                name, released_on = match.groups()
                if name in result:
                    raise ValueError(f"Duplicate changelog section: {name}")
                if name == "Unreleased":
                    if result or released_on:
                        raise ValueError("Unreleased must be first and have no release date")
                elif not released_on:
                    raise ValueError(f"Missing release date for {name}")
                else:
                    date.fromisoformat(released_on)
                result[name] = []
                current = name
                continue
        if current is not None:
            result[current].append(line)
    if "Unreleased" not in result:
        raise ValueError("CHANGELOG.md must start with an Unreleased section")
    if fence:
        raise ValueError("Unclosed code fence in CHANGELOG.md")
    return {name: "\n".join(lines).strip() for name, lines in result.items()}


def release_notes(text, release_version):
    changes = sections(text)
    if release_version not in changes:
        raise ValueError(
            f"Missing [{release_version}] section; move the release's Unreleased entries into a dated version section"
        )
    body = changes[release_version]
    # Fenced examples and headings alone are not release notes.
    fence = None
    has_entry = False
    for line in body.splitlines():
        previous_fence = fence
        fence = fence_after(line, fence)
        if previous_fence is None and fence is None and re.match(r"^- \S", line):
            has_entry = True
    if not has_entry:
        raise ValueError(f"Empty release notes for {release_version}")
    return body + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--file", type=Path, default=Path("CHANGELOG.md"))
    parser.add_argument("--tag", help="Require notes matching the tag and pubspec.yaml")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        text = args.file.read_text(encoding="utf-8")
        if args.tag:
            release_version = version(tag=args.tag).split("+")[0]
            notes = release_notes(text, release_version)
            if args.output:
                args.output.write_text(notes, encoding="utf-8")
            else:
                print(notes, end="")
        else:
            if args.output:
                raise ValueError("--output requires --tag")
            sections(text)
            print("CHANGELOG.md structure is valid")
    except (OSError, ValueError) as error:
        parser.exit(1, f"Changelog validation failed: {error}\n")


if __name__ == "__main__":
    main()
