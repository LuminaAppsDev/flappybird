extends StaticBody2D
## Scrolling ground that loops infinitely.

@export var scroll_speed: float = 100.0

var _active: bool = true

@onready var _sprite1: Sprite2D = $Sprite1
@onready var _sprite2: Sprite2D = $Sprite2


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_sprite1.position.x -= scroll_speed * delta
	_sprite2.position.x -= scroll_speed * delta
	if _sprite1.position.x <= -336.0:
		_sprite1.position.x += 672.0
	if _sprite2.position.x <= -336.0:
		_sprite2.position.x += 672.0


func start() -> void:
	_active = true


func stop() -> void:
	_active = false
