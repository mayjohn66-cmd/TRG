# File: res://core_engine/board/hotel.gd
# Class: class_name Hotel
# Role: 모노폴리 카의 통행료 호텔 - 기물 이동이 끝난 타일에 내 턴 5번간 유지되며, 상대가 밟아 이동을 멈추면 소모된다
class_name Hotel
extends TileAttachment

const LIFETIME_TURNS: int = 5


func _init(owner: int = -1) -> void:
	attachment_id = "HOTEL"
	owner_id = owner
	is_hidden_trap = false
	duration_turns = LIFETIME_TURNS


func on_step_trigger(victim: BoardEntity, ctx: RuleContext) -> bool:
	var pawn: PlayerPawn = victim as PlayerPawn
	if pawn == null or pawn.owner_id == owner_id:
		return false
	# ⚡ 부스터 발판·폭주 기관차처럼 효과로 날아가는 이동은 지나치는 호텔에 붙잡히지 않는다 (멈춘 칸의 호텔만 통행료를 받는다).
	# 그렇지 않으면 발판 가속 중에 빵집 호텔에 걸려 빵집 위에 멈추고도 카드는 못 받는 손해가 생긴다.
	if ctx.charge_depth > 0 and not bool(ctx.metadata.get("is_landing", true)):
		return false
	ctx.metadata["cutscene_id"] = &"hotel_toll"
	# 통행료를 거두면 호텔은 소모된다 (실행기가 만료된 설치물을 타일에서 제거).
	duration_turns = 0
	return true
