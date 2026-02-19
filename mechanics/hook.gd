extends Node3D
class_name Hook

enum State { IDLE, THROWING, STICKING, RETRACTING, GRABBING }

@export var throw_speed: float = 20.0
@export var retract_speed: float = 15.0
@export var max_range: float = 30.0

var current_state: State = State.IDLE
var throw_direction: Vector3 = Vector3.FORWARD
var target_position: Vector3 = Vector3.ZERO
var current_target: Node3D = null

@onready var player: Node3D = get_parent()
@onready var water_physics: WaterPhysics = get_tree().get_first_node_in_group("water")

func _ready() -> void:
	add_to_group("hook")

func _process(delta: float) -> void:
	match current_state:
		State.THROWING:
			process_throwing(delta)
		State.STICKING:
			process_sticking(delta)
		State.RETRACTING:
			process_retracting(delta)
		State.GRABBING:
			process_grabbing(delta)

func throw_hook(direction: Vector3) -> void:
	if current_state != State.IDLE:
		return
	
	throw_direction = direction.normalized()
	target_position = player.global_position + throw_direction * max_range
	current_state = State.THROWING

func process_throwing(delta: float) -> void:
	var move_vec = throw_direction * throw_speed * delta
	global_position += move_vec
	
	# Check if hit max range or water surface
	if global_position.distance_to(player.global_position) >= max_range:
		current_state = State.RETRACTING
	
	# Check for collision with objects
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(player.global_position, global_position)
	var result = space_state.intersect_ray(query)
	
	if result and result.collider.has_method("grab"):
		current_target = result.collider
		current_state = State.GRABBING

func process_sticking(delta: float) -> void:
	# Stick to surface briefly then retract
	await get_tree().create_timer(0.5).timeout
	current_state = State.RETRACTING

func process_retracting(delta: float) -> void:
	var direction = (player.global_position - global_position).normalized()
	global_position += direction * retract_speed * delta
	
	if global_position.distance_to(player.global_position) < 1.5:
		current_state = State.IDLE

func process_grabbing(delta: float) -> void:
	if is_instance_valid(current_target):
		current_target.global_position = global_position
		
		# Pull toward player
		var direction = (player.global_position - global_position).normalized()
		global_position += direction * retract_speed * delta
		
		if global_position.distance_to(player.global_position) < 2.0:
			# Deliver item
			if current_target.has_method("collect"):
				current_target.collect()
			current_target = null
			current_state = State.IDLE
	else:
		current_state = State.RETRACTING

func cancel_hook() -> void:
	current_state = State.RETRACTING
	current_target = null
