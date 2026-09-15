class_name Pathfinder
extends Node

const CELL := 3.0

var grid: AStarGrid2D
var origin := Vector2(-96.0, -96.0)
var map_size := Vector2(192.0, 192.0)


func setup(p_origin: Vector2, p_size: Vector2) -> void:
	origin = p_origin
	map_size = p_size
	grid = AStarGrid2D.new()
	grid.region = Rect2i(0, 0, int(map_size.x / CELL), int(map_size.y / CELL))
	grid.cell_size = Vector2(CELL, CELL)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	grid.update()
	add_to_group("pathfinder")


func world_to_cell(pos: Vector3) -> Vector2i:
	var x := int(floor((pos.x - origin.x) / CELL))
	var y := int(floor((pos.z - origin.y) / CELL))
	return Vector2i(
		clampi(x, 0, grid.region.size.x - 1),
		clampi(y, 0, grid.region.size.y - 1)
	)


func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(
		origin.x + (cell.x + 0.5) * CELL,
		0.0,
		origin.y + (cell.y + 0.5) * CELL
	)


func _in_bounds(cell: Vector2i) -> bool:
	return grid.region.has_point(cell)


func set_blocked_world(pos: Vector3, radius: float, blocked: bool) -> void:
	var r := int(ceil(radius / CELL))
	var c := world_to_cell(pos)
	for x in range(c.x - r, c.x + r + 1):
		for y in range(c.y - r, c.y + r + 1):
			var cell := Vector2i(x, y)
			if _in_bounds(cell):
				var w := cell_to_world(cell)
				if Vector2(w.x - pos.x, w.z - pos.z).length() <= radius + CELL * 0.4:
					grid.set_point_solid(cell, blocked)


func set_blocked_rect(min_xz: Vector2, max_xz: Vector2, blocked: bool) -> void:
	var a := world_to_cell(Vector3(min_xz.x, 0, min_xz.y))
	var b := world_to_cell(Vector3(max_xz.x, 0, max_xz.y))
	var x0 := mini(a.x, b.x)
	var x1 := maxi(a.x, b.x)
	var y0 := mini(a.y, b.y)
	var y1 := maxi(a.y, b.y)
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			var cell := Vector2i(x, y)
			if _in_bounds(cell):
				grid.set_point_solid(cell, blocked)


func is_blocked(pos: Vector3) -> bool:
	var c := world_to_cell(pos)
	return grid.is_point_solid(c)


func _nearest_walkable(cell: Vector2i) -> Vector2i:
	if _in_bounds(cell) and not grid.is_point_solid(cell):
		return cell
	for r in range(1, 18):
		for x in range(cell.x - r, cell.x + r + 1):
			for y in range(cell.y - r, cell.y + r + 1):
				var c := Vector2i(x, y)
				if _in_bounds(c) and not grid.is_point_solid(c):
					return c
	return cell


func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var a := _nearest_walkable(world_to_cell(from))
	var b := _nearest_walkable(world_to_cell(to))
	var ids := grid.get_id_path(a, b)
	var out := PackedVector3Array()
	for id in ids:
		out.append(cell_to_world(id))
	if out.size() > 0 and not is_blocked(to):
		out[out.size() - 1] = Vector3(to.x, 0.0, to.z)
	return out
