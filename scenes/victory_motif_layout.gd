## Printed motifs extend beyond the frame; they are part of the backdrop, not HUD icons.
extends RefCounted
const STRENGTH: Dictionary={"LAW_01":0.44,"LAW_02":0.48,"LAW_04":0.40,"LAW_05":0.34,"LAW_06":0.40,"LAW_07":0.44,"LAW_08":0.40}
static func opacity(id: String, t: float, start: float, end: float) -> float:
	return lerpf(1.0,float(STRENGTH[id]),smoothstep(start,end,t))
