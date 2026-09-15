class_name BattleMap
extends Node3D

const MAP_HALF := 96.0
const RIVER_HALF := 8.0

var pathfinder: Pathfinder
var regions: Array[Dictionary] = [] ## {id, name, min, max, center, owner}
var spawn_points: Dictionary = {} ## player_id -> Vector3
var rng := RandomNumberGenerator.new()
var hill_defs: Array[Dictionary] = []

var _next_wall := 0
var _next_building := 0


func build() -> void:
	rng.seed = 20260325
	add_to_group("battle_map")
	_environment()
	_ground_and_river()
	_hills()
	_bridges()
	_river_barriers()
	_setup_pathfinder()
	_regions()
	_dotted_lines()
	_buildings()
	_cliff_walls()
	_trees()
	spawn_points[1] = Vector3(-78, 0, 8)
	spawn_points[2] = Vector3(78, 0, -8)
	_spawn_markers()


func _environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	var we := Environment.new()
	we.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.42, 0.62, 0.88)
	sky_mat.sky_horizon_color = Color(0.76, 0.82, 0.72)
	sky_mat.ground_bottom_color = Color(0.22, 0.28, 0.16)
	sky_mat.ground_horizon_color = Color(0.62, 0.68, 0.48)
	sky.sky_material = sky_mat
	we.sky = sky
	we.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	we.ambient_light_energy = 0.55
	we.fog_enabled = true
	we.fog_density = 0.0018
	we.fog_light_color = Color(0.7, 0.78, 0.72)
	env.environment = we
	add_child(env)


func _ground_and_river() -> void:
	var land_w := MAP_HALF - RIVER_HALF
	_add_ground_plate(-(RIVER_HALF + land_w * 0.5), land_w)
	_add_ground_plate(RIVER_HALF + land_w * 0.5, land_w)
	# Visible trench of water between the two banks (opaque — mobile CSG alpha was invisible).
	var water := MeshInstance3D.new()
	var wmesh := BoxMesh.new()
	wmesh.size = Vector3(RIVER_HALF * 2.0, 1.6, MAP_HALF * 2.0)
	water.mesh = wmesh
	water.position = Vector3(0, -1.0, 0) # surface at y=-0.2, below the banks
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.12, 0.42, 0.72)
	wm.metallic = 0.35
	wm.roughness = 0.18
	wm.emission_enabled = true
	wm.emission = Color(0.05, 0.18, 0.32)
	wm.emission_energy_multiplier = 0.45
	water.material_override = wm
	add_child(water)
	var bed := MeshInstance3D.new()
	var bmesh := BoxMesh.new()
	bmesh.size = Vector3(RIVER_HALF * 2.0 + 0.4, 0.4, MAP_HALF * 2.0)
	bed.mesh = bmesh
	bed.position = Vector3(0, -1.7, 0)
	bed.material_override = UnitVisuals.mat(Color(0.22, 0.28, 0.18), 0.0, 0.95)
	add_child(bed)
	for sx in [-1.0, 1.0]:
		var bank := CSGBox3D.new()
		bank.size = Vector3(2.6, 0.7, MAP_HALF * 2.0)
		bank.position = Vector3(sx * (RIVER_HALF + 0.4), -0.12, 0)
		bank.material = UnitVisuals.mat(Color(0.48, 0.40, 0.26), 0.0, 0.95)
		add_child(bank)
		var foam := MeshInstance3D.new()
		var fmesh := BoxMesh.new()
		fmesh.size = Vector3(0.55, 0.08, MAP_HALF * 2.0)
		foam.mesh = fmesh
		foam.position = Vector3(sx * (RIVER_HALF - 0.2), -0.16, 0)
		foam.material_override = UnitVisuals.mat(Color(0.55, 0.78, 0.88), 0.0, 0.4)
		add_child(foam)


func _add_ground_plate(center_x: float, width: float) -> void:
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	var gcol := CollisionShape3D.new()
	var gbox := BoxShape3D.new()
	gbox.size = Vector3(width, 2.0, MAP_HALF * 2.0)
	gcol.shape = gbox
	gcol.position.y = -1.0
	ground.add_child(gcol)
	ground.position.x = center_x
	var gmesh := CSGBox3D.new()
	gmesh.size = Vector3(width, 2.0, MAP_HALF * 2.0)
	gmesh.position.y = -1.0
	gmesh.material = UnitVisuals.mat(Color(0.40, 0.55, 0.28), 0.0, 0.95)
	ground.add_child(gmesh)
	add_child(ground)


func _hills() -> void:
	var hills := [
		{"pos": Vector3(-62, -4, 58), "r": 16.0, "h": 14.0},
		{"pos": Vector3(-50, -5, -62), "r": 18.0, "h": 16.0},
		{"pos": Vector3(58, -4, 52), "r": 15.0, "h": 13.0},
		{"pos": Vector3(64, -5, -55), "r": 17.0, "h": 15.0},
		{"pos": Vector3(-28, -6, 18), "r": 10.0, "h": 8.0},
		{"pos": Vector3(30, -6, -22), "r": 11.0, "h": 8.5},
	]
	for h in hills:
		var sx := 1.15
		var sy: float = (h["h"] / h["r"]) * 0.85
		var s := CSGSphere3D.new()
		s.radius = h["r"]
		s.position = h["pos"]
		s.scale = Vector3(sx, sy, sx)
		s.material = UnitVisuals.mat(Color(0.36, 0.50, 0.26), 0.0, 0.95)
		s.use_collision = false
		add_child(s)
		hill_defs.append({
			"px": h["pos"].x,
			"py": h["pos"].y,
			"pz": h["pos"].z,
			"rx": h["r"] * sx,
			"ry": h["r"] * sy,
			"rz": h["r"] * sx,
		})


func sample_height(x: float, z: float) -> float:
	var h := 0.0
	for hill in hill_defs:
		var dx: float = (x - float(hill["px"])) / float(hill["rx"])
		var dz: float = (z - float(hill["pz"])) / float(hill["rz"])
		var d2 := dx * dx + dz * dz
		if d2 < 0.97:
			var y: float = float(hill["py"]) + float(hill["ry"]) * sqrt(1.0 - d2)
			if y > h:
				h = y
	return maxf(h, 0.0)


func is_on_bridge(pos: Vector3) -> bool:
	if absf(pos.x) > RIVER_HALF + 3.0:
		return false
	return absf(pos.z - 40.0) < 6.6 or absf(pos.z + 40.0) < 6.6


func _bridges() -> void:
	for z in [-40.0, 40.0]:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.position = Vector3(0, 0, z)
		# Wide flat floor only — railings are visual and sit outside this volume.
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(RIVER_HALF * 2.0 + 6.0, 1.0, 14.0)
		col.shape = box
		col.position.y = -0.5
		body.add_child(col)
		var deck := CSGBox3D.new()
		deck.size = Vector3(RIVER_HALF * 2.0 + 6.0, 0.28, 13.5)
		deck.position.y = 0.04
		deck.use_collision = false
		deck.material = UnitVisuals.mat(Color(0.42, 0.32, 0.22), 0.05, 0.8)
		body.add_child(deck)
		for side in [-1.0, 1.0]:
			var rail := CSGBox3D.new()
			rail.size = Vector3(RIVER_HALF * 2.0 + 6.0, 0.9, 0.22)
			rail.position = Vector3(0, 0.55, side * 7.15)
			rail.use_collision = false
			rail.material = UnitVisuals.mat(Color(0.3, 0.22, 0.16), 0.1, 0.7)
			body.add_child(rail)
		for i in 8:
			var plank := CSGBox3D.new()
			plank.size = Vector3(2.2, 0.08, 12.6)
			plank.position = Vector3(-11.0 + i * 3.15, 0.2, 0)
			plank.use_collision = false
			plank.material = UnitVisuals.mat(Color(0.5, 0.38, 0.24), 0.05, 0.75)
			body.add_child(plank)
		add_child(body)


func _river_barriers() -> void:
	# Banks block the water; openings are wider than the deck so units don't clip the ends.
	var gap := 8.2
	var spans: Array[Vector2] = [
		Vector2(-MAP_HALF, -40.0 - gap),
		Vector2(-40.0 + gap, 40.0 - gap),
		Vector2(40.0 + gap, MAP_HALF),
	]
	for x in [-RIVER_HALF - 0.15, RIVER_HALF + 0.15]:
		for span in spans:
			var z0: float = span.x
			var z1: float = span.y
			var length := z1 - z0
			if length < 2.0:
				continue
			var wall := StaticBody3D.new()
			wall.collision_layer = 1
			wall.position = Vector3(x, 1.2, (z0 + z1) * 0.5)
			var col := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(0.9, 2.6, length)
			col.shape = box
			wall.add_child(col)
			add_child(wall)


func _setup_pathfinder() -> void:
	pathfinder = Pathfinder.new()
	pathfinder.name = "Pathfinder"
	add_child(pathfinder)
	pathfinder.setup(Vector2(-MAP_HALF, -MAP_HALF), Vector2(MAP_HALF * 2.0, MAP_HALF * 2.0))
	# River blocked except bridges.
	pathfinder.set_blocked_rect(
		Vector2(-RIVER_HALF, -MAP_HALF),
		Vector2(RIVER_HALF, MAP_HALF),
		true
	)
	for z in [-40.0, 40.0]:
		pathfinder.set_blocked_rect(
			Vector2(-RIVER_HALF - 1.5, z - 5.8),
			Vector2(RIVER_HALF + 1.5, z + 5.8),
			false
		)


func _regions() -> void:
	var z_bands := [
		{"name": "North", "min": 32.0, "max": MAP_HALF},
		{"name": "Mid", "min": -32.0, "max": 32.0},
		{"name": "South", "min": -MAP_HALF, "max": -32.0},
	]
	var x_bands := [
		{"name": "West", "min": -MAP_HALF, "max": 0.0},
		{"name": "East", "min": 0.0, "max": MAP_HALF},
	]
	for xb in x_bands:
		for zb in z_bands:
			var id := "%s%s" % [xb["name"][0], zb["name"][0]]
			var nm := "%s %s" % [xb["name"], zb["name"]]
			var mn := Vector2(xb["min"], zb["min"])
			var mx := Vector2(xb["max"], zb["max"])
			var center := Vector3((mn.x + mx.x) * 0.5, 0.0, (mn.y + mx.y) * 0.5)
			regions.append({
				"id": id,
				"name": nm,
				"min": mn,
				"max": mx,
				"center": center,
				"owner": 0,
			})
			var vis_min_x: float = mn.x
			var vis_max_x: float = mx.x
			if vis_max_x > -RIVER_HALF and vis_min_x < -RIVER_HALF:
				vis_max_x = minf(vis_max_x, -RIVER_HALF - 0.6)
			if vis_min_x < RIVER_HALF and vis_max_x > RIVER_HALF:
				vis_min_x = maxf(vis_min_x, RIVER_HALF + 0.6)
			var overlay := MeshInstance3D.new()
			var quad := PlaneMesh.new()
			quad.size = Vector2(vis_max_x - vis_min_x - 1.0, mx.y - mn.y - 1.0)
			overlay.mesh = quad
			overlay.position = Vector3((vis_min_x + vis_max_x) * 0.5, 0.04, center.z)
			overlay.name = "RegionTint_%s" % id
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(1, 1, 1, 0.04)
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			overlay.material_override = mat
			add_child(overlay)


func region_at(pos: Vector3) -> int:
	for i in regions.size():
		var r: Dictionary = regions[i]
		var mn: Vector2 = r["min"]
		var mx: Vector2 = r["max"]
		if pos.x >= mn.x and pos.x < mx.x and pos.z >= mn.y and pos.z < mx.y:
			return i
	return -1


func set_region_owner(index: int, owner_id: int) -> void:
	regions[index]["owner"] = owner_id
	var overlay := get_node_or_null("RegionTint_%s" % String(regions[index]["id"])) as MeshInstance3D
	if overlay == null:
		return
	var mat := overlay.material_override as StandardMaterial3D
	if owner_id == 0:
		mat.albedo_color = Color(1, 1, 1, 0.04)
	else:
		var c := GameSession.color_of(owner_id)
		c.a = 0.12
		mat.albedo_color = c


func _dotted_lines() -> void:
	# Vertical (river) and two horizontals.
	_dash_line(Vector3(0, 0.2, -MAP_HALF), Vector3(0, 0.2, MAP_HALF), Color(1, 1, 1, 0.85))
	_dash_line(Vector3(-MAP_HALF, 0.2, 32), Vector3(MAP_HALF, 0.2, 32), Color(1, 1, 1, 0.8))
	_dash_line(Vector3(-MAP_HALF, 0.2, -32), Vector3(MAP_HALF, 0.2, -32), Color(1, 1, 1, 0.8))
	# Outer border
	var c := Color(0.95, 0.92, 0.7, 0.5)
	_dash_line(Vector3(-MAP_HALF, 0.2, -MAP_HALF), Vector3(MAP_HALF, 0.2, -MAP_HALF), c)
	_dash_line(Vector3(-MAP_HALF, 0.2, MAP_HALF), Vector3(MAP_HALF, 0.2, MAP_HALF), c)
	_dash_line(Vector3(-MAP_HALF, 0.2, -MAP_HALF), Vector3(-MAP_HALF, 0.2, MAP_HALF), c)
	_dash_line(Vector3(MAP_HALF, 0.2, -MAP_HALF), Vector3(MAP_HALF, 0.2, MAP_HALF), c)


func _dash_line(a: Vector3, b: Vector3, color: Color) -> void:
	var dir := b - a
	var length := dir.length()
	var n := dir.normalized()
	var step := 3.2
	var t := 0.0
	var dash := 1.7
	while t < length:
		var p := a + n * (t + dash * 0.5)
		var box := CSGBox3D.new()
		box.size = Vector3(0.35, 0.12, dash) if absf(n.x) < 0.5 else Vector3(dash, 0.12, 0.35)
		box.position = p
		box.material = UnitVisuals.mat(color, 0.0, 1.0)
		add_child(box)
		t += step


func _buildings() -> void:
	var specs := [
		{"pos": Vector3(-55, 0, 55), "size": Vector3(8, 7, 8), "floors": 2, "slots": 1, "name": "North Farmhouse"},
		{"pos": Vector3(-38, 0, 70), "size": Vector3(10, 9, 8), "floors": 2, "slots": 2, "name": "West Warehouse"},
		{"pos": Vector3(-50, 0, 6), "size": Vector3(7, 12, 7), "floors": 3, "slots": 1, "name": "Mid Tower"},
		{"pos": Vector3(-36, 0, -12), "size": Vector3(9, 6, 9), "floors": 2, "slots": 2, "name": "Depot"},
		{"pos": Vector3(-58, 0, -50), "size": Vector3(8, 7, 8), "floors": 2, "slots": 1, "name": "South Cottage"},
		{"pos": Vector3(-42, 0, -72), "size": Vector3(11, 8, 8), "floors": 2, "slots": 2, "name": "Barn"},
		{"pos": Vector3(52, 0, 58), "size": Vector3(8, 7, 8), "floors": 2, "slots": 1, "name": "East Farmhouse"},
		{"pos": Vector3(40, 0, 72), "size": Vector3(10, 10, 8), "floors": 3, "slots": 2, "name": "Office"},
		{"pos": Vector3(48, 0, 4), "size": Vector3(7, 13, 7), "floors": 3, "slots": 1, "name": "Radio Tower"},
		{"pos": Vector3(36, 0, -14), "size": Vector3(9, 6, 9), "floors": 2, "slots": 2, "name": "Garage"},
		{"pos": Vector3(56, 0, -52), "size": Vector3(8, 7, 8), "floors": 2, "slots": 1, "name": "Outpost"},
		{"pos": Vector3(40, 0, -70), "size": Vector3(11, 8, 8), "floors": 2, "slots": 2, "name": "Factory"},
	]
	var brick := Color(0.62, 0.48, 0.38)
	var concrete := Color(0.55, 0.55, 0.5)
	var i := 0
	for s in specs:
		var b := Building.new()
		var col: Color = brick if i % 2 == 0 else concrete
		b.position = s["pos"]
		b.build(_next_building, s["size"], s["floors"], s["slots"], col, s["name"])
		_next_building += 1
		add_child(b)
		pathfinder.set_blocked_world(b.global_position, b.footprint, true)
		i += 1


func _cliff_walls() -> void:
	# Choke walls near the river with gaps, plus flanking cliffs. Tanks can blast holes.
	_wall_run(Vector3(-22, 0, -22), Vector3(-22, 0, 22), 1) # west river cliff, gap at bridges via skip
	_wall_run(Vector3(22, 0, -22), Vector3(22, 0, 22), 1)
	_wall_run(Vector3(-70, 0, 28), Vector3(-24, 0, 28), 0)
	_wall_run(Vector3(24, 0, -28), Vector3(70, 0, -28), 0)
	_wall_run(Vector3(-18, 0, 50), Vector3(-18, 0, 78), 0)
	_wall_run(Vector3(18, 0, -78), Vector3(18, 0, -50), 0)


func _wall_run(from: Vector3, to: Vector3, skip_bridges: int) -> void:
	var dir := to - from
	var length := dir.length()
	var n := dir.normalized()
	var dist := 0.0
	while dist < length:
		var p := from + n * dist
		# Leave gaps at the two bridges.
		var near_bridge := absf(p.z - 40.0) < 8.0 or absf(p.z + 40.0) < 8.0
		if skip_bridges == 1 and near_bridge:
			dist += 3.4
			continue
		var jitter := Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))
		var size := Vector3(
			rng.randf_range(3.2, 4.4),
			rng.randf_range(5.5, 8.5),
			rng.randf_range(3.2, 4.6)
		)
		var shade := rng.randf_range(0.28, 0.42)
		var color := Color(shade, shade * 0.92, shade * 0.78)
		var w := WallSegment.new()
		w.position = p + jitter + Vector3(0, size.y * 0.5, 0)
		w.rotation_degrees.y = rng.randf_range(-12, 12)
		w.build(_next_wall, size, color)
		_next_wall += 1
		add_child(w)
		pathfinder.set_blocked_world(Vector3(w.global_position.x, 0, w.global_position.z), w.block_radius, true)
		dist += 3.35


func _trees() -> void:
	var count := 70
	var placed := 0
	var attempts := 0
	while placed < count and attempts < 400:
		attempts += 1
		var x := rng.randf_range(-MAP_HALF + 8, MAP_HALF - 8)
		var z := rng.randf_range(-MAP_HALF + 8, MAP_HALF - 8)
		if absf(x) < RIVER_HALF + 6.0:
			continue
		if Vector2(x + 78, z - 8).length() < 16.0 or Vector2(x - 78, z + 8).length() < 16.0:
			continue
		var too_close := false
		for n in get_children():
			if n is Building and n.global_position.distance_to(Vector3(x, 0, z)) < 10.0:
				too_close = true
				break
			if n is WallSegment and n.global_position.distance_to(Vector3(x, 0, z)) < 5.0:
				too_close = true
				break
		if too_close:
			continue
		_make_tree(Vector3(x, 0, z))
		placed += 1


func _make_tree(pos: Vector3) -> void:
	var t := Node3D.new()
	t.position = pos
	var h := rng.randf_range(3.5, 6.5)
	var trunk := CSGCylinder3D.new()
	trunk.radius = rng.randf_range(0.22, 0.38)
	trunk.height = h * 0.55
	trunk.position.y = trunk.height * 0.5
	trunk.sides = 6
	trunk.material = UnitVisuals.mat(Color(0.38, 0.24, 0.14), 0.0, 0.9)
	t.add_child(trunk)
	var leaves := CSGBox3D.new()
	var s := rng.randf_range(2.0, 3.4)
	leaves.size = Vector3(s, s * 0.9, s)
	leaves.position.y = h * 0.55 + s * 0.25
	leaves.rotation_degrees.y = rng.randf_range(0, 45)
	var g := rng.randf_range(0.22, 0.40)
	leaves.material = UnitVisuals.mat(Color(0.12, g, 0.14), 0.0, 0.85)
	t.add_child(leaves)
	add_child(t)


func _spawn_markers() -> void:
	for id in spawn_points.keys():
		var p: Vector3 = spawn_points[id]
		var pad := CSGCylinder3D.new()
		pad.radius = 6.0
		pad.height = 0.15
		pad.position = p + Vector3(0, 0.08, 0)
		var c := GameSession.color_of(int(id))
		c.a = 0.45
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pad.material = m
		add_child(pad)
