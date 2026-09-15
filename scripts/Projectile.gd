class_name Projectile
extends Node3D

var velocity: Vector3 = Vector3.ZERO
var damage: float = 10.0
var splash: float = 0.0
var wall_damage: float = 0.0
var building_damage: float = 0.0
var owner_id: int = 0
var kind: int = 0
var life: float = 3.5
var radius: float = 0.25
var _prev: Vector3


func setup(from: Vector3, toward: Vector3, p_kind: int, p_owner: int, dmg: float, spd: float, p_splash: float, p_wall: float, p_build: float) -> void:
	kind = p_kind
	owner_id = p_owner
	damage = dmg
	splash = p_splash
	wall_damage = p_wall
	building_damage = p_build
	global_position = from
	_prev = from
	var dir := toward - from
	if dir.length_squared() < 0.001:
		dir = Vector3.FORWARD
	velocity = dir.normalized() * spd
	look_at(from + dir, Vector3.UP)
	var mesh := CSGSphere3D.new()
	mesh.radius = 0.22 if p_kind != UnitDB.Kind.MLRS else 0.16
	var col := Color(1, 0.75, 0.2) if p_kind != UnitDB.Kind.MLRS else Color(0.85, 0.35, 0.15)
	mesh.material = UnitVisuals.mat(col, 0.0, 0.3)
	add_child(mesh)


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var motion := velocity * delta
	var to := global_position + motion
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(_prev, to)
	q.collision_mask = 1 | 2 | 8 | 16
	var hit := space.intersect_ray(q)
	if hit:
		if GameSession.is_server():
			_impact(hit)
		else:
			Fx.burst(get_tree(), hit.position, GameSession.color_of(owner_id))
		queue_free()
		return
	global_position = to
	_prev = global_position


func _impact(hit: Dictionary) -> void:
	var pos: Vector3 = hit.position
	var col: Object = hit.collider
	_apply_direct(col, pos)
	if splash > 0.1:
		_splash_at(pos)
	Fx.burst(get_tree(), pos, GameSession.color_of(owner_id))


func _apply_direct(col: Object, pos: Vector3) -> void:
	if col is Unit:
		var u := col as Unit
		if u.owner_id == owner_id:
			return
		u.take_damage(damage, owner_id)
	elif col is WallSegment:
		(col as WallSegment).take_damage(wall_damage)
	elif col is Building:
		(col as Building).take_damage(building_damage)
	else:
		# Ground / unknown: splash still applies.
		pass


func _splash_at(pos: Vector3) -> void:
	for n in get_tree().get_nodes_in_group("units"):
		var u := n as Unit
		if u == null or u.owner_id == owner_id:
			continue
		var d := u.aim_point().distance_to(pos)
		if d <= splash:
			var fall := 1.0 - d / splash
			u.take_damage(damage * 0.55 * fall, owner_id)
	for n in get_tree().get_nodes_in_group("walls"):
		var w := n as WallSegment
		if w == null:
			continue
		if w.global_position.distance_to(pos) <= splash + 1.5:
			w.take_damage(wall_damage * 0.7)
	for n in get_tree().get_nodes_in_group("buildings"):
		var b := n as Building
		if b == null:
			continue
		if b.global_position.distance_to(pos) <= splash + 2.0:
			b.take_damage(building_damage * 0.6)
