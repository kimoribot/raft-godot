extends RigidBody3D
class_name RaftTile
## Individual building piece (foundation, bed, etc.)
## RigidBody3D that can connect to raft
## Can be damaged by shark and falls away when destroyed

signal tile_damaged(amount: float, source: Node)
signal tile_destroyed
signal health_changed(new_health: float)

#== TILE TYPES ==#
enum TileType {
	FOUNDATION,
	FLOOR,
	BED,
	STORAGE,
	GRILL,
	WATER_CATCHER,
	PLANTER,
	STOVE,
	ENGINE,
	RAZOR,
	ANTENNA,
	TURRET,
	SIMPLE
}

#== EXPORTS ==#
@export_category("Tile Settings")
@export var tile_type: TileType = TileType.FOUNDATION
@export var tile_name: String = "Tile"
@export var tile_description: String = "A building tile"
@export var grid_size: Vector2i = Vector2i(1, 1)

@export_category("Health")
@export var max_tile_health: float = 50.0
@export var is_destroyable: bool = true

@export_category("Physics")
@export var buoyancy_factor: float = 1.0
@export var mass_multiplier: float = 1.0

#== STATE ==#
var current_raft: Raft = null
var grid_position: Vector2i = Vector2i.ZERO
var is_connected: bool = false
var tile_health: float = max_tile_health
var is_indestructible: bool = false

#== CACHED NODES ==#
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D if has_node("MeshInstance3D") else null
@onready var collision_shape: CollisionShape3D = $CollisionShape3D if has_node("CollisionShape3D") else null

func _ready() -> void:
	_setup_tile()

func _setup_tile() -> void:
	# Configure physics for floating tile behavior
	mass = 10.0 * mass_multiplier
	
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.5
	physics_material_override.bounce = 0.1
	
	# High damping when not connected (will fall)
	linear_damp = 0.5
	angular_damp = 0.5
	
	# Disable by default until connected
	if not is_connected:
		freeze = true

func _physics_process(delta: float) -> void:
	if is_connected and current_raft != null:
		_follow_raft(delta)
	
	# Check if fallen too far (cleanup)
	if global_position.y < -50:
		queue_free()

func _follow_raft(delta: float) -> void:
	if current_raft == null or not is_instance_valid(current_raft):
		_disconnect_from_raft()
		return
	
	# Calculate target position in raft local space
	var raft_transform = current_raft.global_transform
	var local_offset = Vector3(
		grid_position.x * current_raft.grid_size,
		0,
		grid_position.y * current_raft.grid_size
	)
	var target_pos = raft_transform * local_offset
	
	# Smooth follow
	global_position = global_position.lerp(target_pos, delta * 15.0)
	
	# Match raft rotation (smooth)
	var target_basis = raft_transform.basis
	var current_basis = global_transform.basis
	var new_basis = current_basis.slerp(target_basis, delta * 10.0)
	global_transform.basis = new_basis

#== CONNECTION API ==#

func connect_to_raft(raft: Raft, grid_pos: Vector2i) -> void:
	current_raft = raft
	grid_position = grid_pos
	is_connected = true
	
	# Enable physics but with high damping
	freeze = false
	linear_damp = 2.0
	angular_damp = 2.0
	
	# Set collision layer to raft
	set_collision_layer_value(2, true)  # Raft layer
	set_collision_mask_value(1, true)    # World
	
	# Update parent reference for tile
	if get_parent() != raft:
		reparent(raft)

func disconnect_from_raft() -> void:
	is_connected = false
	
	# Store grid position before clearing
	var stored_grid_pos = grid_position
	
	# Clear raft reference
	current_raft = null
	grid_position = Vector2i.ZERO
	
	# Enable full physics (fall into water)
	freeze = false
	linear_damp = 1.0
	angular_damp = 1.0
	
	# Apply water entry force
	_apply_water_entry_force()
	
	# Re-parent to world
	if get_parent() != get_tree().current_scene:
		reparent(get_tree().current_scene)

func _disconnect_from_raft() -> void:
	disconnect_from_raft()

func _apply_water_entry_force() -> void:
	# Small random impulse when entering water
	var impulse = Vector3(
		randf_range(-0.5, 0.5),
		randf_range(0.2, 0.5),
		randf_range(-0.5, 0.5)
	)
	apply_central_impulse(impulse)

#== DAMAGE API ==#

func damage(amount: float, source: Node = null) -> void:
	if is_indestructible or not is_destroyable:
		return
	
	tile_health = max(0, tile_health - amount)
	health_changed.emit(tile_health)
	tile_damaged.emit(amount, source)
	
	if tile_health <= 0:
		destroy()

func heal(amount: float) -> void:
	tile_health = min(max_tile_health, tile_health + amount)
	health_changed.emit(tile_health)

func destroy() -> void:
	if current_raft != null:
		current_raft.destroy_tile(self)
	
	# Play destruction effect
	_play_destruction_effect()
	
	tile_destroyed.emit()
	queue_free()

func _play_destruction_effect() -> void:
	# Visual feedback for destruction
	# Could spawn particles, debris, etc.
	pass

#== DATA API ==#

func get_tile_data() -> Dictionary:
	return {
		"type": tile_type,
		"name": tile_name,
		"description": tile_description,
		"health": tile_health,
		"max_health": max_tile_health,
		"grid_size": grid_size,
		"grid_position": grid_position,
		"is_connected": is_connected
	}

func get_buoyancy_factor() -> float:
	# Different tile types affect buoyancy differently
	match tile_type:
		TileType.STORAGE:
			return 0.7  # Heavy, less buoyant
		TileType.ENGINE:
			return 0.8
		TileType.BED:
			return 1.0
		TileType.FOUNDATION:
			return 1.2  # Provides buoyancy
		TileType.WATER_CATCHER:
			return 1.1
		_:
			return buoyancy_factor

func get_mass_contribution() -> float:
	match tile_type:
		TileType.STORAGE:
			return 3.0  # Heavy
		TileType.ENGINE:
			return 2.5
		TileType.BED:
			return 1.5
		TileType.FOUNDATION:
			return 1.0
		TileType.GRILL, TileType.STOVE:
			return 1.2
		_:
			return mass_multiplier

func get_interaction_prompt() -> String:
	match tile_type:
		TileType.BED:
			return "Sleep"
		TileType.STORAGE:
			return "Open"
		TileType.GRILL:
			return "Cook"
		TileType.WATER_CATCHER:
			return "Collect Water"
		TileType.PLANTER:
			return "Harvest"
		TileType.STOVE:
			return "Craft"
		_:
			return "Interact"

#== INTERACTION ==#

func interact(interactor: Node3D) -> void:
	# Override in subclasses for specific interactions
	pass

func can_interact(interactor: Node3D) -> bool:
	# Override in subclasses
	return true

#== TYPE CHECKING ==#

func is_foundation() -> bool:
	return tile_type == TileType.FOUNDATION

func is_storage() -> bool:
	return tile_type == TileType.STORAGE

func is_occupiable() -> bool:
	return tile_type in [TileType.BED, TileType.FLOOR, TileType.FOUNDATION]

#== SERIALIZATION ==#

func get_save_data() -> Dictionary:
	return {
		"tile_type": tile_type,
		"grid_position": { "x": grid_position.x, "y": grid_position.y },
		"health": tile_health,
		"transform": {
			"position": { "x": global_position.x, "y": global_position.y, "z": global_position.z },
			"rotation": { "x": rotation.x, "y": rotation.y, "z": rotation.z }
		}
	}

func load_save_data(data: Dictionary) -> void:
	if data.has("tile_type"):
		tile_type = data["tile_type"]
	
	if data.has("health"):
		tile_health = data["health"]
	
	if data.has("grid_position"):
		var gp = data["grid_position"]
		grid_position = Vector2i(gp.get("x", 0), gp.get("y", 0))
