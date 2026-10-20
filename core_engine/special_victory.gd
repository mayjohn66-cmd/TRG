# File: res://core_engine/special_victory.gd
# Class: class_name SpecialVictory
# Role: 중앙 법전의 특수 승리 교칙 판정 (2단계에서 채운다). 지금은 달성자가 없다
class_name SpecialVictory
extends RefCounted


## 이 플레이어가 지금 법전의 특수 승리 조건 하나를 달성했다면 그 교칙 ID, 아니면 빈 값.
static func achieved_by(_state: GameState, _player_id: int) -> StringName:
	return &""


## 누군가 졸업했을 때 (2단계: 달성한 특수 승리 교칙을 법전에서 지운다).
static func on_graduated(_state: GameState, _player_id: int, _reason: StringName) -> void:
	return
