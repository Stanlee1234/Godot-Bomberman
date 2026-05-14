# Godot Bomberman

## What I made this with
- Godot 4 (project configured for 4.6)
- GDScript

## Features
- ENet multiplayer setup with server/client roles
- Server-authoritative player spawning via RPC
- Grid-based bomb placement and server-authoritative explosions
- Destructible wall tiles removed from `TileMapLayer` by explosion results from the server
- Movement handled locally on each authority peer (no continuous movement replication)

## Controls
- Move: `WASD` or Arrow keys
- Place bomb: `Space`

## Run locally (server + client)
1. Open the project in Godot 4.6 (or newer Godot 4 release).
2. Start a server instance:
   ```bash
   godot4 --path /path/to/Godot-Bomberman -- --server
   ```
   - You can also use a dedicated server export with the `server` feature tag.
3. Start a client instance (editor run button or CLI):
   ```bash
   godot4 --path /path/to/Godot-Bomberman
   ```
4. The client connects to `127.0.0.1:7777`.
5. Move and press `Space` on the client to request bomb placement. Bomb spawn/explosion and destroyed destructible tiles should match on all peers.
