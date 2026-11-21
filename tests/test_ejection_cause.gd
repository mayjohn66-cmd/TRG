# File: res://tests/test_ejection_cause.gd
# Class: class_name TestEjectionCause
# Role: 설치 함정으로 말이 출발선에 날아갈 때 원인(함정 카드 ID)이 GameState.ejection_causes에 남아, 액션 로그가 "누가 처치"만이 아니라 어떤 함정 때문인지 밝힐 수 있는지 검증 (제보: 지뢰에 걸린 말 3개가 함정 설명 없이 컴퓨터 4의 직접 처치로만 보였다)
class_name TestEjectionCause
extends TestCase


func test_mine_blast_notes_the_mine_for_every_victim() -> void:
	var state := GameState.new()
	state.boost_gimmicks = false
	state.setup([1, 2] as Array[int], 777)
	state.place_attachment(15, TrapMine.new(2))
	place(state, 11, 13, [12])  # 1번 플레이어 말: 13번에서 2칸 -> 15번(지뢰)
	place(state, 12, 14, [13])  # 반경 2칸 안에 서 있는 같은 편 말도 함께 날아간다
	var report: MoveReport = move(state, 11, 2)
	check(report != null, "이동이 끝난다")
	check_eq(state.ejection_causes.get(11, &""), &"TRP_03", "밟은 말의 원인은 지뢰")
	check_eq(state.ejection_causes.get(12, &""), &"TRP_03", "폭발에 휩쓸린 말의 원인도 지뢰")
	check_eq(state.take_ejection_cause(11), &"TRP_03", "꺼내면 원인을 돌려준다")
	check_eq(state.take_ejection_cause(11), &"", "한 번 꺼내면 지워진다")


func test_plain_capture_has_no_cause() -> void:
	var state := GameState.new()
	state.boost_gimmicks = false
	state.setup([1, 2] as Array[int], 778)
	place(state, 11, 5, [4])
	place(state, 21, 8, [7])
	move(state, 11, 3)  # 5 -> 8 직접 잡기
	check(state.ejection_causes.is_empty(), "직접 잡기에는 함정 원인이 없다")
