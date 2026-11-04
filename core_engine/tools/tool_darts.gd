# File: res://core_engine/tools/tool_darts.gd
# Class: class_name ToolDarts
# Role: 불스아이 다트 보드 (v1.1) - 회전하는 다트판에 타이밍 맞춰 던진다. 맞은 칸 숫자(1~6) × 싱글/더블/트리플, 정중앙 불스아이는 10칸 + 한 번 더. 판 밖으로 빗나가면 숫자만큼만
# 조준(aim)은 굴림 행동에 실려 오고(사람의 클릭 타이밍), 손떨림만 호스트 RNG가 더한다. 조준이 없으면(봇·시간 초과) RNG가 조준한다
class_name ToolDarts
extends BaseJudgmentTool

## 다트판 12조각의 숫자 (12시 방향부터 시계 방향).
const WEDGES: Array[int] = [6, 1, 4, 2, 5, 3, 6, 1, 4, 2, 5, 3]
const BULL_STEPS: int = 10
## 중심에서의 거리(0 = 정중앙, 1 = 판 끝)로 나눈 고리: [바깥 경계, 이름, 배수]. 배수 0 = 불스아이.
const RINGS: Array = [
	[0.08, "불스아이", 0],
	[0.45, "싱글", 1],
	[0.56, "트리플", 3],
	[0.84, "싱글", 1],
	[1.0, "더블", 2],
]
## 손떨림: 조준한 거리·각도에 더하는 최대 흔들림. 클수록 트리플·더블·불스아이를 정확히 노려도 덜 맞는다 (2026-11-04: 0.08/0.02 → 0.18/0.04. 이전에는 트리플·더블 평균이 기본 주사위의 3배 이상이었고 정중앙 조준은 항상 불스아이였다).
const JITTER_RADIUS: float = 0.18
const JITTER_ANGLE: float = 0.04
## 판 가장자리 밖으로 빗나간 거리 한계: 이 안에서 1.0을 넘으면 [빗나감] (숫자 × 1칸). 이전에는 0.99로 눌러 바깥쪽을 노리면 늘 더블이었다.
const MAX_THROW_RADIUS: float = 1.08


func _init() -> void:
	tool_id = &"DICE_DARTS"
	display_name = "불스아이 다트 보드"


## 다음 던지기의 조준 [거리, 각도] (굴림 행동의 aim). 던지면 비운다. 음수면 RNG가 조준한다 (봇·시간 초과).
var pending_aim: Vector2 = Vector2(-1.0, -1.0)


func set_aim(aim: Variant) -> void:
	if aim is Array and (aim as Array).size() >= 2:
		pending_aim = Vector2(clampf(float(aim[0]), 0.0, 1.0), fposmod(float(aim[1]), 1.0))


func roll(rng: RandomNumberGenerator) -> RollResult:
	var aim: Vector2 = pending_aim
	pending_aim = Vector2(-1.0, -1.0)
	return throw_at(rng, aim.x, aim.y)


## aim_radius: 0(정중앙)~1(판 끝), aim_angle: 0~1 (한 바퀴, 12시부터 시계 방향). 음수면 RNG가 정한다.
func throw_at(rng: RandomNumberGenerator, aim_radius: float, aim_angle: float) -> RollResult:
	var radius: float = aim_radius if aim_radius >= 0.0 else sqrt(rng.randf()) * 0.98
	var angle: float = aim_angle if aim_angle >= 0.0 else rng.randf()
	radius = clampf(radius + rng.randf_range(-JITTER_RADIUS, JITTER_RADIUS), 0.0, MAX_THROW_RADIUS)
	angle = fposmod(angle + rng.randf_range(-JITTER_ANGLE, JITTER_ANGLE), 1.0)
	var hit: Dictionary = score(radius, angle)
	var result: RollResult = RollResult.make(tool_id, int(hit["steps"]), {"radius": radius, "angle": angle, "number": hit["number"], "ring": hit["ring"], "multiplier": hit["multiplier"], "bull": hit["bull"]})
	result.reroll = bool(hit["bull"])
	return result


## 맞은 자리 → {steps, number, ring, multiplier, bull}.
static func score(radius: float, angle: float) -> Dictionary:
	var number: int = wedge_number(angle)
	for ring: Array in RINGS:
		if radius <= float(ring[0]):
			var multiplier: int = int(ring[2])
			if multiplier == 0:
				return {"steps": BULL_STEPS, "number": 0, "ring": ring[1], "multiplier": 0, "bull": true}
			return {"steps": number * multiplier, "number": number, "ring": ring[1], "multiplier": multiplier, "bull": false}
	return {"steps": number, "number": number, "ring": "빗나감", "multiplier": 1, "bull": false}  # 판 가장자리 밖: 숫자만큼만


static func wedge_number(angle: float) -> int:
	return WEDGES[int(floor(fposmod(angle, 1.0) * WEDGES.size())) % WEDGES.size()]


## 결과 한 줄 ("트리플 5 → 15칸", "★불스아이! 10칸 + 한 번 더").
static func hit_text(details: Dictionary, steps: int) -> String:
	if bool(details.get("bull", false)):
		return "★불스아이! %d칸 + 한 번 더" % steps
	return "%s %d → %d칸" % [str(details.get("ring", "싱글")), int(details.get("number", 0)), steps]
