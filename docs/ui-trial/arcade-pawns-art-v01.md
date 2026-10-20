# 아케이드 기물 이미지 v0.1

킹 체커·루도 복수자·8번 공·스타 카트·지뢰찾기 공병을 각각 native `image_gen.imagegen`으로 생성했다. 이미지 모델 ID는 도구에 공개되지 않는다. 기존 나이트·미니카는 스타일 참고로만 사용했고, 기물마다 독립 호출했다. 수정 재생성은 필요하지 않았다.

원본 5장은 1254×1254 RGBA 투명 PNG다. 원본을 픽셀 수정 없이 프로젝트의 동일한 SubType 파일명으로 복사하고 SHA-256을 대조했다. 런타임은 기존 256px 무손실·밉맵 임포트를 사용한다. 새 그림의 윤곽·알파·여백·48px 이하 판독성과 실제 보드/선택 슬롯/4색 받침대/원형 메달을 검토했다. 루도 불꽃과 카트 바퀴는 10%보다 여백이 적지만 경계에 닿거나 잘리지 않아 채택했다.

## 저장 위치

- `CHECKERS_KING`: [CHECKERS_KING.png](../../content_trickcal/illustrations/pawns/CHECKERS_KING.png)
- `LUDO_AVENGER`: [LUDO_AVENGER.png](../../content_trickcal/illustrations/pawns/LUDO_AVENGER.png)
- `POOL_8BALL`: [POOL_8BALL.png](../../content_trickcal/illustrations/pawns/POOL_8BALL.png)
- `KART_STAR`: [KART_STAR.png](../../content_trickcal/illustrations/pawns/KART_STAR.png)
- `MINESWEEPER_FLAG`: [MINESWEEPER_FLAG.png](../../content_trickcal/illustrations/pawns/MINESWEEPER_FLAG.png)

## 산출물

- `source/`: 채택 원본 5장.
- `prompts.json`: 각 기물의 최종 생성 프롬프트 전문.
- `manifest.json`: 도구가 반환한 원본 경로, 크기·알파·SHA-256, 프로젝트 경로와 검토 결과.
- `previous/`, `previous-imports/`: 교체 전 임시 그림과 임포트 설정.
- `gallery.png`: 큰 이미지, 실제 보드 크기의 4색 기물, 증강 메달 비교.
- `board.png`, `selection.png`: 실제 MainBoard 화면 캡처.
- `validation.json`: 검사 결과.

## 연결과 검사

보드·프로필·기물 선택은 PawnArt/PawnToken, 증강은 AugmentArt의 기존 세부 ID 자동 매핑으로 같은 PNG를 사용한다. 별도 코드 도형을 추가하지 않았다. 전체 그림 커버리지 32/32, 단위 검사 480개/591212 assertions 실패 0, UI_FX_OK, native ARCADE_ART_OK를 확인했다. 기존 WebRTC/종료 리소스 정리 경고는 남아 있다.

신규 아케이드 등록을 실제 작업 폴더에서 사용하기 위해 원격 88e2b45까지 fast-forward한 뒤 기존 야추·블랙잭·핀볼 작업을 복원했다. 원본 소스·이미지 내용은 보존했고 두 테스트 파일은 자동 병합했다. 문서 캡처 임포트 2개는 원격 UID를 유지했다. 복구용 stash 7289ac5e153a40864f578bc301d21420a67bea2d는 삭제하지 않았다. 세부 기록은 sync-recovery.json에 있다.

웹 배포·푸시는 수행하지 않았다. 앞서 검토에서 확인한 규칙 관련 3개 문제는 이 이미지 작업에서 수정하지 않았다.
