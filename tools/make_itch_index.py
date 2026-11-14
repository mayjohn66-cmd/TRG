#!/usr/bin/env python3
"""itch.io용 index.html 손질 (배포본 build/web은 건드리지 않고, 복사본 build/itch/index.html에만 적용한다).

- Vercel 방문자 집계(window.va 스크립트 + /_vercel/insights/script.js)를 뺀다: itch.io에서는 404 콘솔 오류만 낸다.
- 링크 미리보기용 og:/twitter: 메타를 뺀다: itch 페이지가 자기 미리보기를 따로 가지며, 게임은 iframe 안에서 열려 쓸모가 없다.
사용: python3 tools/make_itch_index.py build/itch/index.html
"""
import re
import sys
from pathlib import Path


def convert(html: str) -> str:
    html = re.sub(r"[ \t]*<!-- Vercel Web Analytics:.*?-->\n?", "", html, flags=re.S)
    html = re.sub(r"[ \t]*<script>\s*window\.va\s*=.*?</script>\n?", "", html, flags=re.S)
    html = re.sub(r"[ \t]*<script[^>]*src=\"/_vercel/insights/script\.js\"[^>]*></script>\n?", "", html)
    html = re.sub(r"[ \t]*<meta (?:property=\"og:[^\"]*\"|name=\"twitter:[^\"]*\")[^>]*>\n?", "", html)
    return html


def main() -> None:
    path = Path(sys.argv[1])
    original = path.read_text(encoding="utf-8")
    converted = convert(original)
    if "_vercel" in converted or "window.va" in converted or "og:image" in converted or "twitter:image" in converted:
        raise SystemExit("itch index.html still contains Vercel analytics or share tags")
    path.write_text(converted, encoding="utf-8")
    print(f"itch index.html: {len(original)} -> {len(converted)} bytes")


if __name__ == "__main__":
    main()
