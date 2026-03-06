extends Node
## Main game controller. Manages game states and routes input.

enum State { TITLE, GET_READY, PLAYING, GAME_OVER }

var _state: State = State.TITLE

@onready var _world: Node2D = $World
@onready var _gui: CanvasLayer = $GUI


func _ready() -> void:
	_world.game_over.connect(_on_game_over)
	_world.score_changed.connect(_on_score_changed)
	_gui.play_pressed.connect(_on_play_pressed)
	_gui.retry_pressed.connect(_on_retry_pressed)
	_enter_title()


func _unhandled_input(event: InputEvent) -> void:
	if _state == State.GET_READY:
		if _is_tap(event):
			_enter_playing()
	elif _state == State.PLAYING:
		if _is_tap(event):
			_world.bird.flap()


func _is_tap(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.pressed:
		return true
	if event is InputEventScreenTouch and event.pressed:
		return true
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		return true
	return false


func _enter_title() -> void:
	_state = State.TITLE
	_world.reset()
	_gui.show_title()


func _enter_get_ready() -> void:
	_state = State.GET_READY
	_world.reset()
	_gui.show_get_ready()


func _enter_playing() -> void:
	_state = State.PLAYING
	_gui.show_hud()
	_world.start_game()


func _on_game_over() -> void:
	_state = State.GAME_OVER
	_gui.show_game_over(_world.score)


func _on_score_changed(new_score: int) -> void:
	_gui.update_score(new_score)


func _on_play_pressed() -> void:
	_enter_get_ready()


func _on_retry_pressed() -> void:
	_enter_get_ready()
