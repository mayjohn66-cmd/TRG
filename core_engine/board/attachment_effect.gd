# File: res://core_engine/board/attachment_effect.gd
# Class: class_name AttachmentEffect
# Role: 타일 설치물이 기물에 발동한 결과(이동 중단·출발선 복귀·설치물 소모·컷신 요청)를 담는 값 객체
class_name AttachmentEffect
extends RefCounted

var stop_move: bool = false
var send_to_start: bool = false
var consume: bool = false
var cutscene_id: StringName = &""
var attachment_id: StringName = &""
var owner_id: int = -1
