class_name TestJudgmentCardArt
extends TestCase


func test_all_fifty_two_poker_cards_keep_their_exact_rank_and_suit() -> void:
	var identities: Dictionary = {}
	for card: int in 52:
		var model: Dictionary = JudgmentCardArt.poker(card)
		check_eq(model.rank, JudgmentCardArt.RANKS[card % 13], "rank matches card ID")
		check_eq(model.suit, card / 13, "suit matches card ID")
		check(JudgmentCardArt.texture(model.art) != null, "all four suit illustrations load")
		check(JudgmentCardArt.texture(model.back) != null, "playing-card back loads")
		identities[str(model.suit) + model.rank] = true
	check_eq(identities.size(), 52, "all 52 rank/suit identities stay distinct")


func test_poker_pip_counts_are_exact_without_overlapping_symbols() -> void:
	for rank: int in range(1, 11):
		var points: Array[Vector2] = JudgmentCardArt.pip_positions(rank)
		check_eq(points.size(), rank, "numbered card uses its actual pip count")
		for i: int in points.size():
			check(Rect2(0, 0, 1, 1).has_point(points[i]), "pip stays inside central field")
			for j: int in range(i + 1, points.size()):
				check(points[i].distance_to(points[j]) > 0.20, "pip centres leave a readable gap")


func test_all_hwatu_months_and_tarot_fates_have_matching_illustrations() -> void:
	var months: Dictionary = {}
	for card: int in 48:
		var model: Dictionary = JudgmentCardArt.hwatu(card)
		check_eq(model.month, card / 4 + 1, "Hwatu month matches exact engine ID")
		check_eq(model.type, ToolHwatu.card_type(card), "gwang/yeol/tti/pi use the engine classification")
		check(JudgmentCardArt.texture(model.art) != null and JudgmentCardArt.texture(model.back) != null, "all Hwatu faces have art and back")
		months[model.art] = true
	check_eq(months.size(), 12, "twelve independent month motifs")
	var fates: Dictionary = {}
	for fate: StringName in ToolTarot.FATES:
		var model: Dictionary = JudgmentCardArt.tarot(fate)
		check(JudgmentCardArt.texture(model.art) != null and JudgmentCardArt.texture(model.back) != null, "each actual fate has matching art and back")
		fates[model.art] = true
	check_eq(fates.size(), 5, "five distinct tarot fate illustrations")
	check_eq(JudgmentCardArt.tarot().art, "", "unselected tarot backs have no hidden front artwork assigned")
	print("JUDGMENT_CARD_ART_COVERAGE 52+48+5/105")
