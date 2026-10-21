# File: res://core_engine/commands/skill_effect_command.gd
# Class: class_name SkillEffectCommand
# Role: 굴림을 대신하지 않는 즉시 필살기의 효과 - 코끼리 지진(설치물 파괴) / 용왕·용마 베기(적 처치) / 지뢰 매설. 실행 전 상태를 보관해 되감기(ACT_05)를 따른다
class_name SkillEffectCommand
extends GameCommand

var pawn_id: int = -1
var skill: StringName = &""
var tiles: Array[int] = []
## 실행 결과: 파괴한 설치물 {tile, attachment_id} / 처치한 말 ID.
var destroyed: Array[Dictionary] = []
var victims: Array[int] = []


func _init(acting_player: int = -1, skill_pawn_id: int = -1, skill_id: StringName = &"", target_tiles: Array[int] = []) -> void:
	super()
	sender_id = acting_player
	pawn_id = skill_pawn_id
	skill = skill_id
	tiles = target_tiles
	command_name = "SkillEffect"


func can_execute(_ctx: RuleContext) -> bool:
	if state == null:
		return false
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	return pawn != null and not pawn.is_finished


func _run() -> void:
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	pawn.skill_used = true
	match skill:
		&"quake":
			for tile: int in tiles:
				var node: TileNode = state.board.get_tile(tile)
				for attachment: TileAttachment in node.attachments.duplicate():
					destroyed.append({"tile": tile, "attachment_id": attachment.attachment_id})
					node.remove_attachment(attachment)
		&"slash", &"horse":
			for tile: int in tiles:
				for enemy: PlayerPawn in state.leaders_at(tile):
					if enemy.owner_id == pawn.owner_id or not enemy.has_left_start:
						continue
					if state.break_shield(enemy):
						continue
					for member: PlayerPawn in enemy.stack_members():
						victims.append(member.entity_id)
					state.pawn_captured.emit(pawn.entity_id, enemy.entity_id)
					state.send_to_start(enemy, pawn.owner_id)
		&"plant_mine":
			var mine := TrapMine.new(pawn.owner_id)
			mine.is_hidden_trap = false  # 필살기 지뢰는 모두가 보는 앞에서 묻는다: 칸 위에 지뢰 모형으로 보인다 (카드 지뢰는 숨은 함정)
			state.place_attachment(pawn.current_tile_idx, mine)
		&"hotel":
			# 미니카 [호텔 건설]: 같은 칸의 내 호텔은 새것으로 바꾼다
			var node: TileNode = state.board.get_tile(pawn.current_tile_idx)
			for attachment: TileAttachment in node.attachments.duplicate():
				if attachment.attachment_id == "HOTEL" and attachment.owner_id == pawn.owner_id:
					node.remove_attachment(attachment)
			state.place_attachment(pawn.current_tile_idx, Hotel.new(pawn.owner_id))
