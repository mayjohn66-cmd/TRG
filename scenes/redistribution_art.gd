## Painted redistribution props. Regions are normalized for import resizing.
extends RefCounted

const STAMP = preload("res://content_trickcal/illustrations/effects/redistribution/stamp.png")
const STAMP_REGION := Rect2(73.0/1983,74.0/793,1836.0/1983,646.0/793)
const CARD_BACK = preload("res://content_trickcal/illustrations/effects/redistribution/card_back.png")
const CARD_BACK_REGION := Rect2(92.0/1058,83.0/1487,873.0/1058,1289.0/1487)
const EXCHANGE = preload("res://content_trickcal/illustrations/effects/redistribution/exchange.png")
const EXCHANGE_REGION := Rect2(110.0/1278,84.0/1230,1067.0/1278,1061.0/1230)

static func region(texture: Texture2D, normalized: Rect2) -> Rect2:
	return Rect2(normalized.position*texture.get_size(),normalized.size*texture.get_size())
