import json
from pathlib import Path
import tempfile
import unittest
import zipfile

import artifacts


class ArtifactValidationTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.version = "0.1.1+2"
        self.commit = "a" * 40
        self.apk = self.directory / "xmu-rollcall-0.1.1-android.apk"
        self.zip = self.directory / "xmu-rollcall-0.1.1-windows-x64.zip"
        self.installer = self.directory / "xmu-rollcall-0.1.1-windows-x64-setup.exe"
        with zipfile.ZipFile(self.apk, "w") as archive:
            archive.writestr("AndroidManifest.xml", b"manifest")
            archive.writestr("classes.dex", b"dex")
        with zipfile.ZipFile(self.zip, "w") as archive:
            for entry in (
                "xmu_rollcall.exe", "flutter_windows.dll", "data/icudtl.dat",
                "data/flutter_assets/AssetManifest.bin", "msvcp140.dll",
                "vcruntime140.dll", "vcruntime140_1.dll",
            ):
                archive.writestr(entry, b"fixture")
        self.installer.write_bytes(b"MZfixture")
        self.manifests()

    def manifests(self):
        for platform, signing in (("android", "release"), ("windows", "unsigned")):
            artifacts.write_manifest(self.directory, self.version, self.commit, platform, signing)

    def verify(self):
        return artifacts.verify(self.directory, self.version, self.commit)

    def alter_manifest(self, change):
        path = self.directory / "manifest-android.json"
        manifest = json.loads(path.read_text())
        change(manifest)
        path.write_text(json.dumps(manifest))

    def test_complete_delivery_produces_repeatable_checksums(self):
        first = self.verify().read_bytes()
        self.assertEqual(len(first.splitlines()), 5)
        self.assertEqual(self.verify().read_bytes(), first)

    def test_reject_changed_payload(self):
        # Same length: the verifier must check content, not just file size.
        self.installer.write_bytes(b"MZchanged")
        with self.assertRaisesRegex(ValueError, "checksum mismatch"):
            self.verify()

    def test_reject_missing_payload(self):
        self.apk.unlink()
        with self.assertRaisesRegex(ValueError, "Missing"):
            self.verify()

    def test_reject_mixed_commits(self):
        self.alter_manifest(lambda manifest: manifest.update(commit="b" * 40))
        with self.assertRaisesRegex(ValueError, "mismatch"):
            self.verify()

    def test_reject_mixed_versions(self):
        self.alter_manifest(lambda manifest: manifest.update(version="0.1.1+3"))
        with self.assertRaisesRegex(ValueError, "mismatch"):
            self.verify()

    def test_reject_preview_in_release(self):
        self.alter_manifest(lambda manifest: manifest.update(signing="preview"))
        with self.assertRaisesRegex(ValueError, "mismatch"):
            self.verify()

    def test_reject_manifest_path_traversal(self):
        self.alter_manifest(lambda manifest: manifest["files"][0].update(name="../secret"))
        with self.assertRaisesRegex(ValueError, "Unexpected"):
            self.verify()

    def test_reject_unlisted_delivery_files(self):
        (self.directory / "unrelated.txt").write_text("must not be published")
        with self.assertRaisesRegex(ValueError, "Unexpected"):
            self.verify()

    def test_reject_incomplete_portable_archive(self):
        with zipfile.ZipFile(self.zip, "w") as archive:
            archive.writestr("xmu_rollcall.exe", b"fixture")
        with self.assertRaisesRegex(ValueError, "Incomplete"):
            self.manifests()

    def test_reject_unsafe_archive(self):
        with zipfile.ZipFile(self.zip, "a") as archive:
            archive.writestr("../outside", b"fixture")
        with self.assertRaisesRegex(ValueError, "Unsafe"):
            self.manifests()

    def test_reject_portable_archive_missing_compiler_runtime(self):
        with zipfile.ZipFile(self.zip) as archive:
            entries = {name: archive.read(name) for name in archive.namelist()}
        del entries["vcruntime140_1.dll"]
        with zipfile.ZipFile(self.zip, "w") as archive:
            for name, content in entries.items():
                archive.writestr(name, content)
        with self.assertRaisesRegex(ValueError, "Incomplete"):
            self.manifests()

    def test_reject_empty_installer(self):
        self.installer.write_bytes(b"")
        with self.assertRaisesRegex(ValueError, "empty"):
            self.manifests()

    def test_tag_must_match_pubspec_and_build_number_is_required(self):
        spec = self.directory / "pubspec.yaml"
        spec.write_text("name: example\nversion: 0.1.1+2\n")
        self.assertEqual(artifacts.version(spec, "v0.1.1"), self.version)
        for tag in ("v0.1.0", "v0.1.1+2", "0.1.1"):
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                artifacts.version(spec, tag)
        spec.write_text("version: 0.1.1\n")
        with self.assertRaises(ValueError):
            artifacts.version(spec)


if __name__ == "__main__":
    unittest.main()
