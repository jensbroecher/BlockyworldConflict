extends Control

var _shop: ShopPanel
var _status: Label
var _opp: Label
var _started := false


func _ready() -> void:
	if GameSession.mode == GameSession.Mode.NONE:
		GameSession.begin_skirmish("Commander")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.09, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title := Label.new()
	title.text = "STARTING FORCE"
	title.position = Vector2(80, 40)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.85, 0.9, 0.55))
	add_child(title)
	_opp = Label.new()
	_opp.position = Vector2(80, 90)
	_opp.add_theme_font_size_override("font_size", 18)
	add_child(_opp)
	_shop = ShopPanel.new()
	_shop.loadout_mode = true
	_shop.position = Vector2(80, 140)
	_shop.cart_changed.connect(_on_cart)
	_shop.ready_toggled.connect(_on_ready)
	_shop.start_skirmish.connect(_start_skirmish)
	add_child(_shop)
	_status = Label.new()
	_status.position = Vector2(540, 160)
	_status.add_theme_font_size_override("font_size", 18)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.size = Vector2(500, 400)
	add_child(_status)
	var back := Button.new()
	back.text = "Back"
	back.position = Vector2(80, 1000)
	back.pressed.connect(_back)
	add_child(back)
	Net.lobby_changed.connect(_refresh_status)
	_push_loadout(false)
	_refresh_status()


func _on_cart(_kinds: Array, _remaining: int) -> void:
	_push_loadout(_shop.ready_on)


func _on_ready(is_ready: bool) -> void:
	_push_loadout(is_ready)


func _push_loadout(is_ready: bool) -> void:
	Net.set_local_loadout(_shop.cart, _shop.remaining, is_ready)


func _start_skirmish() -> void:
	if _shop.cart.is_empty():
		_status.text = "Buy at least one unit before deploying."
		return
	_shop.ready_on = true
	_push_loadout(true)
	get_tree().change_scene_to_file("res://scenes/Battle.tscn")


func _process(_delta: float) -> void:
	if _started or GameSession.is_skirmish():
		return
	if not GameSession.is_server():
		return
	if _everyone_ready():
		_started = true
		Net.request_start_battle()


func _everyone_ready() -> bool:
	var ids := GameSession.player_ids()
	if ids.size() < 2:
		return false
	for id in ids:
		if not bool(GameSession.ready_flags.get(id, false)):
			return false
		var bag: Array = GameSession.loadouts.get(id, [])
		if bag.is_empty():
			return false
	return true


func _refresh_status() -> void:
	var bits: PackedStringArray = []
	for id in GameSession.player_ids():
		var ready := "READY" if bool(GameSession.ready_flags.get(id, false)) else "planning"
		var n := 0
		var bag: Array = GameSession.loadouts.get(id, [])
		n = bag.size()
		bits.append("%s — %s (%d units, %d cr)" % [
			String(GameSession.player_names.get(id, "?")),
			ready,
			n,
			GameSession.get_credits(id),
		])
	if GameSession.is_skirmish():
		_opp.text = "Opponent: AI  ·  They already picked a starting force."
		_status.text = "Fill your cart, then Start battle.\nLeftover credits stay with you in the field.\n\n" + "\n".join(bits)
	else:
		_opp.text = "Both commanders must ready up. Host starts the battle automatically."
		_status.text = "\n".join(bits)


func _back() -> void:
	if GameSession.mode == GameSession.Mode.MULTIPLAYER:
		Net.leave()
	else:
		multiplayer.multiplayer_peer = null
		GameSession.mode = GameSession.Mode.NONE
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
