extends Control

var _list: VBoxContainer
var _info: Label
var _start_btn: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.09, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.position = Vector2(80, 80)
	box.custom_minimum_size = Vector2(640, 700)
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var title := Label.new()
	title.text = "LAN LOBBY"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.85, 0.9, 0.55))
	box.add_child(title)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_info)
	_list = VBoxContainer.new()
	box.add_child(_list)
	_start_btn = Button.new()
	_start_btn.text = "Continue to loadout"
	_start_btn.custom_minimum_size.y = 44
	_start_btn.pressed.connect(_continue)
	box.add_child(_start_btn)
	var back := Button.new()
	back.text = "Leave"
	back.pressed.connect(_leave)
	box.add_child(back)
	Net.lobby_changed.connect(_refresh)
	Net.connection_failed.connect(_on_fail)
	_refresh()


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var ips := ", ".join(Net.local_ips())
	if GameSession.is_server():
		_info.text = "Hosting on port %d\nYour LAN IP: %s\nWaiting for one opponent." % [Net.DEFAULT_PORT, ips]
	else:
		_info.text = "Connected to host. Waiting to start."
	for id in GameSession.player_ids():
		var row := Label.new()
		row.text = "• %s  (id %d)  %s" % [
			String(GameSession.player_names.get(id, "?")),
			id,
			"HOST" if id == 1 else "GUEST"
		]
		row.add_theme_font_size_override("font_size", 18)
		row.add_theme_color_override("font_color", GameSession.color_of(id))
		_list.add_child(row)
	_start_btn.visible = GameSession.is_server()
	_start_btn.disabled = GameSession.player_ids().size() < 2


func _continue() -> void:
	if GameSession.player_ids().size() < 2:
		return
	Net.request_start_loadout()


func _leave() -> void:
	Net.leave()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _on_fail(reason: String) -> void:
	_info.text = reason
