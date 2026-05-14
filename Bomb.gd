extends Node2D

signal detonate_requested(cell: Vector2i, range: int)

@onready var _timer: Timer = $Timer

var cell: Vector2i
var owner_id := 1
var blast_range := 3

func _ready():
    _timer.timeout.connect(_on_timer_timeout)

func setup(p_cell: Vector2i, p_owner_id: int, p_range: int, arm_timer: bool):
    cell = p_cell
    owner_id = p_owner_id
    blast_range = p_range
    if arm_timer:
        _timer.start()
    else:
        _timer.stop()

func _on_timer_timeout():
    detonate_requested.emit(cell, blast_range)
    queue_free()
