## One projected plane shared by the board introduction and the printed finale.
extends RefCounted
const INTRO_SECONDS := 2.60
const RISE_AT := 1.24
const FRONT_AT := 1.95
const HANDOFF_SECONDS := 0.65
const FADE_SECONDS := 0.42

static func poster_pose(t: float, view: Vector2, aspect: float) -> Dictionary:
	var move := smoothstep(0.0,HANDOFF_SECONDS,t)
	var width := view.y*lerpf(0.84,1.22,move)
	return {"center":Vector2(0.50,0.46).lerp(Vector2(0.30,0.47),move)*view,
		"extent":Vector2(width,width*aspect),"angle":-0.07*move}

static func pose(t: float, view: Vector2, focus: Vector2, reference: Vector2, aspect: float) -> Dictionary:
	if t>=INTRO_SECONDS: return poster_pose(t-INTRO_SECONDS,view,aspect)
	var rise := smoothstep(RISE_AT,FRONT_AT,t)
	var front := poster_pose(0.0,view,aspect)
	var width := lerpf(minf(view.x*0.53,view.y*0.98),float(front["extent"].x),rise)
	# Orthographic projection of a plane rotating from the board toward the viewer.
	var projection := cos(acos(0.48)*(1.0-rise))
	return {"center":(focus*view/reference).lerp(front["center"],rise),
		"extent":Vector2(width,width*aspect*projection),"angle":0.0}
