extends CharacterBody2D
## Goomba-style enemy: patrols, turns at walls/ledges, dies when stomped.

signal stomped

const SPEED := 65.0
const GRAVITY := 1500.0
const MAX_FALL_SPEED := 800.0

@onready var hurt: Area2D = $Hurt

var dir := -1
var dead := false


func _ready() -> void:
	add_to_group("enemy")
	hurt.body_entered.connect(_on_hurt_body_entered)


func _physics_process(dt: float) -> void:
	if dead:
		return

	velocity.x = dir * SPEED
	velocity.y = minf(velocity.y + GRAVITY * dt, MAX_FALL_SPEED)
	move_and_slide()

	if is_on_wall():
		dir = -dir
		velocity.x = 0.0

	# Turn around at cliff edges (probe the ground just ahead of us).
	var from := global_position + Vector2(dir * 18.0, 0.0)
	var to := from + Vector2(0.0, 44.0)
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		dir = -dir


func _on_hurt_body_entered(body: Node2D) -> void:
	if dead or not body.is_in_group("player"):
		return
	var player_bottom := body.global_position.y + 21.0
	var enemy_top := global_position.y - 14.0
	if body.velocity.y > -50.0 and player_bottom < enemy_top + 12.0:
		_get_stomped(body)
	else:
		if body.has_method("take_damage"):
			body.take_damage()


func _get_stomped(body: Node2D) -> void:
	dead = true
	set_physics_process(false)
	velocity = Vector2.ZERO
	hurt.set_deferred("monitoring", false)
	Sfx.play("stomp")
	emit_signal("stomped")
	if body.has_method("bounce"):
		body.bounce()
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.7, 0.18), 0.12)
	tw.tween_interval(0.5)
	tw.tween_callback(queue_free)
