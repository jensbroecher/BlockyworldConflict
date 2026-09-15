class_name ShopPanel
extends PanelContainer

signal buy_requested(kind: int)
signal ready_toggled(is_ready: bool)
signal start_skirmish
signal cart_changed(kinds: Array, remaining: int)

var loadout_mode: bool = false
var cart: Array[int] = []
var remaining: int = UnitDB.STARTING_CREDITS
var ready_on: bool = false

var _list: VBoxContainer
var _remain_lbl: Label
var _cart_lbl: Label
var _ready_btn: Button
var _hint: Label


func _ready() -> void:
	custom_minimum_size = Vector2(420, 520)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.10, 0.08, 0.94)
	sb.border_color = Color(0.45, 0.55, 0.32)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	add_theme_stylebox_override("panel", sb)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	var title := Label.new()
	title.text = "REQUISITION"
	title.add_theme_font_size_override("font_size", 22)
	root.add_child(title)
	_remain_lbl = Label.new()
	_remain_lbl.add_theme_font_size_override("font_size", 18)
	root.add_child(_remain_lbl)
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_color_override("font_color", Color(0.75, 0.8, 0.7))
	root.add_child(_hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 280
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_cart_lbl = Label.new()
	_cart_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_cart_lbl)
	_rebuild_list()
	if loadout_mode:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		root.add_child(row)
		var clear_btn := Button.new()
		clear_btn.text = "Clear cart"
		clear_btn.pressed.connect(_clear_cart)
		row.add_child(clear_btn)
		_ready_btn = Button.new()
		_ready_btn.text = "Ready"
		_ready_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_ready_btn.pressed.connect(_toggle_ready)
		row.add_child(_ready_btn)
		if GameSession.is_skirmish():
			var go := Button.new()
			go.text = "Start battle"
			go.pressed.connect(func() -> void: start_skirmish.emit())
			root.add_child(go)
	_refresh()


func _rebuild_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	for kind in UnitDB.all_kinds():
		var d: Dictionary = UnitDB.data(kind)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(18, 18)
		swatch.color = GameSession.color_of(GameSession.local_id)
		row.add_child(swatch)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var n := Label.new()
		n.text = "%s  —  %d cr" % [d["name"], d["cost"]]
		info.add_child(n)
		var b := Label.new()
		b.text = String(d["blurb"])
		b.add_theme_font_size_override("font_size", 12)
		b.add_theme_color_override("font_color", Color(0.7, 0.74, 0.65))
		info.add_child(b)
		row.add_child(info)
		var btn := Button.new()
		btn.text = "Add" if loadout_mode else "Order"
		var k := kind
		btn.pressed.connect(func() -> void: _on_buy(k))
		row.add_child(btn)
		_list.add_child(row)


func _on_buy(kind: int) -> void:
	if loadout_mode:
		var c := UnitDB.cost(kind)
		if remaining < c:
			return
		if cart.size() >= UnitDB.MAX_ARMY:
			return
		cart.append(kind)
		remaining -= c
		_refresh()
		cart_changed.emit(cart, remaining)
	else:
		buy_requested.emit(kind)


func _clear_cart() -> void:
	cart.clear()
	remaining = UnitDB.STARTING_CREDITS
	ready_on = false
	_refresh()
	cart_changed.emit(cart, remaining)


func _toggle_ready() -> void:
	ready_on = not ready_on
	_refresh()
	ready_toggled.emit(ready_on)


func set_credits_display(amount: int) -> void:
	if not loadout_mode:
		remaining = amount
		_refresh()


func _refresh() -> void:
	if loadout_mode:
		_remain_lbl.text = "Budget remaining: %d" % remaining
		_hint.text = "Spend credits on a starting force. Leftover credits carry into the battle."
		_cart_lbl.text = "Cart (%d): %s" % [cart.size(), _cart_text()]
		if _ready_btn:
			_ready_btn.text = "Ready ✓" if ready_on else "Ready"
	else:
		_remain_lbl.text = "Credits: %d" % remaining
		_hint.text = "Order reinforcements. They arrive at your spawn. Income ticks up during the fight."
		_cart_lbl.text = "Hotkey: B to close"


func _cart_text() -> String:
	if cart.is_empty():
		return "(empty)"
	var counts := {}
	for k in cart:
		counts[k] = int(counts.get(k, 0)) + 1
	var bits: PackedStringArray = []
	for k in counts.keys():
		bits.append("%dx %s" % [counts[k], UnitDB.data(int(k))["short"]])
	return ", ".join(bits)
