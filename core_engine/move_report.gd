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
var attachment_events: Array[Dictionary] = []
var effect_names: Array[String] = []
## 장기 [포 넘기]로 이동 거리에 +2칸이 붙었는가.
var cannon_bonus: bool = false
## 백돌 무적에 막혀 한 칸 밀려난 이동자.
var pushed_back: bool = false
## 이번 이동의 눈금·경로를 실제로 바꾼 교칙들의 요약 문구 ("LAW_08 결승선 문턱 높이기" 형식).
var law_notes: Array[String] = []
## 업기 선택이 필요한 도착: {"mover": 이동한 말 ID, "others": 합칠 수 있는 아군 대표 말 ID들}. 없으면 빈 Dictionary.
var stack_offer: Dictionary = {}
## 세부 기물 능력 보고: 보너스/제약 문구, 승진한 폰, 들이받힌 말, 증기선이 파괴한 설치물, 강아지가 스쳐서 얻은 카드 수.
var ability_notes: Array[String] = []
var promoted_pawn_ids: Array[int] = []
var destroyed_attachments: Array[Dictionary] = []
var dog_cards: int = 0
## 무인도에서 카드 1장을 내고 탈출했다.
var paid_bail: bool = false
## 지뢰찾기 공병이 적 함정을 해체하고 받은 카드 수.
var defused_cards: int = 0
## 🏃 말 밟고 점프하기로 늘어난 칸수와 ⚡ 부스터 발판이 터진 타일들.
var leapfrog_bonus: int = 0
var dash_tiles: Array[int] = []
## 🔥 리벤지 부스터로 더해진 칸 수 (0이면 발동하지 않음)와 그때의 최종 계획 칸 수.
var revenge_bonus: int = 0
var revenge_total: int = 0


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
	attachment_events.append_array(other.attachment_events)
	effect_names.append_array(other.effect_names)
	cannon_bonus = cannon_bonus or other.cannon_bonus
	pushed_back = pushed_back or other.pushed_back
	law_notes.append_array(other.law_notes)
	if stack_offer.is_empty():
		stack_offer = other.stack_offer
	ability_notes.append_array(other.ability_notes)
	promoted_pawn_ids.append_array(other.promoted_pawn_ids)
	destroyed_attachments.append_array(other.destroyed_attachments)
	dog_cards += other.dog_cards
	defused_cards += other.defused_cards
	paid_bail = paid_bail or other.paid_bail
	leapfrog_bonus += other.leapfrog_bonus
	dash_tiles.append_array(other.dash_tiles)


func to_dict() -> Dictionary:
	return {
		"pawn_id": pawn_id,
		"revenge_bonus": revenge_bonus,
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
		"attachment_events": attachment_events,
		"effects": effect_names,
		"cannon_bonus": cannon_bonus,
		"pushed_back": pushed_back,
		"law_notes": law_notes,
		"stack_offer": stack_offer,
		"ability_notes": ability_notes,
		"promoted": promoted_pawn_ids,
		"destroyed": destroyed_attachments,
		"dog_cards": dog_cards,
		"defused_cards": defused_cards,
		"paid_bail": paid_bail,
		"leapfrog_bonus": leapfrog_bonus,
		"dash_tiles": dash_tiles,
	}
