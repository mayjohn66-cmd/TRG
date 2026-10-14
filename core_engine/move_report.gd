# File: res://core_engine/move_report.gd
# Class: class_name MoveReport
# Role: 한 번의 이동(MOVING_STEP~도착 처리) 결과 보고서. 호스트가 계산해 클라이언트에 브로드캐스트하고 뷰가 연출에 사용한다.
class_name MoveReport
extends RefCounted

var pawn_id: int = -1
## 한 칸씩 밟은 타일 순서 (워프 도착 칸 포함).
var path: Array[int] = []
var canceled: bool = false
var bounced: bool = false
var finished: bool = false
var trapped: bool = false
var stopped_early: bool = false
var warped: bool = false
var captured_pawn_ids: Array[int] = []
var stacked_pawn_ids: Array[int] = []
var extra_turn: bool = false
var drawn_card: StringName = &""
var special_victory: StringName = &""
var attachment_events: Array[Dictionary] = []
var effect_names: Array[String] = []


func merge(other: MoveReport) -> void:
	path.append_array(other.path)
	canceled = canceled or other.canceled
	bounced = bounced or other.bounced
	finished = finished or other.finished
	trapped = trapped or other.trapped
	stopped_early = stopped_early or other.stopped_early
	warped = warped or other.warped
	captured_pawn_ids.append_array(other.captured_pawn_ids)
	stacked_pawn_ids.append_array(other.stacked_pawn_ids)
	extra_turn = extra_turn or other.extra_turn
	if drawn_card == &"":
		drawn_card = other.drawn_card
	if special_victory == &"":
		special_victory = other.special_victory
	attachment_events.append_array(other.attachment_events)
	effect_names.append_array(other.effect_names)


func to_dict() -> Dictionary:
	return {
		"pawn_id": pawn_id,
		"path": path,
		"canceled": canceled,
		"bounced": bounced,
		"finished": finished,
		"trapped": trapped,
		"stopped_early": stopped_early,
		"warped": warped,
		"captured": captured_pawn_ids,
		"stacked": stacked_pawn_ids,
		"extra_turn": extra_turn,
		"drawn_card": drawn_card,
		"special_victory": special_victory,
		"attachment_events": attachment_events,
		"effects": effect_names,
	}
