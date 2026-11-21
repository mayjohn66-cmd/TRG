# File: res://core_engine/tools/tool_darts.gd
# Class: class_name ToolDarts
# Role: 불스아이 다트 보드 (v1.1) - 던진 다트가 어디에 꽂힐지는 완전한 운이다 (2026-11-04: 타이밍 조준을 없애고 호스트 난수로만 정한다). 맞은 칸 숫자(1~6) × 싱글/더블/트리플, 정중앙 불스아이는 10칸 + 한 번 더
# 조준·타이밍 보정은 없다: 굴림 행동에 aim이 실려 와도 쓰지 않고 순수 호스트 RNG로만 정한다 (화면 설명도 "순수한 운"으로 통일)
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
func _init() -> void:
	tool_id = &"DICE_DARTS"
	display_name = "불스아이 다트 보드"


## 던지기: 꽂히는 자리는 판 전체에서 면적에 비례해 무작위다 (바깥 고리가 넓어 더블이 가장 자주 나오고 불스아이는 매우 드물다).
## 조준·타이밍은 없다: 굴림 행동에 aim이 실려 와도 쓰지 않는다 (온라인에서 모두가 같은 호스트 난수로 같은 결과를 본다).
func roll(rng: RandomNumberGenerator) -> RollResult:
	return throw_random(rng)


func throw_random(rng: RandomNumberGenerator) -> RollResult:
	var radius: float = sqrt(rng.randf()) * 0.98
	var angle: float = rng.randf()
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
	return {"steps": number, "number": number, "ring": "싱글", "multiplier": 1, "bull": false}


static func wedge_number(angle: float) -> int:
	return WEDGES[int(floor(fposmod(angle, 1.0) * WEDGES.size())) % WEDGES.size()]


## 결과 한 줄 ("트리플 5 → 15칸", "★불스아이! 10칸 + 한 번 더").
static func hit_text(details: Dictionary, steps: int) -> String:
	if bool(details.get("bull", false)):
		return "★불스아이! %d칸 + 한 번 더" % steps
	return "%s %d → %d칸" % [str(details.get("ring", "싱글")), int(details.get("number", 0)), steps]
