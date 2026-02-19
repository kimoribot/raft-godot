extends CharacterBody3D
class_name Shark

enum State { PATROL, CHASE, ATTACK, RETREAT }

@export var patrol_speed: float = 3.0
@export var chase_speed: float = 6.0
@export var attack_speed: float = 8.0
@export var detection_radius: float = 20.0
@export var attack_radius: float = 5.0
@export var raft_attack_damage: float = 15.0
@export var raft_attack_cooldown: float = 2.0

var current_state: State = State.PATROL
var target: Node3D = null
var patrol_points: Array[Vector3] = []
var current_patrol_index: int = 0
var attack_cooldown: float = 0.0
var raft_attack_timer: float = 0.0
var health: float = 100.0

@onready var water_physics: WaterPhysics = get_tree().get_first_node_in_group("water")

func _ready() -> void:
	add_to_group("shark")
	generate_patrol_points()

func _physics_process(delta: float) -> void:
	if attack_cooldown > 0:
		attack_cooldown -= delta
	if raft_attack_timer > 0:
		raft_attack_timer -= delta
	
	match current_state:
		State.PATROL:
			patrol(delta)
		State.CHASE:
			chase(delta)
		State.ATTACK:
			attack(delta)
		State.RETREAT:
			retreat(delta)
	
	# Apply wave motion
	if water_physics:
		var bob = water_physics.get_bob_offset(global_position)
		global_position.y = bob.y + 0.5
	
	# Check for raft tile collisions (shark attacks raft)
	_check_raft_collision(delta)

func generate_patrol_points() -> void:
	var center = Vector3.ZERO
	for i in range(8):
		var angle = i * PI / 4.0
		var point = center + Vector3(cos(angle) * 30, 0, sin(angle) * 30)
		patrol_points.append(point)

func patrol(delta: float) -> void:
	if patrol_points.is_empty():
		return
	
	var target_point = patrol_points[current_patrol_index]
	var direction = (target_point - global_position).normalized()
	
	velocity = direction * patrol_speed
	look_at(target_point, Vector3.UP)
	move_and_slide()
	
	if global_position.distance_to(target_point) < 2.0:
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
	
	# Check for player
	var player = get_tree().get_first_node_in_group("player")
	if player and global_position.distance_to(player.global_position) < detection_radius:
		current_state = State.CHASE
		target = player
	
	# Check for raft tiles to attack
	_check_for_raft_proximity()

func chase(delta: float) -> void:
	if not is_instance_valid(target):
		current_state = State.PATROL
		return
	
	var player = target as Node3D
	var dist = global_position.distance_to(player.global_position)
	
	# Check if player is in water vs on raft
	var player_state = player.get("current_state")
	var is_in_water = player_state and player_state != 0  # Not ON_RAFT
	
	if is_in_water:
		# More aggressive when player in water
		detection_radius = 30.0
		attack_radius = 8.0
	else:
		detection_radius = 15.0
		attack_radius = 3.0
	
	if dist > detection_radius:
		current_state = State.PATROL
		target = null
	elif dist < attack_radius and attack_cooldown <= 0:
		current_state = State.ATTACK
	elif dist < detection_radius:
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * chase_speed
		look_at(player.global_position, Vector3.UP)
		move_and_slide()

func attack(delta: float) -> void:
	if not is_instance_valid(target):
		current_state = State.PATROL
		return
	
	var player = target as Node3D
	var direction = (player.global_position - global_position).normalized()
	
	velocity = direction * attack_speed
	look_at(player.global_position, Vector3.UP)
	move_and_slide()
	
	# Deal damage on contact
	var dist = global_position.distance_to(player.global_position)
	if dist < 2.0:
		if player.has_method("take_damage"):
			player.take_damage(25)
		attack_cooldown = 3.0
		current_state = State.RETREAT
	
	# Check if player died
	if player.get("current_state") == 2:  # DEAD
		current_state = State.PATROL
		target = null

func retreat(delta: float) -> void:
	# Move away from player
	var direction = (global_position - target.global_position).normalized() if is_instance_valid(target) else Vector3.FORWARD
	velocity = direction * patrol_speed
	move_and_slide()
	
	if attack_cooldown <= 0:
		current_state = State.PATROL

func _check_for_raft_proximity() -> void:
	# Check if shark is near the raft
	var building_system = get_tree().get_first_node_in_group("building_system")
	var raft = get_tree().get_first_node_in_group("raft")
	
	if raft:
		var dist = global_position.distance_to(raft.global_position)
		if dist < detection_radius:
			current_state = State.CHASE

func _check_raft_collision(delta: float) -> void:
	# Check if shark should attack raft tiles
	if current_state == State.CHASE or current_state == State.PATROL:
		if raft_attack_timer > 0:
			return
		
		# Find nearby raft tiles
		var building_system = get_tree().get_first_node_in_group("building_system")
		var raft = get_tree().get_first_node_in_group("raft")
		
		if building_system:
			var tiles = building_system.get_placed_tiles()
			for grid_pos in tiles:
				var tile = tiles[grid_pos]
				if is_instance_valid(tile):
					var dist = global_position.distance_to(tile.global_position)
					if dist < 3.0:
						# Attack the tile!
						_attack_raft_tile(tile)
						raft_attack_timer = raft_attack_cooldown
						return

func _attack_raft_tile(tile: RaftTile) -> void:
	if tile.has_method("damage"):
		tile.damage(raft_attack_damage, self)
		
		# Play attack sound
		var audio_manager = get_tree().get_first_node_in_group("audio_manager")
		if audio_manager and audio_manager.has_method("play_shark_attack"):
			audio_manager.play_shark_attack()
		
		# Visual feedback - recoil from attack
		velocity = -velocity * 0.5
		
		# After attacking, retreat briefly
		current_state = State.RETREAT
		attack_cooldown = 1.0

func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0:
		die()

func die() -> void:
	queue_free()
