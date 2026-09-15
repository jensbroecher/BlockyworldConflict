class_name CommanderAI
extends Node

var player_id: int = 2
var battle: Node = null
var _t: float = 0.0
var _buy_t: float = 2.0


func _process(delta: float) -> void:
	if not GameSession.is_server() or GameSession.match_over:
		return
	if battle == null:
		return
	_t += delta
	_buy_t -= delta
	if _t < 1.15:
		return
	_t = 0.0
	_command_units()
	if _buy_t <= 0.0:
		_buy_t = 3.5
		_try_buy()


func _command_units() -> void:
	var mine: Array[Unit] = []
	for n in get_tree().get_nodes_in_group("units"):
		var u := n as Unit
		if u and u.owner_id == player_id and u.hp > 0.0:
			mine.append(u)
	if mine.is_empty():
		return
	var map := battle.map as BattleMap
	var focus := _target_region(map)
	var enemy := _nearest_enemy_to(mine[0].global_position)
	for u in mine:
		if u.garrison_building:
			continue
		if bool(u.stats["can_garrison"]):
			var b := _nearby_building(u)
			if b:
				u.order_move(b.global_position, null, b)
				continue
		if enemy and u.global_position.distance_to(enemy.global_position) < u.current_range() * 1.6:
			u.order_move(enemy.global_position, enemy, null)
			continue
		if u.path_i >= u.path.size():
			var dest: Vector3 = focus + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
			u.order_move(dest, null, null)


func _target_region(map: BattleMap) -> Vector3:
	# Prefer unowned or enemy regions closest to AI spawn.
	var slot := 1 if player_id == 1 else 2
	var spawn: Vector3 = map.spawn_points.get(slot, Vector3(78, 0, 0))
	var best := spawn
	var best_score := -9999.0
	for r in map.regions:
		var owner: int = int(r["owner"])
		var center: Vector3 = r["center"]
		var score := 0.0
		if owner == 0:
			score += 40.0
		elif owner != player_id:
			score += 55.0
		else:
			score += 5.0
		score -= spawn.distance_to(center) * 0.15
		if score > best_score:
			best_score = score
			best = center
	return best


func _nearest_enemy_to(pos: Vector3) -> Unit:
	var best: Unit = null
	var best_d := 48.0
	for n in get_tree().get_nodes_in_group("units"):
		var u := n as Unit
		if u == null or u.owner_id == player_id or u.hp <= 0.0:
			continue
		var d := pos.distance_to(u.global_position)
		if d < best_d:
			best_d = d
			best = u
	return best


func _nearby_building(u: Unit) -> Building:
	for n in get_tree().get_nodes_in_group("buildings"):
		var b := n as Building
		if b == null:
			continue
		if u.global_position.distance_to(b.global_position) < 18.0 and b.can_seize(player_id):
			return b
	return null


func _try_buy() -> void:
	var credits := GameSession.get_credits(player_id)
	var army := 0
	for n in get_tree().get_nodes_in_group("units"):
		if n is Unit and (n as Unit).owner_id == player_id:
			army += 1
	if army >= UnitDB.MAX_ARMY:
		return
	var choice := _choose_kind(credits)
	if choice < 0:
		return
	battle.server_buy_unit(player_id, choice)


func _choose_kind(credits: int) -> int:
	var options: Array[int] = []
	if credits >= 100:
		options.append(UnitDB.Kind.SOLDIER_SQUAD)
	if credits >= 150:
		options.append(UnitDB.Kind.JEEP)
	if credits >= 250:
		options.append(UnitDB.Kind.IFV)
	if credits >= 400:
		options.append(UnitDB.Kind.TANK)
	if credits >= 350:
		options.append(UnitDB.Kind.ARTILLERY)
	if credits >= 450:
		options.append(UnitDB.Kind.HELICOPTER)
	if credits >= 500:
		options.append(UnitDB.Kind.MLRS)
	if options.is_empty():
		return -1
	# Bias toward tanks / IFV if we can afford them.
	if options.has(UnitDB.Kind.TANK) and randf() < 0.35:
		return UnitDB.Kind.TANK
	if options.has(UnitDB.Kind.IFV) and randf() < 0.3:
		return UnitDB.Kind.IFV
	if options.has(UnitDB.Kind.SOLDIER_SQUAD) and randf() < 0.25:
		return UnitDB.Kind.SOLDIER_SQUAD
	return options[randi() % options.size()]
