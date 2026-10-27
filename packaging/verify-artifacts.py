#!/usr/bin/env python3
"""Check release archive contents and Debian metadata without installing."""
import argparse
from pathlib import Path, PurePosixPath
import subprocess
import tarfile
import tempfile
import zipfile
import xml.etree.ElementTree as ET
from original_icon import icon_pixels


def check_sources(tar_path, zip_path):
    with tarfile.open(tar_path) as archive:
        members = archive.getmembers()
        assert all(m.isfile() for m in members), "Sources must contain regular files only"
        tar_files = {m.name: archive.extractfile(m).read() for m in members}
        assert all(m.mode in (0o644, 0o755) for m in members), "Unsafe source permissions"
    with zipfile.ZipFile(zip_path) as archive:
        zip_files = {name: archive.read(name) for name in archive.namelist()}
    assert tar_files == zip_files, "tar.gz and zip contents differ"
    required = {"build.sh", "run.sh", "launch.sh", "console-pauser.sh", "ui-language.sh", "devcpp_noi.lpr", "devcpp_noi.lpi", "mainform.pas", "devcpp.ico", "COPYING.txt"}
    assert required <= {PurePosixPath(n).name for n in tar_files}, "Missing source/runtime resources"
    for name, data in tar_files.items():
        path = PurePosixPath(name)
        assert path.parts[0] == "linux-noi-lazarus" and ".." not in path.parts, name
        assert not any(p.startswith(".") for p in path.parts), name
        assert path.suffix not in (".o", ".or", ".ppu", ".compiled", ".lps", ".tmp", ".bak", ".swp"), name
        assert path.name not in ("devcpp-noi", "devcpp-noi.build", "devcpp-noi.instance-api", "devcpp-noi.ini"), name
        assert not data.startswith(b"\x7fELF"), name
    assert any(n.startswith("linux-noi-lazarus/icons/") for n in tar_files), "Missing UI icons"
    languages = [data for name, data in tar_files.items()
                 if name.startswith("linux-noi-lazarus/languages/") and name.endswith(".lng")]
    assert len(languages) == 33, "Missing original language resources in source archives"
    for data in languages:
        assert "\ufffd" not in data.decode("utf-8"), "Invalid UTF-8 language resource"
    print("PASS: equivalent source archives without build outputs or local state")


def check_deb(deb_path, version):
    def field(name):
        return subprocess.check_output(["dpkg-deb", "-f", str(deb_path), name], text=True).strip()
    assert field("Package") == "devcpp-noi"
    assert field("Architecture") == "amd64"
    assert field("Homepage") == "https://github.com/TH911/Dev-Cpp-Linux"
    assert field("Description").startswith("Dev-Cpp - C/C++ IDE for NOI Linux")
    assert "GPL-2.0-or-later" in field("Description")
    if version:
        assert field("Version") == version.lstrip("v")
    depends = field("Depends")
    for dependency in ("gcc", "g++", "gdb", "python3", "gnome-terminal | xterm", "libgtk2.0-0", "libc6"):
        assert dependency in depends, dependency
    with tempfile.TemporaryDirectory(prefix="devcpp-verify-") as temp:
        root = Path(temp)
        subprocess.run(["dpkg-deb", "-x", str(deb_path), str(root)], check=True)
        subprocess.run(["dpkg-deb", "-e", str(deb_path), str(root / "DEBIAN")], check=True)
        app = root / "usr/lib/devcpp-noi"
        for name in ("devcpp-noi", "console-pauser.sh", "ui-language.sh", "devcpp.ico", "PORT_REVISION"):
            assert (app / name).is_file(), name
        assert (app / "devcpp-noi").read_bytes().startswith(b"\x7fELF")
        original_icon = Path(__file__).resolve().parent.parent / "linux-noi-lazarus/devcpp.ico"
        assert (root / "usr/share/pixmaps/devcpp-noi.ico").read_bytes() == (app / "devcpp.ico").read_bytes() == original_icon.read_bytes()
        assert not (root / "usr/share/icons/hicolor/scalable/apps/devcpp-noi.svg").exists(), "Unexpected replacement icon"
        png = root / "usr/share/icons/hicolor/48x48/apps/devcpp-noi.png"
        assert png.read_bytes().startswith(b"\x89PNG\r\n\x1a\n")
        pixels = icon_pixels(png)
        assert pixels[:2] == (48, 48), "Unexpected theme icon dimensions"
        assert pixels == icon_pixels(original_icon), "Theme PNG changes original icon pixels"
        metadata = root / "usr/share/metainfo/io.github.TH911.DevCpp.metainfo.xml"
        component = ET.parse(metadata).getroot()
        assert component.tag == "component" and component.get("type") == "desktop-application"
        for tag, expected in {"id": "io.github.TH911.DevCpp", "name": "Dev-Cpp",
                              "pkgname": "devcpp-noi", "metadata_license": "CC0-1.0",
                              "project_license": "GPL-2.0-or-later"}.items():
            assert component.findtext(tag) == expected, tag
        desktop_id = component.find("launchable[@type='desktop-id']").text
        assert desktop_id == "devcpp-noi-installed.desktop"
        assert (root / "usr/share/applications" / desktop_id).is_file()
        assert component.findtext("developer_name"), "Missing developer attribution"
        assert component.findtext("icon[@type='stock']") == "devcpp-noi"
        assert component.findtext("url[@type='homepage']") == field("Homepage")
        # Validate using the actual NOI Linux-era AppStream implementation in CI.
        subprocess.run(["appstreamcli", "validate", "--no-net", str(metadata)], check=True)
        assert (root / "usr/share/doc/devcpp-noi/NOI-LINUX-SOFTWARE-INSTALL.md").is_file()
        assert list((app / "icons").glob("*.bmp")), "Missing toolbar icons"
        catalogs = sorted((app / "languages").glob("*.lng"))
        assert len(catalogs) == 33, "Missing installed language resources"
        for catalog in catalogs:
            source = original_icon.parent / "languages" / catalog.name
            assert catalog.read_bytes() == source.read_bytes(), "Installed catalog differs: " + catalog.name
        for path in root.rglob("*"):
            if path.is_dir():
                assert path.stat().st_mode & 0o005 == 0o005, str(path)
            else:
                assert path.stat().st_mode & 0o004, str(path)
        assert (root / "usr/bin/devcpp-noi").stat().st_mode & 0o111 == 0o111
        launcher = (root / "usr/bin/devcpp-noi").read_text()
        assert 'exec /usr/lib/devcpp-noi/devcpp-noi "$@"' in launcher
        assert "build.sh" not in launcher and "cd " not in launcher
        desktop = (root / "usr/share/applications/devcpp-noi.desktop").read_text()
        assert "Exec=/usr/bin/devcpp-noi %F" in desktop and "MimeType=" in desktop
        assert "NoDisplay=true" in desktop
        old_new_window = (root / "usr/share/applications/devcpp-noi-new-window.desktop").read_text()
        assert "Exec=/usr/bin/devcpp-noi --new-window %F" in old_new_window and "NoDisplay=true" in old_new_window
        visible_desktop = (root / "usr/share/applications/devcpp-noi-installed.desktop").read_text()
        assert "Exec=/usr/bin/devcpp-noi %F" in visible_desktop and "NoDisplay=" not in visible_desktop
        assert "StartupWMClass=DevCppNoiInstalled" in visible_desktop
        assert "Name=Dev-Cpp\n" in visible_desktop and "Name[zh_CN]=Dev-Cpp\n" in visible_desktop
        assert "Icon=/usr/share/pixmaps/devcpp-noi.ico\n" in visible_desktop
        assert (app / "migrate-launchers.py").is_file()
        assert (root / "etc/xdg/autostart/devcpp-noi-migrate.desktop").is_file()
        for path in (root / "DEBIAN").iterdir():
            if path.name in ("preinst", "postinst", "prerm", "postrm"):
                text = path.read_text()
                assert "xdg-mime" not in text and "mimeapps.list" not in text
        assert not (app / "build.sh").exists(), "Installed app must never compile itself"
    print("PASS: Debian architecture, dependencies, resources, permissions and direct launcher")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parent.parent / "dist")
    parser.add_argument("--version", default=(Path(__file__).resolve().parent.parent / "VERSION").read_text().strip())
    parser.add_argument("--source-only", action="store_true")
    args = parser.parse_args()
    version = args.version[1:] if args.version.startswith("v") else args.version
    check_sources(args.output / ("linux-noi-lazarus-" + version + "-src.tar.gz"), args.output / ("linux-noi-lazarus-" + version + "-src.zip"))
    if not args.source_only:
        check_deb(args.output / ("devcpp-noi_" + version + "_amd64.deb"), version)


if __name__ == "__main__":
    main()
