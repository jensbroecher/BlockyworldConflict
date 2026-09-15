class_name Projectile
extends Node3D

var velocity: Vector3 = Vector3.ZERO
var damage: float = 10.0
var splash: float = 0.0
var wall_damage: float = 0.0
var building_damage: float = 0.0
var owner_id: int = 0
var kind: int = 0
var life: float = 4.5
var ignore_rids: Array[RID] = []
var is_rocket: bool = false
var is_ballistic: bool = false

var _prev: Vector3
var _gravity: float = 0.0
var _arm: float = 0.12


func setup(from: Vector3, toward: Vector3, p_kind: int, p_owner: int, dmg: float, spd: float, p_splash: float, p_wall: float, p_build: float) -> void:
	kind = p_kind
	owner_id = p_owner
	damage = dmg
	splash = p_splash
	wall_damage = p_wall
	building_damage = p_build
	is_rocket = p_kind == UnitDB.Kind.MLRS or p_kind == UnitDB.Kind.HELICOPTER
	is_ballistic = p_kind == UnitDB.Kind.ARTILLERY
	var aim := toward
	global_position = from
	_prev = from
	if p_kind == UnitDB.Kind.ARTILLERY:
		_gravity = 24.0
		life = 6.0
		_arm = 0.18
		velocity = _ballistic_velocity(from, toward, _gravity)
	elif p_kind == UnitDB.Kind.MLRS:
		var dist := from.distance_to(toward)
		aim.y += clampf(dist * 0.14, 2.5, 16.0)
		_gravity = 16.0
		life = 5.5
		var dir_m := (aim - from).normalized()
		velocity = dir_m * spd
	elif p_kind == UnitDB.Kind.HELICOPTER:
		_gravity = 3.5
		life = 3.5
		var dir_h := (aim - from).normalized()
		velocity = dir_h * spd
	else:
		var dir_s := (aim - from)
		if dir_s.length_squared() < 0.001:
			dir_s = Vector3.FORWARD
		velocity = dir_s.normalized() * spd
	if velocity.length_squared() < 0.001:
		velocity = Vector3.FORWARD * spd
	_face(velocity.normalized())
	global_position = from + velocity.normalized() * 0.9
	_prev = global_position
	if is_rocket:
		_build_rocket()
	else:
		_build_shell()


func _ballistic_velocity(from: Vector3, toward: Vector3, g: float) -> Vector3:
	var flat := Vector3(toward.x - from.x, 0.0, toward.z - from.z)
	var d := flat.length()
	var dy := toward.y - from.y
	var t := clampf(d / 20.0, 1.35, 3.8)
	if d < 0.01:
		return Vector3(0, 18, 0)
	return Vector3(flat.x / t, (dy + 0.5 * g * t * t) / t, flat.z / t)


func _face(dir: Vector3) -> void:
	var up := Vector3.UP
	if absf(dir.dot(up)) > 0.96:
		up = Vector3.RIGHT
	transform.basis = Basis.looking_at(dir, up)


func _build_rocket() -> void:
	var fat := kind == UnitDB.Kind.HELICOPTER
	var radius := 0.16 if fat else 0.11
	var length := 1.35 if fat else 1.55
	var body := CSGCylinder3D.new()
	body.radius = radius
	body.height = length
	body.sides = 8
	body.rotation_degrees.x = 90.0
	body.material = UnitVisuals.mat(Color(0.32, 0.34, 0.28), 0.35, 0.4)
	add_child(body)
	var nose := CSGSphere3D.new()
	nose.radius = radius * 0.95
	nose.position = Vector3(0, 0, -length * 0.5)
	nose.material = UnitVisuals.mat(Color(0.55, 0.18, 0.12), 0.4, 0.35)
	add_child(nose)
	var band := CSGCylinder3D.new()
	band.radius = radius + 0.02
	band.height = 0.18
	band.sides = 8
	band.rotation_degrees.x = 90.0
	band.position.z = length * 0.12
	band.material = UnitVisuals.mat(Color(0.7, 0.55, 0.15), 0.5, 0.35)
	add_child(band)
	for i in 4:
		var fin := CSGBox3D.new()
		fin.size = Vector3(0.06, 0.28 if fat else 0.22, 0.32)
		var a := TAU * 0.25 * i
		fin.position = Vector3(cos(a) * radius, sin(a) * radius, length * 0.38)
		fin.material = UnitVisuals.mat(Color(0.22, 0.22, 0.2), 0.2, 0.5)
		add_child(fin)
	_add_exhaust(Vector3(0, 0, length * 0.52), fat)


func _build_shell() -> void:
	var mesh := CSGSphere3D.new()
	mesh.radius = 0.38 if is_ballistic else 0.22
	var col := Color(1.0, 0.82, 0.28) if is_ballistic else Color(1, 0.75, 0.2)
	mesh.material = UnitVisuals.mat(col, 0.0, 0.3)
	add_child(mesh)
	if is_ballistic:
		var streak := CSGCylinder3D.new()
		streak.radius = 0.08
		streak.height = 1.1
		streak.rotation_degrees.x = 90.0
		streak.position.z = 0.45
		streak.material = UnitVisuals.mat(Color(1.0, 0.55, 0.15), 0.0, 0.25)
		add_child(streak)


func _add_exhaust(local_pos: Vector3, fat: bool) -> void:
	var fire := _particles(
		local_pos,
		40 if fat else 28,
		0.28,
		Color(1.0, 0.55, 0.12, 0.9),
		0.12 if fat else 0.09,
		18.0
	)
	add_child(fire)
	var smoke := _particles(
		local_pos + Vector3(0, 0, 0.12),
		22,
		0.7,
		Color(0.35, 0.35, 0.35, 0.45),
		0.22 if fat else 0.16,
		7.0
	)
	add_child(smoke)


func _particles(local_pos: Vector3, amount: int, lifetime: float, color: Color, scale: float, speed: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.position = local_pos
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = 0.05
	p.local_coords = true
	p.visibility_aabb = AABB(Vector3(-6, -6, -2), Vector3(12, 12, 14))
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 10.0
	mat.initial_velocity_min = speed * 0.55
	mat.initial_velocity_max = speed
	mat.gravity = Vector3(0, 1.2, 0)
	mat.scale_min = scale * 0.6
	mat.scale_max = scale
	mat.color = color
	p.process_material = mat
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = color
	sm.emission_enabled = true
	sm.emission = Color(color.r, color.g, color.b)
	sm.emission_energy_multiplier = 2.4 if color.r > 0.6 else 0.4
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = sm
	p.draw_pass_1 = mesh
	p.emitting = true
	return p


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		_explode(_prev)
		queue_free()
		return
	if _gravity != 0.0:
		velocity.y -= _gravity * delta
	if velocity.length_squared() > 0.01:
		_face(velocity.normalized())
	var motion := velocity * delta
	var to := global_position + motion
	_arm -= delta
	if _arm <= 0.0:
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(_prev, to)
		# Arcing shells ignore the ground until they start coming down.
		if is_ballistic and velocity.y > 0.4:
			q.collision_mask = 2
		else:
			q.collision_mask = 1 | 2 | 8 | 16
		q.exclude = ignore_rids
		var hit := space.intersect_ray(q)
		if hit:
			if GameSession.is_server():
				_impact(hit)
			else:
				_explode(hit.position)
			queue_free()
			return
	global_position = to
	_prev = global_position


func _impact(hit: Dictionary) -> void:
	var pos: Vector3 = hit.position
	_apply_direct(hit.collider, pos)
	if splash > 0.1:
		_splash_at(pos)
	_explode(pos)


func _explode(pos: Vector3) -> void:
	if is_rocket or is_ballistic:
		Fx.explode(get_tree(), pos, splash if splash > 0.1 else 6.0)
	else:
		Fx.burst(get_tree(), pos, GameSession.color_of(owner_id))


func _apply_direct(col: Object, _pos: Vector3) -> void:
	if col is Unit:
		var u := col as Unit
		if u.owner_id == owner_id:
			return
		u.take_damage(damage, owner_id)
	elif col is WallSegment:
		(col as WallSegment).take_damage(wall_damage)
	elif col is Building:
		(col as Building).take_damage(building_damage)


func _splash_at(pos: Vector3) -> void:
	for n in get_tree().get_nodes_in_group("units"):
		var u := n as Unit
		if u == null or u.owner_id == owner_id:
			continue
		var d := u.aim_point().distance_to(pos)
		if d <= splash:
			var fall := 1.0 - d / splash
			u.take_damage(damage * 0.7 * fall, owner_id)
	for n in get_tree().get_nodes_in_group("walls"):
		var w := n as WallSegment
		if w == null:
			continue
		if w.global_position.distance_to(pos) <= splash + 1.8:
			w.take_damage(wall_damage * 0.75)
	for n in get_tree().get_nodes_in_group("buildings"):
		var b := n as Building
		if b == null:
			continue
		if b.global_position.distance_to(pos) <= splash + 2.2:
			b.take_damage(building_damage * 0.7)
