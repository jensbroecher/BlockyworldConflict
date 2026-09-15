class_name UnitVisuals
extends RefCounted

static var _cache: Dictionary = {}


static func mat(color: Color, metallic: float = 0.18, roughness: float = 0.55) -> StandardMaterial3D:
	var key := "%s_%.2f_%.2f" % [color, metallic, roughness]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	_cache[key] = m
	return m


static func team_body(owner_id: int, mix: Color = Color(0.15, 0.15, 0.16)) -> Color:
	return GameSession.color_of(owner_id).lerp(mix, 0.28)


static func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, metallic: float = 0.18) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.size = size
	b.position = pos
	b.material = mat(color, metallic)
	parent.add_child(b)
	return b


static func cyl(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, sides: int = 8) -> CSGCylinder3D:
	var c := CSGCylinder3D.new()
	c.radius = radius
	c.height = height
	c.sides = sides
	c.position = pos
	c.material = mat(color, 0.25)
	parent.add_child(c)
	return c


static func build(kind: int, owner_id: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Visual"
	var team := team_body(owner_id)
	var dark := team.darkened(0.35)
	var gun := Color(0.18, 0.18, 0.2)
	var rubber := Color(0.08, 0.08, 0.09)
	match kind:
		UnitDB.Kind.SOLDIER_SQUAD:
			_squad(root, team, dark)
		UnitDB.Kind.JEEP:
			_jeep(root, team, dark, gun, rubber)
		UnitDB.Kind.IFV:
			_ifv(root, team, dark, gun, rubber)
		UnitDB.Kind.REPAIR_TRUCK:
			_repair(root, team, dark, gun, rubber)
		UnitDB.Kind.TANK:
			_tank(root, team, dark, gun, rubber)
		UnitDB.Kind.ARTILLERY:
			_artillery(root, team, dark, gun, rubber)
		UnitDB.Kind.MLRS:
			_mlrs(root, team, dark, gun, rubber)
		UnitDB.Kind.HELICOPTER:
			_heli(root, team, dark, gun)
	# Godot look_at uses -Z as forward. Vehicle hulls are built +Z-forward.
	if kind != UnitDB.Kind.HELICOPTER:
		root.rotate_y(PI)
	return root


static func _squad(root: Node3D, team: Color, dark: Color) -> void:
	var offsets := [
		Vector3(-0.55, 0, -0.55), Vector3(0.55, 0, -0.55),
		Vector3(-0.55, 0, 0.55), Vector3(0.55, 0, 0.55),
	]
	for o in offsets:
		box(root, o + Vector3(0, 0.7, 0), Vector3(0.55, 0.8, 0.4), team)
		box(root, o + Vector3(0, 1.2, 0.02), Vector3(0.38, 0.32, 0.38), dark)
		box(root, o + Vector3(0.22, 0.85, 0.28), Vector3(0.12, 0.12, 0.55), Color(0.25, 0.22, 0.18), 0.4)
		box(root, o + Vector3(-0.18, 0.25, 0), Vector3(0.16, 0.5, 0.16), dark)
		box(root, o + Vector3(0.18, 0.25, 0), Vector3(0.16, 0.5, 0.16), dark)


static func _jeep(root: Node3D, team: Color, dark: Color, gun: Color, rubber: Color) -> void:
	box(root, Vector3(0, 0.7, 0), Vector3(1.6, 0.7, 2.8), team)
	box(root, Vector3(0, 1.2, -0.35), Vector3(1.4, 0.55, 1.3), dark)
	box(root, Vector3(0, 1.35, 0.7), Vector3(1.2, 0.12, 1.1), gun) # hood
	var turret := Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0, 1.55, -0.2)
	root.add_child(turret)
	cyl(turret, Vector3.ZERO, 0.22, 0.25, dark, 6)
	box(turret, Vector3(0, 0.05, 0.7), Vector3(0.12, 0.12, 1.3), gun, 0.6)
	_wheels(root, rubber, 1.0, 1.0)


static func _ifv(root: Node3D, team: Color, dark: Color, gun: Color, rubber: Color) -> void:
	box(root, Vector3(0, 0.9, 0), Vector3(2.2, 1.1, 4.2), team)
	box(root, Vector3(0, 1.35, -0.6), Vector3(1.8, 0.55, 2.2), dark)
	var turret := Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0, 1.7, 0.4)
	root.add_child(turret)
	box(turret, Vector3.ZERO, Vector3(1.3, 0.55, 1.3), team.lightened(0.08), 0.3)
	box(turret, Vector3(0, 0.05, 1.3), Vector3(0.18, 0.18, 2.2), gun, 0.7)
	_treads(root, rubber, 2.0, 4.0, 0.55)


static func _repair(root: Node3D, team: Color, dark: Color, gun: Color, rubber: Color) -> void:
	var stripe := Color(0.92, 0.72, 0.12)
	box(root, Vector3(0, 0.75, 0.1), Vector3(2.2, 0.9, 4.2), team)
	box(root, Vector3(0, 1.25, 1.2), Vector3(2.0, 0.85, 1.6), dark) # cab
	box(root, Vector3(0, 1.35, -0.9), Vector3(1.9, 0.7, 2.0), stripe, 0.05) # workshop
	box(root, Vector3(0.7, 1.85, -0.9), Vector3(0.35, 0.35, 0.35), Color(0.2, 0.2, 0.22))
	var crane := Node3D.new()
	crane.name = "Turret"
	crane.position = Vector3(0, 1.85, -0.5)
	root.add_child(crane)
	box(crane, Vector3(0, 0.15, 0), Vector3(0.35, 0.35, 0.35), stripe)
	box(crane, Vector3(0, 0.55, 0.15), Vector3(0.22, 1.1, 0.22), dark)
	box(crane, Vector3(0, 1.05, 0.7), Vector3(0.18, 0.18, 1.4), gun, 0.4)
	box(crane, Vector3(0, 0.7, 1.35), Vector3(0.12, 0.55, 0.12), stripe)
	box(root, Vector3(0, 1.55, 1.2), Vector3(0.15, 0.12, 1.1), gun, 0.5) # light MG
	_wheels(root, rubber, 1.05, 1.35)


static func _tank(root: Node3D, team: Color, dark: Color, gun: Color, rubber: Color) -> void:
	box(root, Vector3(0, 0.85, 0), Vector3(2.8, 1.0, 4.8), team, 0.35)
	box(root, Vector3(0, 1.35, 0.2), Vector3(2.2, 0.45, 3.2), dark, 0.4)
	var turret := Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0, 1.85, -0.15)
	root.add_child(turret)
	cyl(turret, Vector3.ZERO, 1.05, 0.7, team.lightened(0.05), 8)
	box(turret, Vector3(0, 0.1, 2.15), Vector3(0.28, 0.28, 3.4), gun, 0.75)
	box(turret, Vector3(0, 0.45, -0.2), Vector3(0.7, 0.25, 0.7), dark)
	_treads(root, rubber, 2.5, 4.6, 0.6)


static func _artillery(root: Node3D, team: Color, dark: Color, gun: Color, rubber: Color) -> void:
	box(root, Vector3(0, 0.75, 0), Vector3(2.4, 0.9, 4.2), team)
	_treads(root, rubber, 2.2, 4.0, 0.5)
	var turret := Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0, 1.35, -0.4)
	root.add_child(turret)
	box(turret, Vector3(0, 0.2, 0), Vector3(1.4, 0.7, 1.6), dark)
	var barrel := box(turret, Vector3(0, 0.55, 1.8), Vector3(0.22, 0.22, 3.6), gun, 0.7)
	barrel.rotation_degrees.x = -18.0


static func _mlrs(root: Node3D, team: Color, dark: Color, gun: Color, rubber: Color) -> void:
	box(root, Vector3(0, 0.8, 0), Vector3(2.4, 1.0, 4.6), team)
	box(root, Vector3(0, 1.2, 1.3), Vector3(2.0, 0.7, 1.4), dark) # cab
	_treads(root, rubber, 2.2, 4.4, 0.5)
	var turret := Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0, 1.55, -0.55)
	root.add_child(turret)
	box(turret, Vector3.ZERO, Vector3(1.8, 0.9, 2.4), dark)
	for i in 6:
		var x := -0.55 + (i % 3) * 0.55
		var y := 0.18 if i < 3 else -0.18
		cyl(turret, Vector3(x, y, 0.4), 0.16, 2.0, gun, 6).rotation_degrees.x = 90


static func _heli(root: Node3D, team: Color, dark: Color, gun: Color) -> void:
	box(root, Vector3(0, 0.9, 0.2), Vector3(1.6, 1.0, 3.2), team, 0.25)
	box(root, Vector3(0, 1.0, 2.2), Vector3(0.35, 0.35, 2.2), dark) # tail
	box(root, Vector3(0.15, 1.35, 3.2), Vector3(0.12, 0.7, 0.4), dark) # tail fin
	box(root, Vector3(0, 0.45, 0.6), Vector3(0.2, 0.2, 1.4), gun, 0.6)
	var rotor := Node3D.new()
	rotor.name = "Rotor"
	rotor.position = Vector3(0, 1.7, 0.1)
	rotor.set_meta("spin", 14.0)
	root.add_child(rotor)
	cyl(rotor, Vector3.ZERO, 0.12, 0.25, gun, 6)
	box(rotor, Vector3(0, 0.08, 0), Vector3(4.6, 0.08, 0.28), Color(0.12, 0.12, 0.12), 0.4)
	box(rotor, Vector3(0, 0.1, 0), Vector3(0.28, 0.06, 4.6), Color(0.12, 0.12, 0.12), 0.4)
	var turret := Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0, 0.35, 0.8)
	root.add_child(turret)
	cyl(turret, Vector3.ZERO, 0.2, 0.2, dark, 6)
	box(turret, Vector3(0, 0, 0.7), Vector3(0.1, 0.1, 1.1), gun, 0.6)


static func _wheels(root: Node3D, rubber: Color, x: float, z: float) -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			cyl(root, Vector3(sx * x, 0.38, sz * z), 0.38, 0.28, rubber, 8).rotation_degrees.z = 90


static func _treads(root: Node3D, rubber: Color, x: float, length: float, y: float) -> void:
	box(root, Vector3(-x * 0.5, y * 0.5, 0), Vector3(0.55, y, length), rubber, 0.05)
	box(root, Vector3(x * 0.5, y * 0.5, 0), Vector3(0.55, y, length), rubber, 0.05)
