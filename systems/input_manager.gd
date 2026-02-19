## Input Manager
## Handles device detection, input routing, and control remapping
## Autoload: InputManager (accessible globally)

extends Node

# ─── Signals ───────────────────────────────────────────────────────────────
signal device_type_changed(device_type: int)
signal control_mapping_changed

# ─── Device Types ─────────────────────────────────────────────────────────
enum DeviceType {
	DESKTOP = 0,
	MOBILE = 1,
	TOUCH = 2  # Laptop with touchscreen
}

# ─── Action Names ─────────────────────────────────────────────────────────
enum Action {
	MOVE_UP,
	MOVE_DOWN,
	MOVE_LEFT,
	MOVE_RIGHT,
	JUMP,
	SWIM,
	HOOK_THROW,
	HOOK_PULL,
	INVENTORY,
	CRAFTING,
	PAUSE,
	INTERACT,
	ATTACK,
	BLOCK
}

# ─── Configuration ─────────────────────────────────────────────────────────
var _device_type: int = DeviceType.DESKTOP
var _mobile_controls: CanvasLayer = null
var _is_mobile_controls_visible: bool = false
var _remap_enabled: bool = true

# ─── Default Key Bindings ─────────────────────────────────────────────────
var _default_keybindings: Dictionary = {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE, KEY_SHIFT],
	"swim_up": [KEY_SPACE],
	"hook_throw": [KEY_E, BUTTON_LEFT],
	"hook_pull": [KEY_Q, BUTTON_RIGHT],
	"inventory": [KEY_I],
	"crafting": [KEY_C],
	"pause": [KEY_ESCAPE, KEY_P],
	"interact": [KEY_E, KEY_F],
	"attack": [KEY_MOUSE_LEFT, BUTTON_LEFT],
	"block": [KEY_MOUSE_RIGHT, BUTTON_RIGHT]
}

# ─── Current Key Bindings ─────────────────────────────────────────────────
var _current_keybindings: Dictionary = {}

# ─── Input State ───────────────────────────────────────────────────────────
var _joystick_input: Vector2 = Vector2.ZERO
var _virtual_buttons: Dictionary = {}

# ─── Lifecycle ──────────────────────────────────────────────────────────────
func _ready() -> void:
	# Copy default bindings
	_current_keybindings = _default_keybindings.duplicate(true)
	
	# Use consistent action names
	InputMap.add_action("move_up")
	InputMap.add_action("move_down")
	InputMap.add_action("hook_pull")
	InputMap.add_action("inventory")
	InputMap.add_action("crafting")
	InputMap.add_action("pause")
	InputMap.add_action("attack")
	InputMap.add_action("block")
	
	# Remove old action names if they exist
	if InputMap.has_action("move_forward"):
		InputMap.erase_action("move_forward")
	if InputMap.has_action("move_backward"):
		InputMap.erase_action("move_backward")
	if InputMap.has_action("sprint"):
		InputMap.erase_action("sprint")
	if InputMap.has_action("open_build_menu"):
		InputMap.erase_action("open_build_menu")
	if InputMap.has_action("place_building"):
		InputMap.erase_action("place_building")
	if InputMap.has_action("cancel_building"):
		InputMap.erase_action("cancel_building")
	
	# Detect device type
	_detect_device_type()
	
	# Load saved remappings if available
	_load_remappings()
	
	# Connect to mobile controls if present
	_setup_mobile_controls()

func _process(_delta: float) -> void:
	# Update joystick input from mobile controls
	if _is_mobile_controls_visible and _mobile_controls != null:
		_joystick_input = _mobile_controls.get_joystick_input()
	else:
		_joystick_input = Vector2.ZERO

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		_handle_keyboard_input(event)

# ─── Device Detection ───────────────────────────────────────────────────────
func _detect_device_type() -> void:
	var new_device_type: int = DeviceType.DESKTOP
	
	# Check for touch devices
	if DisplayServer.is_touchscreen_available():
		new_device_type = DeviceType.TOUCH
	
	# Check OS for mobile indicators
	var os_name := OS.get_name()
	if os_name in ["Android", "iOS"]:
		new_device_type = DeviceType.MOBILE
	
	# Check screen size for mobile form factor
	var screen_size := DisplayServer.screen_get_size(DisplayServer.main_get_id())
	if screen_size.x <= 800 or screen_size.y <= 600:
		if new_device_type == DeviceType.DESKTOP:
			new_device_type = DeviceType.TOUCH
	
	if new_device_type != _device_type:
		_device_type = new_device_type
		emit_signal("device_type_changed", _device_type)
		
		# Auto-show mobile controls on touch devices
		if _device_type != DeviceType.DESKTOP:
			_show_mobile_controls(true)

func get_device_type() -> int:
	return _device_type

func is_mobile() -> bool:
	return _device_type != DeviceType.DESKTOP

# ─── Mobile Controls ───────────────────────────────────────────────────────
func _setup_mobile_controls() -> void:
	# Try to find mobile controls in the scene
	var root := get_tree().root
	if root.has_node("MobileControls"):
		_mobile_controls = root.get_node("MobileControls")
		_connect_mobile_controls()
	elif root.has_node("main/MobileControls"):
		_mobile_controls = root.get_node("main/MobileControls")
		_connect_mobile_controls()

func _connect_mobile_controls() -> void:
	if _mobile_controls == null:
		return
	
	# Connect signals
	if _mobile_controls.has_signal("joystick_input"):
		_mobile_controls.joystick_input.connect(_on_joystick_input)
	
	if _mobile_controls.has_signal("action_button_pressed"):
		_mobile_controls.action_button_pressed.connect(_on_action_button_pressed)
	
	if _mobile_controls.has_signal("hook_button_pressed"):
		_mobile_controls.hook_button_pressed.connect(_on_hook_button_pressed)
	
	if _mobile_controls.has_signal("inventory_button_pressed"):
		_mobile_controls.inventory_button_pressed.connect(_on_inventory_button_pressed)
	
	if _mobile_controls.has_signal("crafting_button_pressed"):
		_mobile_controls.crafting_button_pressed.connect(_on_crafting_button_pressed)
	
	if _mobile_controls.has_signal("pause_button_pressed"):
		_mobile_controls.pause_button_pressed.connect(_on_pause_button_pressed)

func _on_joystick_input(vector: Vector2) -> void:
	_joystick_input = vector

func _on_action_button_pressed() -> void:
	_virtual_buttons["jump"] = true
	await get_tree().create_timer(0.1).timeout
	_virtual_buttons.erase("jump")

func _on_hook_button_pressed() -> void:
	_virtual_buttons["hook_throw"] = true
	await get_tree().create_timer(0.1).timeout
	_virtual_buttons.erase("hook_throw")

func _on_inventory_button_pressed() -> void:
	_toggle_inventory()

func _on_crafting_button_pressed() -> void:
	_toggle_crafting()

func _on_pause_button_pressed() -> void:
	_toggle_pause()

func _show_mobile_controls(visible: bool) -> void:
	if _mobile_controls == null:
		_setup_mobile_controls()
	
	if _mobile_controls != null:
		_mobile_controls.set_visible(visible)
		_is_mobile_controls_visible = visible

func show_mobile_controls() -> void:
	_show_mobile_controls(true)

func hide_mobile_controls() -> void:
	_show_mobile_controls(false)

func toggle_mobile_controls() -> void:
	_show_mobile_controls(!_is_mobile_controls_visible)

func is_mobile_controls_visible() -> bool:
	return _is_mobile_controls_visible

func register_mobile_controls(node: CanvasLayer) -> void:
	_mobile_controls = node
	_connect_mobile_controls()

# ─── Input Actions ─────────────────────────────────────────────────────────
func get_vector(action: String) -> Vector2:
	# First check keyboard/input map
	var input_vector := Input.get_vector(
		"move_left", "move_right", "move_up", "move_down"
	)
	
	# If no keyboard input, use joystick
	if input_vector == Vector2.ZERO and _joystick_input != Vector2.ZERO:
		input_vector = _joystick_input
	
	return input_vector

func is_action_pressed(action: String) -> bool:
	# Check if virtual button pressed
	if _virtual_buttons.has(action) and _virtual_buttons[action]:
		return true
	
	# Check input map
	return Input.is_action_pressed(action)

func is_action_just_pressed(action: String) -> bool:
	# Check virtual buttons
	if _virtual_buttons.has(action) and _virtual_buttons[action]:
		_virtual_buttons[action] = false
		return true
	
	# Check input map
	return Input.is_action_just_pressed(action)

# ─── Menu Toggles ──────────────────────────────────────────────────────────
func _toggle_inventory() -> void:
	var inventory_path := ""
	var root := get_tree().root
	if root.has_node("main/Inventory"):
		inventory_path = "main/Inventory"
	elif root.has_node("Inventory"):
		inventory_path = "Inventory"
	
	if inventory_path:
		var inventory = root.get_node(inventory_path)
		if inventory.has_method("toggle"):
			inventory.toggle()

func _toggle_crafting() -> void:
	var crafting_path := ""
	var root := get_tree().root
	if root.has_node("main/CraftingMenu"):
		crafting_path = "main/CraftingMenu"
	elif root.has_node("CraftingMenu"):
		crafting_path = "CraftingMenu"
	
	if crafting_path:
		var crafting = root.get_node(crafting_path)
		if crafting.has_method("toggle"):
			crafting.toggle()

func _toggle_pause() -> void:
	var pause_path := ""
	var root := get_tree().root
	if root.has_node("main/PauseMenu"):
		pause_path = "main/PauseMenu"
	elif root.has_node("PauseMenu"):
		pause_path = "PauseMenu"
	
	if pause_path:
		var pause = root.get_node(pause_path)
		if pause.has_method("toggle"):
			pause.toggle()
	elif get_tree():
		get_tree().paused = !get_tree().paused

# ─── Keyboard Input ───────────────────────────────────────────────────────
func _handle_keyboard_input(event: InputEventKey) -> void:
	if not event.pressed:
		return
	
	# Map common keys to actions
	match event.keycode:
		KEY_ESCAPE:
			_toggle_pause()
		KEY_I:
			_toggle_inventory()
		KEY_C:
			_toggle_crafting()

# ─── Key Remapping ─────────────────────────────────────────────────────────
func get_action_bindings(action: String) -> Array:
	return _current_keybindings.get(action, [])

func set_action_binding(action: String, keycodes: Array) -> void:
	_current_keybindings[action] = keycodes
	_apply_remapping()
	emit_signal("control_mapping_changed")

func add_action_binding(action: String, keycode: int) -> void:
	if not _current_keybindings.has(action):
		_current_keybindings[action] = []
	
	if keycode not in _current_keybindings[action]:
		_current_keybindings[action].append(keycode)
		_apply_remapping()
		emit_signal("control_mapping_changed")

func remove_action_binding(action: String, keycode: int) -> void:
	if _current_keybindings.has(action) and keycode in _current_keybindings[action]:
		_current_keybindings[action].erase(keycode)
		_apply_remapping()
		emit_signal("control_mapping_changed")

func reset_to_defaults() -> void:
	_current_keybindings = _default_keybindings.duplicate(true)
	_apply_remapping()
	_save_remappings()
	emit_signal("control_mapping_changed")

func _apply_remapping() -> void:
	if not _remap_enabled:
		return
	
	# Apply current keybindings to InputMap
	for action in _current_keybindings:
		# Clear existing inputs for this action
		var existing := InputMap.get_action_list(action)
		for old_input in existing:
			InputMap.action_erase_event(action, old_input)
		
		# Add new bindings
		for keycode in _current_keybindings[action]:
			var event: InputEventKey = InputEventKey.new()
			event.keycode = keycode
			event.pressed = true
			InputMap.action_add_event(action, event)

func _save_remappings() -> void:
	var config := ConfigFile.new()
	var save_path := "user://input_remappings.cfg"
	
	for action in _current_keybindings:
		var key_list: Array = _current_keybindings[action]
		var key_strings: Array = []
		for key in key_list:
			key_strings.append(str(key))
		config.set_value("bindings", action, key_strings)
	
	config.save(save_path)

func _load_remappings() -> void:
	var config := ConfigFile.new()
	var save_path := "user://input_remappings.cfg"
	
	if config.load(save_path) == OK:
		for action in config.get_section_keys("bindings"):
			var key_strings: Array = config.get_value("bindings", action)
			var key_list: Array = []
			for key_str in key_strings:
				key_list.append(int(key_str))
			_current_keybindings[action] = key_list
		
		_apply_remapping()

# ─── Public API ───────────────────────────────────────────────────────────
func set_remap_enabled(enabled: bool) -> void:
	_remap_enabled = enabled
	if enabled:
		_apply_remapping()

func is_remap_enabled() -> bool:
	return _remap_enabled

func save_remappings() -> void:
	_save_remappings()
