class_name WallSegment
extends StaticBody3D

signal destroyed(wall: WallSegment)

var hp: float = 90.0
var max_hp: float = 90.0
var wall_id: int = 0
var block_radius: float = 2.4


func build(p_id: int, size: Vector3, color: Color) -> void:
	wall_id = p_id
	name = "Wall_%d" % p_id
	collision_layer = 16
	collision_mask = 0
	add_to_group("walls")
	hp = 70.0 + size.x * size.y
	max_hp = hp
	block_radius = maxf(size.x, size.z) * 0.65
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	add_child(col)
	var visual := CSGCombiner3D.new()
	add_child(visual)
	var base := CSGBox3D.new()
	base.size = size
	base.material = UnitVisuals.mat(color, 0.05, 0.85)
	visual.add_child(base)
	# Irregular cliff chunks.
	var chunk := CSGBox3D.new()
	chunk.size = Vector3(size.x * 0.7, size.y * 0.45, size.z * 0.55)
	chunk.position = Vector3(size.x * 0.12, size.y * 0.28, size.z * 0.08)
	chunk.rotation_degrees = Vector3(8, 12, -6)
	chunk.material = UnitVisuals.mat(color.darkened(0.18), 0.04, 0.9)
	chunk.operation = CSGShape3D.OPERATION_UNION
	visual.add_child(chunk)
	var lip := CSGBox3D.new()
	lip.size = Vector3(size.x * 1.05, size.y * 0.18, size.z * 0.9)
	lip.position = Vector3(0, size.y * 0.42, 0)
	lip.material = UnitVisuals.mat(color.lightened(0.08), 0.04, 0.8)
	visual.add_child(lip)


func take_damage(amount: float) -> void:
	if amount <= 0.0 or hp <= 0.0:
		return
	if not GameSession.is_server():
		return
	hp -= amount
	rpc("_rpc_hp", hp)
	if hp <= 0.0:
		_die()


@rpc("authority", "call_local", "reliable")
func _rpc_hp(v: float) -> void:
	hp = v
	var vis := get_child(1) if get_child_count() > 1 else null
	if vis is Node3D:
		var t := clampf(hp / max_hp, 0.0, 1.0)
		(vis as Node3D).scale = Vector3(1, 0.35 + 0.65 * t, 1)


func _die() -> void:
	var pf := get_tree().get_first_node_in_group("pathfinder") as Pathfinder
	if pf:
		pf.set_blocked_world(global_position, block_radius + 0.6, false)
	destroyed.emit(self)
	rpc("_rpc_free")


@rpc("authority", "call_local", "reliable")
func _rpc_free() -> void:
	Fx.burst(get_tree(), global_position + Vector3(0, 1.5, 0), Color(0.45, 0.38, 0.3))
	queue_free()
