extends Node3D
## MultiplayerWorld - Handles world state replication for Raft multiplayer
## Spawns player instances, replicates raft state, syncs collectibles
## Supports 2-8 players for co-op survival

# References
@export var player_scene: PackedScene
@export var raft_scene: PackedScene
@export var collectible_scene: PackedScene

# World sync settings
const SYNC_INTERVAL := 0.1  # 10 times per second
const INTERPOLATION_RATE := 10.0  # Interpolation speed for remote players

# State
var is_world_owner := false  # Server is authoritative
var sync_timer := 0.0
var game_started := false

# World entities
var spawned_players: Dictionary = {}  # peer_id -> Player node
var world_collectibles: Dictionary = {}  # id -> Collectible node
var raft_reference: Node3D = null

# Pending spawns for late-joining players
var pending_player_spawns: Array = []


func _ready() -> void:
	# Get references to existing world objects
	_find_raft_reference()
	_find_collectibles()
	
	# Connect to network manager signals
	if NetworkManager:
		NetworkManager.player_connected.connect(_on_player_connected)
		NetworkManager.player_disconnected.connect(_on_player_disconnected)
		NetworkManager.game_started.connect(_on_game_started)
		
		# Set up as server or client
		if NetworkManager.is_host():
			is_world_owner = true
			_broadcast_world_state()
		else:
			# Client waits for world state from server
			pass


func _process(delta: float) -> void:
	if not game_started:
		return
	
	sync_timer += delta
	
	if sync_timer >= SYNC_INTERVAL:
		sync_timer = 0.0
		_sync_world_state()
	
	# Interpolate remote player positions
	_interpolate_remote_players(delta)


func _find_raft_reference() -> void:
	# Try to find raft in the scene
	raft_reference = get_node_or_null("/root/GameWorld/Raft")
	if not raft_reference:
		# Try other common paths
		raft_reference = get_node_or_null("../Raft")
	if not raft_reference:
		# Look through children
		for child in get_children():
			if child.name.contains("Raft") or "raft" in child.name.to_lower():
				raft_reference = child
				break


func _find_collectibles() -> void:
	# Find all existing collectibles in the world
	var collectibles_container = get_node_or_null("../Collectibles")
	if collectibles_container:
		for child in collectibles_container.get_children():
			if child.has_method("get_collectible_id"):
				world_collectibles[child.get_collectible_id()] = child


# ==================== PLAYER SPAWNING ====================

func spawn_player(peer_id: int, player_name: String, position: Transform3D = Transform3D.IDENTITY) -> Node3D:
	if spawned_players.has(peer_id):
		# Player already spawned, just update
		return spawned_players[peer_id]
	
	var player_node: Node3D = null
	
	# Try to use provided scene or find existing player scene
	if player_scene:
		player_node = player_scene.instantiate()
	else:
		# Try to find player scene in resources
		var player_scene_path := "res://entities/player.tscn"
		if ResourceLoader.exists(player_scene_path):
			player_scene = load(player_scene_path)
			player_node = player_scene.instantiate()
		else:
			# Create a simple placeholder player
			player_node = _create_placeholder_player()
	
	if not player_node:
		push_error("[MultiplayerWorld] Failed to spawn player %d" % peer_id)
		return null
	
	player_node.name = "Player_%d" % peer_id
	player_node.set_meta("peer_id", peer_id)
	player_node.set_meta("player_name", player_name)
	
	# Set initial transform
	if position != Transform3D.IDENTITY:
		player_node.global_transform = position
	
	# Add to scene
	add_child(player_node)
	spawned_players[peer_id] = player_node
	
	# Set up player for multiplayer
	_setup_multiplayer_player(player_node, peer_id)
	
	print("[MultiplayerWorld] Spawned player %s (ID: %d)" % [player_name, peer_id])
	return player_node


func _create_placeholder_player() -> Node3D:
	# Create a simple mesh placeholder for the player
	var player := CharacterBody3D.new()
	player.name = "Player"
	
	# Add collision
	var collision := CollisionShape3D.new()
	collision.shape = CapsuleShape3D.new()
	player.add_child(collision)
	
	# Add mesh
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = CapsuleMesh.new()
	player.add_child(mesh_instance)
	
	# Add name label
	var label := Label3D.new()
	label.name = "NameLabel"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 1.5, 0)
	player.add_child(label)
	
	return player


func _setup_multiplayer_player(player_node: Node3D, peer_id: int) -> void:
	# Configure player based on whether it's local or remote
	var is_local = (peer_id == NetworkManager.get_my_peer_id())
	
	# Set name label
	var label = player_node.get_node_or_null("NameLabel")
	if label:
		var player_name = player_node.get_meta("player_name", "Player")
		label.text = player_name
	
	# Enable/disable controls based on local/remote
	if player_node.has_method("set_network_mode"):
		player_node.set_network_mode(is_local)
	
	# Set up network replication for remote players
	if not is_local:
		player_node.set_process(false)
		player_node.set_physics_process(false)


func despawn_player(peer_id: int) -> void:
	if not spawned_players.has(peer_id):
		return
	
	var player = spawned_players[peer_id]
	spawned_players.erase(peer_id)
	
	# Animate out or destroy
	if is_instance_valid(player):
		player.queue_free()
	
	print("[MultiplayerWorld] Despawned player ID: %d" % peer_id)


# ==================== WORLD STATE SYNC ====================

func _sync_world_state() -> void:
	if NetworkManager.is_host():
		# Server broadcasts world state
		_broadcast_world_state()
	else:
		# Client sends local player state to server
		_send_local_player_state()


func _broadcast_world_state() -> void:
	if not NetworkManager.is_host():
		return
	
	var world_state := {
		"raft_transform": _get_raft_transform_dict(),
		"collectibles": _get_collectibles_state(),
		"players": _get_players_state(),
		"timestamp": Time.get_ticks_msec() / 1000.0
	}
	
	NetworkManager.rpc("_receive_world_state", world_state)


func _send_local_player_state() -> void:
	var my_peer_id = NetworkManager.get_my_peer_id()
	if not spawned_players.has(my_peer_id):
		return
	
	var player = spawned_players[my_peer_id]
	var state := {
		"peer_id": my_peer_id,
		"transform": _transform_to_array(player.global_transform),
		"timestamp": Time.get_ticks_msec() / 1000.0
	}
	
	# Get player components
	if player.has_method("get_inventory"):
		state["inventory"] = player.get_inventory()
	if player.has_method("get_health"):
		state["health"] = player.get_health()
	
	NetworkManager.rpc_id(1, "_receive_player_state", state)


@rpc
func _receive_world_state(state: Dictionary) -> void:
	# Apply raft transform
	if state.has("raft_transform") and raft_reference:
		_apply_raft_transform(state["raft_transform"])
	
	# Sync collectibles
	if state.has("collectibles"):
		_sync_collectibles(state["collectibles"])
	
	# Update remote player states
	if state.has("players"):
		_update_remote_players(state["players"])


@rpc
func _receive_player_state(state: Dictionary) -> void:
	# Server receives player state from clients
	if not NetworkManager.is_host():
		return
	
	var peer_id = state.get("peer_id", 0)
	if not spawned_players.has(peer_id):
		return
	
	var player = spawned_players[peer_id]
	_apply_player_state(player, state)


func _get_raft_transform_dict() -> Dictionary:
	if not raft_reference:
		return {}
	
	return {
		"transform": _transform_to_array(raft_reference.global_transform),
		"velocity": _get_raft_velocity() if raft_reference.has_method("get_velocity") else Vector3.ZERO
	}


func _apply_raft_transform(state: Dictionary) -> void:
	if not raft_reference or not state.has("transform"):
		return
	
	raft_reference.global_transform = _array_to_transform(state["transform"])
	
	if state.has("velocity") and raft_reference.has_method("set_velocity"):
		raft_reference.set_velocity(state["velocity"])


func _get_raft_velocity() -> Vector3:
	if raft_reference and raft_reference.has_method("get_velocity"):
		return raft_reference.get_velocity()
	return Vector3.ZERO


# ==================== COLLECTIBLES SYNC ====================

func _get_collectibles_state() -> Dictionary:
	var state := {}
	
	for id in world_collectibles:
		var collectible = world_collectibles[id]
		if is_instance_valid(collectible):
			state[id] = {
				"transform": _transform_to_array(collectible.global_transform),
				"collected": collectible.is_collected() if collectible.has_method("is_collected") else false
			}
	
	return state


func _sync_collectibles(state: Dictionary) -> void:
	# Mark collected items
	for id in state:
		if not world_collectibles.has(id):
			# New collectible - spawn it
			_spawn_network_collectible(id, state[id])
		else:
			# Update existing
			var collectible = world_collectibles[id]
			if is_instance_valid(collectible):
				if state[id].get("collected", false) and collectible.has_method("collect"):
					collectible.collect()
				else:
					# Interpolate position
					var target_transform = _array_to_transform(state[id]["transform"])
					collectible.global_transform = collectible.global_transform.interpolate_with(target_transform, 0.1)


func _spawn_network_collectible(id: String, state: Dictionary) -> void:
	if collectible_scene:
		var collectible = collectible_scene.instantiate()
		collectible.name = "Collectible_%s" % id
		collectible.set_meta("collectible_id", id)
		
		if state.has("transform"):
			collectible.global_transform = _array_to_transform(state["transform"])
		
		add_child(collectible)
		world_collectibles[id] = collectible


# ==================== PLAYER STATE SYNC ====================

func _get_players_state() -> Dictionary:
	var state := {}
	
	for peer_id in spawned_players:
		var player = spawned_players[peer_id]
		state[peer_id] = {
			"transform": _transform_to_array(player.global_transform),
			"velocity": player.get_velocity() if player is CharacterBody3D else Vector3.ZERO
		}
		
		if player.has_method("get_inventory"):
			state[peer_id]["inventory"] = player.get_inventory()
		if player.has_method("get_health"):
			state[peer_id]["health"] = player.get_health()
	
	return state


func _update_remote_players(state: Dictionary) -> void:
	for peer_id_str in state:
		var peer_id = int(peer_id_str)
		
		# Skip local player
		if peer_id == NetworkManager.get_my_peer_id():
			continue
		
		# Spawn player if needed
		if not spawned_players.has(peer_id):
			var player_name = "Player"
			if NetworkManager.get_player_data(peer_id):
				player_name = NetworkManager.get_player_data(peer_id).name
			spawn_player(peer_id, player_name)
		
		if spawned_players.has(peer_id):
			_apply_player_state(spawned_players[peer_id], state[peer_id_str])


func _apply_player_state(player: Node3D, state: Dictionary) -> void:
	if not is_instance_valid(player):
		return
	
	# Store target transform for interpolation
	var target_transform = _array_to_transform(state.get("transform", []))
	player.set_meta("target_transform", target_transform)
	player.set_meta("last_update", Time.get_ticks_msec() / 1000.0)
	
	# Apply inventory/health if available
	if state.has("inventory") and player.has_method("set_inventory"):
		player.set_inventory(state["inventory"])
	if state.has("health") and player.has_method("set_health"):
		player.set_health(state["health"])


func _interpolate_remote_players(delta: float) -> void:
	var my_peer_id = NetworkManager.get_my_peer_id()
	
	for peer_id in spawned_players:
		if peer_id == my_peer_id:
			continue
		
		var player = spawned_players[peer_id]
		if not is_instance_valid(player):
			continue
		
		var target_transform = player.get_meta("target_transform", null)
		if target_transform:
			player.global_transform = player.global_transform.interpolate_with(target_transform, delta * INTERPOLATION_RATE)


# ==================== LATE JOINING ====================

func handle_player_join(peer_id: int) -> void:
	# Send current world state to newly joining player
	if not NetworkManager.is_host():
		return
	
	var world_state := {
		"raft_transform": _get_raft_transform_dict(),
		"collectibles": _get_collectibles_state(),
		"players": _get_players_state(),
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"game_started": game_started
	}
	
	NetworkManager.rpc_id(peer_id, "_receive_world_state", world_state)
	
	# Queue spawn for the new player
	pending_player_spawns.append(peer_id)


# ==================== SIGNAL HANDLERS ====================

func _on_player_connected(peer_id: int, player_name: String) -> void:
	print("[MultiplayerWorld] Player connected: %s (ID: %d)" % [player_name, peer_id])
	
	if game_started:
		# Mid-game join - send current world state
		handle_player_join(peer_id)
	
	# Spawn player
	spawn_player(peer_id, player_name)


func _on_player_disconnected(peer_id: int) -> void:
	print("[MultiplayerWorld] Player disconnected: ID %d" % peer_id)
	despawn_player(peer_id)


func _on_game_started() -> void:
	game_started = true
	print("[MultiplayerWorld] Game started - multiplayer active")


# ==================== UTILITY FUNCTIONS ====================

func _transform_to_array(transform: Transform3D) -> Array:
	return [
		transform.basis.x.x, transform.basis.x.y, transform.basis.x.z,
		transform.basis.y.x, transform.basis.y.y, transform.basis.y.z,
		transform.basis.z.x, transform.basis.z.y, transform.basis.z.z,
		transform.origin.x, transform.origin.y, transform.origin.z
	]


func _array_to_transform(arr: Array) -> Transform3D:
	if arr.size() < 12:
		return Transform3D.IDENTITY
	
	var basis := Basis(
		Vector3(arr[0], arr[1], arr[2]),
		Vector3(arr[3], arr[4], arr[5]),
		Vector3(arr[6], arr[7], arr[8])
	)
	var origin := Vector3(arr[9], arr[10], arr[11])
	
	return Transform3D(basis, origin)


func get_player_count() -> int:
	return spawned_players.size()


func get_player(peer_id: int) -> Node3D:
	return spawned_players.get(peer_id)


func get_all_players() -> Dictionary:
	return spawned_players.duplicate()


func force_start_game() -> void:
	# Server-only: force start game
	if not NetworkManager.is_host():
		return
	
	game_started = true
	NetworkManager.rpc("_force_game_started")


@rpc
func _force_game_started() -> void:
	game_started = true


# ==================== DEBRIS & COLLECTIBLES MANAGEMENT ====================

func register_collectible(collectible: Node3D) -> void:
	if collectible.has_method("get_collectible_id"):
		var id = collectible.get_collectible_id()
		world_collectibles[id] = collectible


func unregister_collectible(collectible: Node3D) -> void:
	if collectible.has_method("get_collectible_id"):
		var id = collectible.get_collectible_id()
		world_collectibles.erase(id)


func sync_collectible_pickup(peer_id: int, collectible_id: String) -> void:
	# Broadcast collectible pickup to all players
	NetworkManager.rpc("_receive_collectible_pickup", peer_id, collectible_id)


@rpc
func _receive_collectible_pickup(peer_id: int, collectible_id: String) -> void:
	if world_collectibles.has(collectible_id):
		var collectible = world_collectibles[collectible_id]
		if is_instance_valid(collectible) and collectible.has_method("collect"):
			collectible.collect()
