extends Control

var _name_edit: LineEdit
var _ip_edit: LineEdit
var _status: Label
var _preview_root: Node3D


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_build_preview()
	Net.connection_failed.connect(_on_fail)
	Net.lobby_changed.connect(_on_lobby)


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.09, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var panel := VBoxContainer.new()
	panel.position = Vector2(80, 80)
	panel.custom_minimum_size = Vector2(520, 800)
	panel.add_theme_constant_override("separation", 12)
	add_child(panel)
	var title := Label.new()
	title.text = "BLOCKYWORLD\nCONFLICT"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.85, 0.9, 0.55))
	panel.add_child(title)
	var sub := Label.new()
	sub.text = "A blocky 1v1 RTS  ·  seize regions, blast the cliffs, hold the map"
	sub.add_theme_color_override("font_color", Color(0.7, 0.75, 0.6))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(sub)
	panel.add_child(_spacer(16))
	var nl := Label.new()
	nl.text = "Callsign"
	panel.add_child(nl)
	_name_edit = LineEdit.new()
	_name_edit.text = "Commander"
	_name_edit.custom_minimum_size.y = 36
	panel.add_child(_name_edit)
	panel.add_child(_spacer(8))
	panel.add_child(_btn("Skirmish vs AI", _skirmish))
	panel.add_child(_spacer(12))
	panel.add_child(_btn("Host LAN match", _host))
	var ip_row := HBoxContainer.new()
	ip_row.add_theme_constant_override("separation", 8)
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "Host IP"
	_ip_edit.text = "127.0.0.1"
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_row.add_child(_ip_edit)
	var join := Button.new()
	join.text = "Join LAN"
	join.custom_minimum_size = Vector2(140, 40)
	join.pressed.connect(_join)
	ip_row.add_child(join)
	panel.add_child(ip_row)
	panel.add_child(_spacer(16))
	panel.add_child(_btn("Quit", func() -> void: get_tree().quit()))
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(0.95, 0.55, 0.4))
	panel.add_child(_status)
	var tips := Label.new()
	tips.text = "Own every region (majority unit value) to win.\nSoldiers seize buildings. Tanks and artillery punch through rock walls.\nCredits refill during battle — press B to order more units."
	tips.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tips.add_theme_color_override("font_color", Color(0.65, 0.7, 0.58))
	tips.position = Vector2(80, 980)
	add_child(tips)


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(cb)
	return b


func _player_name() -> String:
	var n := _name_edit.text.strip_edges()
	return n if n != "" else "Commander"


func _skirmish() -> void:
	GameSession.begin_skirmish(_player_name())
	get_tree().change_scene_to_file("res://scenes/Loadout.tscn")


func _host() -> void:
	var err := Net.host_game(_player_name())
	if err != OK:
		_status.text = "Failed to host."
		return
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")


func _join() -> void:
	var err := Net.join_game(_player_name(), _ip_edit.text)
	if err != OK:
		_status.text = "Failed to join."
		return
	_status.text = "Connecting..."
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")


func _on_fail(reason: String) -> void:
	_status.text = reason


func _on_lobby() -> void:
	pass


func _build_preview() -> void:
	var wrap := SubViewportContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.stretch = true
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Keep UI on top: add preview first? We already added UI. Put preview behind by moving.
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.size = Vector2i(1920, 1080)
	wrap.add_child(vp)
	add_child(wrap)
	move_child(wrap, 1)
	var world := Node3D.new()
	vp.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 30, 0)
	world.add_child(light)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 6, 14)
	world.add_child(cam)
	cam.look_at(Vector3(0, 1, 0))
	_preview_root = Node3D.new()
	world.add_child(_preview_root)
	var kinds := [UnitDB.Kind.TANK, UnitDB.Kind.HELICOPTER, UnitDB.Kind.REPAIR_TRUCK, UnitDB.Kind.IFV, UnitDB.Kind.SOLDIER_SQUAD, UnitDB.Kind.MLRS]
	for i in kinds.size():
		var vis: Node3D = UnitVisuals.build(kinds[i], 1 if i % 2 == 0 else 2)
		vis.position = Vector3(-8 + i * 4.2, 0, 0)
		_preview_root.add_child(vis)
	var ground := CSGBox3D.new()
	ground.size = Vector3(40, 0.4, 12)
	ground.position.y = -0.2
	ground.material = UnitVisuals.mat(Color(0.28, 0.38, 0.2), 0.0, 1.0)
	world.add_child(ground)


func _process(delta: float) -> void:
	if _preview_root:
		_preview_root.rotate_y(delta * 0.25)
		for c in _preview_root.get_children():
			for ch in c.get_children():
				if ch.has_meta("spin"):
					ch.rotate_y(float(ch.get_meta("spin")) * delta)
