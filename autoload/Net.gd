extends Node

const DEFAULT_PORT := 7777
const MAX_CLIENTS := 1

signal lobby_changed
signal connection_failed(reason: String)
signal match_start_requested

var peer: ENetMultiplayerPeer
var pending_name: String = "Commander"


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host_game(player_name: String, port: int = DEFAULT_PORT) -> Error:
	pending_name = player_name
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		connection_failed.emit("Could not host on port %d" % port)
		return err
	multiplayer.multiplayer_peer = peer
	GameSession.begin_multiplayer_host(player_name)
	lobby_changed.emit()
	return OK


func join_game(player_name: String, ip: String, port: int = DEFAULT_PORT) -> Error:
	pending_name = player_name
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip.strip_edges(), port)
	if err != OK:
		connection_failed.emit("Could not connect to %s:%d" % [ip, port])
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func leave() -> void:
	if peer != null:
		peer.close()
	peer = null
	multiplayer.multiplayer_peer = null
	GameSession.mode = GameSession.Mode.NONE
	GameSession.reset_match_data()
	lobby_changed.emit()


func request_start_loadout() -> void:
	if not GameSession.is_server():
		return
	rpc("_rpc_goto_loadout")


func request_start_battle() -> void:
	if not GameSession.is_server():
		return
	if not _everyone_ready():
		return
	rpc("_rpc_goto_battle")


func set_local_loadout(kinds: Array[int], remaining: int, is_ready: bool) -> void:
	GameSession.loadouts[GameSession.local_id] = kinds.duplicate()
	GameSession.credits[GameSession.local_id] = remaining
	GameSession.ready_flags[GameSession.local_id] = is_ready
	if GameSession.is_server():
		rpc("_rpc_sync_session", _pack_session())
		if GameSession.is_skirmish() or _everyone_ready():
			pass
	else:
		rpc_id(1, "_rpc_client_loadout", kinds, remaining, is_ready)


func _everyone_ready() -> bool:
	var ids := GameSession.player_ids()
	if ids.size() < 2 and GameSession.mode == GameSession.Mode.MULTIPLAYER:
		return false
	for id in ids:
		if not bool(GameSession.ready_flags.get(id, false)):
			return false
	return true


func _on_peer_connected(id: int) -> void:
	if GameSession.is_server():
		# Wait for hello from client.
		lobby_changed.emit()
	else:
		pass


func _on_peer_disconnected(id: int) -> void:
	GameSession.player_names.erase(id)
	GameSession.credits.erase(id)
	GameSession.loadouts.erase(id)
	GameSession.ready_flags.erase(id)
	lobby_changed.emit()


func _on_connected_to_server() -> void:
	var id := multiplayer.get_unique_id()
	GameSession.begin_multiplayer_client(pending_name, id)
	rpc_id(1, "_rpc_hello", pending_name)


func _on_connection_failed() -> void:
	leave()
	connection_failed.emit("Connection failed.")


func _on_server_disconnected() -> void:
	leave()
	connection_failed.emit("Host disconnected.")
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


@rpc("any_peer", "reliable")
func _rpc_hello(player_name: String) -> void:
	if not GameSession.is_server():
		return
	var sid := multiplayer.get_remote_sender_id()
	GameSession.register_remote_player(sid, player_name)
	rpc("_rpc_sync_session", _pack_session())
	lobby_changed.emit()


@rpc("any_peer", "reliable")
func _rpc_client_loadout(kinds: Array, remaining: int, is_ready: bool) -> void:
	if not GameSession.is_server():
		return
	var sid := multiplayer.get_remote_sender_id()
	var typed: Array[int] = []
	for k in kinds:
		typed.append(int(k))
	GameSession.loadouts[sid] = typed
	GameSession.credits[sid] = remaining
	GameSession.ready_flags[sid] = is_ready
	rpc("_rpc_sync_session", _pack_session())


@rpc("authority", "call_local", "reliable")
func _rpc_sync_session(payload: Dictionary) -> void:
	_unpack_session(payload)
	lobby_changed.emit()


@rpc("authority", "call_local", "reliable")
func _rpc_goto_loadout() -> void:
	get_tree().change_scene_to_file("res://scenes/Loadout.tscn")


@rpc("authority", "call_local", "reliable")
func _rpc_goto_battle() -> void:
	match_start_requested.emit()
	get_tree().change_scene_to_file("res://scenes/Battle.tscn")


func _pack_session() -> Dictionary:
	var names := {}
	for k in GameSession.player_names.keys():
		names[str(int(k))] = GameSession.player_names[k]
	var cred := {}
	for k in GameSession.credits.keys():
		cred[str(int(k))] = int(GameSession.credits[k])
	var loads := {}
	for k in GameSession.loadouts.keys():
		loads[str(int(k))] = GameSession.loadouts[k]
	var ready := {}
	for k in GameSession.ready_flags.keys():
		ready[str(int(k))] = bool(GameSession.ready_flags[k])
	return {
		"names": names,
		"credits": cred,
		"loadouts": loads,
		"ready": ready,
	}


func _unpack_session(payload: Dictionary) -> void:
	GameSession.player_names.clear()
	for k in payload.get("names", {}).keys():
		GameSession.player_names[int(k)] = String(payload["names"][k])
	GameSession.credits.clear()
	for k in payload.get("credits", {}).keys():
		GameSession.credits[int(k)] = int(payload["credits"][k])
	GameSession.loadouts.clear()
	for k in payload.get("loadouts", {}).keys():
		var arr: Array[int] = []
		for v in payload["loadouts"][k]:
			arr.append(int(v))
		GameSession.loadouts[int(k)] = arr
	GameSession.ready_flags.clear()
	for k in payload.get("ready", {}).keys():
		GameSession.ready_flags[int(k)] = bool(payload["ready"][k])


func local_ips() -> PackedStringArray:
	var out: PackedStringArray = []
	for ip in IP.get_local_addresses():
		if ip.find(":") != -1:
			continue
		if ip.begins_with("127."):
			continue
		out.append(ip)
	return out
