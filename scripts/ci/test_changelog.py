import unittest

from changelog import release_notes, sections


EXAMPLE = """# Changelog

## [Unreleased]

### Added
- Future feature.

## [0.1.2] - 2026-10-23

### Fixed
- Fix refresh stalls.

## [0.1.0] - 2026-10-01

### Added
- Previous release.
"""


class ChangelogTest(unittest.TestCase):
    def test_exact_version_excludes_future_and_previous_changes(self):
        self.assertEqual(release_notes(EXAMPLE, "0.1.2"), "### Fixed\n- Fix refresh stalls.\n")

    def test_missing_release_does_not_fall_back_to_unreleased(self):
        with self.assertRaisesRegex(ValueError, "Missing"):
            release_notes(EXAMPLE, "0.1.1")

    def test_unreleased_can_be_empty_after_cutting_release(self):
        self.assertIn("Unreleased", sections(EXAMPLE.replace("### Added\n- Future feature.", "")))

    def test_version_requires_valid_date(self):
        for heading in ("## [0.1.2]", "## [0.1.2] - 2026-02-30"):
            with self.subTest(heading=heading), self.assertRaises(ValueError):
                sections(EXAMPLE.replace("## [0.1.2] - 2026-10-23", heading))

    def test_duplicate_versions_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            sections(EXAMPLE + "\n## [0.1.2] - 2026-10-23\n- Ambiguous notes.\n")

    def test_unreleased_is_required_and_first(self):
        for text in (EXAMPLE.replace("## [Unreleased]", ""), EXAMPLE + "\n## [Unreleased]\n"):
            with self.subTest(text=text), self.assertRaises(ValueError):
                sections(text)

    def test_empty_release_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "Empty"):
            release_notes(EXAMPLE.replace("- Fix refresh stalls.", ""), "0.1.2")

    def test_code_example_does_not_create_an_extra_release(self):
        example = "```markdown\n## [0.1.2] - 2026-10-23\n- Example only.\n```\n"
        notes = release_notes(EXAMPLE.replace("- Fix refresh stalls.", "- Fix refresh stalls.\n\n" + example), "0.1.2")
        self.assertIn("Example only", notes)
        with self.assertRaisesRegex(ValueError, "Empty"):
            release_notes(EXAMPLE.replace("- Fix refresh stalls.", example), "0.1.2")


if __name__ == "__main__":
    unittest.main()
