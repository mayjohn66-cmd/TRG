## Presentation resources only: preserve geometry attributes and gameplay outcomes.
extends RefCounted

const PARKED_SIZE := Vector2i(32, 32)
const SIZE_META := &"web_3d_active_size"

static func indexed(source: ArrayMesh) -> ArrayMesh:
	var output := ArrayMesh.new()
	for surface: int in source.get_surface_count():
		var tool := SurfaceTool.new()
		tool.create_from(source, surface)
		tool.index()
		tool.commit(output)
		output.surface_set_material(surface, source.surface_get_material(surface))
	return output

## Keep meshes/shaders warm without retaining every full-size color/depth/MSAA target.
## Printed labels/atlas viewports are 2D and must keep their rendered pixels.
static func park(view: Node) -> void:
	for child: Node in view.find_children("*", "SubViewport", true, false):
		var viewport := child as SubViewport
		if not viewport.own_world_3d or viewport.disable_3d: continue
		if not viewport.has_meta(SIZE_META): viewport.set_meta(SIZE_META, viewport.size)
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		viewport.size = PARKED_SIZE

static func restore(view: Node) -> void:
	if not is_instance_valid(view): return
	for child: Node in view.find_children("*", "SubViewport", true, false):
		if child.has_meta(SIZE_META):
			(child as SubViewport).size = child.get_meta(SIZE_META)
			child.remove_meta(SIZE_META)
