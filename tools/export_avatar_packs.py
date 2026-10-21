#!/usr/bin/env python3
"""아바타 애니메이션(감정 프레임·허브 대기 프레임)을 아바타별 .pck로 따로 내보낸다.

웹 본체(index.pck)는 export_presets.cfg의 exclude_filter로 이 파일들을 빼고 내보낸다.
게임은 시작 후 뒤에서 avatars/<id>.pck를 받아 ProjectSettings.load_resource_pack()으로 붙인다 (core_engine/avatar_packs.gd).

사용: python3 tools/export_avatar_packs.py <godot 실행 파일> <출력 폴더>
예:   python3 tools/export_avatar_packs.py godot build/web/avatars

export_presets.cfg에 임시 프리셋(AvatarPack, export_filter="resources")을 붙여 아바타마다 --export-pack을 돌리고,
끝나면 원래 파일로 되돌린다.
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PRESETS = ROOT / "export_presets.cfg"
AVATARS = ROOT / "content_trickcal" / "avatars"
IMAGE_SUFFIXES = {".png", ".webp", ".jpg"}


def pack_files(avatar: Path) -> list[str]:
    """이 아바타의 분리 대상 리소스(res:// 경로). 본체 exclude_filter와 같은 묶음이어야 한다."""
    files: list[Path] = sorted(avatar.glob("emotion_*.tres"))
    files += sorted(p for p in (avatar / "frames").glob("*") if p.suffix in IMAGE_SUFFIXES)
    if (avatar / "idle_hq.tres").exists():
        # 고화질 대기 프레임이 있으면 허브는 그것만 쓴다 (idle/ 저화질 프레임은 본체에서도 이미 빠져 있다)
        files.append(avatar / "idle_hq.tres")
        files += sorted(p for p in (avatar / "idle_hq").glob("*") if p.suffix in IMAGE_SUFFIXES)
    else:
        files += sorted(p for p in (avatar / "idle").glob("*") if p.suffix in IMAGE_SUFFIXES)
    return ["res://" + p.relative_to(ROOT).as_posix() for p in files]


def preset_block(original: str, index: int, export_files: list[str]) -> str:
    """원래 Web 프리셋의 옵션을 그대로 쓰고, 고른 파일만 내보내는 임시 프리셋을 만든다."""
    options = re.search(r"\[preset\.0\.options\]\n(.*)", original, re.S)
    if options is None:
        raise SystemExit("export_presets.cfg에 [preset.0.options]가 없습니다")
    listed = ", ".join('"%s"' % path for path in export_files)
    return (
        f"\n[preset.{index}]\n\n"
        'name="AvatarPack"\nplatform="Web"\nrunnable=false\nadvanced_options=false\ndedicated_server=false\n'
        'custom_features=""\nexport_filter="resources"\n'
        f"export_files=PackedStringArray({listed})\n"
        'include_filter=""\nexclude_filter=""\nexport_path=""\npatches=PackedStringArray()\n'
        'encryption_include_filters=""\nencryption_exclude_filters=""\nseed=0\nencrypt_pck=false\n'
        "encrypt_directory=false\nscript_export_mode=2\n\n"
        f"[preset.{index}.options]\n\n{options.group(1)}"
    )


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    godot, out_dir = sys.argv[1], Path(sys.argv[2])
    out_dir.mkdir(parents=True, exist_ok=True)
    original = PRESETS.read_text(encoding="utf-8")
    index = len(re.findall(r"^\[preset\.\d+\]$", original, re.M))
    try:
        for avatar in sorted(p for p in AVATARS.glob("avatar_*") if p.is_dir()):
            files = pack_files(avatar)
            if not files:
                continue
            PRESETS.write_text(original + preset_block(original, index, files), encoding="utf-8")
            target = out_dir / f"{avatar.name}.pck"
            subprocess.run([godot, "--headless", "--path", str(ROOT), "--export-pack", "AvatarPack", str(target.resolve())], check=True)
            print(f"{target} = {target.stat().st_size / 1048576:.2f} MiB ({len(files)} files)")
    finally:
        PRESETS.write_text(original, encoding="utf-8")


if __name__ == "__main__":
    main()
