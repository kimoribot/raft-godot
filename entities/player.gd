extends CharacterBody3D
class_name Player

enum State { ON_RAFT, SWIMMING, DEAD }

@export var move_speed: float = 5.0
@export var swim_speed: float = 3.0
@export var jump_force: float = 8.0

var current_state: State = State.ON_RAFT
var health: float = 100.0
var oxygen: float = 60.0
var hunger: float = 100.0
var thirst: float = 100.0

var current_raft: Node3D = null
var is_on_raft: bool = true

@onready var camera: Camera3D = $Camera3D
@onready var water_physics: WaterPhysics = get_tree().get_first_node_in_group("water")

func _ready() -> void:
	add_to_group("player")

func _physics_process(delta: float) -> void:
	match current_state:
		State.ON_RAFT:
			process_raft_movement(delta)
		State.SWIMMING:
			process_swimming(delta)
		State.DEAD:
			process_dead(delta)
	
	# Update survival stats
	update_survival(delta)
	
	# Apply wave bobbing when on raft
	if is_on_raft and water_physics:
		var bob = water_physics.get_bob_offset(global_position)
		global_position.y = bob.y + 1.0

func process_raft_movement(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = move_toward(velocity.x, direction.x * move_speed, 10 * delta)
		velocity.z = move_toward(velocity.z, direction.z * move_speed, 10 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, 5 * delta)
		velocity.z = move_toward(velocity.z, 0, 5 * delta)
	
	# Jump into water
	if Input.is_action_just_pressed("jump") and current_raft:
		jump_into_water()
	
	move_and_slide()

func process_swimming(delta: float) -> void:
	oxygen -= delta
	
	if oxygen <= 0:
		health -= delta * 10
		if health <= 0:
			current_state = State.DEAD
	
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	velocity.x = move_toward(velocity.x, direction.x * swim_speed, 5 * delta)
	velocity.z = move_toward(velocity.z, direction.z * swim_speed, 5 * delta)
	
	# Vertical movement
	if Input.is_action_pressed("jump"):
		velocity.y = move_toward(velocity.y, 2.0, 5 * delta)
	else:
		velocity.y = move_toward(velocity.y, -1.0, 2 * delta)
	
	move_and_slide()
	
	# Return to raft if close
	if current_raft and global_position.distance_to(current_raft.global_position) < 3.0:
		return_to_raft()

func process_dead(delta: float) -> void:
	velocity = Vector3.ZERO

func jump_into_water() -> void:
	current_state = State.SWIMMING
	is_on_raft = false
	oxygen = 60.0
	velocity.y = -jump_force

func return_to_raft() -> void:
	current_state = State.ON_RAFT
	is_on_raft = true
	oxygen = 60.0

func update_survival(delta: float) -> void:
	if current_state == State.DEAD:
		return
	
	hunger -= delta * 0.5
	thirst -= delta * 1.0
	
	if hunger <= 0:
		health -= delta * 2
	if thirst <= 0:
		health -= delta * 3
	
	health = clamp(health, 0, 100)

func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0:
		current_state = State.DEAD
