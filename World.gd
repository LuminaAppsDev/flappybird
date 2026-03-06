extends Node2D
## Contains all gameplay elements: bird, pipes, ground, background.

signal game_over
signal score_changed(score: int)

const BIRD_START := Vector2(60.0, 200.0)

var score: int = 0

@onready var bird: Area2D = $GameLayer/Bird
@onready var pipe_spawner: Node2D = $GameLayer/PipeSpawner
@onready var ground: StaticBody2D = $GameLayer/Ground


func _ready() -> void:
	bird.hit.connect(_on_bird_hit)
	pipe_spawner.pipe_passed.connect(_on_pipe_passed)


func start_game() -> void:
	score = 0
	score_changed.emit(score)
	bird.start()
	bird.flap()
	pipe_spawner.start()
	ground.start()


func reset() -> void:
	score = 0
	bird.reset(BIRD_START)
	pipe_spawner.stop()
	pipe_spawner.clear_pipes()
	ground.start()


func _stop_all() -> void:
	pipe_spawner.stop()
	ground.stop()
	for pipe in $GameLayer/Pipes.get_children():
		pipe.stop()


func _on_bird_hit() -> void:
	_stop_all()
	$HitSound.play()
	$DieSound.play()
	game_over.emit()


func _on_pipe_passed() -> void:
	score += 1
	score_changed.emit(score)
	$PointSound.play()
