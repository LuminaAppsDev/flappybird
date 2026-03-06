extends Area2D
## The player-controlled bird character.

signal hit

@export var gravity: float = 900.0
@export var flap_impulse: float = -280.0
@export var max_fall_speed: float = 400.0
@export var rotation_speed: float = 2.5

var velocity: float = 0.0
var alive: bool = true

var _active: bool = false
var _hover_time: float = 0.0
var _start_y: float = 0.0


func _ready() -> void:
	_start_y = position.y
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if not _active:
		if alive:
			_hover_time += delta
			position.y = _start_y + sin(_hover_time * 4.0) * 8.0
		return

	velocity += gravity * delta
	velocity = min(velocity, max_fall_speed)
	position.y += velocity * delta
	_update_rotation(delta)


func flap() -> void:
	if not alive:
		return
	velocity = flap_impulse
	rotation = deg_to_rad(-30.0)
	$FlapSound.play()


func start() -> void:
	_active = true
	alive = true
	velocity = 0.0
	rotation = 0.0
	$AnimatedSprite2D.play(&"flap")


func stop() -> void:
	_active = false
	alive = false
	$AnimatedSprite2D.stop()


func reset(start_position: Vector2) -> void:
	position = start_position
	_start_y = start_position.y
	velocity = 0.0
	rotation = 0.0
	_hover_time = 0.0
	_active = false
	alive = true
	$AnimatedSprite2D.play(&"flap")


func _update_rotation(delta: float) -> void:
	if velocity < 0:
		rotation = deg_to_rad(-30.0)
	else:
		rotation = move_toward(rotation, deg_to_rad(90.0), rotation_speed * delta)


func _on_body_entered(_body: Node2D) -> void:
	if alive:
		alive = false
		hit.emit()
