#!/usr/bin/env python3
"""웹 묶음(index.pck) 용량 정책: 텍스처 임포트 설정(.import)만 바꾸고 원본 그림은 그대로 둔다.

- 무손실(compress/mode=0) 텍스처는 손실 WebP(품질 0.85)로 바꾼다. 128px 이하 작은 그림은 그대로 둔다.
- 화면에 작게(150px 이하) 그려지는 아이콘(기물·도구·증강·교칙 그림)은 최대 256px로 임포트한다.
- 에르핀 고화질 대기 프레임(idle_hq)은 640px로 임포트하고 idle_hq.tres의 AtlasTexture 영역을 같은 비율로 맞춘다
  (로비에서 520px 높이로 그려지고 표시 영역은 약 522px: 다른 사도의 512px 대기 프레임보다 여전히 크다).
- 로비 대기 프레임(idle_hq, avatar_*/idle)은 거의 원래 크기로만 그려지므로 밉맵을 끈다 (밉맵은 용량을 약 1/3 늘린다).
- 제한이 없는 큰 그림은 최대 1280px(배경·컷인 크기)로 묶는다. 처치 컷인 포즈(attack/hit)는 1024px 이상을 유지한다.
- 이미 손실 압축이고 품질이 0.85 이하인 텍스처, VRAM 압축 텍스처(3D)는 건드리지 않는다.

다시 실행해도 결과가 같다. 실행 뒤 `godot --headless --path . --import`로 다시 임포트한다.
"""
import fnmatch
import glob
import os
import re
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
QUALITY = 0.85
ICON_LIMIT = 256
ICON_DIRS = [
    "content_trickcal/illustrations/augments",
    "content_trickcal/illustrations/pawns",
    "content_trickcal/illustrations/dice",
    "content_trickcal/illustrations/laws",
]
IDLE_HQ_DIR = "content_trickcal/avatars/avatar_01/idle_hq"
IDLE_HQ_LIMIT = 640
IDLE_HQ_SOURCE = 1536
IDLE_HQ_SOURCE_REGION = (88.0, 140.0, 1373.0, 1253.0)  # README: 1536px 원본 좌표의 공통 실루엣 영역 (x, y, 너비, 높이)
BIG_LIMIT = 1280
SMALL_KEEP = 128


def excluded(path: str, patterns: list) -> bool:
    return any(fnmatch.fnmatch(path, pattern) for pattern in patterns)


def set_option(text: str, key: str, value: str) -> str:
    pattern = re.compile(r"^%s=.*$" % re.escape(key), re.M)
    if pattern.search(text):
        return pattern.sub("%s=%s" % (key, value), text, count=1)
    return text.replace("[params]\n", "[params]\n\n%s=%s\n" % (key, value), 1)


def main() -> int:
    os.chdir(ROOT)
    presets = open("export_presets.cfg", encoding="utf-8").read()
    patterns = [p.strip() for p in re.search(r'^exclude_filter="(.*)"', presets, re.M).group(1).split(",")]
    changed = 0
    for imp in glob.glob("**/*.import", recursive=True):
        if imp.startswith((".godot", "tests", "docs", "build")):
            continue
        source = imp[: -len(".import")]
        if not os.path.exists(source) or excluded(source, patterns):
            continue
        text = open(imp, encoding="utf-8").read()
        if 'importer="texture"' not in text:
            continue
        mode = int(re.search(r"^compress/mode=(\d)", text, re.M).group(1))
        quality = float(re.search(r"^compress/lossy_quality=([\d.]+)", text, re.M).group(1))
        limit = int(re.search(r"^process/size_limit=(\d+)", text, re.M).group(1))
        try:
            width, height = Image.open(source).size
        except Exception:
            continue
        biggest = max(width, height)
        folder = os.path.dirname(source)
        new_mode, new_quality, new_limit = mode, quality, limit
        if mode not in (0, 1):
            continue  # VRAM 압축 등은 그대로
        if biggest <= SMALL_KEEP:
            continue
        if mode == 0 or quality > QUALITY:
            new_mode, new_quality = 1, QUALITY
        if folder == IDLE_HQ_DIR:
            new_limit = IDLE_HQ_LIMIT
        elif any(folder == d or folder.startswith(d + "/") for d in ICON_DIRS):
            new_limit = ICON_LIMIT if limit == 0 else min(limit, ICON_LIMIT)
        elif biggest > BIG_LIMIT and (limit == 0 or limit > BIG_LIMIT):
            new_limit = BIG_LIMIT
        mipmaps = re.search(r"^mipmaps/generate=(\w+)", text, re.M)
        old_mip = mipmaps.group(1) if mipmaps else "false"
        new_mip = old_mip
        if folder == IDLE_HQ_DIR or re.fullmatch(r"content_trickcal/avatars/avatar_\d+/idle", folder):
            new_mip = "false"
        if (new_mode, new_quality, new_limit, new_mip) == (mode, quality, limit, old_mip):
            continue
        text = set_option(text, "mipmaps/generate", new_mip)
        text = set_option(text, "compress/mode", str(new_mode))
        text = set_option(text, "compress/lossy_quality", repr(new_quality))
        text = set_option(text, "process/size_limit", str(new_limit))
        open(imp, "w", encoding="utf-8").write(text)
        changed += 1
    # idle_hq.tres: 임포트 크기가 바뀌었으니 AtlasTexture 영역도 같은 비율로
    tres = "content_trickcal/avatars/avatar_01/idle_hq.tres"
    if os.path.exists(tres):
        scale = IDLE_HQ_LIMIT / IDLE_HQ_SOURCE
        x, y, w, h = (v * scale for v in IDLE_HQ_SOURCE_REGION)
        region = "region = Rect2(%g, %g, %g, %g)" % (x, y, w, h)
        body = open(tres, encoding="utf-8").read()
        body = re.sub(r"^region = Rect2\([^)]*\)$", region, body, flags=re.M)
        open(tres, "w", encoding="utf-8").write(body)
    print("changed imports:", changed)
    return 0


if __name__ == "__main__":
    sys.exit(main())
