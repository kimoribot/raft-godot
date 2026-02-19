extends Node
## Network Manager - Multiplayer for Raft

const DEFAULT_PORT = 7777
const MAX_PLAYERS = 8

signal player_connected(id, name)
signal player_disconnected(id)
signal connection_succeeded()
signal connection_failed(reason)
signal chat_message(id, name, message)

var players = {}
var my_id = 0
var my_name = "Player"
var chat_history = []

func create_server(port = DEFAULT_PORT) -> bool:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		emit_signal("connection_failed", "Failed to create server")
		return false
	multiplayer.set_multiplayer_peer(peer)
	my_id = 1
	players[1] = {"name": my_name}
	emit_signal("connection_succeeded")
	print("[Network] Server started on port ", port)
	return true

func join_server(ip: String, port = DEFAULT_PORT) -> bool:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, port)
	if err != OK:
		emit_signal("connection_failed", "Failed to connect")
		return false
	multiplayer.set_multiplayer_peer(peer)
	emit_signal("connection_succeeded")
	print("[Network] Joining ", ip, ":", port)
	return true

func disconnect_network() -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.get_multiplayer_peer().close()
	players.clear()
	my_id = 0

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_peer_connected(id: int) -> void:
	players[id] = {"name": "Player" + str(id)}
	emit_signal("player_connected", id, players[id].name)
	print("[Network] Player ", id, " connected")

func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
	emit_signal("player_disconnected", id)
	print("[Network] Player ", id, " disconnected")

func _on_connected_to_server() -> void:
	my_id = multiplayer.get_unique_id()
	print("[Network] Connected with ID: ", my_id)

func _on_connection_failed() -> void:
	emit_signal("connection_failed", "Connection failed")

func _on_server_disconnected() -> void:
	players.clear()
	print("[Network] Server disconnected")

func send_chat(message: String) -> void:
	if my_id == 0: return
	chat_history.append({"id": my_id, "name": my_name, "message": message})
	rpc("broadcast_chat", my_id, my_name, message)

@rpc func broadcast_chat(id: int, name: String, message: String) -> void:
	chat_history.append({"id": id, "name": name, "message": message})
	emit_signal("chat_message", id, name, message)

func is_server() -> bool:
	return my_id == 1 and players.size() > 0

func is_network_connected() -> bool:
	return my_id != 0

func get_player_count() -> int:
	return players.size()
