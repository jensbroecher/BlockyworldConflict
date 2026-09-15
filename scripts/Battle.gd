extends Node3D

var map: BattleMap
var camera: RTSCamera
var hud: HUD
var units_root: Node3D

var selected: Array[Unit] = []
var _boxing := false
var _box_start := Vector2.ZERO
var _next_unit := 1
var _spawn_queue: Array[Dictionary] = []
var _hold_win := 0.0
var _sync_t := 0.0
var _region_t := 0.0


func _ready() -> void:
	if GameSession.mode == GameSession.Mode.NONE:
		GameSession.begin_skirmish("Commander")
		GameSession.loadouts[1] = [
			UnitDB.Kind.SOLDIER_SQUAD, UnitDB.Kind.SOLDIER_SQUAD,
			UnitDB.Kind.JEEP, UnitDB.Kind.IFV, UnitDB.Kind.TANK,
		]
	map = BattleMap.new()
	map.name = "Map"
	add_child(map)
	map.build()
	units_root = Node3D.new()
	units_root.name = "Units"
	add_child(units_root)
	camera = RTSCamera.new()
	camera.name = "RTSCamera"
	add_child(camera)
	var focus: Vector3 = map.spawn_points[_spawn_slot(GameSession.local_id)]
	camera.focus(focus)
	hud = HUD.new()
	hud.battle = self
	hud.shop_buy.connect(_on_shop_buy)
	hud.leave_match.connect(_leave)
	add_child(hud)
	if GameSession.is_server():
		call_deferred("_spawn_loadouts")
	if GameSession.is_skirmish() and GameSession.is_server():
		var ai := CommanderAI.new()
		ai.name = "AI"
		ai.battle = self
		ai.player_id = GameSession.ai_id
		add_child(ai)
	GameSession.match_over = false


func _spawn_loadouts() -> void:
	for pid in GameSession.player_ids():
		var bag: Array = GameSession.loadouts.get(pid, [])
		var i := 0
		for k in bag:
			server_spawn_unit(int(k), int(pid), _slot_pos(int(pid), i), 0.0)
			i += 1


func _spawn_slot(pid: int) -> int:
	return 1 if pid == 1 else 2


func _slot_pos(pid: int, i: int) -> Vector3:
	var base: Vector3 = map.spawn_points[_spawn_slot(pid)]
	var cols := 5
	return base + Vector3(float(i % cols) * 4.6 - 9.0, 0.0, float(int(i / cols)) * 4.6)


func server_spawn_unit(kind: int, owner_id: int, pos: Vector3, delay: float) -> void:
	if not GameSession.is_server():
		return
	if delay > 0.0:
		_spawn_queue.append({"kind": kind, "owner": owner_id, "pos": pos, "t": delay})
		return
	var uname := "U%d" % _next_unit
	_next_unit += 1
	rpc("_rpc_spawn_unit", kind, owner_id, pos, uname)


@rpc("authority", "call_local", "reliable")
func _rpc_spawn_unit(kind: int, owner_id: int, pos: Vector3, uname: String) -> void:
	var u := Unit.new()
	u.name = uname
	units_root.add_child(u, true)
	u.setup(kind, owner_id)
	u.global_position = pos
	if u.is_air():
		u.global_position.y = float(u.stats["fly_height"])
	else:
		u.global_position.y = 0.08
	u.died.connect(_on_unit_died)


func server_buy_unit(player_id: int, kind: int) -> void:
	if not GameSession.is_server() or GameSession.match_over:
		return
	var cost := UnitDB.cost(kind)
	if GameSession.get_credits(player_id) < cost:
		return
	if _army_count(player_id) >= UnitDB.MAX_ARMY:
		return
	GameSession.set_credits(player_id, GameSession.get_credits(player_id) - cost)
	var n := _army_count(player_id)
	server_spawn_unit(kind, player_id, _slot_pos(player_id, n), 2.2)
	_sync_economy()


func _army_count(player_id: int) -> int:
	var n := 0
	for u in units_root.get_children():
		if u is Unit and (u as Unit).owner_id == player_id:
			n += 1
	for q in _spawn_queue:
		if int(q["owner"]) == player_id:
			n += 1
	return n


func _on_shop_buy(kind: int) -> void:
	if GameSession.is_server():
		server_buy_unit(GameSession.local_id, kind)
	else:
		rpc_id(1, "_rpc_buy", kind)


@rpc("any_peer", "reliable")
func _rpc_buy(kind: int) -> void:
	if not GameSession.is_server():
		return
	var sid := multiplayer.get_remote_sender_id()
	server_buy_unit(sid, kind)


func _process(delta: float) -> void:
	if GameSession.is_server() and not GameSession.match_over:
		_tick_economy(delta)
		_tick_queue(delta)
		_region_t += delta
		if _region_t >= 0.45:
			_region_t = 0.0
			_tick_regions()
		_check_win(delta)
		_sync_t += delta
		if _sync_t >= 0.3:
			_sync_t = 0.0
			_sync_economy()
	var owned := _owned_count(GameSession.local_id)
	var inc := UnitDB.BASE_INCOME + float(owned) * UnitDB.REGION_INCOME
	hud.refresh(GameSession.get_credits(GameSession.local_id), owned, map.regions.size(), inc, selected)
	_prune_selected()


func _tick_economy(delta: float) -> void:
	for pid in GameSession.player_ids():
		var inc := UnitDB.BASE_INCOME + float(_owned_count(pid)) * UnitDB.REGION_INCOME
		GameSession.add_credits(pid, inc * delta)


func _tick_queue(delta: float) -> void:
	var i := 0
	while i < _spawn_queue.size():
		_spawn_queue[i]["t"] = float(_spawn_queue[i]["t"]) - delta
		if float(_spawn_queue[i]["t"]) <= 0.0:
			var item: Dictionary = _spawn_queue[i]
			_spawn_queue.remove_at(i)
			server_spawn_unit(int(item["kind"]), int(item["owner"]), item["pos"], 0.0)
		else:
			i += 1


func _tick_regions() -> void:
	var totals: Array[Dictionary] = []
	for _i in map.regions.size():
		totals.append({})
	for n in get_tree().get_nodes_in_group("units"):
		var u := n as Unit
		if u == null or u.hp <= 0.0:
			continue
		var idx := map.region_at(u.global_position)
		if idx < 0:
			continue
		var pid := u.owner_id
		totals[idx][pid] = int(totals[idx].get(pid, 0)) + u.unit_value()
	for i in map.regions.size():
		var best_id := 0
		var best_v := 0
		var second := 0
		for k in totals[i].keys():
			var v: int = int(totals[i][k])
			if v > best_v:
				second = best_v
				best_v = v
				best_id = int(k)
			elif v > second:
				second = v
		if best_v <= 0 or best_v == second:
			continue
		if int(map.regions[i]["owner"]) != best_id:
			rpc("_rpc_region_owner", i, best_id)


@rpc("authority", "call_local", "reliable")
func _rpc_region_owner(index: int, owner_id: int) -> void:
	if index < 0 or index >= map.regions.size():
		return
	map.set_region_owner(index, owner_id)
	GameSession.region_owners[String(map.regions[index]["id"])] = owner_id


func _owned_count(player_id: int) -> int:
	var n := 0
	for r in map.regions:
		if int(r["owner"]) == player_id:
			n += 1
	return n


func _check_win(delta: float) -> void:
	var total := map.regions.size()
	var winner := 0
	for pid in GameSession.player_ids():
		if _owned_count(pid) == total:
			winner = pid
			break
	if winner == 0:
		_hold_win = 0.0
		return
	_hold_win += delta
	if _hold_win >= UnitDB.HOLD_WIN_SECONDS:
		rpc("_rpc_match_over", winner)


@rpc("authority", "call_local", "reliable")
func _rpc_match_over(winner: int) -> void:
	GameSession.match_over = true
	GameSession.winner_id = winner
	var name := String(GameSession.player_names.get(winner, "Player %d" % winner))
	hud.show_winner("%s controls the map!" % name, GameSession.color_of(winner))
	get_tree().create_timer(6.0).timeout.connect(_leave)


func _sync_economy() -> void:
	var ids := GameSession.player_ids()
	var a := ids[0] if ids.size() > 0 else 1
	var b := ids[1] if ids.size() > 1 else 0
	rpc("_rpc_credits", a, GameSession.get_credits(a), b, GameSession.get_credits(b))


@rpc("authority", "call_local", "unreliable")
func _rpc_credits(id_a: int, c_a: int, id_b: int, c_b: int) -> void:
	GameSession.set_credits(id_a, c_a)
	if id_b != 0:
		GameSession.set_credits(id_b, c_b)


func _on_unit_died(u: Unit) -> void:
	selected.erase(u)


func _prune_selected() -> void:
	selected = selected.filter(func(u: Unit) -> bool: return is_instance_valid(u) and u.hp > 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if GameSession.match_over:
		return
	if event.is_action_pressed("shop"):
		hud.toggle_shop()
		return
	if event.is_action_pressed("pause_menu"):
		if hud._shop.visible:
			hud.toggle_shop()
		return
	if hud.over_ui or hud._shop.visible:
		return
	if event.is_action_pressed("garrison"):
		_order_garrison()
		return
	if event.is_action_pressed("stop"):
		for u in selected:
			u.order_stop()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_boxing = true
				_box_start = mb.position
			else:
				_finish_box(mb.position, mb.shift_pressed)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_issue_command()


func _finish_box(end: Vector2, additive: bool) -> void:
	_boxing = false
	hud.set_box(Rect2(), false)
	var rect := Rect2(_box_start, end - _box_start).abs()
	if rect.size.length() < 12.0:
		_click_select(additive)
		return
	if not additive:
		_clear_select()
	for n in get_tree().get_nodes_in_group("units"):
		var u := n as Unit
		if u == null or u.owner_id != GameSession.local_id:
			continue
		var sp := camera.cam.unproject_position(u.aim_point())
		if rect.has_point(sp):
			_add_select(u)


func _click_select(additive: bool) -> void:
	var hit := camera.ray_query(2)
	var u: Unit = null
	if hit and hit.collider is Unit:
		u = hit.collider as Unit
	if u and u.owner_id == GameSession.local_id:
		if not additive:
			_clear_select()
		_add_select(u)
	elif not additive:
		_clear_select()


func _clear_select() -> void:
	for u in selected:
		if is_instance_valid(u):
			u.selected = false
	selected.clear()


func _add_select(u: Unit) -> void:
	if selected.has(u):
		return
	u.selected = true
	selected.append(u)


func _issue_command() -> void:
	if selected.is_empty():
		return
	var hit := camera.ray_query(2 | 8 | 16)
	var enemy: Unit = null
	var building: Building = null
	if hit:
		if hit.collider is Unit and (hit.collider as Unit).owner_id != GameSession.local_id:
			enemy = hit.collider as Unit
		elif hit.collider is Building:
			building = hit.collider as Building
	var dest := camera.ground_point()
	if hit:
		dest = hit.position
	if building and _any_can_garrison():
		_order_garrison_to(building)
		return
	_order_move(dest, enemy)


func _any_can_garrison() -> bool:
	for u in selected:
		if bool(u.stats.get("can_garrison", false)):
			return true
	return false


func _order_move(dest: Vector3, enemy: Unit) -> void:
	var n := selected.size()
	var cols := maxi(ceili(sqrt(float(n))), 1)
	var i := 0
	for u in selected:
		var ox := float(i % cols) * 4.2 - float(cols) * 2.0
		var oz := float(int(i / cols)) * 4.2
		u.order_move(dest + Vector3(ox, 0, oz), enemy, null)
		i += 1


func _order_garrison() -> void:
	var b := _closest_building_for_selected()
	if b:
		_order_garrison_to(b)


func _order_garrison_to(b: Building) -> void:
	for u in selected:
		if bool(u.stats.get("can_garrison", false)):
			u.order_move(b.global_position, null, b)


func _closest_building_for_selected() -> Building:
	if selected.is_empty():
		return null
	var origin := selected[0].global_position
	var best: Building = null
	var best_d := 22.0
	for n in get_tree().get_nodes_in_group("buildings"):
		var b := n as Building
		if b == null:
			continue
		var d := origin.distance_to(b.global_position)
		if d < best_d and b.can_seize(GameSession.local_id):
			best_d = d
			best = b
	return best


func _leave() -> void:
	if GameSession.mode == GameSession.Mode.MULTIPLAYER:
		Net.leave()
	else:
		multiplayer.multiplayer_peer = null
		GameSession.mode = GameSession.Mode.NONE
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _physics_process(_delta: float) -> void:
	if _boxing:
		var end := get_viewport().get_mouse_position()
		hud.set_box(Rect2(_box_start, end - _box_start).abs(), true)
