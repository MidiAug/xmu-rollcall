"""Validate release identity and package completeness using only the standard library."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import zipfile


def version(pubspec=Path("pubspec.yaml"), tag=None):
    match = re.search(
        r"^version:\s*((?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\+([1-9]\d*))\s*$",
        pubspec.read_text(encoding="utf-8"),
        re.MULTILINE,
    )
    if not match:
        raise ValueError("pubspec.yaml must contain version: MAJOR.MINOR.PATCH+BUILD")
    full = match[1]
    if tag is not None and tag != "v" + full.split("+")[0]:
        raise ValueError(f"Tag {tag!r} does not match pubspec version {full}")
    return full


def source_commit():
    commit = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], text=True
    ).strip()
    if os.environ.get("GITHUB_SHA", commit) != commit:
        raise ValueError("Checkout does not match the workflow source commit")
    return commit


def names(full_version, platform, signing):
    prefix = "xmu-rollcall-" + full_version.split("+")[0]
    if platform == "windows" and signing == "unsigned":
        return [prefix + "-windows-x64-setup.exe", prefix + "-windows-x64.zip"]
    if platform == "android" and signing in ("preview", "release"):
        suffix = "-preview" if signing == "preview" else ""
        return [prefix + "-android" + suffix + ".apk"]
    raise ValueError(f"Invalid platform/signing combination: {platform}/{signing}")


def digest(path):
    hasher = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def inspect_package(path):
    if path.is_symlink() or not path.is_file() or path.stat().st_size == 0:
        raise ValueError(f"Missing, empty or linked package: {path.name}")
    if path.suffix in (".zip", ".apk"):
        with zipfile.ZipFile(path) as archive:
            entries = archive.namelist()
            for entry in entries:
                # All supported package paths use forward slashes.
                if entry.startswith("/") or "\\" in entry or ":" in entry or ".." in entry.split("/"):
                    raise ValueError(f"Unsafe archive entry in {path.name}")
            if len(entries) != len(set(entries)) or archive.testzip() is not None:
                raise ValueError(f"Corrupt or ambiguous archive: {path.name}")
            required = (
                {"AndroidManifest.xml", "classes.dex"}
                if path.suffix == ".apk"
                else {"xmu_rollcall.exe", "flutter_windows.dll", "data/icudtl.dat"}
            )
            if not required.issubset(entries):
                raise ValueError(f"Incomplete package: {path.name}")
            if path.suffix == ".zip" and not any(
                entry.startswith("data/flutter_assets/") for entry in entries
            ):
                raise ValueError("Windows portable ZIP is missing Flutter assets")
    elif path.suffix == ".exe":
        with path.open("rb") as stream:
            if stream.read(2) != b"MZ":
                raise ValueError(f"Invalid Windows executable: {path.name}")


def write_manifest(directory, full_version, commit, platform, signing):
    files = []
    for name in names(full_version, platform, signing):
        path = directory / name
        inspect_package(path)
        files.append({"name": name, "size": path.stat().st_size, "sha256": digest(path)})
    manifest = {
        "schemaVersion": 1,
        "version": full_version,
        "commit": commit,
        "platform": platform,
        "signing": signing,
        "files": files,
    }
    path = directory / f"manifest-{platform}.json"
    path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return path


def verify(directory, full_version, commit):
    expected = set()
    for platform, signing in (("android", "release"), ("windows", "unsigned")):
        manifest_name = f"manifest-{platform}.json"
        manifest_path = directory / manifest_name
        if manifest_path.is_symlink():
            raise ValueError("Manifest must not be a symlink")
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        identity = (manifest["schemaVersion"], manifest["version"], manifest["commit"], manifest["platform"], manifest["signing"])
        if identity != (1, full_version, commit, platform, signing):
            raise ValueError(f"Version, commit or signing mismatch: {manifest_name}")
        allowed = names(full_version, platform, signing)
        entries = manifest["files"]
        if sorted(item["name"] for item in entries) != sorted(allowed):
            raise ValueError(f"Unexpected or missing files in {manifest_name}")
        for item in entries:
            path = directory / item["name"]
            inspect_package(path)
            if path.stat().st_size != item["size"] or digest(path) != item["sha256"]:
                raise ValueError(f"Package checksum mismatch: {path.name}")
        expected.update(allowed)
        expected.add(manifest_name)
    actual = {path.name for path in directory.iterdir()} - {"SHA256SUMS"}
    if actual != expected:
        raise ValueError(f"Unexpected or missing delivery files: {sorted(actual ^ expected)}")
    checksums = directory / "SHA256SUMS"
    checksums.write_text(
        "".join(f"{digest(directory / name)}  {name}\n" for name in sorted(expected)),
        encoding="ascii",
    )
    return checksums


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    info = sub.add_parser("version")
    info.add_argument("--tag")
    manifest = sub.add_parser("manifest")
    manifest.add_argument("--directory", type=Path, required=True)
    manifest.add_argument("--platform", choices=("android", "windows"), required=True)
    manifest.add_argument("--signing", choices=("preview", "release", "unsigned"), required=True)
    validate = sub.add_parser("verify")
    validate.add_argument("--directory", type=Path, required=True)
    validate.add_argument("--tag", required=True)
    args = parser.parse_args()
    try:
        full_version = version(tag=getattr(args, "tag", None))
        if args.command == "version":
            print(full_version)
        elif args.command == "manifest":
            print(write_manifest(args.directory, full_version, source_commit(), args.platform, args.signing))
        else:
            print(verify(args.directory, full_version, source_commit()))
    except (ValueError, KeyError, OSError, zipfile.BadZipFile) as error:
        parser.exit(1, f"Artifact validation failed: {error}\n")


if __name__ == "__main__":
    main()
