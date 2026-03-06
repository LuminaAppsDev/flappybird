extends Node2D
## Spawns pipe pairs at regular intervals with randomized vertical positions.

signal pipe_passed

@export var pipe_scene: PackedScene
@export var spawn_interval: float = 1.8
@export var min_y: float = 100.0
@export var max_y: float = 300.0
@export var pipe_speed: float = 100.0

@onready var _spawn_timer: Timer = $SpawnTimer
@onready var _pipes_container: Node2D = get_node("../Pipes")


func _ready() -> void:
	_spawn_timer.wait_time = spawn_interval
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)


func start() -> void:
	_spawn_timer.start()


func stop() -> void:
	_spawn_timer.stop()


func clear_pipes() -> void:
	for pipe in _pipes_container.get_children():
		pipe.queue_free()


func _on_spawn_timer_timeout() -> void:
	var pipe_pair: Node2D = pipe_scene.instantiate()
	pipe_pair.position = Vector2(320.0, randf_range(min_y, max_y))
	pipe_pair.speed = pipe_speed
	pipe_pair.passed.connect(_on_pipe_passed)
	_pipes_container.add_child(pipe_pair)


func _on_pipe_passed() -> void:
	pipe_passed.emit()
