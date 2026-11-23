# File: res://core_engine/release_gate.gd
# Class: class_name ReleaseGate
# Role: 다음 버전용 내용 잠금. 데이터에 "공개 버전"(since)을 적어 두면 게임 버전(project.godot의 config/version)이 그보다 낮을 때는
#       보드 목록·증강 풀·도감에서 빠진다. 버전을 올리면 따로 손대지 않아도 열린다.
#       테스트는 preview를 켜서 잠긴 내용도 검사한다.
class_name ReleaseGate
extends RefCounted

## 잠긴 내용도 연다 (테스트 실행기·미리보기).
static var preview: bool = false

## 판정 도구별 공개 버전 (여기 없으면 이미 공개).
const TOOL_SINCE: Dictionary = {
	&"DICE_PIRATE": "1.3.0",
	&"DICE_SCRATCH": "1.3.0",
}


## 지금 게임 버전 ("1.2.1+abc1234" 같은 빌드 꼬리표는 뗀다).
static func current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0")).split("+")[0].split("-")[0]


## since 버전이 공개되었는가 (빈 문자열이면 늘 공개).
static func is_open(since: String) -> bool:
	if preview or since.strip_edges() == "":
		return true
	return compare(current_version(), since) >= 0


static func tool_open(tool_id: StringName) -> bool:
	return is_open(str(TOOL_SINCE.get(tool_id, "")))


## 점으로 나눈 버전 비교: a < b면 -1, 같으면 0, 크면 1.
static func compare(a: String, b: String) -> int:
	var left: PackedStringArray = a.split(".")
	var right: PackedStringArray = b.split(".")
	for index: int in maxi(left.size(), right.size()):
		var x: int = int(left[index]) if index < left.size() else 0
		var y: int = int(right[index]) if index < right.size() else 0
		if x != y:
			return -1 if x < y else 1
	return 0
