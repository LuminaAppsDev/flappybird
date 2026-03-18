extends CanvasLayer
## Handles all UI screens: title, get ready, HUD, and game over.

signal play_pressed
signal retry_pressed
signal score_button_pressed
signal rate_button_pressed
signal new_best_score(score: int)

const SAVE_PATH := "user://highscore.cfg"
const GAMEOVER_TEXT_FINAL_Y := 120.0
const PANEL_FINAL_Y := 186.0
const POP_DURATION := 0.3
const SLIDE_DURATION := 0.6
const PAUSE_BETWEEN := 0.4

var _atlas: Texture2D = preload("res://assets/gfx/atlas.png")
var _digit_regions: Array[Rect2] = []
var _panel_digit_regions: Array[Rect2] = []
var _medal_regions: Array[Rect2] = []
var _best_score: int = 0

@onready var _title_screen: Control = $TitleScreen
@onready var _get_ready_screen: Control = $GetReadyScreen
@onready var _score_container: Node2D = $ScoreContainer
@onready var _game_over_screen: Control = $GameOverScreen
@onready var _game_over_text: TextureRect = $GameOverScreen/GameOverText
@onready var _panel_container: Node2D = $GameOverScreen/PanelContainer
@onready var _medal_sprite: Sprite2D = $GameOverScreen/PanelContainer/Medal
@onready var _current_score_node: Node2D = $GameOverScreen/PanelContainer/CurrentScore
@onready var _best_score_node: Node2D = $GameOverScreen/PanelContainer/BestScore
@onready var _new_badge: Sprite2D = $GameOverScreen/PanelContainer/NewBadge
@onready var _title_play_button: TextureButton = $TitleScreen/PlayButton
@onready var _play_button: TextureButton = $GameOverScreen/PlayButton
@onready var _score_button: TextureButton = $GameOverScreen/ScoreButton
@onready var _swoosh: AudioStreamPlayer = $SwooshSound


func _ready() -> void:
	_init_digit_regions()
	_init_panel_regions()
	_setup_button_press_offsets()
	_load_best_score()


func show_title() -> void:
	_title_screen.visible = true
	_get_ready_screen.visible = false
	_score_container.visible = false
	_game_over_screen.visible = false
	_title_play_button.grab_focus()


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


func show_game_over(final_score: int) -> void:
	var is_new_best := final_score > _best_score
	if is_new_best:
		_best_score = final_score
		_save_best_score()
		new_best_score.emit(final_score)

	_get_ready_screen.visible = false
	_score_container.visible = false
	_game_over_screen.visible = true

	_render_panel_digits(_current_score_node, final_score)
	_render_panel_digits(_best_score_node, _best_score)
	_update_medal(final_score)
	_new_badge.visible = is_new_best

	_play_button.visible = false
	_score_button.visible = false
	_panel_container.visible = false
	_animate_game_over()


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


func _render_panel_digits(container: Node2D, value: int) -> void:
	for child in container.get_children():
		child.queue_free()

	var digits: String = str(value)
	var digit_w: float = 16.0
	var spacing: float = 1.0
	var total_width: float = digits.length() * digit_w
	total_width += (digits.length() - 1) * spacing
	var x_offset: float = -total_width

	for i in digits.length():
		var idx: int = digits.unicode_at(i) - 48
		var sprite := Sprite2D.new()
		var tex := AtlasTexture.new()
		tex.atlas = _atlas
		tex.region = _panel_digit_regions[idx]
		tex.filter_clip = true
		sprite.texture = tex
		sprite.centered = false
		sprite.position = Vector2(x_offset, -10.0)
		container.add_child(sprite)
		x_offset += digit_w + spacing


func _update_medal(score: int) -> void:
	if score < 10:
		_medal_sprite.visible = false
		return
	_medal_sprite.visible = true
	var medal_idx: int
	if score >= 40:
		medal_idx = 0
	elif score >= 30:
		medal_idx = 1
	elif score >= 20:
		medal_idx = 2
	else:
		medal_idx = 3
	var tex := AtlasTexture.new()
	tex.atlas = _atlas
	tex.region = _medal_regions[medal_idx]
	tex.filter_clip = true
	_medal_sprite.texture = tex


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


func _init_panel_regions() -> void:
	_panel_digit_regions = [
		Rect2(272, 612, 16, 20),
		Rect2(272, 954, 16, 20),
		Rect2(272, 978, 16, 20),
		Rect2(260, 1002, 16, 20),
		Rect2(1002, 0, 16, 20),
		Rect2(1002, 24, 16, 20),
		Rect2(1008, 52, 16, 20),
		Rect2(1008, 84, 16, 20),
		Rect2(584, 484, 16, 20),
		Rect2(620, 412, 16, 20),
	]
	_medal_regions = [
		Rect2(242, 516, 44, 44),
		Rect2(242, 564, 44, 44),
		Rect2(224, 906, 44, 44),
		Rect2(224, 954, 44, 44),
	]


func _load_best_score() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		_best_score = config.get_value("score", "best", 0)


func _save_best_score() -> void:
	var config := ConfigFile.new()
	config.set_value("score", "best", _best_score)
	config.save(SAVE_PATH)


func _setup_button_press_offsets() -> void:
	for screen in [_title_screen, _game_over_screen]:
		for child in screen.get_children():
			if child is TextureButton:
				child.button_down.connect(_on_button_down.bind(child))
				child.button_up.connect(_on_button_up.bind(child))


func _on_button_down(button: TextureButton) -> void:
	button.position.y += 1.0


func _on_button_up(button: TextureButton) -> void:
	button.position.y -= 1.0


func _animate_game_over() -> void:
	_game_over_text.pivot_offset = _game_over_text.size / 2.0
	_game_over_text.scale = Vector2.ZERO
	_swoosh.play()

	var tween := create_tween()
	(
		tween
		. tween_property(_game_over_text, "scale", Vector2.ONE, POP_DURATION)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_BACK)
	)
	tween.tween_interval(PAUSE_BETWEEN)
	tween.tween_callback(_swoosh.play)
	tween.tween_callback(func() -> void: _panel_container.visible = true)
	_panel_container.position.y = 520.0
	(
		tween
		. tween_property(_panel_container, "position:y", PANEL_FINAL_Y, SLIDE_DURATION)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_CUBIC)
	)
	tween.tween_callback(
		func() -> void:
			_play_button.visible = true
			_score_button.visible = true
			_play_button.grab_focus()
	)


func _on_play_button_pressed() -> void:
	_swoosh.play()
	play_pressed.emit()


func _on_retry_button_pressed() -> void:
	_swoosh.play()
	retry_pressed.emit()


func _on_score_button_pressed() -> void:
	_swoosh.play()
	score_button_pressed.emit()


func _on_rate_button_pressed() -> void:
	_swoosh.play()
	rate_button_pressed.emit()
