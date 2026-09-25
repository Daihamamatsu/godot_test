extends CharacterBody2D
## Pien敵: 巡回、正面索敵攻撃、HP0時の消滅演出を管理する。

signal stomped
signal hp_changed(current_hp: int, maximum_hp: int)

const SPEED := 65.0
const GRAVITY := 1500.0
const MAX_FALL_SPEED := 800.0
const MAX_HP := 100
const STOMP_AP := 50
const HITSTUN_TIME := 0.3
const HITSTUN_KNOCKBACK := 180.0
const HITSTUN_ALPHA := 0.45
const DETECTION_DISTANCE := 180.0
const DETECTION_VERTICAL_DISTANCE := 96.0
const NORMAL_ANIMATION_FRAMES := 30
const ATTACK_PREPARE_FRAMES := 10
const ATTACK_GROW_FRAMES := 8
const ATTACK_ACTIVE_START := 18
const ATTACK_ACTIVE_END := 20
const ATTACK_RECOVERY_END := 26
const ATTACK_COOLDOWN_FRAMES := 180
const DEATH_FRAMES := 90
const ENEMY_ATTACK_AP := 25
const NORMAL_SCALE := Vector2(0.375, 0.4375)
const PANTI_SCALE := Vector2(0.4937, 0.4375)

@onready var normal_sprite: Sprite2D = $Visual/NormalSprite
@onready var attack_sprite: Sprite2D = $Visual/AttackSprite
@onready var panti_sprite: Sprite2D = $Visual/PantiSprite
@onready var death_sprite: Sprite2D = $Visual/DeathSprite
@onready var hurt: Area2D = $Hurt
@onready var attack_area: Area2D = $AttackArea
@onready var hp_bar: ProgressBar = $HPBar

var dir := -1
var dead := false
var hp := MAX_HP
var hitstun := 0.0
var attack_frame := -1
var attack_cooldown_frame := 0
var death_frame := -1
var _hitbox_debug_draw: Node2D
var _attack_hit_targets: Array[Node] = []


func _ready() -> void:
	add_to_group("enemy")
	hurt.add_to_group("enemy_hurt")
	hurt.body_entered.connect(_on_hurt_body_entered)
	hurt.area_entered.connect(_on_hurt_area_entered)
	hp_changed.connect(_on_hp_changed)
	_hp_bar_setup()
	_hitbox_debug_draw = preload("res://scripts/hitbox_debug.gd").new()
	_hitbox_debug_draw.name = "HitboxDebug"
	add_child(_hitbox_debug_draw)
	attack_area.monitoring = false
	attack_sprite.visible = false
	panti_sprite.visible = false
	death_sprite.visible = false
	_apply_facing()
	hp_changed.emit(hp, MAX_HP)


func _physics_process(dt: float) -> void:
	if death_frame >= 0:
		_update_death()
		return
	if attack_frame >= 0:
		_update_attack()
		return
	if hitstun > 0.0:
		_update_hitstun(dt)
		return
	if attack_cooldown_frame > 0:
		attack_cooldown_frame -= 1

	if attack_cooldown_frame <= 0 and _player_in_front():
		_start_attack()
		return

	velocity.x = dir * SPEED
	velocity.y = minf(velocity.y + GRAVITY * dt, MAX_FALL_SPEED)
	move_and_slide()
	modulate.a = 1.0
	_update_normal_visual()

	if is_on_wall():
		dir = -dir
		velocity.x = 0.0

	# 崖の縁で転向する(少し先の地面をレイキャストで探る)。
	var from := global_position + Vector2(dir * 42.0, 0.0)
	var to := from + Vector2(0.0, 92.0)
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		dir = -dir


func _update_normal_visual() -> void:
	var cycle_frame := Engine.get_physics_frames() % (NORMAL_ANIMATION_FRAMES * 2)
	normal_sprite.scale = Vector2(NORMAL_SCALE.x, NORMAL_SCALE.y * (0.88 if cycle_frame < NORMAL_ANIMATION_FRAMES else 1.0))
	normal_sprite.visible = true
	attack_sprite.visible = false
	panti_sprite.visible = false
	death_sprite.visible = false
	_apply_facing()


func _player_in_front() -> bool:
	for player in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(player) or not player.visible:
			continue
		var delta: Vector2 = player.global_position - global_position
		if delta.x * float(dir) >= 0.0 and absf(delta.x) <= DETECTION_DISTANCE and absf(delta.y) <= DETECTION_VERTICAL_DISTANCE:
			return true
	return false


func _start_attack() -> void:
	attack_frame = 0
	_attack_hit_targets.clear()
	velocity = Vector2.ZERO
	normal_sprite.visible = true
	attack_sprite.visible = true
	panti_sprite.visible = false
	death_sprite.visible = false
	attack_area.monitoring = false
	attack_sprite.scale = NORMAL_SCALE
	normal_sprite.scale = NORMAL_SCALE
	panti_sprite.scale = Vector2.ZERO
	_update_attack_direction()
	_apply_facing()


func _update_attack() -> void:
	velocity = Vector2.ZERO
	normal_sprite.visible = true
	attack_sprite.visible = attack_frame < ATTACK_PREPARE_FRAMES
	panti_sprite.visible = attack_frame >= ATTACK_PREPARE_FRAMES and attack_frame <= ATTACK_RECOVERY_END
	death_sprite.visible = false
	attack_area.monitoring = attack_frame >= ATTACK_ACTIVE_START and attack_frame <= ATTACK_ACTIVE_END
	attack_sprite.scale = NORMAL_SCALE

	if panti_sprite.visible:
		var grow_frame := clampi(attack_frame - ATTACK_PREPARE_FRAMES + 1, 1, ATTACK_GROW_FRAMES)
		var grow := float(grow_frame) / float(ATTACK_GROW_FRAMES)
		panti_sprite.scale = PANTI_SCALE * grow
		_update_attack_direction()
		_apply_facing()
	if attack_area.monitoring:
		_resolve_attack_overlaps()

	attack_frame += 1
	if attack_frame > ATTACK_RECOVERY_END:
		attack_frame = -1
		attack_cooldown_frame = ATTACK_COOLDOWN_FRAMES
		attack_area.set_deferred("monitoring", false)
		panti_sprite.visible = false
		attack_sprite.visible = false
		_update_normal_visual()


func _update_attack_direction() -> void:
	# dirと同じ側を敵の正面として、パンチ画像と攻撃判定を同じ位置へ置く。
	panti_sprite.position.x = 92.0 * float(dir)
	attack_area.position.x = 92.0 * float(dir)


func _resolve_attack_overlaps() -> void:
	var attack_shape_node := attack_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if attack_shape_node == null or attack_shape_node.shape == null:
		return
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = attack_shape_node.shape
	query.transform = attack_shape_node.global_transform
	query.collision_mask = attack_area.collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for result in get_world_2d().direct_space_state.intersect_shape(query, 16):
		_handle_attack_area(result.get("collider") as Area2D)
	for area in attack_area.get_overlapping_areas():
		_handle_attack_area(area)


func _handle_attack_area(area: Area2D) -> void:
	if area == null or not area.is_in_group("player_hurt"):
		return
	var target := area.get_parent()
	if target == null or target in _attack_hit_targets or not target.has_method("take_damage"):
		return
	_attack_hit_targets.append(target)
	target.take_damage(ENEMY_ATTACK_AP)
	Sfx.play("hit")


func is_attack_active() -> bool:
	return attack_frame >= ATTACK_ACTIVE_START and attack_frame <= ATTACK_ACTIVE_END


func _update_hitstun(dt: float) -> void:
	hitstun = maxf(hitstun - dt, 0.0)
	velocity.x = move_toward(velocity.x, 0.0, 900.0 * dt)
	velocity.y = minf(velocity.y + GRAVITY * dt, MAX_FALL_SPEED)
	move_and_slide()
	modulate.a = HITSTUN_ALPHA if hitstun > 0.0 else 1.0
	_update_normal_visual()


func _on_hurt_body_entered(body: Node2D) -> void:
	if dead or attack_frame >= 0 or not body.is_in_group("player"):
		return
	# 踏みつけ判定: プレイヤーの底面が敵の頭上付近にある場合だけ成立させる。
	var player_bottom := body.global_position.y + 121.0
	var enemy_top := global_position.y - 56.0
	if body.velocity.y > -50.0 and player_bottom < enemy_top + 48.0:
		_get_stomped(body)


func _on_hurt_area_entered(area: Area2D) -> void:
	if dead or hitstun > 0.0 or not area.is_in_group("player_attack"):
		return
	var attacker := area.get_parent()
	if not attacker.is_in_group("player") or not attacker.has_method("consume_attack_hit"):
		return
	if not attacker.consume_attack_hit(self):
		return
	receive_attack_damage(attacker.ATTACK_AP, attacker)
	Sfx.play("hit")


func receive_attack_damage(ap: int, attacker: Node2D) -> void:
	if dead or hitstun > 0.0:
		return
	var attacker_delta_x := attacker.global_position.x - global_position.x
	if not is_zero_approx(attacker_delta_x):
		dir = 1 if attacker_delta_x > 0.0 else -1
	else:
		dir = int(attacker.get("facing"))
	_apply_facing()
	take_damage(ap)
	if dead:
		return
	var knockback_dir := signf(global_position.x - attacker.global_position.x)
	if is_zero_approx(knockback_dir):
		knockback_dir = -float(int(attacker.get("facing")))
	velocity.x = knockback_dir * HITSTUN_KNOCKBACK
	velocity.y = -70.0
	hitstun = HITSTUN_TIME
	modulate.a = HITSTUN_ALPHA


func _get_stomped(body: Node2D) -> void:
	take_damage(STOMP_AP)
	if body.has_method("bounce"):
		body.bounce()
	if not dead:
		return
	velocity = Vector2.ZERO
	hurt.set_deferred("monitoring", false)
	attack_area.set_deferred("monitoring", false)
	Sfx.play("stomp")
	emit_signal("stomped")


func take_damage(ap: int) -> void:
	if dead:
		return
	hp = maxi(hp - maxi(ap, 0), 0)
	hp_changed.emit(hp, MAX_HP)
	if hp <= 0:
		_begin_death()


func _begin_death() -> void:
	dead = true
	death_frame = 0
	attack_frame = -1
	attack_cooldown_frame = 0
	attack_area.set_deferred("monitoring", false)
	normal_sprite.visible = false
	attack_sprite.visible = false
	panti_sprite.visible = false
	death_sprite.visible = true
	death_sprite.modulate.a = 0.5
	velocity = Vector2.ZERO


func _update_death() -> void:
	velocity = Vector2.ZERO
	hurt.set_deferred("monitoring", false)
	attack_area.set_deferred("monitoring", false)
	normal_sprite.visible = false
	attack_sprite.visible = false
	panti_sprite.visible = false
	death_sprite.visible = true
	death_sprite.modulate.a = 0.5
	death_frame += 1
	if death_frame >= DEATH_FRAMES:
		hide()
		set_physics_process(false)


func _apply_facing() -> void:
	attack_sprite.flip_h = dir > 0
	panti_sprite.flip_h = dir > 0
	normal_sprite.flip_h = dir > 0
	death_sprite.flip_h = dir > 0


func set_hitbox_debug_enabled(value: bool) -> void:
	if _hitbox_debug_draw != null:
		_hitbox_debug_draw.set_enabled(value)


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