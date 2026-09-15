class_name HUD
extends CanvasLayer

signal shop_buy(kind: int)
signal shop_closed
signal leave_match

var over_ui: bool = false

var _credits: Label
var _regions: Label
var _income: Label
var _select_info: Label
var _help: Label
var _groups_lbl: Label
var _banner: Label
var _minimap: Control
var _box: ColorRect
var _shop: ShopPanel
var _shop_btn: Button
var battle: Node = null


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_top_bar(root)
	_select_info = Label.new()
	_select_info.position = Vector2(20, 1080 - 160)
	_select_info.add_theme_font_size_override("font_size", 16)
	_select_info.add_theme_color_override("font_color", Color(0.92, 0.95, 0.85))
	root.add_child(_select_info)
	_help = Label.new()
	_help.position = Vector2(20, 70)
	_help.text = "LMB select  ·  RMB move/attack  ·  Ctrl+1-9 group  ·  1-9 select  ·  double-tap jump  ·  G garrison  ·  H stop  ·  B shop"
	_help.add_theme_font_size_override("font_size", 14)
	_help.add_theme_color_override("font_color", Color(0.8, 0.85, 0.7, 0.8))
	root.add_child(_help)
	_groups_lbl = Label.new()
	_groups_lbl.position = Vector2(20, 92)
	_groups_lbl.add_theme_font_size_override("font_size", 14)
	_groups_lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.55, 0.9))
	root.add_child(_groups_lbl)
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.offset_left = -400
	_banner.offset_right = 400
	_banner.offset_top = -40
	_banner.offset_bottom = 40
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 42)
	_banner.visible = false
	root.add_child(_banner)
	_box = ColorRect.new()
	_box.color = Color(0.3, 0.8, 0.35, 0.18)
	_box.visible = false
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_box)
	_minimap = Control.new()
	_minimap.custom_minimum_size = Vector2(220, 220)
	_minimap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_minimap.offset_left = -240
	_minimap.offset_top = -240
	_minimap.offset_right = -20
	_minimap.offset_bottom = -20
	_minimap.mouse_filter = Control.MOUSE_FILTER_STOP
	_minimap.gui_input.connect(_on_minimap_input)
	_minimap.draw.connect(_draw_minimap)
	root.add_child(_minimap)
	_shop_btn = Button.new()
	_shop_btn.text = "Shop  (B)"
	_shop_btn.position = Vector2(1560, 16)
	_shop_btn.custom_minimum_size = Vector2(140, 36)
	_shop_btn.pressed.connect(toggle_shop)
	_shop_btn.mouse_entered.connect(func() -> void: over_ui = true)
	_shop_btn.mouse_exited.connect(func() -> void: over_ui = false)
	root.add_child(_shop_btn)
	_shop = ShopPanel.new()
	_shop.loadout_mode = false
	_shop.visible = false
	_shop.position = Vector2(1470, 70)
	_shop.size = Vector2(430, 720)
	_shop.buy_requested.connect(func(k: int) -> void: shop_buy.emit(k))
	_shop.mouse_entered.connect(func() -> void: over_ui = true)
	_shop.mouse_exited.connect(func() -> void: over_ui = false)
	root.add_child(_shop)
	var leave := Button.new()
	leave.text = "Leave"
	leave.position = Vector2(1920 - 200, 16)
	leave.pressed.connect(func() -> void: leave_match.emit())
	leave.mouse_entered.connect(func() -> void: over_ui = true)
	leave.mouse_exited.connect(func() -> void: over_ui = false)
	root.add_child(leave)


func _top_bar(root: Control) -> void:
	var bar := ColorRect.new()
	bar.color = Color(0.05, 0.07, 0.05, 0.78)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 56
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	_credits = Label.new()
	_credits.position = Vector2(20, 12)
	_credits.add_theme_font_size_override("font_size", 22)
	root.add_child(_credits)
	_regions = Label.new()
	_regions.position = Vector2(320, 12)
	_regions.add_theme_font_size_override("font_size", 22)
	root.add_child(_regions)
	_income = Label.new()
	_income.position = Vector2(620, 12)
	_income.add_theme_font_size_override("font_size", 18)
	_income.add_theme_color_override("font_color", Color(0.75, 0.9, 0.6))
	root.add_child(_income)


func toggle_shop() -> void:
	_shop.visible = not _shop.visible
	if not _shop.visible:
		shop_closed.emit()
		over_ui = false


func set_box(rect: Rect2, on: bool) -> void:
	_box.visible = on
	if on:
		_box.position = rect.position
		_box.size = rect.size


func refresh(credits: int, owned: int, total: int, income: float, selected: Array) -> void:
	_credits.text = "Credits  %d" % credits
	_regions.text = "Regions  %d / %d" % [owned, total]
	_income.text = "+%.0f /s" % income
	_shop.set_credits_display(credits)
	if selected.is_empty():
		_select_info.text = ""
	else:
		var counts := {}
		var hp_sum := 0.0
		var hp_max := 0.0
		for u in selected:
			if not is_instance_valid(u):
				continue
			var k: int = u.kind
			counts[k] = int(counts.get(k, 0)) + 1
			hp_sum += u.hp
			hp_max += u.max_hp
		var bits: PackedStringArray = []
		for k in counts.keys():
			bits.append("%dx %s" % [counts[k], UnitDB.data(int(k))["name"]])
		var garrisoned := 0
		for u2 in selected:
			if is_instance_valid(u2) and u2.garrison_building:
				garrisoned += 1
		var extra := "G to seize a building"
		if garrisoned > 0:
			extra = "G to unload from building  ·  RMB ground also ejects"
		_select_info.text = "Selected: %s\nHP %.0f / %.0f   ·   %s" % [
			", ".join(bits), hp_sum, hp_max, extra
		]
	_minimap.queue_redraw()


func set_group_hint(text: String) -> void:
	if _groups_lbl:
		_groups_lbl.text = text


func show_winner(text: String, color: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.visible = true


func _minimap_axes() -> Array[Vector2]:
	var yaw := 0.0
	if battle and battle.camera:
		yaw = deg_to_rad(battle.camera.yaw)
	# Ground-forward of the RTS camera (screen-up) and screen-right.
	var look := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(-look.y, look.x)
	var out: Array[Vector2] = [right, look]
	return out


func _world_to_minimap(p: Vector3) -> Vector2:
	var half := BattleMap.MAP_HALF
	var axes := _minimap_axes()
	var rel := Vector2(p.x, p.z)
	var u := rel.dot(axes[0]) / (half * 2.0) + 0.5
	var v := 0.5 - rel.dot(axes[1]) / (half * 2.0)
	return Vector2(u * _minimap.size.x, v * _minimap.size.y)


func _minimap_to_world(screen: Vector2) -> Vector3:
	var half := BattleMap.MAP_HALF
	var axes := _minimap_axes()
	var u := screen.x / _minimap.size.x - 0.5
	var v := 0.5 - screen.y / _minimap.size.y
	var rel := axes[0] * (u * half * 2.0) + axes[1] * (v * half * 2.0)
	return Vector3(rel.x, 0.0, rel.y)


func _draw_world_poly(corners: Array, color: Color) -> void:
	var pts := PackedVector2Array()
	for c in corners:
		pts.append(_world_to_minimap(c))
	if pts.size() >= 3:
		_minimap.draw_colored_polygon(pts, color)


func _draw_minimap() -> void:
	if battle == null or battle.map == null:
		return
	var r := Rect2(Vector2.ZERO, _minimap.size)
	_minimap.draw_rect(r, Color(0.12, 0.18, 0.1, 0.9))
	var half := BattleMap.MAP_HALF
	for region in battle.map.regions:
		var mn: Vector2 = region["min"]
		var mx: Vector2 = region["max"]
		var owner: int = int(region["owner"])
		var col := Color(1, 1, 1, 0.08)
		if owner != 0:
			col = GameSession.color_of(owner)
			col.a = 0.28
		_draw_world_poly([
			Vector3(mn.x, 0, mn.y),
			Vector3(mx.x, 0, mn.y),
			Vector3(mx.x, 0, mx.y),
			Vector3(mn.x, 0, mx.y),
		], col)
	_draw_world_poly([
		Vector3(-8, 0, -half),
		Vector3(8, 0, -half),
		Vector3(8, 0, half),
		Vector3(-8, 0, half),
	], Color(0.2, 0.45, 0.7, 0.7))
	for n in get_tree().get_nodes_in_group("units"):
		var u := n as Unit
		if u == null:
			continue
		var p := _world_to_minimap(u.global_position)
		var uc := GameSession.color_of(u.owner_id)
		_minimap.draw_rect(Rect2(p - Vector2(2, 2), Vector2(5, 5)), uc)
	if battle.camera:
		var cam_p := _world_to_minimap(battle.camera.global_position)
		_minimap.draw_arc(cam_p, 10.0, 0, TAU, 16, Color(1, 1, 1, 0.7), 1.5)
		var tip := _world_to_minimap(battle.camera.global_position + Vector3(_minimap_axes()[1].x, 0, _minimap_axes()[1].y) * 14.0)
		_minimap.draw_line(cam_p, tip, Color(1, 1, 1, 0.85), 2.0)


func _on_minimap_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if battle and battle.camera:
			battle.camera.focus(_minimap_to_world(mb.position))
