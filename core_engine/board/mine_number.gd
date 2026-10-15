# File: res://core_engine/board/mine_number.gd
# Class: class_name MineNumber
# Role: TRP_03 지뢰 양옆에 표시되는 [1] 숫자 칸. 효과는 없고 공개 표시로만 쓰인다
class_name MineNumber
extends TileAttachment


func _init(owner: int = -1) -> void:
	attachment_id = "MINE_NUM"
	owner_id = owner
	is_hidden_trap = false
