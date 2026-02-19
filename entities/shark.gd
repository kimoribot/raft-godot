extends RigidBody3D
class_name Shark
## Shark AI with patrol, chase, and attack behaviors
## Threatens the player when in water and can damage the raft

# AI Parameters
@export_group("AI Settings")
@export var patrol_speed: float = 3.0
@export var chase_speed: float = 7.0
@export var attack_speed: float = 9.0
@export var detection_radius: float = 20.0
@export var attack_radius: float = 5.0
@export var chase_timeout: float = 10.0

# Patrol behavior
@export_group("Patrol Settings")
@export var patrol_radius: float = 30.0
@export var patrol_points_count: int = 8
@export var wait_time_at_point: float = 2.0

# Attack behavior
@export_group("Attack Settings")
@export var attack_damage: float = 25.0
@export var attack_cooldown: float = 3.0
@export var raft_damage: float = 15.0
@export var bite_force: float = 500.0

# Visual
@export_group("Visual Settings")
@export var mesh: MeshInstance3D

# State machine
enum State { PATROL, CHASE, ATTACK, RETREAT }
var current_state: State = State.PATROL
var target: Node3D = null
var last_known_player_position: Vector3 = Vector3.ZERO

# Timers
var chase_timer: float = 0.0
var attack_cooldown_timer: float = 0.0
var wait_timer: float = 0.0

# Movement
var patrol_points: Array[Vector3] = []
var current_patrol_index: int = 0
var movement_direction: Vector3 = Vector3.ZERO

# References
var water_physics: WaterPhysics = null

# Debug
var debug_mode: bool = false


func _ready() -> void:
	# Add to physics groups
	add_to_group("shark")
	add_to_group("enemy")
	
	# Find water physics
	if not water_physics:
		water_physics = get_tree().get_first_node_in_group("water")
	
	# Setup collision
	_setup_collision()
	
	# Generate patrol points
	_generate_patrol_points()
	
	# Random starting point
	current_patrol_index = randi() % patrol_points.size()
	
	# Setup physics
	mass = 200.0
	linear_damp = 2.0
	angular_damp = 3.0
	
	# Gravity handled by water
	gravity_scale = 0.0


func _setup_collision() -> void:
	# Create shark-shaped collision
	if not collision_shape:
		var shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(4.0, 1.5, 2.0)
		shape.shape = box
		add_child(shape)


func _generate_patrol_points() -> void:
	patrol_points.clear()
	var origin = global_position
	
	for i in range(patrol_points_count):
		var angle = (PI * 2.0 / patrol_points_count) * i
		var point = origin + Vector3(
			cos(angle) * patrol_radius,
			0,
			sin(angle) * patrol_radius
		)
		
		# Keep at water level
		if water_physics:
			point.y = water_physics.get_wave_height(point)
		
		patrol_points.append(point)


func _physics_process(delta: float) -> void:
	# Update timers
	if chase_timer > 0:
		chase_timer -= delta
	
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
	
	if wait_timer > 0:
		wait_timer -= delta
	
	# Update water depth
	_update_depth()
	
	# State machine
	match current_state:
		State.PATROL:
			_patrol_behavior(delta)
		State.CHASE:
			_chase_behavior(delta)
		State.ATTACK:
			_attack_behavior(delta)
		State.RETREAT:
			_retreat_behavior(delta)
	
	# Apply movement
	_apply_movement(delta)


func _update_depth() -> void:
	if water_physics:
		var water_height = water_physics.get_wave_height(global_position)
		
		# Keep shark at water surface
		if global_position.y < water_height - 1.0:
			apply_central_force(Vector3.UP * 100.0)
		elif global_position.y > water_height + 0.5:
			apply_central_force(Vector3.DOWN * 50.0)
		
		# Apply current
		var current = water_physics.get_current(global_position)
		apply_central_force(current * mass * 0.5)


func _patrol_behavior(delta: float) -> void:
	# Check for player detection
	var player = _get_player()
	if player and _can_detect_player(player):
		_start_chase(player)
		return
	
	# Wait at patrol point
	if wait_timer > 0:
		return
	
	# Move to current patrol point
	var target_point = patrol_points[current_patrol_index]
	var distance_to_point = global_position.distance_to(target_point)
	
	if distance_to_point < 3.0:
		# Reached point, move to next
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
		wait_timer = wait_time_at_point
		movement_direction = Vector3.ZERO
	else:
		# Move towards point
		movement_direction = (target_point - global_position).normalized()
		_look_towards(target_point)


func _chase_behavior(delta: float) -> void:
	var player = _get_player()
	
	if not player:
		# Player lost, check timeout
		if chase_timer <= 0:
			_return_to_patrol()
		else:
			# Search last known position
			movement_direction = (last_known_player_position - global_position).normalized()
			_look_towards(last_known_player_position)
		return
	
	# Check if player is in water
	var player_in_water = false
	if player.has_method("is_in_water_state"):
		player_in_water = player.is_in_water_state()
	
	if not player_in_water and player.current_state != player.State.SWIMMING:
		# Player on raft, stay in chase but don't get too close
		var distance = global_position.distance_to(player.global_position)
		if distance < attack_radius * 2.0:
			# Circle around
			var to_player = (player.global_position - global_position).normalized()
			var perpendicular = Vector3(-to_player.z, 0, to_player.x)
			movement_direction = perpendicular * 0.5 + to_player * 0.5
			chase_timer = chase_timeout
		else:
			# Get closer
			movement_direction = to_player
			last_known_player_position = player.global_position
			chase_timer = chase_timeout
	else:
		# Player in water - ATTACK!
		var distance = global_position.distance_to(player.global_position)
		last_known_player_position = player.global_position
		chase_timer = chase_timeout
		
		if distance < attack_radius:
			_start_attack(player)
		else:
			# Chase towards player
			movement_direction = (player.global_position - global_position).normalized()
			_look_towards(player.global_position)


func _attack_behavior(delta: float) -> void:
	var player = _get_player()
	
	if not player or attack_cooldown_timer > 0:
		_return_to_patrol()
		return
	
	# Move directly at player
	var target_pos = player.global_position
	var distance = global_position.distance_to(target_pos)
	
	if distance < 2.0:
		# Bite!
		if attack_cooldown_timer <= 0:
			_perform_bite(player)
	else:
		# Move in for the kill
		movement_direction = (target_pos - global_position).normalized()
		_look_towards(target_pos)


func _perform_bite(player: Node3D) -> void:
	var damage = attack_damage
	
	# Apply damage to player
	if player.has_method("take_damage"):
		player.take_damage(damage)
	
	# Apply bite force (knockback)
	var bite_direction = (player.global_position - global_position).normalized()
	player.apply_central_force(bite_direction * bite_force)
	
	# Reset cooldown
	attack_cooldown_timer = attack_cooldown
	
	# Retreat briefly after attack
	current_state = State.RETREAT


func _retreat_behavior(delta: float) -> void:
	# Move away from player
	var player = _get_player()
	if player:
		var away_direction = (global_position - player.global_position).normalized()
		movement_direction = away_direction
	
	# Return to patrol after brief retreat
	if attack_cooldown_timer <= 0:
		_return_to_patrol()


func _apply_movement(delta: float) -> void:
	# Calculate speed based on state
	var speed = patrol_speed
	match current_state:
		State.CHASE:
			speed = chase_speed
		State.ATTACK:
			speed = attack_speed
		State.RETREAT:
			speed = chase_speed * 0.8
	
	# Apply force in movement direction
	if movement_direction.length() > 0.1:
		var force = movement_direction * speed * mass
		apply_central_force(force)
	
	# Apply drag
	var velocity_length = linear_velocity.length()
	if velocity_length > speed:
		apply_central_force(-linear_velocity.normalized() * velocity_length * mass * 0.5)


func _look_towards(target_position: Vector3) -> void:
	var direction = target_position - global_position
	if direction.length() > 0.1:
		var target_rotation = atan2(direction.x, direction.z)
		var current_rotation = rotation.y
		rotation.y = lerp_angle(current_rotation, target_rotation, delta * 3.0)


func _get_player() -> Node3D:
	return get_tree().get_first_node_in_group("player")


func _can_detect_player(player: Node3D) -> bool:
	if not player:
		return false
	
	var distance = global_position.distance_to(player.global_position)
	return distance < detection_radius


func _start_chase(player: Node3D) -> void:
	current_state = State.CHASE
	chase_timer = chase_timeout
	last_known_player_position = player.global_position


func _start_attack(player: Node3D) -> void:
	current_state = State.ATTACK


func _return_to_patrol() -> void:
	current_state = State.PATROL
	_generate_patrol_points()
	current_patrol_index = randi() % patrol_points.size()


## Attack the raft
func attack_raft(raft: RigidBody3D) -> void:
	if attack_cooldown_timer > 0:
		return
	
	# Damage the raft
	var damage = raft_damage
	
	if raft.has_method("take_damage"):
		raft.take_damage(damage)
	
	# Apply force to raft
	var attack_direction = (raft.global_position - global_position).normalized()
	raft.apply_central_force(attack_direction * bite_force * 2.0)
	
	# Reset cooldown
	attack_cooldown_timer = attack_cooldown
	
	# Visual/audio feedback would go here


## Check if shark is currently aggressive
func is_aggressive() -> bool:
	return current_state == State.CHASE or current_state == State.ATTACK


## Get current state as string
func get_state_string() -> String:
	match current_state:
		State.PATROL: return "Patrolling"
		State.CHASE: return "Chasing"
		State.ATTACK: return "Attacking"
		State.RETREAT: return "Retreating"
		_: return "Unknown"


## Force shark to leave area
func flee_from(position: Vector3) -> void:
	var away_direction = global_position - position
	away_direction.y = 0
	if away_direction.length() > 0:
		movement_direction = away_direction.normalized()
		current_state = State.RETREAT
		attack_cooldown_timer = 2.0
