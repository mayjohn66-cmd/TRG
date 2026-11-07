## Each outcome is a composed finale, with its own headline, type and stage action.
extends RefCounted
const FONTS := "res://assets/fonts/victory/"
const THEMES: Dictionary = {
	"LAW_01":{"font":"bangers","headline":"Mochi Reality Shock","lines":"Mochi Reality Shock","ink":"211a20","accent":"d73335","tilt":-0.065},
	"LAW_02":{"font":"pacifico","headline":"SWEET VICTORY","lines":"Sweet Victory","ink":"2d1821","accent":"c27a26","tilt":-0.065},
	"LAW_03":{"font":"bungee","headline":"Unlimited Trap Works","lines":"Unlimited\nTrap Works","ink":"20102d","accent":"a63d78","tilt":-0.055},
	"LAW_04":{"font":"bungee","headline":"JACK POT","lines":"JACK\nPOT","ink":"17131d","accent":"e7b743","tilt":-0.08},
	"LAW_05":{"font":"songmyung","headline":"CIRCLE COMPLETE","lines":"CIRCLE\nCOMPLETE","ink":"211532","accent":"7950c2","tilt":-0.035},
	"LAW_06":{"font":"blackopsone","headline":"Perma Death","lines":"Perma\nDeath","ink":"211d29","accent":"9e4055","tilt":-0.045},
	"LAW_07":{"font":"bungee","headline":"ENDLESS DICE","lines":"ENDLESS\nDICE","ink":"152641","accent":"23bdcb","tilt":-0.055},
	"LAW_08":{"font":"bebasneue","headline":"Attack on Meeple","lines":"Attack on Meeple","ink":"161b23","accent":"bd3035","tilt":-0.04},
	"LAW_09":{"font":"orbitron","headline":"HURRICANE FORCE","lines":"HURRICANE\nFORCE","ink":"241b35","accent":"9767b8","tilt":-0.045,"preview_only":true},
	"FINISH":{"font":"goldman","headline":"RACE OVER","lines":"RACE\nOVER","ink":"17131d","accent":"e33230","tilt":-0.075},
}
const PAPERS: Dictionary = {
	"LAW_01":"eee9df","LAW_02":"fff0cd","LAW_03":"f1e7f5","LAW_04":"0b493b",
	"LAW_05":"eee7f7","LAW_06":"e6dedc","LAW_07":"e6f4e9","LAW_08":"e8e1d4","FINISH":"eee9dd",
	"LAW_09":"f0eaf5",
}
## One headline palette per outcome: bright face, white second line, colored block depth.
const COMIC_TITLES: Dictionary = {
	"FINISH":{"upper":"ffdf49","lower":"ffffff","shadow":"c72835"},
	"LAW_01":{"upper":"fffaf0","lower":"ffffff","shadow":"b9203b"},
	"LAW_02":{"upper":"ffe18a","lower":"ffffff","shadow":"b7631c"},
	"LAW_03":{"upper":"ffda4a","lower":"ffffff","shadow":"9b1b5a"},
	"LAW_04":{"upper":"ffda4a","lower":"ffffff","shadow":"b42036"},
	"LAW_05":{"upper":"b4ffe0","lower":"ffffff","shadow":"7540bb"},
	"LAW_06":{"upper":"f5edf4","lower":"ffffff","shadow":"9b2847"},
	"LAW_07":{"upper":"a1f7ff","lower":"ffffff","shadow":"2367af"},
	"LAW_08":{"upper":"ffe06a","lower":"ffffff","shadow":"b62332"},
	"LAW_09":{"upper":"bdffda","lower":"ffffff","shadow":"a93a7d"},
}
static var _fonts: Dictionary = {}
static func of(id: String) -> Dictionary:
	return THEMES.get(id,{})

static func headline(id: String) -> String:
	return str(of(id).get("lines",""))

static func law_label(id: String) -> String:
	if id=="LAW_09": return "방해령 허리케인 포스!!"
	return LawRegistry.create(id).law_name

static func font_for(id: String, _language: String) -> Font:
	var theme := of(id)
	if theme.is_empty(): return null
	# The poster's display phrase stays English; the winner and win condition localize below it.
	var family := str(theme["font"])
	if not _fonts.has(family): _fonts[family] = load(FONTS+"finale-"+family+".ttf")
	return _fonts[family] as Font
