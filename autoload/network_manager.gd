extends Node
## NetworkManager - High-level multiplayer networking for Raft
## Handles server/client architecture, player management, and state sync
## Supports 2-8 players for co-op survival

# Network settings
const DEFAULT_PORT := 7777
const MAX_PLAYERS := 8
const TICK_RATE := 60  # Network tick rate
const SNAPSHOT_RATE := 15  # State snapshot rate for interpolation

# Network modes
enum NetworkMode { DISCONNECTED, SERVER, CLIENT }

# Signals for game integration
signal player_connected(peer_id: int, player_name: String)
signal player_disconnected(peer_id: int)
signal player_list_updated(players: Dictionary)
signal connection_failed(reason: String)
signal connection_succeeded()
signal game_started()
signal chat_message_received(sender_id: int, sender_name: String, message: String)

# Player data structure
class PlayerData:
	var peer_id: int
	var name: String
	var transform: Transform3D
	var inventory: Dictionary
	var health: float = 100.0
	var is_ready: bool = false
	var last_update_time: float = 0.0

# Internal state
var network_mode: NetworkMode = NetworkMode.DISCONNECTED
var players: Dictionary = {}  # peer_id -> PlayerData
var server_info: Dictionary = {}
var my_peer_id: int = 0
var my_name: String = "Player"
var tick_timer: float = 0.0
var snapshot_timer: float = 0.0

# MultiplayerAPI reference
var multiplayer_api: MultiplayerAPI

# Chat history
var chat_history: Array = []
const MAX_CHAT_HISTORY := 50


func _ready() -> void:
	multiplayer_api = MultiplayerAPI.create_default()
	multiplayer_api.allow_object_decoding = true
	
	# Connect to MultiplayerAPI signals
	multiplayer_api.peer_connected.connect(_on_peer_connected)
	multiplayer_api.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer_api.connected_to_server.connect(_on_connected_to_server)
	multiplayer_api.connection_failed.connect(_on_connection_failed)
	multiplayer_api.server_disconnected.connect(_on_server_disconnected)
	
	# Set as default multiplayer API
	get_tree().set_multiplayer(multiplayer_api, self)


func _process(delta: float) -> void:
	if network_mode == NetworkMode.DISCONNECTED:
		return
	
	tick_timer += delta
	snapshot_timer += delta
	
	# Send regular updates
	if tick_timer >= 1.0 / TICK_RATE:
		tick_timer = 0.0
		_send_network_updates()
	
	# Send state snapshots
	if snapshot_timer >= 1.0 / SNAPSHOT_RATE:
		snapshot_timer = 0.0
		_send_state_snapshots()


# ==================== SERVER FUNCTIONS ====================

func start_server(port: int = DEFAULT_PORT, server_name: String = "Raft Server") -> bool:
	if network_mode != NetworkMode.DISCONNECTED:
		push_warning("Already connected or hosting")
		return false
	
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	
	if err != OK:
		connection_failed.emit("Failed to start server: " + str(err))
		return false
	
	multiplayer_api.multiplayer_peer = peer
	network_mode = NetworkMode.SERVER
	my_peer_id = 1  # Server is always peer_id 1
	
	# Create host player data
	var host_data := PlayerData.new()
	host_data.peer_id = my_peer_id
	host_data.name = my_name
	host_data.transform = Transform3D.IDENTITY
	host_data.is_ready = true
	players[my_peer_id] = host_data
	
	server_info = {
		"name": server_name,
		"port": port,
		"max_players": MAX_PLAYERS,
		"current_players": 1
	}
	
	connection_succeeded.emit()
	player_list_updated.emit(players.duplicate())
	print("[NetworkManager] Server started on port %d" % port)
	return true


func stop_server() -> void:
	if network_mode != NetworkMode.SERVER:
		return
	
	# Notify all clients
	_broadcast_disconnect()
	
	# Clear players
	players.clear()
	multiplayer_api.multiplayer_peer = null
	network_mode = NetworkMode.DISCONNECTED
	print("[NetworkManager] Server stopped")


# ==================== CLIENT FUNCTIONS ====================

func connect_to_server(address: String, port: int = DEFAULT_PORT, player_name: String = "Player") -> bool:
	if network_mode != NetworkMode.DISCONNECTED:
		push_warning("Already connected or hosting")
		return false
	
	my_name = player_name
	
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	
	if err != OK:
		connection_failed.emit("Failed to connect: " + str(err))
		return false
	
	multiplayer_api.multiplayer_peer = peer
	network_mode = NetworkMode.CLIENT
	my_name = player_name
	
	print("[NetworkManager] Connecting to %s:%d" % [address, port])
	return true


func disconnect_from_server() -> void:
	if network_mode == NetworkMode.DISCONNECTED:
		return
	
	if network_mode == NetworkMode.SERVER:
		stop_server()
	else:
		multiplayer_api.multiplayer_peer = null
		players.clear()
		network_mode = NetworkMode.DISCONNECTED
		my_peer_id = 0
		print("[NetworkManager] Disconnected from server")


# ==================== PLAYER MANAGEMENT ====================

func add_peer(peer_id: int, player_name: String) -> void:
	if players.has(peer_id):
		return
	
	var data := PlayerData.new()
	data.peer_id = peer_id
	data.name = player_name
	data.transform = Transform3D.IDENTITY
	data.is_ready = false
	
	players[peer_id] = data
	player_connected.emit(peer_id, player_name)
	player_list_updated.emit(players.duplicate())
	
	print("[NetworkManager] Player %s joined (ID: %d)" % [player_name, peer_id])


func remove_peer(peer_id: int) -> void:
	if not players.has(peer_id):
		return
	
	var player_name = players[peer_id].name
	players.erase(peer_id)
	player_disconnected.emit(peer_id)
	player_list_updated.emit(players.duplicate())
	
	print("[NetworkManager] Player %s disconnected (ID: %d)" % [player_name, peer_id])


func get_player_count() -> int:
	return players.size()


func get_players() -> Dictionary:
	return players.duplicate(true)


func get_player_data(peer_id: int) -> PlayerData:
	return players.get(peer_id)


func is_host() -> bool:
	return network_mode == NetworkMode.SERVER


func is_connected() -> bool:
	return network_mode != NetworkMode.DISCONNECTED


func get_my_peer_id() -> int:
	return my_peer_id


func get_my_name() -> String:
	return my_name


func set_my_name(new_name: String) -> void:
	my_name = new_name
	if players.has(my_peer_id):
		players[my_peer_id].name = new_name


# ==================== SYNC FUNCTIONS ====================

func update_my_transform(transform: Transform3D) -> void:
	if not players.has(my_peer_id):
		return
	
	players[my_peer_id].transform = transform
	players[my_peer_id].last_update_time = Time.get_ticks_msec() / 1000.0


func update_my_inventory(inventory: Dictionary) -> void:
	if not players.has(my_peer_id):
		return
	
	players[my_peer_id].inventory = inventory.duplicate(true)


func update_my_health(health: float) -> void:
	if not players.has(my_peer_id):
		return
	
	players[my_peer_id].health = health


func _send_network_updates() -> void:
	if network_mode == NetworkMode.DISCONNECTED:
		return
	
	# Send player state updates to all peers
	if is_inside_tree():
		rpc("_receive_player_update", my_peer_id, _get_player_state_dict(my_peer_id))


func _send_state_snapshots() -> void:
	if network_mode != NetworkMode.SERVER:
		return
	
	# Server sends full state snapshot to all clients
	rpc("_receive_state_snapshot", _get_full_state_dict())


func _get_player_state_dict(peer_id: int) -> Dictionary:
	if not players.has(peer_id):
		return {}
	
	var p = players[peer_id]
	return {
		"peer_id": peer_id,
		"name": p.name,
		"transform": _transform_to_array(p.transform),
		"inventory": p.inventory,
		"health": p.health,
		"timestamp": Time.get_ticks_msec() / 1000.0
	}


func _get_full_state_dict() -> Dictionary:
	var state := {
		"players": {},
		"timestamp": Time.get_ticks_msec() / 1000.0
	}
	
	for peer_id in players:
		state["players"][peer_id] = _get_player_state_dict(peer_id)
	
	return state


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


# ==================== CHAT SYSTEM ====================

func send_chat_message(message: String) -> void:
	if message.is_empty() or not is_connected():
		return
	
	# Sanitize message
	message = message.strip_edges().left(500)
	
	if network_mode == NetworkMode.SERVER:
		_process_chat_message(my_peer_id, my_name, message)
	else:
		rpc_id(1, "_relay_chat_message", my_peer_id, my_name, message)


@rpc("any_peer")
func _relay_chat_message(sender_id: int, sender_name: String, message: String) -> void:
	# Server processes and broadcasts
	if network_mode == NetworkMode.SERVER:
		_process_chat_message(sender_id, sender_name, message)


func _process_chat_message(sender_id: int, sender_name: String, message: String) -> void:
	# Add to history
	chat_history.append({
		"sender_id": sender_id,
		"sender_name": sender_name,
		"message": message,
		"timestamp": Time.get_ticks_msec() / 1000.0
	})
	
	# Trim history
	while chat_history.size() > MAX_CHAT_HISTORY:
		chat_history.pop_front()
	
	# Emit signal
	chat_message_received.emit(sender_id, sender_name, message)
	
	# Broadcast to all
	if network_mode == NetworkMode.SERVER:
		rpc("_receive_chat_message", sender_id, sender_name, message)


@rpc
func _receive_chat_message(sender_id: int, sender_name: String, message: String) -> void:
	chat_history.append({
		"sender_id": sender_id,
		"sender_name": sender_name,
		"message": message,
		"timestamp": Time.get_ticks_msec() / 1000.0
	})
	chat_message_received.emit(sender_id, sender_name, message)


# ==================== RPC HANDLERS ====================

@rpc
func _receive_player_update(peer_id: int, state: Dictionary) -> void:
	if not players.has(peer_id):
		add_peer(peer_id, state.get("name", "Unknown"))
	
	var p = players[peer_id]
	if state.has("transform"):
		p.transform = _array_to_transform(state["transform"])
	if state.has("inventory"):
		p.inventory = state["inventory"]
	if state.has("health"):
		p.health = state["health"]
	p.last_update_time = state.get("timestamp", 0.0)


@rpc
func _receive_state_snapshot(state: Dictionary) -> void:
	if not state.has("players"):
		return
	
	for peer_id_str in state["players"]:
		var peer_id := int(peer_id_str)
		var p_state = state["players"][peer_id_str]
		
		if not players.has(peer_id):
			add_peer(peer_id, p_state.get("name", "Unknown"))
		
		var p = players[peer_id]
		if p_state.has("transform"):
			p.transform = _array_to_transform(p_state["transform"])
		if p_state.has("inventory"):
			p.inventory = p_state["inventory"]
		if p_state.has("health"):
			p.health = p_state["health"]
		p.last_update_time = p_state.get("timestamp", 0.0)


func _broadcast_disconnect() -> void:
	rpc("_receive_disconnect_notification", my_peer_id)


@rpc
func _receive_disconnect_notification(peer_id: int) -> void:
	remove_peer(peer_id)


# ==================== LOBBY FUNCTIONS ====================

func set_player_ready(ready: bool) -> void:
	if not players.has(my_peer_id):
		return
	
	players[my_peer_id].is_ready = ready
	rpc("_sync_player_ready", my_peer_id, ready)


@rpc
func _sync_player_ready(peer_id: int, ready: bool) -> void:
	if players.has(peer_id):
		players[peer_id].is_ready = ready
		player_list_updated.emit(players.duplicate())


func check_all_players_ready() -> bool:
	for peer_id in players:
		if not players[peer_id].is_ready:
			return false
	return players.size() >= 1


func start_game() -> bool:
	if network_mode != NetworkMode.SERVER:
		return false
	
	if not check_all_players_ready():
		return false
	
	rpc("_receive_game_start")
	game_started.emit()
	return true


@rpc
func _receive_game_start() -> void:
	game_started.emit()


# ==================== SIGNAL HANDLERS ====================

func _on_peer_connected(peer_id: int) -> void:
	print("[NetworkManager] Peer connected: %d" % peer_id)
	# Client waits for server to assign their ID
	# Server assigns ID via name request


func _on_peer_disconnected(peer_id: int) -> void:
	print("[NetworkManager] Peer disconnected: %d" % peer_id)
	remove_peer(peer_id)


func _on_connected_to_server() -> void:
	print("[NetworkManager] Connected to server")
	connection_succeeded.emit()
	my_peer_id = multiplayer_api.get_unique_id()
	
	# Send join request with name
	rpc_id(1, "_request_join", my_peer_id, my_name)


@rpc
func _request_join(peer_id: int, player_name: String) -> void:
	if network_mode == NetworkMode.SERVER:
		add_peer(peer_id, player_name)
		# Send current state to new player
		rpc_id(peer_id, "_receive_state_snapshot", _get_full_state_dict())


func _on_connection_failed() -> void:
	print("[NetworkManager] Connection failed")
	connection_failed.emit("Connection failed")
	network_mode = NetworkMode.DISCONNECTED


func _on_server_disconnected() -> void:
	print("[NetworkManager] Server disconnected")
	players.clear()
	network_mode = NetworkMode.DISCONNECTED
	player_disconnected.emit(0)


# ==================== UTILITY FUNCTIONS ====================

func get_network_info() -> Dictionary:
	return {
		"mode": NetworkMode.keys()[network_mode],
		"my_peer_id": my_peer_id,
		"my_name": my_name,
		"player_count": players.size(),
		"max_players": MAX_PLAYERS,
		"is_host": is_host(),
		"is_connected": is_connected()
	}


func get_chat_history() -> Array:
	return chat_history.duplicate()
