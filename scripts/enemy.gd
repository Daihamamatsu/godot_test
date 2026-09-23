extends CharacterBody2D
## グム系敵: パトロール移動、壁/崖の縁で転向、HP制で踏みつけられて倒れる。

signal stomped
signal hp_changed(current_hp: int, maximum_hp: int)

const SPEED := 65.0
const GRAVITY := 1500.0
const MAX_FALL_SPEED := 800.0
const MAX_HP := 100
const STOMP_AP := 50

@onready var hurt: Area2D = $Hurt
@onready var hurt_shape: CollisionShape2D = $Hurt/CollisionShape2D
@onready var hp_bar: ProgressBar = $HPBar

var dir := -1
var dead := false
var hp := MAX_HP


func _ready() -> void:
	add_to_group("enemy")
	hurt.body_entered.connect(_on_hurt_body_entered)
	hurt.area_entered.connect(_on_hurt_area_entered)
	hp_changed.connect(_on_hp_changed)
	_hp_bar_setup()
	hp_changed.emit(hp, MAX_HP)


func _physics_process(dt: float) -> void:
	if dead:
		return

	velocity.x = dir * SPEED
	velocity.y = minf(velocity.y + GRAVITY * dt, MAX_FALL_SPEED)
	move_and_slide()

	if is_on_wall():
		dir = -dir
		velocity.x = 0.0

	# 崖の縁で転向する(少し先の地面をレイキャストで探る)。
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


func _on_hurt_area_entered(area: Area2D) -> void:
	if dead or not area.is_in_group("player_attack"):
		return
	var attacker := area.get_parent()
	if not attacker.is_in_group("player") or not attacker.has_method("consume_attack_hit"):
		return
	if not attacker.consume_attack_hit(self):
		return
	take_damage(attacker.ATTACK_AP)
	Sfx.play("hit")


func _get_stomped(body: Node2D) -> void:
	take_damage(STOMP_AP)
	if body.has_method("bounce"):
		body.bounce()
	if not dead:
		return
	set_physics_process(false)
	velocity = Vector2.ZERO
	hurt.set_deferred("monitoring", false)
	Sfx.play("stomp")
	emit_signal("stomped")
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.7, 0.18), 0.12)
	tw.tween_interval(0.5)
	tw.tween_callback(queue_free)


func take_damage(ap: int) -> void:
	if dead:
		return
	hp = maxi(hp - maxi(ap, 0), 0)
	hp_changed.emit(hp, MAX_HP)
	if hp <= 0:
		dead = true


func _hp_bar_setup() -> void:
	hp_bar.max_value = MAX_HP
	hp_bar.value = hp
	hp_bar.show_percentage = false
	hp_bar.add_theme_stylebox_override("background", _make_bar_style(Color(0.12, 0.08, 0.08, 0.9)))
	hp_bar.add_theme_stylebox_override("fill", _make_bar_style(_hp_color()))


func _on_hp_changed(current_hp: int, _maximum_hp: int) -> void:
	hp_bar.value = current_hp
	hp_bar.add_theme_stylebox_override("fill", _make_bar_style(_hp_color()))


func _hp_color() -> Color:
	return Color(0.9, 0.16, 0.12).lerp(Color(0.2, 0.82, 0.25), float(hp) / float(MAX_HP))


func _make_bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style
