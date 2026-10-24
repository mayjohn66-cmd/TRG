#!/usr/bin/env python3
"""웹 빌드 index.html에 빌드 버전을 새긴다 (캐시 버스팅 + 옛 캐시 청소, web/shell.html의 trg-cache-guard).

__TRG_BUILD_ID__ -> 커밋 7자리 (index.js·엔진 파일·스플래시 그림의 ?v=)
__TRG_VERSION__  -> project.godot의 config/version (예: 0.9.0+abc1234, trg_cached_version 비교 값)

사용: python3 tools/stamp_web_build.py build/web <커밋7자리>
"""
import re
import sys
from pathlib import Path


def project_version(project_file: Path) -> str:
    match = re.search(r'^config/version="([^"]*)"', project_file.read_text(encoding="utf-8"), re.M)
    if not match:
        raise SystemExit("project.godot에 config/version이 없다")
    return match.group(1)


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    web_dir = Path(sys.argv[1])
    build_id = sys.argv[2].strip()
    if not re.fullmatch(r"[0-9a-f]{7,40}", build_id):
        raise SystemExit(f"빌드 id는 커밋 해시여야 한다: {build_id!r}")
    version = project_version(Path(__file__).resolve().parent.parent / "project.godot")
    page = web_dir / "index.html"
    html = page.read_text(encoding="utf-8")
    for token in ("__TRG_BUILD_ID__", "__TRG_VERSION__", 'id="trg-cache-guard"'):
        if token not in html:
            raise SystemExit(f"index.html에 {token}이 없다: web/shell.html의 캐시 가드를 확인")
    html = html.replace("__TRG_BUILD_ID__", build_id).replace("__TRG_VERSION__", version)
    if "__TRG_" in html:
        raise SystemExit("index.html에 채우지 못한 __TRG_ 토큰이 남았다")
    if f'src="index.js?v={build_id}"' not in html:
        raise SystemExit("index.js 주소에 ?v=커밋이 붙지 않았다")
    page.write_text(html, encoding="utf-8")
    print(f"index.html: build {build_id}, version {version}")


if __name__ == "__main__":
    main()
