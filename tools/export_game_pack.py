#!/usr/bin/env python3
"""웹 첫 로딩을 가볍게: 메뉴(시작 화면·허브·로비)에 필요 없는 리소스를 게임 묶음(game.pck)으로 따로 내보낸다.

게임 묶음은 메뉴가 뜨면 뒤에서 받고, 게임 시작·도감·온라인 게임 입장 때 다 붙을 때까지 기다린다 (scenes/game_pack.gd).

어떤 리소스가 본체에 남는가는 손으로 정하지 않는다:
  tests/menu_tour.gd(메뉴를 한 바퀴 도는 스크립트)를 --verbose로 돌려 메뉴가 실제로 읽은 리소스 + 모든 스크립트·셰이더·데이터는 본체,
  나머지 그림·모델·소리·장면은 게임 묶음. 코드가 바뀌어도 배포 때마다 다시 뽑는다.

사용 (배포 CI, 순서 중요):
  python3 tools/export_game_pack.py pack <godot> <출력 폴더>   # 게임 묶음 목록을 뽑아 game.pck를 내보낸다 (버전에 +커밋을 붙이기 전에: 내용이 같으면 해시가 같아 다시 받지 않는다)
  python3 tools/export_game_pack.py main <godot> <출력 폴더>   # 게임 묶음 파일을 뺀 본체(index.html·index.pck ...)를 내보낸다
  python3 tools/export_game_pack.py list                       # (확인용) 목록만 뽑아 크기를 출력한다

export_presets.cfg는 잠시 고쳐 쓰고 끝나면 원래대로 되돌린다.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PRESETS = ROOT / "export_presets.cfg"
LIST_FILE = ROOT / "build" / "game_pack_files.json"
## 게임 묶음 안에 같이 넣는 UID 목록 (묶음을 붙인 뒤 GamePack이 ResourceUID에 등록한다). 생성 파일이라 저장소에는 없다 (.gitignore).
MANIFEST = ROOT / "game_pack_manifest.json"
MANIFEST_RES = "res://game_pack_manifest.json"
## 게임 묶음으로 보낼 수 있는 리소스 종류 (스크립트·셰이더·데이터·글꼴은 작고, 스크립트를 읽을 때 바로 필요할 수 있어 늘 본체에 둔다).
MOVABLE = {".png", ".webp", ".jpg", ".jpeg", ".svg", ".ogg", ".wav", ".mp3", ".glb", ".gltf", ".tscn", ".scn", ".tres", ".res", ".obj"}
## 본체에 늘 남긴다: 메뉴 장면, 웹 셸·아이콘, 그리고 소리.
## 헤드리스로 도는 메뉴 한 바퀴는 소리를 내지 않아(Sfx.enabled()가 거짓) 메뉴가 쓰는 소리를 잡지 못한다:
## 효과음 전부(약 1 MB, 버튼 클릭 등 메뉴에서도 쓴다)·로비 음악·아바타 고르기 대사는 늘 본체에 둔다.
ALWAYS_CORE_PREFIXES = ("web/", "scenes/start_menu.tscn", "scenes/lobby.tscn", "assets/sfx/", "assets/bgm/lobby_daylife.ogg")
ALWAYS_CORE_SUFFIXES = ("/select_voice.ogg",)
SKIP_DIRS = {".godot", ".git", "build", "tests", "docs", "tools", "__pycache__", "node_modules"}


def main_preset_filters(text: str) -> tuple[str, str]:
    block = text.split("[preset.0.options]")[0]
    exclude = re.search(r'^exclude_filter="(.*)"$', block, re.M)
    include = re.search(r'^include_filter="(.*)"$', block, re.M)
    return (exclude.group(1) if exclude else ""), (include.group(1) if include else "")


def excluded_by_main(rel: str, exclude: str) -> bool:
    """본체 프리셋이 이미 빼는 파일 (아바타 애니메이션 묶음 등): 게임 묶음에도 넣지 않는다."""
    from fnmatch import fnmatch
    for pattern in [p.strip() for p in exclude.split(",") if p.strip()]:
        if fnmatch(rel, pattern):
            return True
    return False


def tour_loaded(godot: str) -> set[str]:
    """메뉴 한 바퀴(tests/menu_tour.gd)에서 엔진이 읽은 리소스의 원본 경로 (res:// 없이)."""
    run = subprocess.run([godot, "--headless", "--verbose", "--path", str(ROOT), "-s", "res://tests/menu_tour.gd"],
                         capture_output=True, text=True, timeout=600)
    output = run.stdout + run.stderr
    if "MENU_TOUR_OK" not in output:
        print(output[-4000:])
        raise SystemExit("tests/menu_tour.gd가 끝나지 않았다: 게임 묶음 목록을 정할 수 없다")
    loaded = set(re.findall(r"^Loading resource: res://(\S+)", output, re.M))
    imported_to_source: dict[str, str] = {}
    for import_file in ROOT.rglob("*.import"):
        if any(part in SKIP_DIRS for part in import_file.relative_to(ROOT).parts):
            continue
        source = import_file.relative_to(ROOT).as_posix()[: -len(".import")]
        for dest in re.findall(r'res://(\.godot/imported/[^"]+)', import_file.read_text(encoding="utf-8", errors="ignore")):
            imported_to_source[dest] = source
    sources = set()
    for path in loaded:
        sources.add(imported_to_source.get(path, path))
    return sources


def project_files() -> list[str]:
    files = []
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        rel = path.relative_to(ROOT)
        if any(part in SKIP_DIRS for part in rel.parts) or rel.suffix in {".import", ".uid"}:
            continue
        files.append(rel.as_posix())
    return sorted(files)


def uid_of(rel: str) -> str:
    """리소스의 UID (uid://...): 가져온 파일은 .import의 uid, 글로 된 장면·리소스는 머리줄의 uid."""
    path = ROOT / rel
    sidecar = Path(str(path) + ".import")
    if sidecar.exists():
        match = re.search(r'^uid="(uid://[^"]+)"', sidecar.read_text(encoding="utf-8", errors="ignore"), re.M)
        return match.group(1) if match else ""
    if path.suffix in {".tscn", ".tres"}:
        head = path.read_text(encoding="utf-8", errors="ignore").split("\n", 1)[0]
        match = re.search(r'uid="(uid://[^"]+)"', head)
        return match.group(1) if match else ""
    return ""


def plan(godot: str) -> list[str]:
    text = PRESETS.read_text(encoding="utf-8")
    exclude, _include = main_preset_filters(text)
    core = tour_loaded(godot)
    # 번호 붙은 변형(ui_click_01/02/03.ogg 등)은 무작위로 하나를 고르므로, 메뉴가 하나라도 읽었으면 형제 변형도 모두 본체에 둔다
    # (메뉴 한 바퀴에서 우연히 고른 것만 남기면 다른 변형이 뽑힐 때 [No loader found]로 소리가 빠진다).
    variant = re.compile(r"^(.*?)[_-]?\d+(\.[^.]+)$")
    stems = set()
    for rel in core:
        m = variant.match(rel)
        if m:
            stems.add((m.group(1), m.group(2)))
    for rel in project_files():
        m = variant.match(rel)
        if m and (m.group(1), m.group(2)) in stems:
            core.add(rel)
    game: list[str] = []
    for rel in project_files():
        if Path(rel).suffix.lower() not in MOVABLE or rel in core or rel.startswith(ALWAYS_CORE_PREFIXES) or rel.endswith(ALWAYS_CORE_SUFFIXES):
            continue
        if excluded_by_main(rel, exclude):
            continue
        game.append(rel)
    LIST_FILE.parent.mkdir(parents=True, exist_ok=True)
    LIST_FILE.write_text(json.dumps(game, ensure_ascii=False, indent=0), encoding="utf-8")
    uids = {}
    for rel in game:
        uid = uid_of(rel)
        if uid:
            uids[uid] = "res://" + rel
    MANIFEST.write_text(json.dumps({"files": len(game), "uids": uids}, ensure_ascii=False), encoding="utf-8")
    size = sum((ROOT / rel).stat().st_size for rel in game)
    print(f"게임 묶음: 원본 {len(game)}개 ({size / 1048576:.1f} MiB 원본 기준), 메뉴가 읽은 리소스 {len(core)}개는 본체, UID {len(uids)}개")
    return game


def pack_preset(original: str, index: int, export_files: list[str]) -> str:
    options = re.search(r"\[preset\.0\.options\]\n(.*)", original, re.S)
    if options is None:
        raise SystemExit("export_presets.cfg에 [preset.0.options]가 없습니다")
    listed = ", ".join('"res://%s"' % rel for rel in export_files)
    return (
        f"\n[preset.{index}]\n\n"
        'name="GamePack"\nplatform="Web"\nrunnable=false\nadvanced_options=false\ndedicated_server=false\n'
        'custom_features=""\nexport_filter="resources"\n'
        f"export_files=PackedStringArray({listed})\n"
        f'include_filter="{MANIFEST.name}"\nexclude_filter=""\nexport_path=""\npatches=PackedStringArray()\n'
        'encryption_include_filters=""\nencryption_exclude_filters=""\nseed=0\nencrypt_pck=false\n'
        "encrypt_directory=false\nscript_export_mode=2\n\n"
        f"[preset.{index}.options]\n\n{options.group(1)}"
    )


def export_pack(godot: str, out_dir: Path) -> None:
    game = plan(godot)
    original = PRESETS.read_text(encoding="utf-8")
    index = len(re.findall(r"^\[preset\.\d+\]$", original, re.M))
    target = (out_dir / "game.pck").resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    try:
        PRESETS.write_text(original + pack_preset(original, index, game), encoding="utf-8")
        subprocess.run([godot, "--headless", "--path", str(ROOT), "--export-pack", "GamePack", str(target)], check=True)
    finally:
        PRESETS.write_text(original, encoding="utf-8")
    print(f"{target} = {target.stat().st_size / 1048576:.2f} MiB")


def export_main(godot: str, out_dir: Path) -> None:
    if not LIST_FILE.exists():
        raise SystemExit(f"{LIST_FILE}가 없다: 먼저 pack을 실행한다")
    game: list[str] = json.loads(LIST_FILE.read_text(encoding="utf-8"))
    original = PRESETS.read_text(encoding="utf-8")
    exclude, _include = main_preset_filters(original)
    extra = ", ".join(game + [MANIFEST.name])
    patched = original.replace(f'exclude_filter="{exclude}"', f'exclude_filter="{exclude}, {extra}"' if exclude else f'exclude_filter="{extra}"', 1)
    out_dir.mkdir(parents=True, exist_ok=True)
    try:
        PRESETS.write_text(patched, encoding="utf-8")
        subprocess.run([godot, "--headless", "--path", str(ROOT), "--export-release", "Web", str((out_dir / "index.html").resolve())], check=True)
    finally:
        PRESETS.write_text(original, encoding="utf-8")
    pck = out_dir / "index.pck"
    print(f"{pck} = {pck.stat().st_size / 1048576:.2f} MiB (게임 묶음 {len(game)}개 제외)")


def main() -> None:
    if len(sys.argv) >= 2 and sys.argv[1] == "list" and len(sys.argv) == 3:
        plan(sys.argv[2])
        return
    if len(sys.argv) != 4 or sys.argv[1] not in ("pack", "main"):
        raise SystemExit(__doc__)
    command, godot, out_dir = sys.argv[1], sys.argv[2], Path(sys.argv[3])
    if command == "pack":
        export_pack(godot, out_dir)
    else:
        export_main(godot, out_dir)


if __name__ == "__main__":
    main()
