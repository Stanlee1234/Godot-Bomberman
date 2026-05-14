extends CharacterBody2D

const SPEED := 120.0

func _physics_process(_delta: float):
    if not is_multiplayer_authority():
        return

    var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    velocity = input_vector * SPEED
    move_and_slide()

    if Input.is_action_just_pressed("place_bomb"):
        var game := get_parent().get_parent()
        if game and game.has_method("request_place_bomb_for_player"):
            game.request_place_bomb_for_player(get_multiplayer_authority())
