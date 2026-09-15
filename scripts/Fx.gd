class_name Fx
extends RefCounted


static func burst(tree: SceneTree, pos: Vector3, color: Color) -> void:
	if tree == null or tree.current_scene == null:
		return
	var n := Node3D.new()
	n.global_position = pos + Vector3(0, 0.4, 0)
	var s := CSGSphere3D.new()
	s.radius = 0.35
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, 0.85)
	m.emission_enabled = true
	m.emission = color.lightened(0.3)
	m.emission_energy_multiplier = 2.2
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	s.material = m
	n.add_child(s)
	tree.current_scene.add_child(n)
	var tw := tree.create_tween()
	tw.tween_property(s, "radius", 1.6, 0.22)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.22)
	tw.tween_callback(n.queue_free)


static func tracer(tree: SceneTree, from: Vector3, to: Vector3, color: Color) -> void:
	if tree == null or tree.current_scene == null:
		return
	var n := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	im.surface_begin(Mesh.PRIMITIVE_LINES, m)
	im.surface_add_vertex(from)
	im.surface_add_vertex(to)
	im.surface_end()
	n.mesh = im
	n.material_override = m
	tree.current_scene.add_child(n)
	var tw := tree.create_tween()
	tw.tween_interval(0.08)
	tw.tween_callback(n.queue_free)
