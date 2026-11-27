## Preserve the original Bangers numerals; only 7 gains a matching crossbar.
class_name ResultTypography
extends RefCounted
static var DIGITS: FontFile=preload("res://assets/fonts/TRGComicResultDigits.ttf")
const NORMAL: Font=preload("res://assets/fonts/game_ui_font.tres")
const DISPLAY: Font=preload("res://assets/fonts/result/bangers.ttf")
static var _cache: Dictionary={}

static func font(base: Font = DISPLAY) -> Font:
	DIGITS.allow_system_fallback=false
	var key:=base.get_instance_id()
	if not _cache.has(key):
		var composite:=FontVariation.new()
		composite.base_font=DIGITS
		composite.fallbacks=[base] if base==NORMAL else [base,NORMAL]
		_cache[key]=composite
	return _cache[key]

static func apply(label: Label, base: Font = DISPLAY) -> void:
	label.add_theme_font_override("font",font(base))
