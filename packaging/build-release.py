#!/usr/bin/env python3
"""Build directory source archives and an amd64 Debian package; never compile."""
import argparse
import gzip
import os
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import tempfile
import time
import zipfile

ROOT = Path(__file__).resolve().parent.parent
TEMPLATES = ROOT / "packaging" / "templates"
SOURCE = ROOT / "linux-noi-lazarus"
# An allowlist also keeps newly-created test outputs, local settings, lock files
# and compiler output out of release archives. Extend it for new runtime assets.
SOURCE_SUFFIXES = {
    ".pas", ".pp", ".inc", ".lpr", ".lpi", ".lfm", ".lrs", ".sh",
    ".md", ".txt", ".ico", ".bmp", ".png", ".svg", ".xpm", ".po",
    ".mo", ".json", ".xml", ".sample", ".example", ".ini", ".cfg",
    ".conf", ".theme", ".toml", ".yaml", ".yml",
}
EXCLUDED_DIRS = {"backup", "lib", "dist", "tmp", "temp", "__pycache__"}
RUNTIME_FILES = ("console-pauser.sh", "ui-language.sh", "devcpp.ico", "PORT_REVISION")


def source_files():
    for path in sorted(SOURCE.rglob("*")):
        relative = path.relative_to(SOURCE)
        if any(p.startswith(".") or p.lower() in EXCLUDED_DIRS for p in relative.parts):
            continue
        if path.is_symlink():
            raise ValueError("Refusing symlink in source tree: " + str(relative))
        if not path.is_file():
            continue
        if relative == Path("devcpp-noi.ini"):
            continue
        if path.name != "PORT_REVISION" and path.suffix.lower() not in SOURCE_SUFFIXES:
            continue
        if path.name.lower().startswith(("ppas", "link")) and path.suffix == ".sh":
            continue
        if any(part in path.name.lower() for part in (".tmp.", ".bak.", ".orig.", ".swp.")):
            continue
        yield path, Path("linux-noi-lazarus") / relative


def archive_mode(path):
    return 0o755 if path.suffix == ".sh" else 0o644


def build_sources(version, output, epoch):
    files = list(source_files())
    required = {"devcpp_noi.lpr", "devcpp_noi.lpi", "mainform.pas", "build.sh", *RUNTIME_FILES}
    if not required <= {p.name for p, _ in files}:
        raise ValueError("Source directory is missing required source/runtime files")
    base = output / ("linux-noi-lazarus-" + version + "-src")
    # Set archive owners, permissions and timestamps explicitly, including gzip's
    # header, so the same inputs and SOURCE_DATE_EPOCH produce the same assets.
    with open(str(base) + ".tar.gz", "wb") as raw:
        with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=epoch) as gz:
            with tarfile.open(fileobj=gz, mode="w") as archive:
                for path, relative in files:
                    info = archive.gettarinfo(str(path), arcname=relative.as_posix())
                    info.uid = info.gid = 0
                    info.uname = info.gname = "root"
                    info.mode = archive_mode(path)
                    info.mtime = epoch
                    with path.open("rb") as source:
                        archive.addfile(info, source)
    zip_time = time.gmtime(max(epoch, 315532800))[:6]
    with zipfile.ZipFile(str(base) + ".zip", "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path, relative in files:
            info = zipfile.ZipInfo(relative.as_posix(), zip_time)
            info.create_system = 3
            info.external_attr = (0o100000 | archive_mode(path)) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, path.read_bytes())
    print(str(base) + ".tar.gz")
    print(str(base) + ".zip")


def copy_file(source, destination, mode=0o644):
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, destination)
    destination.chmod(mode)


def build_deb(version, output, binary, epoch):
    # Check ELF64, little-endian, x86-64 before stamping the package amd64.
    header = binary.read_bytes()[:20]
    if len(header) < 20 or header[:6] != b"\x7fELF\x02\x01" or header[18:20] != b"\x3e\x00":
        raise ValueError("--binary must be a prebuilt Linux amd64 ELF executable")
    if not os.access(binary, os.X_OK):
        raise ValueError("--binary is not executable")
    with tempfile.TemporaryDirectory(prefix="devcpp-noi-deb-") as temp:
        package = Path(temp) / "package"
        app = package / "usr/lib/devcpp-noi"
        copy_file(binary, app / "devcpp-noi", 0o755)
        for name in RUNTIME_FILES:
            copy_file(SOURCE / name, app / name, 0o755 if name.endswith(".sh") else 0o644)
        for directory in ("icons", "profiles"):
            location = SOURCE / directory
            if location.is_dir():
                for source in sorted(location.rglob("*")):
                    if source.is_symlink():
                        raise ValueError("Refusing runtime asset symlink: " + str(source))
                    if source.is_file() and not any(p.startswith(".") for p in source.relative_to(location).parts):
                        if source.suffix.lower() in SOURCE_SUFFIXES:
                            copy_file(source, app / directory / source.relative_to(location))
        copy_file(TEMPLATES / "devcpp-noi", package / "usr/bin/devcpp-noi", 0o755)
        copy_file(TEMPLATES / "devcpp-noi.desktop", package / "usr/share/applications/devcpp-noi.desktop")
        copy_file(TEMPLATES / "devcpp-noi-installed.desktop", package / "usr/share/applications/devcpp-noi-installed.desktop")
        copy_file(TEMPLATES / "devcpp-noi-new-window.desktop", package / "usr/share/applications/devcpp-noi-new-window.desktop")
        copy_file(TEMPLATES / "migrate-launchers.py", app / "migrate-launchers.py", 0o755)
        copy_file(TEMPLATES / "devcpp-noi-migrate.desktop", package / "etc/xdg/autostart/devcpp-noi-migrate.desktop")
        copy_file(TEMPLATES / "devcpp-noi.svg", package / "usr/share/icons/hicolor/scalable/apps/devcpp-noi.svg")
        docs = package / "usr/share/doc/devcpp-noi"
        copy_file(SOURCE / "COPYING.txt", docs / "copyright")
        copy_file(SOURCE / "README.md", docs / "README.md")
        copy_file(ROOT / "docs/PACKAGING.md", docs / "PACKAGING.md")
        (package / "DEBIAN").mkdir()
        size = sum(p.stat().st_size for p in package.rglob("*") if p.is_file())
        control = (TEMPLATES / "control").read_text().replace("@VERSION@", version).replace("@INSTALLED_SIZE@", str((size + 1023) // 1024))
        (package / "DEBIAN/control").write_text(control)
        for name in ("postinst", "postrm"):
            copy_file(TEMPLATES / name, package / "DEBIAN" / name, 0o755)
        # Explicit modes avoid depending on checkout umask (some environments
        # check out directories as 0700, which makes an installed IDE unreadable).
        for path in package.rglob("*"):
            if path.is_dir():
                path.chmod(0o755)
            os.utime(path, (epoch, epoch))
        package.chmod(0o755)
        os.utime(package, (epoch, epoch))
        target = output / ("devcpp-noi_" + version + "_amd64.deb")
        env = dict(os.environ, SOURCE_DATE_EPOCH=str(epoch))
        subprocess.run(["dpkg-deb", "--build", "--root-owner-group", "-Zxz", str(package), str(target)], check=True, env=env)
        print(target)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kind", choices=("source", "deb", "all"))
    parser.add_argument("--version", default=(ROOT / "VERSION").read_text().strip(), help="Release version or tag; optional leading v is removed")
    parser.add_argument("--output", type=Path, default=ROOT / "dist")
    parser.add_argument("--binary", type=Path, default=SOURCE / "devcpp-noi", help="Already built Ubuntu 20.04 amd64 GTK2 executable")
    args = parser.parse_args()
    version = args.version[1:] if args.version.startswith("v") else args.version
    if not re.fullmatch(r"[0-9][0-9A-Za-z.+~-]*", version):
        parser.error("Version must be a Debian-compatible version starting with a digit")
    epoch = int(os.environ.get("SOURCE_DATE_EPOCH", "315532800"))
    args.output.mkdir(parents=True, exist_ok=True)
    if args.kind in ("source", "all"):
        build_sources(version, args.output, epoch)
    if args.kind in ("deb", "all"):
        build_deb(version, args.output, args.binary, epoch)


if __name__ == "__main__":
    main()
