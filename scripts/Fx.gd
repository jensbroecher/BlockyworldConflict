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


static func explode(tree: SceneTree, pos: Vector3, radius: float = 6.0) -> void:
	if tree == null or tree.current_scene == null:
		return
	var root := Node3D.new()
	root.global_position = pos + Vector3(0, 0.3, 0)
	tree.current_scene.add_child(root)
	var fire := CSGSphere3D.new()
	fire.radius = 0.45
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.55, 0.12, 0.95)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.45, 0.05)
	fm.emission_energy_multiplier = 4.0
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire.material = fm
	root.add_child(fire)
	var core := CSGSphere3D.new()
	core.radius = 0.22
	var cm := fm.duplicate() as StandardMaterial3D
	cm.albedo_color = Color(1.0, 0.92, 0.45, 0.95)
	cm.emission = Color(1.0, 0.9, 0.4)
	core.material = cm
	root.add_child(core)
	var smoke := CSGSphere3D.new()
	smoke.radius = 0.5
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(0.18, 0.18, 0.16, 0.55)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke.material = sm
	root.add_child(smoke)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 6.0
	light.omni_range = 14.0
	root.add_child(light)
	var bits := GPUParticles3D.new()
	bits.amount = 18
	bits.lifetime = 0.45
	bits.one_shot = true
	bits.explosiveness = 1.0
	bits.emitting = true
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 80.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 11.0
	pm.gravity = Vector3(0, -6, 0)
	pm.scale_min = 0.15
	pm.scale_max = 0.4
	pm.color = Color(1.0, 0.4, 0.1)
	bits.process_material = pm
	var bm := SphereMesh.new()
	bm.radius = 0.5
	bm.height = 1.0
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.albedo_color = Color(1.0, 0.5, 0.12)
	bmat.emission_enabled = true
	bmat.emission = Color(1.0, 0.45, 0.1)
	bm.material = bmat
	bits.draw_pass_1 = bm
	root.add_child(bits)
	var r := maxf(radius * 0.35, 2.2)
	var tw := tree.create_tween()
	tw.tween_property(fire, "radius", r, 0.22)
	tw.parallel().tween_property(core, "radius", r * 0.45, 0.18)
	tw.parallel().tween_property(smoke, "radius", r * 1.35, 0.45)
	tw.parallel().tween_property(fm, "albedo_color:a", 0.0, 0.28)
	tw.parallel().tween_property(cm, "albedo_color:a", 0.0, 0.22)
	tw.parallel().tween_property(sm, "albedo_color:a", 0.0, 0.5)
	tw.parallel().tween_property(light, "light_energy", 0.0, 0.28)
	tw.tween_callback(root.queue_free)


static func collapse_smoke(tree: SceneTree, pos: Vector3, height: float) -> void:
	if tree == null or tree.current_scene == null:
		return
	var root := Node3D.new()
	root.global_position = pos + Vector3(0, height * 0.35, 0)
	tree.current_scene.add_child(root)
	var p := GPUParticles3D.new()
	p.amount = 36
	p.lifetime = 1.3
	p.one_shot = true
	p.explosiveness = 0.65
	p.emitting = true
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 50.0
	mat.initial_velocity_min = 1.5
	mat.initial_velocity_max = 5.5
	mat.gravity = Vector3(0, 1.4, 0)
	mat.scale_min = 0.6
	mat.scale_max = 1.6
	mat.color = Color(0.28, 0.26, 0.22, 0.7)
	p.process_material = mat
	var mesh := SphereMesh.new()
	mesh.radius = 0.7
	mesh.height = 1.4
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(0.3, 0.28, 0.24, 0.55)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = sm
	p.draw_pass_1 = mesh
	root.add_child(p)
	var dust := CSGSphere3D.new()
	dust.radius = 0.8
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_color = Color(0.32, 0.3, 0.26, 0.5)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust.material = dm
	root.add_child(dust)
	var tw := tree.create_tween()
	tw.tween_property(dust, "radius", 3.2, 0.9)
	tw.parallel().tween_property(dm, "albedo_color:a", 0.0, 1.1)
	tw.tween_interval(0.4)
	tw.tween_callback(root.queue_free)


static func crush_puff(tree: SceneTree, pos: Vector3) -> void:
	burst(tree, pos, Color(0.45, 0.28, 0.18))


static func spawn_debris(tree: SceneTree, pos: Vector3, color: Color, count: int, force: float = 10.0) -> void:
	if tree == null or tree.current_scene == null:
		return
	for _i in count:
		var rb := RigidBody3D.new()
		rb.collision_layer = 0
		rb.collision_mask = 1
		rb.mass = 0.35
		rb.position = pos + Vector3(randf_range(-0.6, 0.6), randf_range(0.4, 1.4), randf_range(-0.6, 0.6))
		var sz := Vector3(randf_range(0.18, 0.55), randf_range(0.14, 0.4), randf_range(0.18, 0.5))
		var col := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = sz
		col.shape = sh
		rb.add_child(col)
		var vis := CSGBox3D.new()
		vis.size = sz
		vis.material = UnitVisuals.mat(color, 0.15, 0.6)
		rb.add_child(vis)
		rb.linear_velocity = Vector3(
			randf_range(-force, force),
			randf_range(force * 0.55, force * 1.25),
			randf_range(-force, force)
		)
		rb.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		tree.current_scene.add_child(rb)
		tree.create_timer(randf_range(2.2, 3.4)).timeout.connect(rb.queue_free)


static func fire_column(tree: SceneTree, pos: Vector3) -> void:
	if tree == null or tree.current_scene == null:
		return
	var n := Node3D.new()
	n.global_position = pos + Vector3(0, 0.2, 0)
	tree.current_scene.add_child(n)
	var p := GPUParticles3D.new()
	p.amount = 28
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 0.4
	p.emitting = true
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 18.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 6.0
	mat.gravity = Vector3(0, 2.5, 0)
	mat.scale_min = 0.25
	mat.scale_max = 0.7
	mat.color = Color(1.0, 0.4, 0.08, 0.85)
	p.process_material = mat
	var mesh := SphereMesh.new()
	mesh.radius = 0.45
	mesh.height = 0.9
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(1.0, 0.45, 0.1, 0.8)
	sm.emission_enabled = true
	sm.emission = Color(1.0, 0.4, 0.05)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = sm
	p.draw_pass_1 = mesh
	n.add_child(p)
	tree.create_timer(1.2).timeout.connect(n.queue_free)


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
