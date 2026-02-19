extends Node3D
class_name Hook
## Hook throwing and grabbing mechanic with arc trajectory

# Hook parameters
@export_group("Hook Settings")
@export var throw_force: float = 20.0
@export var throw_height: float = 8.0
@export var max_range: float = 30.0
@export var grab_radius: float = 1.5
@export var pull_speed: float = 3.0

# Physics
@export_group("Physics")
@export var hook_mass: float = 0.5
@export var air_drag: float = 0.1
@export var water_drag: float = 2.0

# Hook states
enum HookState { IDLE, THROWING, STICKING, RETRACTING, GRABBING }
var current_state: HookState = HookState.IDLE

# References
var player: Node3D = null
var water_physics: WaterPhysics = null

# Hook components
@onready var hook_mesh: MeshInstance3D = $HookMesh
@onready var hook_collision: Area3D = $HookArea

# Position tracking
var start_position: Vector3 = Vector3.ZERO
var target_position: Vector3 = Vector3.ZERO
var landing_position: Vector3 = Vector3.ZERO

# Velocity
var velocity: Vector3 = Vector3.ZERO

# Grabbed object
var grabbed_object: RigidBody3D = null
var grab_offset: Vector3 = Vector3.ZERO

# Trail effect
var trail_points: Array[Vector3] = []
var max_trail_points: int = 20

# Timers
var throw_timer: float = 0.0
var throw_duration: float = 1.5
var retract_timer: float = 0.0
var retract_duration: float = 2.0

# Input state
var is_pulling: bool = false

# Collision layers
const LAYER_DEFAULT = 1
const LAYER_WATER = 4
const LAYER_OBJECTS = 2


func _ready() -> void:
	# Find player
	player = get_tree().get_first_node_in_group("player")
	
	# Find water physics
	if not water_physics:
		water_physics = get_tree().get_first_node_in_group("water")
	
	# Setup collision
	_setup_collision()
	
	# Initially hidden
	visible = false


func _setup_collision() -> void:
	# Create collision area for hook
	if not hook_collision:
		hook_collision = Area3D.new()
		add_child(hook_collision)
	
	var collision = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = grab_radius
	collision.shape = sphere
	hook_collision.add_child(collision)
	
	# Connect area signals
	hook_collision.area_entered.connect(_on_hook_area_entered)
	hook_collision.body_entered.connect(_on_hook_body_entered)


func _physics_process(delta: float) -> void:
	# Update timers
	match current_state:
		HookState.THROWING:
			throw_timer += delta
			if throw_timer >= throw_duration:
				_transition_to_sticking()
		HookState.RETRACTING:
			retract_timer += delta
			if retract_timer >= retract_duration:
				_return_to_idle()
	
	# State behavior
	match current_state:
		HookState.IDLE:
			_follow_player()
		HookState.THROWING:
			_update_throw(delta)
		HookState.STICKING:
			_update_sticking(delta)
		HookState.RETRACTING:
			_update_retracting(delta)
		HookState.GRABBING:
			_update_grabbing(delta)
	
	# Update visuals
	_update_trail()
	_update_mesh_rotation()


func _follow_player() -> void:
	"""Hook follows player when idle"""
	if player and player.has_method("get_hook_origin"):
		global_position = player.get_hook_origin()


func _update_throw(delta: float) -> void:
	"""Update hook position during throw arc"""
	# Calculate arc position using quadratic bezier
	var t = throw_timer / throw_duration
	t = clamp(t, 0.0, 1.0)
	
	# Parabolic arc: start -> peak -> target
	var start = start_position
	var peak = (start_position + target_position) / 2.0 + Vector3(0, throw_height, 0)
	var end = target_position
	
	# Quadratic bezier interpolation
	var pos = pow(1 - t, 2) * start + 2 * (1 - t) * t * peak + pow(t, 2) * end
	global_position = pos
	
	# Check if we hit water or object early
	if water_physics:
		var water_height = water_physics.get_wave_height(global_position)
		if global_position.y < water_height:
			# Hit water early
			landing_position = global_position
			landing_position.y = water_height
			_transition_to_retracting()


func _update_sticking(delta: float) -> void:
	"""Hook stuck in object/surface"""
	# Stay at landing position
	# Could add wobble effect here
	pass


func _update_retracting(delta: float) -> void:
	"""Hook returning to player"""
	var player_origin = player.get_hook_origin() if player else global_position
	
	# Move towards player
	var direction = (player_origin - global_position).normalized()
	var distance = global_position.distance_to(player_origin)
	
	if distance < 1.0:
		# Returned to player
		if grabbed_object:
			_transition_to_grabbing()
		else:
			_return_to_idle()
	else:
		# Move back with deceleration
		var speed = pull_speed * (1.0 - (retract_timer / retract_duration))
		global_position += direction * max(speed, 1.0) * delta


func _update_grabbing(delta: float) -> void:
	"""Pulling grabbed object towards player"""
	if not grabbed_object:
		_return_to_idle()
		return
	
	# Move grabbed object towards player
	var player_origin = player.get_hook_origin() if player else global_position
	var direction = (player_origin - grabbed_object.global_position).normalized()
	var distance = grabbed_object.global_position.distance_to(player_origin)
	
	if distance < 2.0:
		# Close enough - collect item
		_collect_grabbed_object()
	else:
		# Pull object
		grabbed_object.global_position += direction * pull_speed * delta
		# Disable object's physics while being pulled
		grabbed_object.freeze = true


func _collect_grabbed_object() -> void:
	# Item collection logic
	if grabbed_object.has_method("on_collected"):
		grabbed_object.on_collected(player)
	
	# Destroy or store object
	grabbed_object.queue_free()
	grabbed_object = null
	
	_return_to_idle()


func _transition_to_sticking() -> void:
	current_state = HookState.STICKING
	landing_position = global_position
	
	# Check for grabbable objects nearby
	_check_for_grabbable()


func _transition_to_retracting() -> void:
	current_state = HookState.RETRACTING
	retract_timer = 0.0
	
	# If we have a grabbed object, we're in grabbing state
	if grabbed_object:
		current_state = HookState.GRABBING
		grabbed_object.freeze = true


func _return_to_idle() -> void:
	current_state = HookState.IDLE
	
	# Reset
	if grabbed_object:
		grabbed_object.freeze = false
		grabbed_object = null
	
	visible = false
	trail_points.clear()


func _check_for_grabbable() -> void:
	# Get overlapping bodies
	var bodies = hook_collision.get_overlapping_bodies()
	
	for body in bodies:
		if body is RigidBody3D and body.is_in_group("grabbable"):
			grabbed_object = body
			grab_offset = body.global_position - global_position
			break


func _on_hook_area_entered(area: Area3D) -> void:
	# Check for collectibles
	if current_state == HookState.THROWING or current_state == HookState.STICKING:
		if area.is_in_group("collectible"):
			# Auto-grab small items
			grabbed_object = area.get_parent() as RigidBody3D
			if grabbed_object:
				_transition_to_retracting()


func _on_hook_body_entered(body: Node3D) -> void:
	if current_state == HookState.THROWING:
		# Hit something - stick or grab
		if body is RigidBody3D:
			if body.is_in_group("grabbable"):
				grabbed_object = body
				grab_offset = body.global_position - global_position
			landing_position = global_position
			_transition_to_sticking()


## Throw the hook towards a target position
func throw(target_pos: Vector3) -> bool:
	if current_state != HookState.IDLE:
		return false
	
	# Validate range
	if player:
		var distance = player.get_hook_origin().distance_to(target_pos)
		if distance > max_range:
			return false
	
	# Setup throw
	start_position = player.get_hook_origin() if player else global_position
	target_position = target_pos
	
	# Calculate initial velocity for arc
	var horizontal_distance = Vector2(
		target_pos.x - start_position.x,
		target_pos.z - start_position.z
	).length()
	
	# Time to reach target horizontally
	var t = horizontal_distance / throw_force
	
	# Calculate required vertical velocity
	var y_difference = target_pos.y - start_position.y
	var gravity = 9.8
	var vy = (y_difference - 0.5 * gravity * t * t) / t
	
	# Set velocity
	velocity = Vector3(
		(target_pos.x - start_position.x) / t,
		vy,
		(target_pos.z - start_position.z) / t
	)
	
	# Start throwing
	current_state = HookState.THROWING
	throw_timer = 0.0
	visible = true
	
	# Add start position to trail
	trail_points.clear()
	trail_points.append(start_position)
	
	return true


## Cancel and retract hook
func cancel() -> void:
	if current_state == HookState.THROWING or current_state == HookState.STICKING:
		_transition_to_retracting()


## Pull the hook (faster retraction)
func pull() -> void:
	is_pulling = true
	if current_state == HookState.STICKING:
		retract_duration = 1.0  # Faster when pulling
		_transition_to_retracting()


func _update_trail() -> void:
	# Add current position to trail
	trail_points.append(global_position)
	
	# Limit trail length
	while trail_points.size() > max_trail_points:
		trail_points.pop_front()
	
	# Update visual trail (would connect to Line3D or similar)
	# For now, this is a placeholder


func _update_mesh_rotation() -> void:
	# Point hook in direction of movement
	if velocity.length() > 0.5 and current_state == HookState.THROWING:
		look_at(global_position + velocity, Vector3.UP)


## Get hook state as string
func get_state_string() -> String:
	match current_state:
		HookState.IDLE: return "Idle"
		HookState.THROWING: return "Throwing"
		HookState.STICKING: return "Sticking"
		HookState.RETRACTING: return "Retracting"
		HookState.GRABBING: return "Grabbing"
		_: return "Unknown"


## Check if hook is currently active
func is_active() -> bool:
	return current_state != HookState.IDLE


## Get maximum throw range
func get_max_range() -> float:
	return max_range
