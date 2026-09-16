extends Area2D
## Collectible coin with a simple spin animation.

signal collected

var _t := randf() * 10.0
var _taken := false

@onready var body_poly: Polygon2D = $Body


func _ready() -> void:
	add_to_group("coin")
	body_entered.connect(_on_body_entered)


func _process(dt: float) -> void:
	_t += dt
	body_poly.scale.x = 0.15 + 0.85 * absf(cos(_t * 3.5))


func _on_body_entered(other: Node2D) -> void:
	if _taken or not other.is_in_group("player"):
		return
	_taken = true
	Sfx.play("coin")
	emit_signal("collected")
	queue_free()
