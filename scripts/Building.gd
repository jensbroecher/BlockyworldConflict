class_name Building
extends StaticBody3D

signal destroyed(building: Building)

var building_id: int = 0
var hp: float = 220.0
var max_hp: float = 220.0
var building_height: float = 6.0
var slots: int = 1
var occupants: Array[Unit] = []
var owner_id: int = 0
var footprint: float = 4.0
var display_name: String = "Building"

var _flag: Node3D
var _flag_cloth: CSGBox3D
var _roof: Marker3D
var _crumbling: bool = false


func build(p_id: int, size: Vector3, floors: int, p_slots: int, color: Color, p_name: String) -> void:
	building_id = p_id
	name = "Building_%d" % p_id
	display_name = p_name
	slots = p_slots
	building_height = size.y
	footprint = maxf(size.x, size.z) * 0.55
	hp = 160.0 + size.x * size.y * 2.2
	max_hp = hp
	collision_layer = 8
	collision_mask = 0
	add_to_group("buildings")
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position.y = size.y * 0.5
	add_child(col)
	var body := CSGBox3D.new()
	body.size = size
	body.position.y = size.y * 0.5
	body.material = UnitVisuals.mat(color, 0.05, 0.7)
	add_child(body)
	# Roof
	var roof := CSGBox3D.new()
	roof.size = Vector3(size.x + 0.4, 0.35, size.z + 0.4)
	roof.position.y = size.y + 0.1
	roof.material = UnitVisuals.mat(color.darkened(0.25), 0.08, 0.6)
	add_child(roof)
	# Windows
	for i in floors:
		var wy := 1.2 + i * (size.y / float(maxi(floors, 1)))
		for sx in [-1.0, 1.0]:
			var w := CSGBox3D.new()
			w.size = Vector3(0.12, 0.7, 0.9)
			w.position = Vector3(sx * size.x * 0.51, wy, 0)
			w.material = UnitVisuals.mat(Color(0.35, 0.55, 0.7), 0.4, 0.2)
			add_child(w)
	_roof = Marker3D.new()
	_roof.position = Vector3(0, size.y + 0.4, 0)
	add_child(_roof)
	_flag = Node3D.new()
	_flag.position = Vector3(0, size.y + 0.2, 0)
	_flag.visible = false
	add_child(_flag)
	var pole := CSGCylinder3D.new()
	pole.radius = 0.06
	pole.height = 2.4
	pole.position.y = 1.2
	pole.material = UnitVisuals.mat(Color(0.75, 0.75, 0.7), 0.5)
	_flag.add_child(pole)
	_flag_cloth = CSGBox3D.new()
	_flag_cloth.size = Vector3(1.2, 0.7, 0.08)
	_flag_cloth.position = Vector3(0.6, 2.0, 0)
	_flag.add_child(_flag_cloth)


func roof_point() -> Vector3:
	return _roof.global_position


func range_bonus() -> float:
	return building_height * 0.85


func damage_taken_multiplier() -> float:
	return 0.32


func has_room() -> bool:
	_prune()
	return occupants.size() < slots


func can_seize(player_id: int) -> bool:
	_prune()
	if hp <= 0.0:
		return false
	if occupants.is_empty():
		return true
	return owner_id == player_id and has_room()


func occupy(unit: Unit) -> bool:
	if not can_seize(unit.owner_id) and not (owner_id == unit.owner_id and has_room()):
		return false
	if occupants.has(unit):
		return true
	occupants.append(unit)
	owner_id = unit.owner_id
	_refresh_flag()
	return true


func vacate(unit: Unit) -> void:
	occupants.erase(unit)
	_prune()
	if occupants.is_empty():
		# Keep last owner so the flag stays until recaptured or destroyed.
		pass
	_refresh_flag()


func _prune() -> void:
	var keep: Array[Unit] = []
	for u in occupants:
		if is_instance_valid(u) and u.hp > 0.0:
			keep.append(u)
	occupants = keep
	if occupants.is_empty():
		return
	owner_id = occupants[0].owner_id


func _refresh_flag() -> void:
	_prune()
	if occupants.is_empty() or owner_id == 0:
		_flag.visible = false
		return
	_flag.visible = true
	_flag_cloth.material = UnitVisuals.mat(GameSession.color_of(owner_id), 0.05, 0.45)


func take_damage(amount: float) -> void:
	if amount <= 0.0 or hp <= 0.0 or _crumbling:
		return
	if not GameSession.is_server():
		return
	hp -= amount
	rpc("_rpc_state", hp, owner_id)
	if hp <= 0.0:
		_die()


@rpc("authority", "call_local", "reliable")
func _rpc_state(p_hp: float, p_owner: int) -> void:
	hp = p_hp
	owner_id = p_owner
	_refresh_flag()


func _die() -> void:
	if _crumbling:
		return
	_prune()
	for u in occupants.duplicate():
		u.eject_from_building(40.0)
	occupants.clear()
	var pf := get_tree().get_first_node_in_group("pathfinder") as Pathfinder
	if pf:
		pf.set_blocked_world(global_position, footprint + 0.8, false)
	destroyed.emit(self)
	rpc("_rpc_free")


@rpc("authority", "call_local", "reliable")
func _rpc_free() -> void:
	_crumble_into_ground()


func _crumble_into_ground() -> void:
	if _crumbling:
		return
	_crumbling = true
	hp = 0.0
	collision_layer = 0
	collision_mask = 0
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).disabled = true
	Fx.collapse_smoke(get_tree(), global_position, building_height)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "global_position:y", global_position.y - building_height - 1.8, 1.15).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(self, "rotation_degrees:z", randf_range(-14.0, 14.0), 1.15)
	tw.tween_property(self, "rotation_degrees:x", randf_range(-8.0, 8.0), 1.15)
	tw.chain().tween_callback(queue_free)
