extends CanvasLayer
## Handles all UI screens: title, get ready, HUD, and game over.

signal play_pressed
signal retry_pressed

var _atlas: Texture2D = preload("res://assets/gfx/atlas.png")
var _digit_regions: Array[Rect2] = []

@onready var _title_screen: Control = $TitleScreen
@onready var _get_ready_screen: Control = $GetReadyScreen
@onready var _score_container: Node2D = $ScoreContainer
@onready var _game_over_screen: Control = $GameOverScreen


func _ready() -> void:
	_init_digit_regions()


func show_title() -> void:
	_title_screen.visible = true
	_get_ready_screen.visible = false
	_score_container.visible = false
	_game_over_screen.visible = false


func show_get_ready() -> void:
	_title_screen.visible = false
	_get_ready_screen.visible = true
	_score_container.visible = true
	_game_over_screen.visible = false
	update_score(0)


func show_hud() -> void:
	_title_screen.visible = false
	_get_ready_screen.visible = false
	_score_container.visible = true
	_game_over_screen.visible = false


func show_game_over(_final_score: int) -> void:
	_get_ready_screen.visible = false
	_score_container.visible = false
	_game_over_screen.visible = true


func update_score(value: int) -> void:
	for child in _score_container.get_children():
		child.queue_free()

	var digits: String = str(value)
	var total_width := _calculate_score_width(digits)
	var x_offset: float = -total_width / 2.0

	for i in digits.length():
		var idx: int = digits.unicode_at(i) - 48
		var sprite := Sprite2D.new()
		var tex := AtlasTexture.new()
		tex.atlas = _atlas
		tex.region = _digit_regions[idx]
		tex.filter_clip = true
		sprite.texture = tex
		sprite.centered = false
		sprite.position = Vector2(x_offset, -22.0)
		_score_container.add_child(sprite)
		x_offset += _digit_regions[idx].size.x + 2.0


func _calculate_score_width(digits: String) -> float:
	var total: float = 0.0
	for i in digits.length():
		var idx: int = digits.unicode_at(i) - 48
		total += _digit_regions[idx].size.x
	total += (digits.length() - 1) * 2.0
	return total


func _init_digit_regions() -> void:
	_digit_regions = [
		Rect2(992, 116, 24, 44),
		Rect2(272, 906, 16, 44),
		Rect2(584, 316, 24, 44),
		Rect2(612, 316, 24, 44),
		Rect2(640, 316, 24, 44),
		Rect2(668, 316, 24, 44),
		Rect2(584, 364, 24, 44),
		Rect2(612, 364, 24, 44),
		Rect2(640, 364, 24, 44),
		Rect2(668, 364, 24, 44),
	]


func _on_play_button_pressed() -> void:
	play_pressed.emit()


func _on_retry_button_pressed() -> void:
	retry_pressed.emit()
