# File: res://core_engine/tools/tool_scratch_lottery.gd
# Class: class_name ToolScratchLottery
# Role: 스크래치 복권 (신규 판정 도구) - 당첨 문양(♠♥◆♣ 중 하나)이 적힌 복권의 칸 3개를 긁는다.
#       당첨 문양과 일치한 칸 수: 3개 12칸 + 한 번 더 / 2개 5칸 / 1개 1칸 / 0개 0칸.
#       일치한 칸 중 하나라도 황금 문양이면 칸수 2배 (꽝은 그대로 0칸). 문양은 포커 카드의 네 문양.
class_name ToolScratchLottery
extends BaseJudgmentTool

## 네 문양 (포커 카드와 같은 순서: 스페이드·하트·다이아·클럽).
const SUITS: Array[String] = ["♠", "♥", "◆", "♣"]  # 포커 카드와 같은 글자 (게임 글꼴에 ♦가 없어 ◆)
const CELLS: int = 3
## 칸마다 당첨 문양이 나올 확률 (%). 43%면 3개 약 8% · 2개 약 32% · 1개 약 42% · 꽝 약 19%.
const MATCH_PERCENT: int = 43
## 당첨 문양 칸이 황금일 확률 (%).
const GOLD_PERCENT: int = 10
## 일치 수 -> 칸수.
const PAYOUT: Array[int] = [0, 1, 5, 12]
const JACKPOT_MATCHES: int = 3


func _init() -> void:
	tool_id = &"DICE_SCRATCH"
	display_name = "스크래치 복권"


func roll(rng: RandomNumberGenerator) -> RollResult:
	var winning: int = rng.randi_range(0, SUITS.size() - 1)
	var cells: Array[int] = []
	var gold: Array[bool] = []
	for _index: int in CELLS:
		if rng.randi_range(1, 100) <= MATCH_PERCENT:
			cells.append(winning)
			gold.append(rng.randi_range(1, 100) <= GOLD_PERCENT)
		else:
			var other: int = rng.randi_range(0, SUITS.size() - 2)
			cells.append(other if other < winning else other + 1)  # 당첨 문양을 뺀 세 문양 중 하나
			gold.append(false)
	return of_cells(winning, cells, gold)


## 당첨 문양·칸 문양·황금 여부로 결과를 만든다 (테스트·연출 공용).
static func of_cells(winning: int, cells: Array[int], gold: Array[bool]) -> RollResult:
	var matches: int = 0
	var golden: bool = false
	for index: int in cells.size():
		if cells[index] == winning:
			matches += 1
			golden = golden or (index < gold.size() and gold[index])
	var base: int = PAYOUT[clampi(matches, 0, PAYOUT.size() - 1)]
	var doubled: bool = golden and base > 0
	var result: RollResult = RollResult.make(&"DICE_SCRATCH", base * 2 if doubled else base, {
		"winning": winning, "cells": cells.duplicate(), "gold": gold.duplicate(), "matches": matches, "base": base, "golden": doubled,
	})
	if matches == JACKPOT_MATCHES:
		result.reroll = true  # 3개 일치: 12칸(황금이면 24칸) + 한 번 더
	return result


static func caption(details: Dictionary, steps: int) -> String:
	var matches: int = int(details.get("matches", 0))
	var golden: String = " ★황금 2배" if bool(details.get("golden", false)) else ""
	match matches:
		3: return "3개 일치! %d칸 + 한 번 더%s" % [steps, golden]
		0: return "꽝! 0칸"
	return "%d개 일치 → %d칸%s" % [matches, steps, golden]
