# ElevenLabs 효과음 생성

이 폴더의 파일:
- `sfx_prompts_en.csv` — 바로 쓸 수 있는 영어 프롬프트 228개. 열: file, section, priority, duration_s, loop, prompt.
- `sfx_prompts_en.md` — 같은 프롬프트를 읽기 쉽게 정리한 것 (프롬프트는 생성기에 그대로 넣으므로 영어).
- `sfx_list_ko.md` — 기존 소리 목록, 쓰이는 곳, 새로 제안한 소리 (한국어).

만드는 법 (환경이 키와 네트워크 허용 목록을 읽도록 새 세션이 필요하다):
1. 환경에 `ELEVENLABS_API_KEY`가 있고 `api.elevenlabs.io`가 허용돼 있어야 한다. `npx -y @elevenlabs/cli@latest onboard check --env-path .env.local`로 확인한다. 키를 채팅에 붙여 넣거나 `.env.local`을 커밋하지 않는다 (git이 무시한다).
2. `python tools/audio/generate_elevenlabs_sfx.py --dry-run`, 그다음 `--priority high`를 실행한다 (스크립트는 환경 변수나 `.env.local`에서 키를 읽고, 표준 라이브러리만 쓴다).
3. `content_trickcal/audio/sfx/<파일>`로 저장한다. 기존 사건과 이름이 같은 파일(예: `hop_01.ogg`)은 코드 수정 없이 옛 소리를 대신한다. 새 이름은 `scenes/sfx.gd`의 EVENTS에 연결하고 `Sfx.play(&"이름")`을 불러야 한다.
4. `high` 우선순위 줄부터 만들어 들어 보고 나머지를 만든다 (생성할 때마다 ElevenLabs 크레딧을 쓴다).
