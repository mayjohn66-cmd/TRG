# File: res://core_engine/move_report.gd
# Class: class_name MoveReport
# Role: 한 번의 이동(MOVING_STEP~도착 처리) 결과 보고서. 호스트가 계산해 클라이언트에 브로드캐스트하고 뷰가 연출에 사용한다.
class_name MoveReport
extends RefCounted

var pawn_id: int = -1
## 한 칸씩 밟은 타일 순서 (워프 도착 칸 포함).
var path: Array[int] = []
var canceled: bool = false
var jailed: bool = false
var released: bool = false
var hotel_built: bool = false
var salary_cards: int = 0
var bonus_roll: bool = false
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
## 장기 [포 넘기]로 이동 거리에 +2칸이 붙었는가.
var cannon_bonus: bool = false
## 바둑 [알까기]로 2칸 튕겨 나간 말들 / 포석 무적에 막혀 한 칸 밀려난 이동자 / 장기 2세트 [초나라 포진]으로 구속된 말들.
var knocked_pawn_ids: Array[int] = []
var pushed_back: bool = false
var restrained_pawn_ids: Array[int] = []


func merge(other: MoveReport) -> void:
	path.append_array(other.path)
	canceled = canceled or other.canceled
	jailed = jailed or other.jailed
	released = released or other.released
	hotel_built = hotel_built or other.hotel_built
	salary_cards += other.salary_cards
	bonus_roll = bonus_roll or other.bonus_roll
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
	cannon_bonus = cannon_bonus or other.cannon_bonus
	knocked_pawn_ids.append_array(other.knocked_pawn_ids)
	pushed_back = pushed_back or other.pushed_back
	restrained_pawn_ids.append_array(other.restrained_pawn_ids)


func to_dict() -> Dictionary:
	return {
		"pawn_id": pawn_id,
		"path": path,
		"canceled": canceled,
		"jailed": jailed,
		"released": released,
		"hotel_built": hotel_built,
		"salary_cards": salary_cards,
		"bonus_roll": bonus_roll,
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
		"cannon_bonus": cannon_bonus,
		"knocked": knocked_pawn_ids,
		"pushed_back": pushed_back,
		"restrained": restrained_pawn_ids,
	}
