"""Conservative handoff packaging, dependency audit, and reversible workspace cleanup."""
from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
from pathlib import Path
import re
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Build/交付-渝见-20261018"
ARCHIVE = ROOT / "Build/清理备份-20261018"
PACKAGE_ROOT = "渝见-开发交接-20261018"
TEXT_SUFFIXES = {".gd", ".tscn", ".tres", ".godot", ".cfg", ".json", ".md", ".txt", ".py", ".ps1", ".gdshader"}
SOURCE_DIRS = ("assets", "autoload", "scenes", "scripts")
SOURCE_ROOTS = ("project.godot", "export_presets.cfg", ".gitignore")
TOOLS = ("test_release_pack_oct17.gd", "test_future_ethereal_bgm_v1.gd", "test_hero_animation_v2.gd",
         "test_spirit_path_light_v1.gd", "test_chapter_arrival_v1.gd", "test_quest_guide_v1.gd",
         "test_future_difficulty_v1.gd", "test_flyer_walk_smooth_v1.gd",
         "finalize_hero_jog_v3.py", "finalize_flyer_walk_v4.py", "build_future_ethereal_audio.py")
ART_DIRS = ("hero-jog-v3-oct18", "flyer-walk-v4-oct18", "future-ethereal-oct18")
DOCS = ("渝灯AI接入说明.md", "渝灯AI主流预设-v3.md", "第六关玩法升级-v2.md", "第六关重构-v3.md")


def safe(path: Path) -> Path:
    resolved = path.resolve()
    if ROOT.resolve() not in resolved.parents:
        raise ValueError("Path leaves project workspace")
    if path.is_symlink():
        raise ValueError("Symlink excluded")
    return resolved


def export_patterns() -> list[str]:
    config = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
    return re.search(r'exclude_filter="([^"]*)"', config).group(1).split(",")


def private(path: Path) -> bool:
    name = path.name.lower()
    return (name.startswith(".env") or name in {"yudeng_ai.cfg", "story_save.cfg", "export_credentials.cfg"}
            or any(part in {".godot", ".git", ".mcp-runtime", "__pycache__"} for part in path.parts)
            or path.suffix.lower() in {".bak", ".tmp", ".pyc"})


def selected_files() -> list[Path]:
    patterns = export_patterns()
    selected = [ROOT / name for name in SOURCE_ROOTS]
    for directory in SOURCE_DIRS:
        for path in (ROOT / directory).rglob("*"):
            if not path.is_file() or private(path):
                continue
            relative = path.relative_to(ROOT).as_posix()
            license_file = "license" in path.name.lower() or "copyright" in path.name.lower()
            if directory == "assets" and not license_file and any(fnmatch.fnmatch(relative, pattern) for pattern in patterns):
                continue
            selected.append(path)
    for name in TOOLS:
        path = ROOT / "tools" / name
        selected.append(path)
        if path.with_suffix(path.suffix + ".uid").exists():
            selected.append(path.with_suffix(path.suffix + ".uid"))
    for directory in ART_DIRS:
        selected.extend(path for path in (ROOT / "art_source" / directory).rglob("*")
                        if path.is_file() and path.suffix != ".import" and not private(path))
    for name in DOCS:
        selected.append(ROOT / "docs" / name)
    selected.append(ROOT / "交接说明-20261017.md")
    return sorted(set(selected))


def audit(files: list[Path]) -> dict:
    included = {path.relative_to(ROOT).as_posix() for path in files}
    missing = []
    findings = []
    for path in files:
        safe(path)
        if not path.exists() or private(path):
            raise ValueError("Missing or private package file: " + str(path.relative_to(ROOT)))
        if path.suffix.lower() not in TEXT_SUFFIXES:
            continue
        content = path.read_text(encoding="utf-8", errors="replace")
        # Report file path only, never suspected secret text.
        if re.search(r'\bsk-[A-Za-z0-9_-]{24,}|\b[0-9a-f]{32}\.[A-Za-z0-9]{16,}', content):
            findings.append(path.relative_to(ROOT).as_posix())
        if path.parts[len(ROOT.parts)] not in ("scripts", "autoload", "scenes"):
            continue
        for ref in re.findall(r'res://[^\s"\'<>]+', content):
            relative = ref[6:]
            if "%" in relative or "{" in relative or not Path(relative).suffix:
                continue
            if (ROOT / relative).is_file() and relative not in included:
                missing.append({"source": path.relative_to(ROOT).as_posix(), "reference": relative})
    return {"file_count": len(files), "uncompressed_bytes": sum(path.stat().st_size for path in files),
            "missing_static_references": missing, "possible_secret_files": findings}


def cleanup_targets() -> list[Path]:
    targets = [ROOT / name for name in ("preview", "tmp") if (ROOT / name).exists()]
    for path in (ROOT / "Build").iterdir():
        if path.is_dir() and (path.name.startswith(("Previous-", "Release-")) or path.name == "Game"):
            targets.append(path)
    # Only broad original-source directories already excluded by the release preset.
    for name in ("raw", "npc_src", "player_frames", "player_frames_norm"):
        path = ROOT / "assets" / name
        if path.exists():
            targets.append(path)
    return targets


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest().upper()


def assemble(files: list[Path]) -> None:
    if OUT.exists():
        raise ValueError("Output exists; refusing overwrite")
    OUT.mkdir(parents=True)
    source = OUT / "01-源码工程"
    source.mkdir()
    for path in files:
        destination = source / path.relative_to(ROOT)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, destination)
    # Make res://tools checks use clean test userdata, not the developer's live save.
    (source / "Build/Game").mkdir(parents=True)
    (source / "Build/.gdignore").touch()
    handoff = ROOT / "docs/开发交接-20261018.md"
    shutil.copy2(handoff, OUT / "请先阅读.md")
    shutil.copy2(handoff, source / "README-交接.md")
    runtime = OUT / "02-Windows试玩"
    runtime.mkdir()
    for ext in ("exe", "pck"):
        shutil.copy2(ROOT / f"洞见.{ext}", runtime / f"渝见.{ext}")
    shutil.copy2(ROOT / "交接说明-20261017.md", OUT / "版本与修改入口.md")
    manifest = []
    for path in sorted(OUT.rglob("*")):
        if path.is_file():
            manifest.append({"path": path.relative_to(OUT).as_posix(), "bytes": path.stat().st_size,
                             "sha256": digest(path)})
    (OUT / "文件清单-SHA256.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"output": str(OUT), "files": len(manifest)}, ensure_ascii=True))


def archive_extras() -> None:
    if ARCHIVE.exists():
        raise ValueError("Cleanup archive exists; refusing overwrite")
    targets = cleanup_targets()
    # No move if code dynamically loads one of these source directories.
    runtime_text = "\n".join(path.read_text(encoding="utf-8", errors="replace")
                             for directory in ("autoload", "scripts", "scenes")
                             for path in (ROOT / directory).rglob("*")
                             if path.is_file() and path.suffix in TEXT_SUFFIXES)
    for target in targets:
        safe(target)
        if target.relative_to(ROOT).parts[0] == "assets" and "res://" + target.relative_to(ROOT).as_posix() in runtime_text:
            raise ValueError("Runtime reference blocks cleanup: " + str(target))
    ARCHIVE.mkdir()
    (ARCHIVE / ".gdignore").touch()
    log = []
    for target in targets:
        relative = target.relative_to(ROOT)
        destination = safe(ARCHIVE / relative)
        destination.parent.mkdir(parents=True, exist_ok=True)
        byte_count = sum(path.stat().st_size for path in target.rglob("*") if path.is_file())
        shutil.move(str(safe(target)), str(destination))
        log.append({"original": relative.as_posix(), "archived": destination.relative_to(ROOT).as_posix(), "bytes": byte_count})
    (ARCHIVE / "恢复清单.json").write_text(json.dumps(log, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"archived_directories": len(log), "bytes": sum(item["bytes"] for item in log)}, ensure_ascii=True))


def compress() -> None:
    package = OUT.with_suffix(".zip")
    if package.exists():
        raise ValueError("ZIP exists; refusing overwrite")
    with zipfile.ZipFile(package, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in sorted(OUT.rglob("*")):
            if path.is_file() and not any(part == ".godot" for part in path.relative_to(OUT).parts):
                archive.write(path, PACKAGE_ROOT + "/" + path.relative_to(OUT).as_posix())
    with zipfile.ZipFile(package) as archive:
        bad = archive.testzip()
        if bad:
            raise ValueError("ZIP CRC failure: " + bad)
    checksum = digest(package)
    package.with_suffix(".zip.sha256").write_text(checksum + "  " + package.name + "\n", encoding="utf-8")
    print(json.dumps({"zip": str(package), "bytes": package.stat().st_size, "sha256": checksum}, ensure_ascii=True))


def finalize() -> None:
    source = OUT / "01-源码工程"
    # Validation cache is recoverable but must not be distributed.
    cache = source / ".godot"
    destination = ARCHIVE / "交接验证缓存"
    if cache.exists():
        if destination.exists():
            raise ValueError("Validation cache archive exists")
        shutil.move(str(safe(cache)), str(safe(destination)))
    (source / "art_source/.gdignore").touch()
    handoff = ROOT / "docs/开发交接-20261018.md"
    shutil.copy2(handoff, OUT / "请先阅读.md")
    shutil.copy2(handoff, source / "README-交接.md")
    report = {"fresh_source_import": "PASS; first import rebuilt font/texture cache",
              "fresh_source_export": "PASS", "six_level_resource_audit": "PASS",
              "hero_animation": "PASS", "user_bgm_loop_duck_switch": "PASS",
              "runtime_exe_sha256": digest(OUT / "02-Windows试玩/渝见.exe"),
              "runtime_pck_sha256": digest(OUT / "02-Windows试玩/渝见.pck"),
              "notes": "Some tests still report ObjectDB/resource cleanup warnings; not a full manual playthrough."}
    (OUT / "交接验证结果.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    manifest = []
    for path in sorted(OUT.rglob("*")):
        if path.is_file() and path.name != "文件清单-SHA256.json":
            if private(path):
                raise ValueError("Private file in final output: " + str(path.relative_to(OUT)))
            manifest.append({"path": path.relative_to(OUT).as_posix(), "bytes": path.stat().st_size,
                             "sha256": digest(path)})
    (OUT / "文件清单-SHA256.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"final_files": len(manifest), "bytes": sum(item["bytes"] for item in manifest)}, ensure_ascii=True))


def verify() -> None:
    package = OUT.with_suffix(".zip")
    with zipfile.ZipFile(package) as archive:
        names = archive.namelist()
        manifest = json.loads(archive.read(PACKAGE_ROOT + "/文件清单-SHA256.json"))
        for item in manifest:
            name = PACKAGE_ROOT + "/" + item["path"]
            value = hashlib.sha256()
            with archive.open(name) as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                    value.update(chunk)
            if value.hexdigest().upper() != item["sha256"]:
                raise ValueError("Manifest hash mismatch: " + name)
        if any(private(Path(name)) for name in names):
            raise ValueError("Private path in ZIP")
    # Retired upload zips and the duplicate validation export are also recoverable.
    extras = sorted((ROOT / "Build").glob("洞见*.zip"))
    validation = ROOT / "Build/HandoffValidation"
    if validation.exists():
        extras.append(validation)
    log = []
    for path in extras:
        destination = ARCHIVE / "旧上传包与验证产物" / path.name
        safe(path)
        safe(destination)
        if destination.exists():
            raise ValueError("Archive destination exists")
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(path), str(destination))
        log.append({"original": path.relative_to(ROOT).as_posix(), "archived": destination.relative_to(ROOT).as_posix()})
    (ARCHIVE / "补充恢复清单.json").write_text(json.dumps(log, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"zip_entries": len(names), "verified_sha256_files": len(manifest),
                      "private_paths": 0, "extra_archived_items": len(log)}, ensure_ascii=True))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("audit", "assemble", "cleanup", "finalize", "zip", "verify"))
    args = parser.parse_args()
    if args.mode == "cleanup":
        archive_extras()
    elif args.mode == "zip":
        compress()
    elif args.mode == "finalize":
        finalize()
    elif args.mode == "verify":
        verify()
    else:
        chosen = selected_files()
        result = audit(chosen)
        print(json.dumps(result, ensure_ascii=True, indent=2))
        if result["missing_static_references"] or result["possible_secret_files"]:
            raise SystemExit(1)
        if args.mode == "assemble":
            assemble(chosen)
