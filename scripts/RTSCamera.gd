class_name RTSCamera
extends Node3D

var cam: Camera3D
var zoom: float = 52.0
var yaw: float = 0.0
var pitch: float = -52.0
var pan_speed: float = 38.0
var _dragging := false
var _last_mouse := Vector2.ZERO


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.near = 0.4
	cam.far = 800.0
	cam.current = true
	add_child(cam)
	_apply()
	cam.make_current()


func focus(pos: Vector3) -> void:
	global_position = Vector3(pos.x, 0.0, pos.z)
	# Put the boom on the map-edge side so we look inward toward the river.
	if absf(pos.x) > 0.01 or absf(pos.z) > 0.01:
		yaw = rad_to_deg(atan2(pos.x, pos.z))
	_apply()


func _process(delta: float) -> void:
	if cam and not cam.current:
		cam.make_current()
	var input_v := Vector3.ZERO
	if Input.is_action_pressed("cam_forward"):
		input_v.z -= 1
	if Input.is_action_pressed("cam_back"):
		input_v.z += 1
	if Input.is_action_pressed("cam_left"):
		input_v.x -= 1
	if Input.is_action_pressed("cam_right"):
		input_v.x += 1
	if Input.is_action_pressed("cam_rot_left"):
		yaw += 70.0 * delta
	if Input.is_action_pressed("cam_rot_right"):
		yaw -= 70.0 * delta
	var mouse := get_viewport().get_mouse_position()
	var vs := get_viewport().get_visible_rect().size
	var edge := 18.0
	if mouse.x < edge:
		input_v.x -= 1
	elif mouse.x > vs.x - edge:
		input_v.x += 1
	if mouse.y < edge:
		input_v.z -= 1
	elif mouse.y > vs.y - edge:
		input_v.z += 1
	if input_v != Vector3.ZERO:
		var basis_yaw := Basis(Vector3.UP, deg_to_rad(yaw))
		var move := (basis_yaw * input_v).normalized() * pan_speed * (zoom / 40.0) * delta
		global_position += move
		global_position.x = clampf(global_position.x, -90, 90)
		global_position.z = clampf(global_position.z, -90, 90)
	if _dragging:
		var d := mouse - _last_mouse
		_last_mouse = mouse
		var basis_yaw2 := Basis(Vector3.UP, deg_to_rad(yaw))
		var move2 := basis_yaw2 * Vector3(-d.x, 0, -d.y) * 0.08 * (zoom / 40.0)
		global_position += move2
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
			_last_mouse = mb.position
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom = clampf(zoom - 4.0, 18.0, 110.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom = clampf(zoom + 4.0, 18.0, 110.0)


func _apply() -> void:
	if cam == null:
		return
	rotation_degrees = Vector3(0, yaw, 0)
	var pitch_rad := deg_to_rad(pitch)
	# Boom sits above and behind the look-at pivot (pitch is negative, e.g. -52).
	cam.position = Vector3(
		0.0,
		zoom * sin(-pitch_rad),
		zoom * cos(-pitch_rad)
	)
	if cam.is_inside_tree():
		cam.look_at(global_position + Vector3(0, 1.2, 0), Vector3.UP)


func ray_query(mask: int = 0xFFFFFFFF) -> Dictionary:
	var mouse := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mouse)
	var to := from + cam.project_ray_normal(mouse) * 800.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = mask
	return get_world_3d().direct_space_state.intersect_ray(q)


func ground_point() -> Vector3:
	var mouse := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mouse)
	var dir := cam.project_ray_normal(mouse)
	if absf(dir.y) < 0.001:
		return global_position
	var t := -from.y / dir.y
	var p := from + dir * t
	return Vector3(p.x, 0.0, p.z)
