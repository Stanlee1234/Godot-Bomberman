# Godot Bomberman

## What I made this with
- Godot 4 (project configured for 4.6)
- GDScript
- Godot WakaTime editor plugin (included in `addons/godot-wakatime`)

## Features
- ENet multiplayer setup with server/client roles
- Server-authoritative player spawning via RPC
- Organized scene tree with TileMapLayer, Players, and Bombs containers
- Player scene based on `CharacterBody2D` with sprite and collision

## How to run locally
1. Open the project in Godot 4.
2. Enable the **Godot-Wakatime** plugin in `Project -> Project Settings -> Plugins`.
3. Run a server instance:
   ```
   godot --server --path /path/to/Godot-Bomberman
   ```
4. Run another instance normally as a client from the editor or with:
   ```
   godot --path /path/to/Godot-Bomberman
   ```
5. The client should connect to `127.0.0.1:7777` and request a player spawn from the server.

## Guide to finish the project
Follow the tutorial steps in the assignment:
- Build out the TileMapLayer with destructible walls and floor tiles.
- Add bomb placement RPCs and a Bomb scene that spawns explosions.
- Keep movement local to the authority peer and replicate only important events.
- Test with one server instance and at least one client instance before exporting.
