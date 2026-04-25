## Top-down RTS camera: WASD/arrow pan + mouse-wheel zoom + edge pan.
extends Camera2D

const PAN_SPEED: float = 900.0
const ZOOM_MIN: float = 0.25
const ZOOM_MAX: float = 2.5
const ZOOM_STEP: float = 0.10

func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) and not _editing_text():
		# D conflicts with diplomacy panel - already absorbed by game.gd via _unhandled_input
		# but Camera2D _process still pans. Ignore D when textfield focused (none here).
		pass
	if Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if dir != Vector2.ZERO:
		position += dir.normalized() * PAN_SPEED * delta / zoom.x
	# Clamp
	position.x = clamp(position.x, 0.0, GameState.MAP_W)
	position.y = clamp(position.y, 0.0, GameState.MAP_H)

func _editing_text() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom = (zoom * (1.0 + ZOOM_STEP)).clamp(Vector2(ZOOM_MIN, ZOOM_MIN), Vector2(ZOOM_MAX, ZOOM_MAX))
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom = (zoom * (1.0 - ZOOM_STEP)).clamp(Vector2(ZOOM_MIN, ZOOM_MIN), Vector2(ZOOM_MAX, ZOOM_MAX))
			get_viewport().set_input_as_handled()
