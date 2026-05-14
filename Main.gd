extends Node2D

const PORT := 7777
const MAX_PLAYERS := 4
const BOMB_SCENE := preload("res://bomb.tscn")
const BOMB_RANGE := 3

var _active_bomb_cells: Dictionary = {}
var _spawned_player_ids: Dictionary = {}

func _ready():
    if _is_server_mode():
        start_server()
    else:
        start_client()

func _is_server_mode() -> bool:
    return OS.has_feature("server") or OS.get_cmdline_args().has("--server")

func start_server():
    var peer := ENetMultiplayerPeer.new()
    var err := peer.create_server(PORT, MAX_PLAYERS)
    if err != OK:
        push_error("failed to start server on port %d: %s" % [PORT, error_string(err)])
        return
    multiplayer.multiplayer_peer = peer
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    print("server started on port %d" % PORT)
    _spawn_player_for_all(multiplayer.get_unique_id())

func start_client():
    var peer := ENetMultiplayerPeer.new()
    var err := peer.create_client("127.0.0.1", PORT)
    if err != OK:
        push_error("failed to create client for 127.0.0.1:%d: %s" % [PORT, error_string(err)])
        return
    multiplayer.multiplayer_peer = peer
    multiplayer.connected_to_server.connect(_on_connected_to_server)
    multiplayer.connection_failed.connect(_on_connection_failed)
    multiplayer.server_disconnected.connect(_on_server_disconnected)
    print("connecting to server...")

func _on_peer_connected(id: int):
    print("peer connected: %d" % id)

func _on_peer_disconnected(id: int):
    print("peer disconnected: %d" % id)
    var existing := $Players.get_node_or_null("Player_%d" % id)
    if existing:
        existing.queue_free()
    _spawned_player_ids.erase(id)

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
    var id := multiplayer.get_remote_sender_id()
    for existing_id in _spawned_player_ids.keys():
        rpc_id(id, "spawn_player", int(existing_id))
    _spawn_player_for_all(id)

@rpc("authority", "call_local", "reliable")
func spawn_player(id: int):
    if $Players.get_node_or_null("Player_%d" % id):
        return
    var player := preload("res://Player.tscn").instantiate()
    player.name = "Player_%d" % id
    player.set_multiplayer_authority(id)
    player.position = Vector2(48 + (id * 32), 48)
    $Players.add_child(player, true)

func _spawn_player_for_all(id: int):
    if _spawned_player_ids.has(id):
        return
    _spawned_player_ids[id] = true
    spawn_player.rpc(id)

func request_place_bomb_for_player(player_id: int):
    if multiplayer.is_server():
        _try_place_bomb_for_peer(player_id)
    elif player_id == multiplayer.get_unique_id():
        request_place_bomb.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func request_place_bomb():
    if not multiplayer.is_server():
        return
    var sender_id := multiplayer.get_remote_sender_id()
    _try_place_bomb_for_peer(sender_id)

func _try_place_bomb_for_peer(peer_id: int):
    var player := $Players.get_node_or_null("Player_%d" % peer_id)
    if player == null:
        return
    var tilemap: TileMapLayer = $TileMapLayer
    var cell := tilemap.local_to_map(tilemap.to_local(player.global_position))
    if not _can_place_bomb_at_cell(cell):
        return
    _active_bomb_cells[cell] = true
    spawn_bomb.rpc(cell, peer_id)

func _can_place_bomb_at_cell(cell: Vector2i) -> bool:
    if _active_bomb_cells.has(cell):
        return false
    var tilemap: TileMapLayer = $TileMapLayer
    if not tilemap.get_used_rect().has_point(cell):
        return false
    if tilemap.get_cell_source_id(cell) == -1:
        return false
    var tile_data := tilemap.get_cell_tile_data(cell)
    if tile_data == null:
        return true
    var is_destructible := bool(tile_data.get_custom_data("destructible"))
    if is_destructible:
        return false
    return tile_data.get_collision_polygons_count(0) == 0

@rpc("authority", "call_local", "reliable")
func spawn_bomb(cell: Vector2i, owner_id: int):
    if $Bombs.get_node_or_null("Bomb_%d_%d" % [cell.x, cell.y]):
        return
    var bomb := BOMB_SCENE.instantiate()
    bomb.name = "Bomb_%d_%d" % [cell.x, cell.y]
    bomb.global_position = _cell_to_world_center(cell)
    bomb.setup(cell, owner_id, BOMB_RANGE, multiplayer.is_server())
    bomb.detonate_requested.connect(_on_bomb_detonate_requested)
    $Bombs.add_child(bomb, true)

func _on_bomb_detonate_requested(cell: Vector2i, blast_range: int):
    if not multiplayer.is_server():
        return
    if not _active_bomb_cells.has(cell):
        return
    _active_bomb_cells.erase(cell)
    var explosion_result := _calculate_explosion(cell, blast_range)
    apply_explosion.rpc(explosion_result["affected"], explosion_result["destroyed"])

func _calculate_explosion(origin: Vector2i, blast_range: int) -> Dictionary:
    var tilemap: TileMapLayer = $TileMapLayer
    var affected: Array[Vector2i] = [origin]
    var destroyed: Array[Vector2i] = []
    var directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

    for dir in directions:
        for step in range(1, blast_range + 1):
            var cell := origin + (dir * step)
            if not tilemap.get_used_rect().has_point(cell):
                break
            var tile_data := tilemap.get_cell_tile_data(cell)
            if tile_data == null:
                affected.append(cell)
                continue

            var is_destructible := bool(tile_data.get_custom_data("destructible"))
            if is_destructible:
                affected.append(cell)
                destroyed.append(cell)
                break

            var is_blocking := tile_data.get_collision_polygons_count(0) > 0
            if is_blocking:
                break
            affected.append(cell)

    return {
        "affected": affected,
        "destroyed": destroyed,
    }

@rpc("authority", "call_local", "reliable")
func apply_explosion(affected_cells: Array[Vector2i], destroyed_cells: Array[Vector2i]):
    if not affected_cells.is_empty():
        var origin := affected_cells[0]
        var bomb := $Bombs.get_node_or_null("Bomb_%d_%d" % [origin.x, origin.y])
        if bomb:
            bomb.queue_free()

    for cell in destroyed_cells:
        $TileMapLayer.erase_cell(cell)

    for cell in affected_cells:
        _spawn_explosion_visual(cell)

func _spawn_explosion_visual(cell: Vector2i):
    var visual := Sprite2D.new()
    visual.texture = preload("res://bomb.png")
    visual.modulate = Color(1.0, 0.72, 0.3, 0.9)
    visual.scale = Vector2(0.75, 0.75)
    visual.global_position = _cell_to_world_center(cell)
    $Bombs.add_child(visual)

    var timer := Timer.new()
    timer.wait_time = 0.2
    timer.one_shot = true
    timer.timeout.connect(func():
        if is_instance_valid(visual):
            visual.queue_free()
        timer.queue_free()
    )
    add_child(timer)
    timer.start()

func _cell_to_world_center(cell: Vector2i) -> Vector2:
    var tilemap: TileMapLayer = $TileMapLayer
    return tilemap.to_global(tilemap.map_to_local(cell))
