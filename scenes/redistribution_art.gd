## Painted redistribution props. Regions are normalized for import resizing.
extends RefCounted

const STAMP = preload("res://content_trickcal/illustrations/effects/redistribution/stamp.png")
const STAMP_REGION := Rect2(73.0/1983,74.0/793,1836.0/1983,646.0/793)
const CARD_BACK = preload("res://content_trickcal/illustrations/effects/redistribution/card_back.png")
const CARD_BACK_REGION := Rect2(92.0/1058,83.0/1487,873.0/1058,1289.0/1487)
const EXCHANGE = preload("res://content_trickcal/illustrations/effects/redistribution/exchange.png")
const EXCHANGE_REGION := Rect2(110.0/1278,84.0/1230,1067.0/1278,1061.0/1230)

const STAMP_EN = preload("res://content_trickcal/illustrations/effects/redistribution/stamp_en.png")
const STAMP_EN_REGION := Rect2(22.0/1983,116.0/793,1950.0/1983,567.0/793)
const STAMP_JA = preload("res://content_trickcal/illustrations/effects/redistribution/stamp_ja.png")
const STAMP_JA_REGION := Rect2(71.0/1983,72.0/793,1840.0/1983,649.0/793)

static func region(texture: Texture2D, normalized: Rect2) -> Rect2:
	return Rect2(normalized.position*texture.get_size(),normalized.size*texture.get_size())

static func stamp_for_language(language: String = "") -> Dictionary:
	var code := L10n.current_lang if language.is_empty() else language
	match code:
		"en":
			return {"texture":STAMP_EN,"region":STAMP_EN_REGION,"width":330.0}
		"ja":
			return {"texture":STAMP_JA,"region":STAMP_JA_REGION,"width":270.0}
	return {"texture":STAMP,"region":STAMP_REGION,"width":270.0}
