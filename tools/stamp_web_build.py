#!/usr/bin/env python3
"""웹 빌드 index.html에 빌드 버전을 새긴다 (캐시 버스팅 + 옛 캐시 청소, web/shell.html의 trg-cache-guard).

__TRG_BUILD_ID__      -> 커밋 7자리 (스플래시 그림 등 해시 표에 없는 파일의 ?v=)
__TRG_VERSION__       -> project.godot의 config/version (예: 0.9.0+abc1234, trg_cached_version 비교 값)
__TRG_FILE_HASHES__   -> {"index.wasm": "<내용 해시>", "avatars/<id>.pck": ...} (엔진 파일·아바타 묶음의 ?v=)
__TRG_HASH_INDEX_JS__ -> index.js 내용 해시 (script 태그의 ?v=)

내용 해시로 주소를 정하므로, 바뀌지 않은 파일(엔진이 그대로인 index.wasm 37MB, 그대로인 아바타 묶음)은
배포가 바뀌어도 같은 주소라 다시 받지 않는다. 아바타 묶음을 내보낸 뒤에 실행해야 묶음 해시가 들어간다.

사용: python3 tools/stamp_web_build.py build/web <커밋7자리>
"""
import hashlib
import json
import re
import sys
from pathlib import Path


def project_version(project_file: Path) -> str:
    match = re.search(r'^config/version="([^"]*)"', project_file.read_text(encoding="utf-8"), re.M)
    if not match:
        raise SystemExit("project.godot에 config/version이 없다")
    return match.group(1)


HASHED_PATTERNS = ("index.wasm", "index.pck", "*.worklet.js", "avatars/*.pck")


def content_hash(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()[:12]


def file_hashes(web_dir: Path) -> dict:
    hashes = {}
    for pattern in HASHED_PATTERNS:
        for path in sorted(web_dir.glob(pattern)):
            if path.is_file():
                hashes[path.relative_to(web_dir).as_posix()] = content_hash(path)
    if "index.wasm" not in hashes or "index.pck" not in hashes:
        raise SystemExit("index.wasm·index.pck이 없다: 내보내기 뒤에 실행")
    return hashes


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
    for token in ("__TRG_BUILD_ID__", "__TRG_VERSION__", "__TRG_FILE_HASHES__", "__TRG_HASH_INDEX_JS__", 'id="trg-cache-guard"'):
        if token not in html:
            raise SystemExit(f"index.html에 {token}이 없다: web/shell.html의 캐시 가드를 확인")
    hashes = file_hashes(web_dir)
    js_hash = content_hash(web_dir / "index.js")
    # 작은따옴표 JS 문자열 안에 들어간다: 경로·해시에 따옴표·역슬래시가 없음을 확인
    hashes_json = json.dumps(hashes, separators=(",", ":"), sort_keys=True)
    if "'" in hashes_json or "\\" in hashes_json:
        raise SystemExit("해시 표에 따옴표·역슬래시가 들어갔다")
    html = (html.replace("__TRG_BUILD_ID__", build_id).replace("__TRG_VERSION__", version)
            .replace("__TRG_FILE_HASHES__", hashes_json).replace("__TRG_HASH_INDEX_JS__", js_hash))
    if "__TRG_" in html:
        raise SystemExit("index.html에 채우지 못한 __TRG_ 토큰이 남았다")
    if f'src="index.js?v={js_hash}"' not in html:
        raise SystemExit("index.js 주소에 ?v=내용 해시가 붙지 않았다")
    page.write_text(html, encoding="utf-8")
    print(f"index.html: build {build_id}, version {version}, hashed files {len(hashes)}")
    for name, digest in sorted(hashes.items()):
        print(f"  {name} ?v={digest}")


if __name__ == "__main__":
    main()
