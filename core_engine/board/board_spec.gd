# File: res://core_engine/board/board_spec.gd
# Class: class_name BoardSpec
# Role: 보드 크기와 특수 타일 번호의 단일 출처. 기본은 32칸(한 변 8칸) 사각 순환 트랙이고, apply(24)로 옛 24칸(한 변 6칸) 배치로 바꿀 수 있다 (단위 테스트의 기본 이동 규칙 검증용). 모든 참가자가 같은 값을 써야 하므로 게임 중에는 바꾸지 않는다
class_name BoardSpec
extends RefCounted

const DEFAULT_TILE_COUNT: int = 32

## 총 칸 수와 한 변의 칸 수 (코너 포함하지 않는 변 길이).
static var tile_count: int = 32
static var side: int = 8
## 코너 타일 (0·변·2변·3변).
static var corner_tiles: Array[int] = [0, 8, 16, 24]
## 반환점 코너: 폰·쇼기 승급 기준이자 고스트 NPC의 소환·연행 지점.
static var halfway_tile: int = 16
static var last_tile: int = 31
static var bakery_tiles: Array[int] = [5, 13, 19, 30]
static var portal_tiles: Array[int] = [12, 22]
## 옷장 포탈 일반 워프 (LAW_01 중에는 작동하지 않는다): 두 옷장은 왕복이라 12번을 밟으면 22번으로, 22번을 밟으면 12번으로 간다 / 모노폴리 비행기가 워프하는 곳.
static var portal_warp_targets: Dictionary = {12: 22, 22: 12}
static var plane_warp_targets: Dictionary = {12: 24, 22: 30}
## 점프 코너: 코너 기본 점프대는 삭제되었다 (코너는 코너 전용 함정 슬롯). 하위 호환을 위해 빈 사전으로 남긴다.
static var jump_corner_targets: Dictionary = {}
## 출발선을 뺀 코너: 각행 코너 보너스·비숍 코너 진입·코너 전용 함정 슬롯.
static var bonus_corner_tiles: Array[int] = [8, 16, 24]
## 체스 폰·쇼기 기물이 반환점 이상에 도달하거나 지나가는 순간 승진·승급하는 타일.
static var promotion_tiles: Array[int] = []
## 부스터 발판.
static var dash_tiles: Array[int] = [3, 27]


## 일반 함정을 설치할 수 없는 칸: 코너(출발선 포함)·빵집·옷장·부스터 발판. 코너는 코너 전용 함정 슬롯이다.
static func is_special_tile(index: int) -> bool:
	return corner_tiles.has(index) or bakery_tiles.has(index) or portal_tiles.has(index) or dash_tiles.has(index)


## 칸 수를 24(한 변 6칸) 또는 32(한 변 8칸)로 정한다. 특수 타일 번호도 함께 바뀐다.
static func apply(count: int) -> void:
	tile_count = count
	side = count / 4
	last_tile = count - 1
	if count == 24:
		corner_tiles = [0, 6, 12, 18]
		halfway_tile = 12
		bakery_tiles = [4, 10, 14, 20]
		portal_tiles = [9, 16]
		portal_warp_targets = {9: 16, 16: 20}
		plane_warp_targets = {9: 18, 16: 22}
		jump_corner_targets = {}
		bonus_corner_tiles = [6, 12, 18]
		dash_tiles = [4, 11, 19]
	else:
		corner_tiles = [0, 8, 16, 24]
		halfway_tile = 16
		bakery_tiles = [5, 13, 19, 30]
		portal_tiles = [12, 22]
		portal_warp_targets = {12: 22, 22: 12}
		plane_warp_targets = {12: 24, 22: 30}
		jump_corner_targets = {}
		bonus_corner_tiles = [8, 16, 24]
		dash_tiles = [3, 27]
	promotion_tiles = []
	for index: int in range(halfway_tile, count):
		promotion_tiles.append(index)


## 한 변이 6칸인 옛 보드인가 (타일 그림의 크기 보정에 쓴다).
static func tile_scale() -> float:
	return 6.0 / float(side)


static func _static_init() -> void:
	apply(DEFAULT_TILE_COUNT)
