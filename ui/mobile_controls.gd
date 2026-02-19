## Mobile Controls Script
## Handles touch input, joystick mechanics, and button feedback

extends CanvasLayer

# ─── Configuration ─────────────────────────────────────────────────────────
@export_group("Joystick Settings")
@export var joystick_dead_zone: float = 0.15
@export var joystick_max_radius: float = 60.0
@export var joystick_visual_radius: float = 50.0
@export var joystick_return_speed: float = 10.0

@export_group("Button Settings")
@export var button_press_scale: float = 0.85
@export var button_feedback_duration: float = 0.1

@export_group("Layout")
@export var joystick_position: Vector2 = Vector2(120, 180)
@export var button_spacing: float = 80.0

# ─── Signals ───────────────────────────────────────────────────────────────
signal joystick_input(vector: Vector2)
signal action_button_pressed
signal hook_button_pressed
signal inventory_button_pressed
signal crafting_button_pressed
signal pause_button_pressed

# ─── Node References ───────────────────────────────────────────────────────
@onready var joystick_base: TextureRect = $Control/JoystickBase
@onready var joystick_thumb: TextureRect = $Control/JoystickBase/JoystickThumb
@onready var action_button: Button = $Control/ActionButton
@onready var hook_button: Button = $Control/HookButton
@onready var inventory_button: Button = $Control/InventoryButton
@onready var crafting_button: Button = $Control/CraftingButton
@onready var pause_button: Button = $Control/PauseButton
@onready var control_container: Control = $Control

# ─── State Variables ───────────────────────────────────────────────────────
var _is_visible: bool = true
var _joystick_active: bool = false
var _joystick_touch_id: int = -1
var _joystick_center: Vector2 = Vector2.ZERO
var _current_joystick_input: Vector2 = Vector2.ZERO
var _button_touches: Dictionary = {}

# ─── Lifecycle ──────────────────────────────────────────────────────────────
func _ready() -> void:
	_setup_joystick()
	_setup_buttons()
	_apply_layout()

func _process(delta: float) -> void:
	if _joystick_active:
		return
	
	# Smooth return to center when joystick released
	if _current_joystick_input.length() > 0.01:
		_current_joystick_input = _current_joystick_input.lerp(Vector2.ZERO, joystick_return_speed * delta)
		_joystick_thumb.position = _joystick_thumb.position.lerp(Vector2.ZERO, joystick_return_speed * delta)
		_emit_joystick_input()

# ─── Input Handling ───────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not _is_visible:
		return
	
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
	var touch_pos := event.position
	
	if event.pressed:
		# Check if touch is in joystick area (left side)
		if _is_in_joystick_zone(touch_pos):
			_joystick_touch_id = event.index
			_joystick_active = true
			_joystick_center = joystick_base.global_position + joystick_base.size / 2
			_update_joystick(touch_pos)
		
		# Check if touch hits any button
		elif _is_button_pressed(action_button, touch_pos):
			_button_pressed(action_button, event.index)
		elif _is_button_pressed(hook_button, touch_pos):
			_button_pressed(hook_button, event.index)
		elif _is_button_pressed(inventory_button, touch_pos):
			_button_pressed(inventory_button, event.index)
		elif _is_button_pressed(crafting_button, touch_pos):
			_button_pressed(crafting_button, event.index)
		elif _is_button_pressed(pause_button, touch_pos):
			_button_pressed(pause_button, event.index)
	else:
		# Touch released
		if event.index == _joystick_touch_id:
			_joystick_active = false
			_joystick_touch_id = -1
			_current_joystick_input = Vector2.ZERO
			_joystick_thumb.position = Vector2.ZERO
			_emit_joystick_input()
		elif _button_touches.has(event.index):
			_button_released(_button_touches[event.index])
			_button_touches.erase(event.index)

func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _joystick_touch_id and _joystick_active:
		_update_joystick(event.position)

func _update_joystick(touch_pos: Vector2) -> void:
	var delta := touch_pos - _joystick_center
	var distance := delta.length()
	var direction := delta.normalized() if distance > 0 else Vector2.ZERO
	
	# Apply dead zone
	if distance < joystick_dead_zone * joystick_max_radius:
		_current_joystick_input = Vector2.ZERO
		_joystick_thumb.position = Vector2.ZERO
	else:
		# Clamp to max radius
		var clamped_distance := min(distance, joystick_max_radius)
		var visual_distance := min(distance, joystick_visual_radius)
		
		_current_joystick_input = direction * ((clamped_distance - joystick_dead_zone * joystick_max_radius) / (joystick_max_radius * (1 - joystick_dead_zone)))
		_current_joystick_input = _current_joystick_input.clampf(-1.0, 1.0)
		
		# Update thumb position visually
		_joystick_thumb.position = direction * visual_distance
	
	_emit_joystick_input()

func _emit_joystick_input() -> void:
	emit_signal("joystick_input", _current_joystick_input)

# ─── Button Handling ───────────────────────────────────────────────────────
func _button_pressed(button: Button, touch_id: int) -> void:
	_button_touches[touch_id] = button
	_animate_button_press(button)
	
	match button:
		action_button:
			emit_signal("action_button_pressed")
		hook_button:
			emit_signal("hook_button_pressed")
		inventory_button:
			emit_signal("inventory_button_pressed")
		crafting_button:
			emit_signal("crafting_button_pressed")
		pause_button:
			emit_signal("pause_button_pressed")

func _button_released(button: Button) -> void:
	_animate_button_release(button)

func _animate_button_press(button: Button) -> void:
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2(button_press_scale, button_press_scale), button_feedback_duration)
	tween.set_parallel(true)
	tween.tween_property(button, "modulate:a", 0.7, button_feedback_duration)

func _animate_button_release(button: Button) -> void:
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2.ONE, button_feedback_duration)
	tween.set_parallel(true)
	tween.tween_property(button, "modulate:a", 1.0, button_feedback_duration)

# ─── Zone Detection ───────────────────────────────────────────────────────
func _is_in_joystick_zone(pos: Vector2) -> bool:
	var joystick_area := Rect2(
		joystick_base.global_position - Vector2(joystick_visual_radius * 2, joystick_visual_radius * 2),
		joystick_base.size + Vector2(joystick_visual_radius * 4, joystick_visual_radius * 4)
	)
	return joystick_area.has_point(pos)

func _is_button_pressed(button: Button, pos: Vector2) -> bool:
	var button_rect := Rect2(button.global_position, button.size)
	return button_rect.has_point(pos)

# ─── Setup ─────────────────────────────────────────────────────────────────
func _setup_joystick() -> void:
	_joystick_center = joystick_base.global_position + joystick_base.size / 2

func _setup_buttons() -> void:
	# Connect signals
	action_button.pressed.connect(func(): emit_signal("action_button_pressed"))
	hook_button.pressed.connect(func(): emit_signal("hook_button_pressed"))
	inventory_button.pressed.connect(func(): emit_signal("inventory_button_pressed"))
	crafting_button.pressed.connect(func(): emit_signal("crafting_button_pressed"))
	pause_button.pressed.connect(func(): emit_signal("pause_button_pressed"))

func _apply_layout() -> void:
	# Position joystick on left side
	joystick_base.position = joystick_position
	
	# Position action buttons on right side
	var right_edge := get_viewport().get_visible_rect().size.x
	var bottom_edge := get_viewport().get_visible_rect().size.y
	var button_size := action_button.size
	
	# Action button (jump/swim) - lowest, closest to center
	action_button.position = Vector2(right_edge - button_size.x - button_spacing, bottom_edge - button_size.y - button_spacing)
	
	# Hook button - above action
	hook_button.position = Vector2(right_edge - button_size.x - button_spacing, action_button.position.y - button_size.y - 20)
	
	# Inventory button - far right
	inventory_button.position = Vector2(right_edge - button_size.x - 20, bottom_edge - button_size.y - button_spacing)
	
	# Crafting button - above inventory
	crafting_button.position = Vector2(right_edge - button_size.x - 20, inventory_button.position.y - button_size.y - 20)
	
	# Pause button - top right corner
	pause_button.position = Vector2(right_edge - button_size.x - 20, 20)

# ─── Public API ───────────────────────────────────────────────────────────
func set_visible(visible: bool) -> void:
	_is_visible = visible
	control_container.visible = visible

func is_visible() -> bool:
	return _is_visible

func get_joystick_input() -> Vector2:
	return _current_joystick_input
