class_name Unit
extends CharacterBody3D

signal died(unit: Unit)

var kind: int = 0
var owner_id: int = 1
var hp: float = 100.0
var max_hp: float = 100.0
var stats: Dictionary = {}
var selected: bool = false:
	set(v):
		selected = v
		if _sel:
			_sel.visible = v

var path: PackedVector3Array = PackedVector3Array()
var path_i: int = 0
var attack_target: Unit = null
var garrison_building: Building = null
var pending_garrison: Building = null
var _move_priority: bool = false

var _visual: Node3D
var _sel: MeshInstance3D
var _hp_fill: MeshInstance3D
var _turret: Node3D
var _cooldown: float = 0.0
var _mlrs_left: int = 0
var _net_pos: Vector3
var _net_yaw: float
var _sync_t: float = 0.0
var _acquire_t: float = 0.0
var _crashing: bool = false
var _crash_spin: Vector3 = Vector3.ZERO
var _pop_turret_on_wreck: bool = false
var _repair_fx_t: float = 0.0


func setup(p_kind: int, p_owner: int) -> void:
	kind = p_kind
	owner_id = p_owner
	stats = UnitDB.data(kind)
	hp = float(stats["hp"])
	max_hp = hp
	add_to_group("units")
	collision_layer = 2
	collision_mask = 1 | 8 | 16
	floor_max_angle = deg_to_rad(55.0)
	floor_snap_length = 0.45
	var ext: Vector3 = stats["extent"]
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = ext
	col.shape = box
	col.position.y = ext.y * 0.5
	add_child(col)
	_visual = UnitVisuals.build(kind, owner_id)
	add_child(_visual)
	_turret = _visual.find_child("Turret", true, false)
	_make_selection(ext)
	_make_hp_bar(ext)
	if bool(stats["air"]):
		collision_mask = 0
		motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_net_pos = position
	_net_yaw = rotation.y


func _make_selection(ext: Vector3) -> void:
	_sel = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = maxf(ext.x, ext.z) * 0.7
	cyl.bottom_radius = cyl.top_radius
	cyl.height = 0.08
	_sel.mesh = cyl
	_sel.position.y = 0.06
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = GameSession.color_of(owner_id)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color.a = 0.7
	_sel.material_override = m
	_sel.visible = false
	add_child(_sel)


func _make_hp_bar(ext: Vector3) -> void:
	var root := Node3D.new()
	root.position = Vector3(0, ext.y + 0.55, 0)
	add_child(root)
	var bg := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.6, 0.14)
	bg.mesh = qm
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(0.05, 0.05, 0.05, 0.7)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg.material_override = bm
	root.add_child(bg)
	_hp_fill = MeshInstance3D.new()
	var qm2 := QuadMesh.new()
	qm2.size = Vector2(1.5, 0.1)
	_hp_fill.mesh = qm2
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(0.25, 0.85, 0.3)
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_fill.material_override = fm
	_hp_fill.position.z = 0.01
	root.add_child(_hp_fill)


func is_air() -> bool:
	return bool(stats.get("air", false))


func is_infantry() -> bool:
	return bool(stats.get("can_garrison", false))


func is_vehicle() -> bool:
	return not is_air() and not is_infantry()


func is_repairer() -> bool:
	return float(stats.get("repair_rate", 0.0)) > 0.0


func aim_point() -> Vector3:
	if garrison_building and is_instance_valid(garrison_building):
		return garrison_building.roof_point()
	var ext: Vector3 = stats["extent"]
	return global_position + Vector3(0, ext.y * 0.7, 0)


func muzzle() -> Vector3:
	if garrison_building and is_instance_valid(garrison_building):
		return garrison_building.roof_point() + Vector3(0, 0.4, 0)
	if _turret:
		return _turret.global_position + _turret.global_transform.basis.z * 1.6
	return aim_point() + -global_transform.basis.z * 1.2


func current_range() -> float:
	var r := float(stats["range"])
	if garrison_building and is_instance_valid(garrison_building):
		r += garrison_building.range_bonus()
	return r


func order_move(dest: Vector3, target: Unit = null, garrison: Building = null) -> void:
	if not GameSession.is_server():
		var tpath := target.get_path() if is_instance_valid(target) else NodePath()
		var gpath := garrison.get_path() if is_instance_valid(garrison) else NodePath()
		rpc_id(1, "_rpc_order_move", dest, tpath, gpath)
		return
	_apply_order(dest, target, garrison)


@rpc("any_peer", "reliable")
func _rpc_order_move(dest: Vector3, tpath: NodePath, gpath: NodePath) -> void:
	if not GameSession.is_server():
		return
	var sid := multiplayer.get_remote_sender_id()
	if sid != 0 and sid != owner_id:
		return
	var t: Unit = get_node_or_null(tpath) as Unit if tpath != NodePath() else null
	var g: Building = get_node_or_null(gpath) as Building if gpath != NodePath() else null
	_apply_order(dest, t, g)


func _apply_order(dest: Vector3, target: Unit, garrison: Building) -> void:
	if garrison_building:
		_leave_garrison()
	attack_target = target
	pending_garrison = garrison
	# Ground click (no attack target) must be allowed to walk away from a fight.
	_move_priority = target == null and garrison == null
	if is_air():
		path = PackedVector3Array([Vector3(dest.x, float(stats["fly_height"]), dest.z)])
		path_i = 0
		return
	var pf := get_tree().get_first_node_in_group("pathfinder") as Pathfinder
	if pf:
		path = pf.find_path(global_position, dest)
	else:
		path = PackedVector3Array([dest])
	path_i = 0


func order_stop() -> void:
	if not GameSession.is_server():
		rpc_id(1, "_rpc_stop")
		return
	path = PackedVector3Array()
	attack_target = null
	pending_garrison = null
	_move_priority = false


@rpc("any_peer", "reliable")
func _rpc_stop() -> void:
	if not GameSession.is_server():
		return
	if multiplayer.get_remote_sender_id() != owner_id and multiplayer.get_remote_sender_id() != 0:
		return
	path = PackedVector3Array()
	attack_target = null
	pending_garrison = null
	_move_priority = false


func _map() -> BattleMap:
	return get_tree().get_first_node_in_group("battle_map") as BattleMap


func _ground_y() -> float:
	var m := _map()
	if m == null:
		return 0.08
	return m.sample_height(global_position.x, global_position.z) + 0.08


func _physics_process(delta: float) -> void:
	if hp <= 0.0:
		if _crashing:
			_crash_tick(delta)
		return
	_update_hp_bar()
	if GameSession.is_server():
		_server_sim(delta)
		_sync_t += delta
		if _sync_t >= 0.1:
			_sync_t = 0.0
			rpc("_rpc_state", global_position, rotation.y, hp)
	else:
		global_position = global_position.lerp(_net_pos, clampf(delta * 12.0, 0.0, 1.0))
		rotation.y = lerp_angle(rotation.y, _net_yaw, clampf(delta * 12.0, 0.0, 1.0))
	_spin_rotors(delta)


@rpc("authority", "unreliable_ordered")
func _rpc_state(pos: Vector3, yaw: float, p_hp: float) -> void:
	_net_pos = pos
	_net_yaw = yaw
	hp = p_hp


func _server_sim(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if garrison_building:
		velocity = Vector3.ZERO
		_try_shoot(delta)
		return
	_try_enter_garrison()
	var repairing := _try_repair(delta)
	var shooting := _try_shoot(delta)
	if repairing or not shooting:
		_follow_path(delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_air():
			velocity.y = 0
			move_and_slide()
			global_position.y = _ground_y()


func _follow_path(delta: float) -> void:
	var speed: float = float(stats["speed"])
	if is_air():
		var target_y := float(stats["fly_height"])
		if path_i < path.size():
			var dest: Vector3 = path[path_i]
			dest.y = target_y
			var to := dest - global_position
			if to.length() < 1.2:
				path_i += 1
			else:
				global_position += to.normalized() * speed * delta
				_look_xz(dest)
		else:
			global_position.y = move_toward(global_position.y, target_y, 6.0 * delta)
			_move_priority = false
		return
	var map := _map()
	if path_i < path.size():
		var dest: Vector3 = path[path_i]
		var to := Vector3(dest.x, global_position.y, dest.z) - global_position
		to.y = 0
		if to.length() < 1.3:
			path_i += 1
		else:
			_look_xz(dest)
			var dir := to.normalized()
			if map:
				var ahead := global_position + dir * 2.2
				var slope := (map.sample_height(ahead.x, ahead.z) - map.sample_height(global_position.x, global_position.z)) / 2.2
				if slope > 0.0:
					speed *= clampf(1.0 - slope * 2.4, 0.34, 1.0)
				elif slope < -0.05:
					speed *= 1.06
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
	else:
		velocity.x = 0
		velocity.z = 0
		_move_priority = false
	velocity.y = 0
	_keep_out_of_water()
	_separate()
	move_and_slide()
	if map:
		global_position.y = _ground_y()
	if GameSession.is_server() and is_vehicle():
		_try_crush()


func _separate() -> void:
	for n in get_tree().get_nodes_in_group("units"):
		var o := n as Unit
		if o == null or o == self or o.is_air() != is_air():
			continue
		# Vehicles drive through infantry instead of bouncing off them.
		if is_vehicle() and o.is_infantry():
			continue
		if is_infantry() and o.is_vehicle() and o.owner_id != owner_id:
			continue
		var d := global_position.distance_to(o.global_position)
		if d < 2.4 and d > 0.01:
			var push := (global_position - o.global_position).normalized() * (2.4 - d) * 2.0
			velocity.x += push.x
			velocity.z += push.z


func _try_crush() -> void:
	var speed_xz := Vector2(velocity.x, velocity.z).length()
	if speed_xz < 2.8 and path_i >= path.size():
		return
	var ext: Vector3 = stats["extent"]
	var radius := maxf(ext.x, ext.z) * 0.62
	for n in get_tree().get_nodes_in_group("units"):
		var o := n as Unit
		if o == null or o == self or o.owner_id == owner_id or o.hp <= 0.0:
			continue
		if not o.is_infantry() or o.garrison_building:
			continue
		var d := Vector2(global_position.x - o.global_position.x, global_position.z - o.global_position.z).length()
		if d <= radius + 0.7:
			o.take_damage(o.max_hp + 20.0, owner_id)
			Fx.crush_puff(get_tree(), o.global_position)


func _keep_out_of_water() -> void:
	if is_air():
		return
	var map := _map()
	var on_bridge := map != null and map.is_on_bridge(global_position)
	var over_water := absf(global_position.x) < BattleMap.RIVER_HALF - 0.2
	if global_position.y < -0.35 or (over_water and not on_bridge):
		var side := 1.0 if global_position.x >= 0.0 else -1.0
		global_position.x = side * (BattleMap.RIVER_HALF + 1.6)
		global_position.y = _ground_y()
		velocity = Vector3.ZERO


func _look_xz(dest: Vector3) -> void:
	var p := Vector3(dest.x, global_position.y, dest.z)
	if p.distance_to(global_position) < 0.05:
		return
	look_at(p, Vector3.UP)


func _try_shoot(_delta: float) -> bool:
	_acquire_t -= _delta
	if not is_instance_valid(attack_target) or attack_target.hp <= 0.0:
		attack_target = null
	var following_move := _move_priority and path_i < path.size()
	if attack_target == null and not following_move and _acquire_t <= 0.0:
		_acquire_t = 0.35
		attack_target = _acquire_enemy()
	if attack_target == null:
		return false
	var origin := muzzle()
	var aim := attack_target.aim_point()
	var dist := origin.distance_to(aim)
	var rng := current_range()
	var minr: float = float(stats["min_range"])
	_aim_turret(aim)
	if dist > rng:
		if not following_move and path_i >= path.size() and garrison_building == null:
			_apply_order(attack_target.global_position, attack_target, null)
		return false
	if dist < minr:
		return false
	if kind != UnitDB.Kind.ARTILLERY and kind != UnitDB.Kind.MLRS and not _los_ok(origin, aim):
		return false
	if _cooldown <= 0.0:
		_fire(origin, aim)
	# Keep walking if the player ordered a move; otherwise stop to fire.
	return not following_move


func _aim_turret(aim: Vector3) -> void:
	if _turret == null:
		_look_xz(aim)
		return
	var local_aim := Vector3(aim.x, _turret.global_position.y, aim.z)
	if local_aim.distance_to(_turret.global_position) > 0.1:
		_turret.look_at(local_aim, Vector3.UP)
		_turret.rotate_y(PI)


func _los_ok(from: Vector3, to: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 8 | 16
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return true
	var col: Object = hit.collider
	if col is Building and garrison_building == col:
		return true
	if col is WallSegment:
		return float(stats["wall_damage"]) > 0.0
	if col is Building:
		return true
	return true


func _acquire_enemy() -> Unit:
	var best: Unit = null
	var best_d := current_range() * 1.35
	var origin := aim_point()
	for n in get_tree().get_nodes_in_group("units"):
		var u := n as Unit
		if u == null or u == self or u.owner_id == owner_id or u.hp <= 0.0:
			continue
		var d := origin.distance_to(u.aim_point())
		if d < best_d:
			best_d = d
			best = u
	return best


func _fire(from: Vector3, to: Vector3) -> void:
	var spd: float = float(stats["projectile_speed"])
	var rocket := bool(stats.get("rocket", false))
	if kind == UnitDB.Kind.MLRS:
		if _mlrs_left <= 0:
			_mlrs_left = 3
		_mlrs_left -= 1
		_cooldown = 0.42 if _mlrs_left > 0 else float(stats["fire_interval"])
		to += Vector3(randf_range(-2.4, 2.4), 0.0, randf_range(-2.4, 2.4))
	else:
		_cooldown = float(stats["fire_interval"])
	if rocket or spd > 1.0:
		_spawn_projectile(from, to, spd)
	else:
		rpc("_rpc_shot_fx", from, to)
		_hitscan(from, to)


func _hitscan(from: Vector3, to: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to + (to - from).normalized() * 1.5)
	q.collision_mask = 2 | 8 | 16
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		_deal_to_unit(attack_target)
		return
	var col: Object = hit.collider
	if col is Unit:
		_deal_to_unit(col as Unit)
	elif col is WallSegment:
		(col as WallSegment).take_damage(float(stats["wall_damage"]))
	elif col is Building:
		(col as Building).take_damage(float(stats["building_damage"]))
		if is_instance_valid(attack_target):
			_deal_to_unit(attack_target)


func _spawn_projectile(from: Vector3, to: Vector3, spd: float) -> void:
	rpc("_rpc_spawn_projectile", from, to, spd)


@rpc("authority", "call_local", "unreliable")
func _rpc_spawn_projectile(from: Vector3, to: Vector3, spd: float) -> void:
	var p := Projectile.new()
	p.setup(
		from, to, kind, owner_id,
		float(stats["damage"]), spd,
		float(stats["splash"]),
		float(stats["wall_damage"]),
		float(stats["building_damage"])
	)
	p.ignore_rids = [get_rid()]
	get_tree().current_scene.add_child(p, true)


func _deal_to_unit(u: Unit) -> void:
	if u == null or u.owner_id == owner_id:
		return
	u.take_damage(float(stats["damage"]), owner_id)


@rpc("authority", "call_local", "unreliable")
func _rpc_shot_fx(from: Vector3, to: Vector3) -> void:
	Fx.tracer(get_tree(), from, to, GameSession.color_of(owner_id).lightened(0.4))


func receive_repair(amount: float) -> void:
	if hp <= 0.0 or amount <= 0.0 or hp >= max_hp:
		return
	if not GameSession.is_server():
		return
	hp = minf(max_hp, hp + amount)


func _try_repair(delta: float) -> bool:
	if not is_repairer() or hp <= 0.0:
		return false
	var radius := float(stats.get("repair_range", 12.0))
	var rate := float(stats.get("repair_rate", 0.0))
	var best: Unit = null
	var best_need := 0.0
	for n in get_tree().get_nodes_in_group("units"):
		var u := n as Unit
		if u == null or u == self or u.owner_id != owner_id or u.hp <= 0.0:
			continue
		if u.is_infantry():
			continue
		if u.hp >= u.max_hp - 0.05:
			continue
		var d := global_position.distance_to(u.global_position)
		if d > radius:
			continue
		var need := u.max_hp - u.hp
		if need > best_need:
			best_need = need
			best = u
	if best == null:
		return false
	best.receive_repair(rate * delta)
	_repair_fx_t -= delta
	if _repair_fx_t <= 0.0:
		_repair_fx_t = 0.12
		rpc("_rpc_repair_fx", best.get_path())
	return true


@rpc("authority", "call_local", "unreliable")
func _rpc_repair_fx(target_path: NodePath) -> void:
	var t := get_node_or_null(target_path) as Unit
	if t == null:
		return
	Fx.repair_beam(get_tree(), aim_point() + Vector3(0, 0.8, 0), t.aim_point())


func take_damage(amount: float, _from_owner: int) -> void:
	if hp <= 0.0 or amount <= 0.0:
		return
	if not GameSession.is_server():
		return
	var armor: float = float(stats["armor"])
	var dmg := maxf(amount - armor * 0.55, amount * 0.35)
	if garrison_building and is_instance_valid(garrison_building):
		dmg *= garrison_building.damage_taken_multiplier()
		garrison_building.take_damage(amount * 0.25)
	hp -= dmg
	if hp <= 0.0:
		hp = 0.0
		_die()


func _die() -> void:
	if garrison_building:
		_leave_garrison()
	died.emit(self)
	rpc("_rpc_die", kind == UnitDB.Kind.TANK and randf() < 0.62)


@rpc("authority", "call_local", "reliable")
func _rpc_die(pop_turret: bool = false) -> void:
	hp = 0.0
	selected = false
	remove_from_group("units")
	collision_layer = 0
	collision_mask = 0
	var cs := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs:
		cs.disabled = true
	_pop_turret_on_wreck = pop_turret
	if is_air():
		_start_heli_crash()
		return
	_play_wreck()
	get_tree().create_timer(0.35).timeout.connect(queue_free)


func _start_heli_crash() -> void:
	_crashing = true
	_crash_spin = Vector3(randf_range(-1.6, 1.6), randf_range(2.5, 4.5), randf_range(-1.2, 1.2))
	velocity = Vector3(randf_range(-4, 4), -2.0, randf_range(-4, 4))
	Fx.fire_column(get_tree(), global_position)


func _crash_tick(delta: float) -> void:
	velocity.y -= 22.0 * delta
	global_position += velocity * delta
	rotate_x(_crash_spin.x * delta)
	rotate_y(_crash_spin.y * delta)
	rotate_z(_crash_spin.z * delta)
	if Engine.get_physics_frames() % 4 == 0:
		Fx.burst(get_tree(), global_position, Color(1.0, 0.45, 0.1))
	var floor_y := _ground_y()
	if global_position.y <= floor_y + 0.6:
		_crashing = false
		Fx.explode(get_tree(), global_position, 9.0)
		Fx.spawn_debris(get_tree(), global_position, GameSession.color_of(owner_id), 10, 12.0)
		Fx.fire_column(get_tree(), global_position)
		queue_free()


func _play_wreck() -> void:
	var pos := aim_point()
	var col := GameSession.color_of(owner_id)
	if kind == UnitDB.Kind.TANK:
		Fx.explode(get_tree(), pos, 8.0)
		Fx.fire_column(get_tree(), global_position)
		Fx.spawn_debris(get_tree(), pos, col, 8, 11.0)
		if _pop_turret_on_wreck:
			_pop_turret()
	elif kind == UnitDB.Kind.ARTILLERY or kind == UnitDB.Kind.MLRS:
		Fx.explode(get_tree(), pos, 7.5)
		Fx.spawn_debris(get_tree(), pos, col, 7, 10.0)
		Fx.fire_column(get_tree(), global_position)
		get_tree().create_timer(0.18).timeout.connect(func() -> void:
			if is_inside_tree():
				Fx.explode(get_tree(), global_position + Vector3(randf_range(-1.2, 1.2), 1.0, randf_range(-1.2, 1.2)), 5.0)
		)
	elif is_infantry():
		Fx.burst(get_tree(), pos, col)
		Fx.spawn_debris(get_tree(), pos, col.darkened(0.2), 5, 7.0)
	else:
		Fx.explode(get_tree(), pos, 6.0)
		Fx.spawn_debris(get_tree(), pos, col, 6, 9.0)
		Fx.fire_column(get_tree(), global_position)


func _pop_turret() -> void:
	if _turret == null or not is_instance_valid(_turret):
		return
	var gpos := _turret.global_position
	var grot := _turret.global_rotation
	_visual.remove_child(_turret)
	var rb := RigidBody3D.new()
	rb.collision_layer = 0
	rb.collision_mask = 1
	rb.mass = 1.4
	rb.global_position = gpos
	rb.global_rotation = grot
	var col := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.1
	col.shape = sh
	rb.add_child(col)
	rb.add_child(_turret)
	_turret.position = Vector3.ZERO
	_turret.rotation = Vector3.ZERO
	get_tree().current_scene.add_child(rb)
	rb.linear_velocity = Vector3(randf_range(-5, 5), randf_range(11, 16), randf_range(-5, 5))
	rb.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-8, 8), randf_range(-6, 6))
	_turret = null
	get_tree().create_timer(3.5).timeout.connect(rb.queue_free)


func _try_enter_garrison() -> void:
	if pending_garrison == null or not is_instance_valid(pending_garrison):
		pending_garrison = null
		return
	if not bool(stats["can_garrison"]):
		return
	if global_position.distance_to(pending_garrison.global_position) > pending_garrison.footprint + 3.5:
		return
	if not pending_garrison.can_seize(owner_id):
		return
	_enter_garrison(pending_garrison)
	pending_garrison = null


func _enter_garrison(b: Building) -> void:
	if not b.occupy(self):
		return
	garrison_building = b
	path = PackedVector3Array()
	visible = false
	var cs := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs:
		cs.disabled = true
	global_position = b.global_position


func _leave_garrison() -> void:
	if garrison_building and is_instance_valid(garrison_building):
		garrison_building.vacate(self)
		global_position = garrison_building.global_position + Vector3(3.5, 0.08, 0)
	garrison_building = null
	visible = true
	var cs := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs:
		cs.disabled = false


func eject_from_building(damage: float) -> void:
	_leave_garrison()
	take_damage(damage, 0)


func order_unload() -> void:
	if not GameSession.is_server():
		rpc_id(1, "_rpc_unload")
		return
	_do_unload()


@rpc("any_peer", "reliable")
func _rpc_unload() -> void:
	if not GameSession.is_server():
		return
	if multiplayer.get_remote_sender_id() != owner_id and multiplayer.get_remote_sender_id() != 0:
		return
	_do_unload()


func _do_unload() -> void:
	if garrison_building == null or not is_instance_valid(garrison_building):
		return
	var origin := garrison_building.global_position
	_leave_garrison()
	var a := randf() * TAU
	var dest := origin + Vector3(cos(a), 0.0, sin(a)) * 4.5
	dest.y = 0.08
	global_position = dest
	_move_priority = true
	attack_target = null
	pending_garrison = null
	var pf := get_tree().get_first_node_in_group("pathfinder") as Pathfinder
	if pf and not is_air():
		path = pf.find_path(global_position, dest + Vector3(cos(a), 0.0, sin(a)) * 2.0)
		path_i = 0
	else:
		path = PackedVector3Array()
		path_i = 0


func _spin_rotors(delta: float) -> void:
	if _visual == null:
		return
	for c in _visual.get_children():
		if c.has_meta("spin"):
			(c as Node3D).rotate_y(float(c.get_meta("spin")) * delta)


func _update_hp_bar() -> void:
	if _hp_fill == null:
		return
	var t := clampf(hp / max_hp, 0.0, 1.0)
	_hp_fill.scale.x = maxf(t, 0.02)
	var m := _hp_fill.material_override as StandardMaterial3D
	if m:
		m.albedo_color = Color(0.85, 0.18, 0.15).lerp(Color(0.25, 0.85, 0.3), t)


func unit_value() -> int:
	return int(stats.get("value", 0))
