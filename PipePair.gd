extends Node2D
## A pair of pipes with a gap for the bird to pass through.

signal passed

@export var speed: float = 100.0

var _scored: bool = false
var _active: bool = true


func _physics_process(delta: float) -> void:
	if not _active:
		return
	position.x -= speed * delta
	if position.x < -60.0:
		queue_free()


func stop() -> void:
	_active = false


func _on_score_zone_area_entered(_area: Area2D) -> void:
	if not _scored:
		_scored = true
		passed.emit()
