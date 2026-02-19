extends CharacterBody3D
class_name Player
## Player controller with raft movement and ocean survival mechanics

# References
@export var water_physics: WaterPhysics
@export var camera_pivot: Node3D
@export var hook_anchor: Marker3D

# Movement parameters
@export_group("Movement Settings")
@export var move_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var rotation_speed: float = 3.0
@export var acceleration: float = 10.0
@export var deceleration: float = 8.0

# Raft interaction
@export_group("Raft Settings")
@export var raft_detect_radius: float = 3.0
@export var jump_force: float = 8.0
@export var swim_speed: float = 3.0
@export var swim_depth_limit: float = 2.0

# Player state
enum State { ON_RAFT, SWIMMING, DEAD }
var current_state: State = State.ON_RAFT

# Physics
var current_speed: float = 0.0
var target_direction: Vector3 = Vector3.ZERO
var swim_exhaustion: float = 0.0
var oxygen: float = 100.0
var health: float = 100.0
var is_in_water: bool = false

# Hook state
var hook_active: bool = false
var hook_target_position: Vector3 = Vector3.ZERO

# Raft reference
var current_raft: RigidBody3D = null

# Input state
var input_move: Vector2 = Vector2.ZERO
var input_sprint: bool = false

# Visual debug
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	# Auto-find water physics if not assigned
	if not water_physics:
		water_physics = get_tree().get_first_node_in_group("water")
	
	# Setup input
	_setup_input()


func _setup_input() -> void:
	# Input will be handled via _unhandled_input for action events
	pass


func _unhandled_input(event: InputEvent) -> void:
	# Handle movement input
	if event.is_action("move_forward"):
		input_move.y = -1.0 if event.is_pressed() else (input_move.y if input_move.y < 0 else 0)
	elif event.is_action("move_backward"):
		input_move.y = 1.0 if event.is_pressed() else (input_move.y if input_move.y > 0 else 0)
	elif event.is_action("move_left"):
		input_move.x = -1.0 if event.is_pressed() else (input_move.x if input_move.x < 0 else 0)
	elif event.is_action("move_right"):
		input_move.x = 1.0 if event.is_pressed() else (input_move.x if input_move.x > 0 else 0)
	
	# Sprint
	if event.is_action_pressed("move_forward") or event.is_action_pressed("move_backward"):
		input_sprint = Input.is_action_pressed("move_forward") or Input.is_action_pressed("move_backward")


func _physics_process(delta: float) -> void:
	_update_state(delta)
	_handle_movement(delta)
	_apply_environmental_effects(delta)
	_update_animations(delta)


func _update_state(delta: float) -> void:
	# Check if in water
	if water_physics:
		var water_height = water_physics.get_wave_height(global_position)
		is_in_water = global_position.y < water_height
	
	# Check for nearby raft
	_detect_nearby_raft()
	
	# State transitions
	match current_state:
		State.ON_RAFT:
			if is_in_water and not current_raft:
				current_state = State.SWIMMING
				swim_exhaustion = 0.0
		State.SWIMMING:
			if current_raft and not is_in_water:
				current_state = State.ON_RAFT
				oxygen = 100.0
				swim_exhaustion = 0.0
		State.DEAD:
			pass


func _detect_nearby_raft() -> void:
	if current_raft:
		# Check if still near the raft
		var distance = global_position.distance_to(current_raft.global_position)
		if distance > raft_detect_radius * 2.0:
			current_raft = null
	else:
		# Look for nearby raft
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsShapeQueryParameters3D.new()
		var sphere = SphereShape3D.new()
		sphere.radius = raft_detect_radius
		query.shape = sphere
		query.transform = global_transform
		
		var results = space_state.intersect_shape(query)
		for result in results:
			var collider = result["collider"]
			if collider is RigidBody3D and collider.is_in_group("raft"):
				current_raft = collider
				break


func _handle_movement(delta: float) -> void:
	match current_state:
		State.ON_RAFT:
			_handle_raft_movement(delta)
		State.SWIMMING:
			_handle_swim_movement(delta)
		State.DEAD:
			_handle_dead_movement(delta)


func _handle_raft_movement(delta: float) -> void:
	if not current_raft:
		return
	
	# Get movement direction relative to camera
	var move_dir = Vector3(input_move.x, 0, input_move.y)
	
	# Rotate movement direction based on camera
	if camera_pivot:
		var camera_basis = camera_pivot.global_transform.basis
		move_dir = camera_basis * move_dir
		move_dir.y = 0
		move_dir = move_dir.normalized()
	
	# Apply movement to raft
	var target_speed = move_speed
	if input_sprint:
		target_speed = sprint_speed
	
	# Smooth acceleration
	current_speed = move_toward(current_speed, target_speed, acceleration * delta)
	
	# Move on raft (local space)
	var raft_velocity = current_raft.linear_velocity
	var movement = move_dir * current_speed * delta
	
	# Convert to world space and apply to raft
	var world_movement = current_raft.global_transform.basis * movement
	current_raft.apply_central_force(world_movement * 50.0)
	
	# Apply drag to stop drifting
	if move_dir.length() < 0.1:
		current_raft.apply_central_force(-raft_velocity * 5.0)
	
	# Position player on raft
	_follow_raft(delta)


func _handle_swim_movement(delta: float) -> void:
	# Swimming physics
	var move_dir = Vector3(input_move.x, 0, input_move.y)
	
	if camera_pivot:
		var camera_basis = camera_pivot.global_transform.basis
		move_dir = camera_basis * move_dir
	
	# Swimming has vertical control
	if Input.is_action_pressed("move_forward"):
		move_dir = move_dir.normalized()
		# Slight upward bias when swimming forward
		move_dir.y = 0.2
	
	if Input.is_action_pressed("move_backward"):
		move_dir.y = -0.3
	
	# Apply swim movement
	velocity = move_dir * swim_speed
	move_and_slide()
	
	# Keep player at water surface
	if water_physics:
		var water_height = water_physics.get_wave_height(global_position)
		var target_y = water_height - 0.3  # Slightly submerged
		
		if global_position.y < target_y - swim_depth_limit:
			# Rising too slow - sink
			velocity.y = -2.0
		elif global_position.y > target_y + 0.5:
			# Above water too much - sink naturally
			velocity.y -= 5.0 * delta
		else:
			# Float at surface
			velocity.y = lerp(velocity.y, (target_y - global_position.y) * 2.0, delta * 3.0)
		
		# Apply current
		var current = water_physics.get_current(global_position)
		velocity.x += current.x * delta * 2.0
		velocity.z += current.z * delta * 2.0
	
	# Exhaustion from swimming
	swim_exhaustion += delta * 0.1
	if swim_exhaustion > 1.0:
		health -= delta * 5.0


func _handle_dead_movement(delta: float) -> void:
	# Dead players sink
	if water_physics:
		var water_height = water_physics.get_wave_height(global_position)
		if global_position.y > water_height - 5.0:
			velocity.y -= 2.0 * delta
	
	move_and_slide()


func _apply_environmental_effects(delta: float) -> void:
	match current_state:
		State.SWIMMING:
			# Oxygen depletion while swimming
			oxygen -= delta * 2.0
			if oxygen <= 0:
				oxygen = 0
				health -= delta * 10.0
			
			# Health regeneration when not swimming
		State.ON_RAFT:
			if health < 100.0:
				health += delta * 1.0
			oxygen = 100.0
	
	# Check death
	if health <= 0:
		current_state = State.DEAD
		health = 0


func _update_animations(delta: float) -> void:
	# Animation blending would go here
	# For now, this is a placeholder for AnimationPlayer/AnimationTree
	pass


func _follow_raft(delta: float) -> void:
	if not current_raft:
		return
	
	# Get raft surface position
	var raft_center = current_raft.global_position
	var water_height = 0.0
	
	if water_physics:
		water_height = water_physics.get_wave_height(raft_center)
	
	# Position player above raft with wave bobbing
	var target_pos = raft_center
	target_pos.y = water_height + 1.0
	
	# Smooth follow
	global_position = global_position.lerp(target_pos, delta * 5.0)
	
	# Rotate player to face movement direction
	if target_direction.length() > 0.1:
		var target_rotation = atan2(target_direction.x, target_direction.z)
		var current_rotation = rotation.y
		rotation.y = lerp_angle(current_rotation, target_rotation, delta * rotation_speed)


## Jump from raft into water
func jump_into_water() -> void:
	if current_state == State.ON_RAFT and current_raft:
		# Apply jump force
		velocity = Vector3.UP * jump_force
		current_raft = null
		current_state = State.SWIMMING


## Swim to a specific position
func swim_to(target: Vector3) -> void:
	if current_state == State.SWIMMING:
		var direction = (target - global_position).normalized()
		velocity = direction * swim_speed


## Get hook throwing position
func get_hook_origin() -> Vector3:
	if hook_anchor:
		return hook_anchor.global_position
	return global_position + Vector3.UP * 1.5


## Check if can throw hook
func can_throw_hook() -> bool:
	return not hook_active and current_state == State.ON_RAFT


## Activate hook throw
func activate_hook(target_pos: Vector3) -> void:
	if can_throw_hook():
		hook_active = true
		hook_target_position = target_pos


## Deactivate hook
func deactivate_hook() -> void:
	hook_active = false


## Get current health percentage
func get_health_percent() -> float:
	return health / 100.0


## Get current oxygen percentage
func get_oxygen_percent() -> float:
	return oxygen / 100.0


## Get player state as string
func get_state_string() -> String:
	match current_state:
		State.ON_RAFT: return "On Raft"
		State.SWIMMING: return "Swimming"
		State.DEAD: return "Dead"
		_: return "Unknown"


## Take damage
func take_damage(amount: float) -> void:
	health -= amount
	if health < 0:
		health = 0
		current_state = State.DEAD


## Restore oxygen
func restore_oxygen(amount: float) -> void:
	oxygen += amount
	if oxygen > 100.0:
		oxygen = 100.0
