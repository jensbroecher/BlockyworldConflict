extends Node

enum Mode { NONE, SKIRMISH, MULTIPLAYER }

const PLAYER_COLORS := {
	1: Color(0.22, 0.48, 0.95),
	2: Color(0.90, 0.22, 0.18),
}

var mode: Mode = Mode.NONE
var local_id: int = 1
var ai_id: int = 2
var player_names: Dictionary = {} ## int -> String
var credits: Dictionary = {} ## int -> float
var loadouts: Dictionary = {} ## int -> Array[int] kinds
var ready_flags: Dictionary = {} ## int -> bool
var region_owners: Dictionary = {} ## String -> int  (0 = neutral)
var match_over: bool = false
var winner_id: int = 0


func _ready() -> void:
	_ensure_actions()
	reset_match_data()


func reset_match_data() -> void:
	match_over = false
	winner_id = 0
	region_owners.clear()
	credits.clear()
	loadouts.clear()
	ready_flags.clear()
	player_names.clear()


func begin_skirmish(player_name: String) -> void:
	reset_match_data()
	mode = Mode.SKIRMISH
	local_id = 1
	ai_id = 2
	var peer := OfflineMultiplayerPeer.new()
	multiplayer.multiplayer_peer = peer
	player_names[1] = player_name if player_name.strip_edges() != "" else "Commander"
	player_names[2] = "AI Opponent"
	credits[1] = UnitDB.STARTING_CREDITS
	credits[2] = UnitDB.STARTING_CREDITS
	loadouts[1] = []
	loadouts[2] = []
	ready_flags[1] = false
	ready_flags[2] = true
	_ai_pick_loadout()


func begin_multiplayer_host(player_name: String) -> void:
	reset_match_data()
	mode = Mode.MULTIPLAYER
	local_id = 1
	player_names[1] = player_name if player_name.strip_edges() != "" else "Host"
	credits[1] = UnitDB.STARTING_CREDITS
	loadouts[1] = []
	ready_flags[1] = false


func begin_multiplayer_client(player_name: String, peer_id: int) -> void:
	reset_match_data()
	mode = Mode.MULTIPLAYER
	local_id = peer_id
	player_names[peer_id] = player_name if player_name.strip_edges() != "" else "Guest"
	credits[peer_id] = UnitDB.STARTING_CREDITS
	loadouts[peer_id] = []
	ready_flags[peer_id] = false


func register_remote_player(peer_id: int, player_name: String) -> void:
	player_names[peer_id] = player_name
	credits[peer_id] = UnitDB.STARTING_CREDITS
	loadouts[peer_id] = []
	ready_flags[peer_id] = false


func opponent_id() -> int:
	if mode == Mode.SKIRMISH:
		return ai_id if local_id == 1 else local_id
	for id in player_names.keys():
		if int(id) != local_id:
			return int(id)
	return 0


func player_ids() -> Array[int]:
	var out: Array[int] = []
	if mode == Mode.SKIRMISH:
		out.append(1)
		out.append(2)
		return out
	for id in player_names.keys():
		out.append(int(id))
	out.sort()
	return out


func color_of(player_id: int) -> Color:
	if player_id == 1:
		return PLAYER_COLORS[1]
	return PLAYER_COLORS[2]


func is_server() -> bool:
	if multiplayer.multiplayer_peer == null:
		return true
	return multiplayer.is_server()


func is_skirmish() -> bool:
	return mode == Mode.SKIRMISH


func get_credits(player_id: int) -> int:
	return int(floor(float(credits.get(player_id, 0.0))))


func set_credits(player_id: int, amount: int) -> void:
	credits[player_id] = float(maxi(0, amount))


func add_credits(player_id: int, amount: float) -> void:
	credits[player_id] = maxf(0.0, float(credits.get(player_id, 0.0)) + amount)


func try_spend(player_id: int, cost: int) -> bool:
	if get_credits(player_id) < cost:
		return false
	credits[player_id] = float(credits.get(player_id, 0.0)) - float(cost)
	return true


func army_value_cap_ok(player_id: int, extra: int) -> bool:
	return extra <= UnitDB.MAX_ARMY


func _ai_pick_loadout() -> void:
	var bag: Array[int] = []
	var money := UnitDB.STARTING_CREDITS
	var plan: Array[int] = [
		UnitDB.Kind.SOLDIER_SQUAD,
		UnitDB.Kind.SOLDIER_SQUAD,
		UnitDB.Kind.JEEP,
		UnitDB.Kind.IFV,
		UnitDB.Kind.TANK,
		UnitDB.Kind.ARTILLERY,
		UnitDB.Kind.SOLDIER_SQUAD,
	]
	for k in plan:
		var c := UnitDB.cost(k)
		if money >= c:
			bag.append(k)
			money -= c
	if money >= UnitDB.cost(UnitDB.Kind.JEEP):
		bag.append(UnitDB.Kind.JEEP)
		money -= UnitDB.cost(UnitDB.Kind.JEEP)
	loadouts[2] = bag
	credits[2] = money


func _ensure_actions() -> void:
	_key("cam_forward", KEY_W)
	_key("cam_back", KEY_S)
	_key("cam_left", KEY_A)
	_key("cam_right", KEY_D)
	_key("cam_rot_left", KEY_Q)
	_key("cam_rot_right", KEY_E)
	_key("shop", KEY_B)
	_key("garrison", KEY_G)
	_key("stop", KEY_H)
	_key("pause_menu", KEY_ESCAPE)
	_mouse("select", MOUSE_BUTTON_LEFT)
	_mouse("command", MOUSE_BUTTON_RIGHT)
	_mouse("cam_pan", MOUSE_BUTTON_MIDDLE)


func _key(action: String, key: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == key:
			return
	var e := InputEventKey.new()
	e.physical_keycode = key as Key
	InputMap.action_add_event(action, e)


func _mouse(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for ev in InputMap.action_get_events(action):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == button:
			return
	var e := InputEventMouseButton.new()
	e.button_index = button as MouseButton
	InputMap.action_add_event(action, e)
