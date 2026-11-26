# 웹 효과음 무음 수정

## 원인

Godot 4.7.1의 단일 스레드 웹 빌드는 기본적으로 Sample 재생을 사용한다. `Sfx._ensure_buses()`에서 `AudioServer.add_bus()`로 SFX/BGM을 추가하면 엔진 JS 브리지의 append(-1) 처리 때문에 버스 순서가 뒤섞이고 Master의 출력 연결이 끊긴다. 음량 0.8, 음소거 해제, AudioContext running, 실제 오디오 소스 생성 상태여도 최종 출력은 0이었다.

엔진 이슈와 코드: <https://github.com/godotengine/godot/issues/119026>, <https://github.com/godotengine/godot/blob/4.7-stable/platform/web/js/libs/library_godot_audio.js>. `Bus.addAt()`은 -1도 move 대상으로 처리하지만 `Bus.setCount()`는 순서를 바꾸지 않고 뒤에 버스를 추가한다.

## 변경

- `add_bus()` 대신 `set_bus_count(count + 1)`로 새 채널을 뒤에 추가한 다음 기존 이름·Master 전송·음량을 설정한다. 웹의 Sample 재생 방식과 단일 스레드 배포는 유지한다.
- 로비의 UiSkin/HubArt 버튼에도 공통 클릭음을 연결했다. 재스킨·기존 대전 버튼의 중복 연결을 방지한다.
- 시작 메뉴에서 저장된 설정을 읽은 뒤 오디오 풀을 미리 만든다. 첫 클릭에서 풀의 deferred 생성 때문에 소리를 놓치지 않도록 한다.

## 브라우저 회귀 검증

`tests/e2e/build_web_audio_fixture.py`는 **실제 scenes/sfx.gd와 실제 hop_01.ogg**를 복사해 작은 웹 프로젝트를 만든다. GameSession은 Sfx가 읽는 세 가지 음량/음소거 값만 공급하는 대역이다. JS 명령은 이 테스트 프로젝트에만 존재하며 제품 빌드에는 들어가지 않는다.

```text
python tests/e2e/build_web_audio_fixture.py <새 임시 폴더> <web_nothreads_release.zip> <Godot 실행 파일>
node tests/e2e/web_audio.mjs <임시 폴더/build> <playwright 모듈> <Chrome 실행 파일>
```

Chrome Web Audio의 최종 출력에 분석기를 연결해 검사한다. 헤드리스 Godot는 Sfx 재생을 건너뛰므로 기존 단위 테스트만으로 발견할 수 없었던 문제다.

- 수정 전: 파일 OGG / 생성 PCM 모두 피크 **0 / 0**. `--expect-silence`로 동일 현상을 재현했다.
- 수정 후: **0.8977 / 0.1452**. 두 소스 모두 최종 출력까지 전달됐다.
- 음소거 때 0, 해제 후 출력 복구, 낮은 음량과 높은 음량의 차이, 반복 설정 적용 후 출력 유지와 Master/SFX/BGM 순서를 검증했다.
- 기존 메뉴 UI 및 연출 테스트, 전체 단위 테스트도 통과했다. 기존 헤드리스 종료 시 RID/리소스 경고는 남아 있다.
- 전체 게임도 같은 4.7.1 템플릿으로 웹 내보내기 후 Chrome에서 이름 입력 → 놀이터 → 대전 시작까지 실행했다. 첫 버튼 클릭부터 출력 피크 0.1479가 확인됐고 대전 시작 효과음도 출력됐다. 수정 전 실제 배포본의 같은 경로에서는 출력이 0이었다.
