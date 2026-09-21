extends CharacterBody2D
## グム系敵: パトロール移動、壁/崖の縁で転向、踏みつけられて倒れる。

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

	# 崖の縁で転向する(少し先の地面をレイキャストで探る)
	# 敵カプセル(r48/h112)のつま先より外側・足元より十分に下へ張る
	var from := global_position + Vector2(dir * 42.0, 0.0)
	var to := from + Vector2(0.0, 92.0)
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		dir = -dir


func _on_hurt_body_entered(body: Node2D) -> void:
	if dead or not body.is_in_group("player"):
		return
	# 踏みつけ判定: プレイヤーの底面(カプセル高さ241/2=120.5)が
	# 敵の頭上(視覚上 -56)から上側 48px 以内なら上面ヒットとする
	var player_bottom := body.global_position.y + 121.0
	var enemy_top := global_position.y - 56.0
	if body.velocity.y > -50.0 and player_bottom < enemy_top + 48.0:
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
