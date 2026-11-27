## Non-destructive runtime copies. Engine meshoptimizer preserves seams and attributes.
extends SceneTree
var OUTPUT := "res://assets/models/optimized/v4/"
var meshes: Dictionary={}
var materials: Dictionary={}
var textures: Dictionary={}
var mapping: Dictionary={}
var rows: Array[Dictionary]=[]
var failures: Array[String]=[]
var folder: String
var original_vertices:=0
var reduced_vertices:=0
var original_triangles:=0
var reduced_triangles:=0

func _initialize() -> void: run.call_deferred()
func run() -> void:
	folder=OS.get_cmdline_user_args()[0]
	if OS.get_cmdline_user_args().size()>1: OUTPUT=OS.get_cmdline_user_args()[1].trim_suffix("/")+"/"
	if not OUTPUT.begins_with("res://assets/models/optimized/"):
		push_error("Choose a new output folder under assets/models/optimized")
		quit(1)
		return
	if DirAccess.dir_exists_absolute(OUTPUT) and (not DirAccess.get_files_at(OUTPUT).is_empty() or not DirAccess.get_directories_at(OUTPUT).is_empty()):
		push_error("Output already exists; pass a new version folder to preserve the previous models")
		quit(1)
		return
	for child: String in ["meshes","materials","textures"]:
		DirAccess.make_dir_recursive_absolute(OUTPUT.path_join(child))
	var source_list:=folder.path_join("active-models.json")
	if not FileAccess.file_exists(source_list): source_list="res://tools/art/model_optimization_sources.json"
	var file:=FileAccess.open(source_list,FileAccess.READ)
	var sources: Array=JSON.parse_string(file.get_as_text())
	for raw: Variant in sources:
		var source:=str(raw)
		var before_hash:=file_hash(source)
		var resource:=load(source)
		var destination:=OUTPUT+source.trim_prefix("res://assets/models/").get_basename()+".scn"
		var before:=original_triangles
		var after:=reduced_triangles
		var names: Array[String]=[]
		DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
		if resource is PackedScene:
			var node: Node=resource.instantiate()
			optimize_node(node,node,names)
			var packed:=PackedScene.new()
			if packed.pack(node)!=OK or ResourceSaver.save(packed,destination,ResourceSaver.FLAG_COMPRESS)!=OK:
				failures.append("Save failed: "+destination)
			node.free()
		elif resource is Mesh:
			destination=OUTPUT+source.trim_prefix("res://assets/models/").get_basename()+".res"
			var mesh:=optimize_mesh(resource as Mesh)
			ResourceSaver.save(mesh,destination,ResourceSaver.FLAG_COMPRESS)
		else:
			failures.append("Unsupported root "+source)
			continue
		mapping[source]=destination
		if file_hash(source)!=before_hash: failures.append("Source changed "+source)
		var check:=load(destination) as Resource
		if check==null: failures.append("Readback failed "+destination)
		elif check is PackedScene:
			var readback: Node=check.instantiate()
			var actual: Array[String]=[]
			verify_node(readback,actual)
			if actual!=names: failures.append("Node hierarchy changed "+source)
			readback.free()
		rows.append({"source":source,"output":destination,"source_bytes":FileAccess.get_file_as_bytes(source).size(),"scene_bytes":FileAccess.get_file_as_bytes(destination).size(),"new_mesh_triangles_before":original_triangles-before,"new_mesh_triangles_after":reduced_triangles-after,"node_count":names.size(),"source_preserved":true,"saved_readback":check!=null})
		print("LOWPOLY ",source.get_file()," ",original_triangles-before," -> ",reduced_triangles-after)
		await process_frame
	var report: Dictionary={"models":rows,"mapping":mapping,"unique_meshes":meshes.size(),"unique_materials":materials.size(),"unique_textures":textures.size(),"triangles_before":original_triangles,"triangles_after":reduced_triangles,"vertices_before":original_vertices,"vertices_after":reduced_vertices,"failures":failures}
	file=FileAccess.open(folder.path_join("optimization-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file=FileAccess.open(OUTPUT+"model-map.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(mapping,"  "))
	print("LOWPOLY_BUILD_DONE models=",rows.size()," triangles=",original_triangles," -> ",reduced_triangles," failures=",failures.size())
	for failure: String in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func optimize_node(node: Node,owner: Node,names: Array[String]) -> void:
	names.append(str(owner.get_path_to(node)))
	node.scene_file_path=""
	if node!=owner: node.owner=owner
	if node is MeshInstance3D and node.mesh!=null:
		node.mesh=optimize_mesh(node.mesh)
		if node.material_override!=null: node.material_override=optimize_material(node.material_override)
		for i: int in node.get_surface_override_material_count():
			var material: Material=node.get_surface_override_material(i)
			if material!=null: node.set_surface_override_material(i,optimize_material(material))
	for child: Node in node.get_children(): optimize_node(child,owner,names)

func optimize_material(source: Material) -> Material:
	var key:=source.get_rid().get_id()
	if materials.has(key): return materials[key]
	var result:=source.duplicate() as Material
	materials[key]=result
	if result is BaseMaterial3D:
		for slot: int in BaseMaterial3D.TEXTURE_MAX:
			var texture:=result.get_texture(slot) as Texture2D
			if texture!=null: result.set_texture(slot,optimize_texture(texture,slot==BaseMaterial3D.TEXTURE_NORMAL))
	if result.next_pass!=null: result.next_pass=optimize_material(result.next_pass)
	var path:=OUTPUT+"materials/material_%04d.res" % materials.size()
	ResourceSaver.save(result,path,ResourceSaver.FLAG_COMPRESS|ResourceSaver.FLAG_CHANGE_PATH)
	result.take_over_path(path)
	return result

func optimize_texture(source: Texture2D,normal_map: bool) -> Texture2D:
	var key:=str(source.get_rid().get_id())+":"+str(normal_map)
	if textures.has(key): return textures[key]
	var pixels:=source.get_image()
	if pixels==null: return source
	if pixels.is_compressed(): pixels.decompress()
	if max(pixels.get_width(),pixels.get_height())>512:
		var scale: float=512.0/max(pixels.get_width(),pixels.get_height())
		pixels.resize(maxi(1,roundi(pixels.get_width()*scale)),maxi(1,roundi(pixels.get_height()*scale)),Image.INTERPOLATE_LANCZOS)
	pixels.generate_mipmaps()
	var result:=PortableCompressedTexture2D.new()
	result.set_keep_compressed_buffer(true)
	result.create_from_image(pixels,PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS if normal_map else PortableCompressedTexture2D.COMPRESSION_MODE_LOSSY,normal_map,.86)
	textures[key]=result
	var path:=OUTPUT+"textures/texture_%03d.res" % textures.size()
	ResourceSaver.save(result,path,ResourceSaver.FLAG_COMPRESS|ResourceSaver.FLAG_CHANGE_PATH)
	result.take_over_path(path)
	return result

func optimize_mesh(source: Mesh) -> Mesh:
	var key:=source.get_rid().get_id()
	if meshes.has(key): return meshes[key]
	# Blend shapes are retained intact; these models are animated through nodes.
	if source is ArrayMesh and source.get_blend_shape_count()>0: return source
	var importer:=ImporterMesh.new()
	var prepared: Array[Array]=[]
	for surface: int in source.get_surface_count():
		var arrays:=source.surface_get_arrays(surface)
		var count: int=arrays[Mesh.ARRAY_VERTEX].size()
		original_vertices+=count
		original_triangles+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty() else count)/3
		if arrays[Mesh.ARRAY_INDEX]==null or arrays[Mesh.ARRAY_INDEX].is_empty():
			var welder:=SurfaceTool.new()
			welder.create_from(source,surface)
			welder.index()
			arrays=welder.commit_to_arrays()
		prepared.append(arrays)
		importer.add_surface(source.surface_get_primitive_type(surface) if source is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},source.surface_get_material(surface))
	importer.generate_lods(60.0,60.0,[])
	var result:=ArrayMesh.new()
	for surface: int in source.get_surface_count():
		var arrays: Array=prepared[surface]
		var vertex_count: int=arrays[Mesh.ARRAY_VERTEX].size()
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		if indices.is_empty():
			indices.resize(vertex_count)
			for i: int in vertex_count: indices[i]=i
		var selected:=indices
		var original_bounds:=index_bounds(arrays[Mesh.ARRAY_VERTEX],indices)
		if indices.size()>=240:
			# Keep shape-critical seams, UVs and vertex colours. Lowest viable engine LOD.
			var target:=maxi(48,roundi(indices.size()*.12))
			for lod: int in importer.get_surface_lod_count(surface):
				var candidate:=importer.get_surface_lod_indices(surface,lod)
				if candidate.size()<selected.size() and candidate.size()>=target:
					var bounds:=index_bounds(arrays[Mesh.ARRAY_VERTEX],candidate)
					var error:=maxf(original_bounds.position.distance_to(bounds.position),original_bounds.end.distance_to(bounds.end))/maxf(original_bounds.size.length(),.0001)
					if error<=.035: selected=candidate
		var compact:=compact_arrays(arrays,selected)
		result.add_surface_from_arrays(source.surface_get_primitive_type(surface) if source is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES,compact)
		var material:=source.surface_get_material(surface)
		if material!=null: result.surface_set_material(surface,optimize_material(material))
		reduced_vertices+=compact[Mesh.ARRAY_VERTEX].size()
		reduced_triangles+=selected.size()/3
	meshes[key]=result
	var path:=OUTPUT+"meshes/mesh_%04d.res" % meshes.size()
	ResourceSaver.save(result,path,ResourceSaver.FLAG_COMPRESS|ResourceSaver.FLAG_CHANGE_PATH)
	result.take_over_path(path)
	return result

func compact_arrays(arrays: Array,indices: PackedInt32Array) -> Array:
	var order:=PackedInt32Array()
	var remap: Dictionary={}
	var rewritten:=PackedInt32Array()
	rewritten.resize(indices.size())
	for i: int in indices.size():
		var old:=indices[i]
		if not remap.has(old):
			remap[old]=order.size()
			order.append(old)
		rewritten[i]=int(remap[old])
	var count: int=arrays[Mesh.ARRAY_VERTEX].size()
	var result:=arrays.duplicate()
	for channel: int in Mesh.ARRAY_MAX:
		if channel==Mesh.ARRAY_INDEX or arrays[channel]==null: continue
		var data: Variant=arrays[channel]
		if data.size()==0: continue
		var stride: int=data.size()/count
		var compact: Variant=data.duplicate()
		compact.resize(order.size()*stride)
		for i: int in order.size():
			for j: int in stride: compact[i*stride+j]=data[order[i]*stride+j]
		result[channel]=compact
	result[Mesh.ARRAY_INDEX]=rewritten
	return result

func verify_node(node: Node,names: Array[String],owner: Node=null) -> void:
	if owner==null: owner=node
	names.append(str(owner.get_path_to(node)))
	if node is Node3D and not node.transform.is_finite(): failures.append("Nonfinite pose "+str(node.name))
	if node is MeshInstance3D and node.mesh!=null:
		if not node.mesh.get_aabb().size.is_finite(): failures.append("Nonfinite mesh "+str(node.name))
		for surface: int in node.mesh.get_surface_count():
			var arrays: Array=node.mesh.surface_get_arrays(surface)
			for index: int in arrays[Mesh.ARRAY_INDEX]:
				if index<0 or index>=arrays[Mesh.ARRAY_VERTEX].size(): failures.append("Invalid index "+str(node.name));break
	for child: Node in node.get_children(): verify_node(child,names,owner)

func file_hash(path: String) -> String:
	var context:=HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(FileAccess.get_file_as_bytes(path))
	return context.finish().hex_encode()

func index_bounds(vertices: PackedVector3Array,indices: PackedInt32Array) -> AABB:
	var result:=AABB(vertices[indices[0]],Vector3.ZERO)
	for i: int in indices: result=result.expand(vertices[i])
	return result
