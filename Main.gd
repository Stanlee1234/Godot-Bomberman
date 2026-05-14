extends Node2D

const PORT = 7777
const MAX_PLAYERS = 4

func _ready():
if OS.has_feature("server"):
start_server()
else:
start_client()

func start_server():
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		push_error("failed to start server on port %d: %s" % [PORT, err])
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("server started on port %d" % PORT)

func start_client():
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client("127.0.0.1", PORT)
	if err != OK:
		push_error("failed to create client for 127.0.0.1:%d: %s" % [PORT, err])
		return
multiplayer.multiplayer_peer = peer
multiplayer.connected_to_server.connect(_on_connected_to_server)
multiplayer.connection_failed.connect(_on_connection_failed)
multiplayer.server_disconnected.connect(_on_server_disconnected)
print("connecting to server...")

func _on_peer_connected(id):
print("peer connected: %d" % id)

func _on_peer_disconnected(id):
print("peer disconnected: %d" % id)
var existing = $Players.get_node_or_null("Player_%d" % id)
if existing:
existing.queue_free()

func _on_connected_to_server():
print("successfully connected to server")
request_player_spawn.rpc_id(1)

func _on_connection_failed():
print("connection failed")

func _on_server_disconnected():
print("disconnected from server")

@rpc("any_peer", "call_remote", "reliable")
func request_player_spawn():
if not multiplayer.is_server():
return
var id = multiplayer.get_remote_sender_id()
_spawn_player_for_peer(id)

func _spawn_player_for_peer(id):
var player = preload("res://Player.tscn").instantiate()
player.name = "Player_%d" % id
player.set_multiplayer_authority(id)
player.position = Vector2(50 + (id * 100), 50)
$Players.add_child(player, true)
