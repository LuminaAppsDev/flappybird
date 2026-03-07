extends Node2D
## Contains all gameplay elements: bird, pipes, ground, background.

signal game_over
signal score_changed(score: int)

const BIRD_START := Vector2(60.0, 200.0)
const DESIGN_HEIGHT := 512.0
const SKY_COLORS: Array[Color] = [
	Color("4ec0ca"),
	Color("008793"),
]

var score: int = 0
var _atlas: Texture2D = preload("res://assets/gfx/atlas.png")
var _sky_fill: ColorRect

var _bg_regions: Array[Rect2] = [
	Rect2(0, 0, 288, 512),
	Rect2(292, 0, 288, 512),
]

var _bird_frame_regions: Array[Array] = [
	[Rect2(0, 970, 48, 48), Rect2(56, 970, 48, 48), Rect2(112, 970, 48, 48)],
	[Rect2(168, 970, 48, 48), Rect2(224, 646, 48, 48), Rect2(224, 698, 48, 48)],
	[Rect2(224, 750, 48, 48), Rect2(224, 802, 48, 48), Rect2(224, 854, 48, 48)],
]

@onready var bird: Area2D = $GameLayer/Bird
@onready var pipe_spawner: Node2D = $GameLayer/PipeSpawner
@onready var ground: StaticBody2D = $GameLayer/Ground
@onready var _background: Sprite2D = $Background


func _ready() -> void:
	bird.hit.connect(_on_bird_hit)
	pipe_spawner.pipe_passed.connect(_on_pipe_passed)
	_adapt_to_viewport()


func start_game() -> void:
	score = 0
	score_changed.emit(score)
	bird.start()
	bird.flap()
	pipe_spawner.start()
	ground.start()


func reset() -> void:
	score = 0
	_randomize_visuals()
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
	bird.die()
	$HitSound.play()
	$DieSound.play()
	game_over.emit()


func _on_pipe_passed() -> void:
	score += 1
	score_changed.emit(score)
	$PointSound.play()


func _adapt_to_viewport() -> void:
	var vp_size := get_viewport_rect().size
	var extra := vp_size.y - DESIGN_HEIGHT
	if extra <= 0.0:
		return
	position.y = extra
	_sky_fill = ColorRect.new()
	_sky_fill.color = SKY_COLORS[0]
	_sky_fill.position = Vector2(0.0, -extra)
	_sky_fill.size = Vector2(vp_size.x, extra)
	_sky_fill.z_index = -1
	add_child(_sky_fill)
	move_child(_sky_fill, 0)


func _randomize_visuals() -> void:
	var bg_idx := randi() % _bg_regions.size()
	var bg_tex := AtlasTexture.new()
	bg_tex.atlas = _atlas
	bg_tex.region = _bg_regions[bg_idx]
	bg_tex.filter_clip = true
	_background.texture = bg_tex
	if _sky_fill:
		_sky_fill.color = SKY_COLORS[bg_idx]

	var color_idx: int = randi() % _bird_frame_regions.size()
	var frames: Array = _bird_frame_regions[color_idx]
	var sprite_frames := SpriteFrames.new()
	sprite_frames.add_animation(&"flap")
	sprite_frames.set_animation_speed(&"flap", 10.0)
	sprite_frames.set_animation_loop(&"flap", true)
	for i in frames.size():
		var tex := AtlasTexture.new()
		tex.atlas = _atlas
		tex.region = frames[i]
		tex.filter_clip = true
		sprite_frames.add_frame(&"flap", tex)
	bird.get_node("AnimatedSprite2D").sprite_frames = sprite_frames
