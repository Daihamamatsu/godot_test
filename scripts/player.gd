extends CharacterBody2D
## HP制とキック攻撃を持つシンプルなマリオ風プレイヤー。

signal died
signal hp_changed(current_hp: int, maximum_hp: int)

enum State { ALIVE, DYING, WIN }

const MOVE_SPEED := 240.0
const ACCEL := 2400.0
const FRICTION := 2600.0
const AIR_ACCEL := 1600.0
const GRAVITY := 1500.0
const FALL_GRAVITY := 2200.0
const MAX_FALL_SPEED := 900.0
const JUMP_VELOCITY := -540.0
const COYOTE_TIME := 0.1
const JUMP_BUFFER_TIME := 0.12
const KILL_Y := 720.0
const MAX_HP := 100
const ATTACK_AP := 25
const ATTACK_FPS := 24.0
const ATTACK_FRAME_COUNT := 21
# 攻撃判定は攻撃モーションの8枚目・9枚目だけ有効にする(内部フレームは0始まり)。
const ATTACK_ACTIVE_START := 7
const ATTACK_ACTIVE_END := 8

@onready var visual: Node2D = $Visual
@onready var walk_sprite: AnimatedSprite2D = $Visual/WalkSprite
@onready var attack_sprite: AnimatedSprite2D = $Visual/AttackSprite
@onready var attack_area: Area2D = $AttackArea

var state: int = State.ALIVE
var _hitbox_debug_draw: Node2D
var facing := 1
var invincible := 0.0
var hp := MAX_HP
var attacking := false
var _attack_elapsed := 0.0
var _attack_hit_targets: Array[Node] = []

var _coyote := 0.0
var _jump_buffer := 0.0
var _jump_cut := false
var _was_in_air := false
var _stretch := Vector2.ONE


func _ready() -> void:
	add_to_group("player")
	$HurtBox.add_to_group("player_hurt")
	attack_area.add_to_group("player_attack")
	attack_area.monitoring = false
	attack_sprite.visible = false
	_hitbox_debug_draw = preload("res://scripts/hitbox_debug.gd").new()
	_hitbox_debug_draw.name = "HitboxDebug"
	add_child(_hitbox_debug_draw)
	hp_changed.emit(hp, MAX_HP)


func _physics_process(dt: float) -> void:
	if state == State.DYING:
		# その場で転がる(落下中もレベルとの衝突は継続する)。
		velocity.y = minf(velocity.y + FALL_GRAVITY * dt, MAX_FALL_SPEED)
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * dt)
		visual.rotation += dt * 7.0
		move_and_slide()
		return

	var dir := 0.0
	if state == State.ALIVE and not attacking:
		dir = Input.get_axis("move_left", "move_right")
		if Input.is_action_just_pressed("attack"):
			start_attack()

	# --- 横移動 ---
	if attacking:
		# 攻撃中は移動入力を受け付けず、その場で攻撃を続ける。
		velocity.x = 0.0
	elif dir != 0.0:
		var accel := ACCEL if is_on_floor() else AIR_ACCEL
		velocity.x = move_toward(velocity.x, dir * MOVE_SPEED, accel * dt)
		facing = 1 if dir > 0.0 else -1
	else:
		var decel := FRICTION if is_on_floor() else AIR_ACCEL * 0.6
		velocity.x = move_toward(velocity.x, 0.0, decel * dt)

	# --- ジャンプバッファ + コヨーテタイム ---
	if attacking:
		_jump_buffer = 0.0
	elif Input.is_action_just_pressed("jump") and state == State.ALIVE:
		_jump_buffer = JUMP_BUFFER_TIME
	else:
		_jump_buffer = maxf(_jump_buffer - dt, 0.0)

	if is_on_floor():
		_coyote = COYOTE_TIME
		_jump_cut = false
	else:
		_coyote = maxf(_coyote - dt, 0.0)

	if _jump_buffer > 0.0 and _coyote > 0.0 and state == State.ALIVE and not attacking:
		velocity.y = JUMP_VELOCITY
		_jump_buffer = 0.0
		_coyote = 0.0
		_stretch = Vector2(0.82, 1.18)
		Sfx.play("jump")

	# ジャンプキーを早く離したときは上昇を短くする。
	if state == State.ALIVE and not Input.is_action_pressed("jump") and velocity.y < 0.0 and not _jump_cut:
		velocity.y *= 0.45
		_jump_cut = true

	# クリア後のホップ。
	if state == State.WIN and is_on_floor():
		velocity.y = -260.0

	# 重力(落下中は強くして弧をきびきびさせる)。
	var gravity := GRAVITY if velocity.y < 0.0 else FALL_GRAVITY
	velocity.y = minf(velocity.y + gravity * dt, MAX_FALL_SPEED)

	move_and_slide()
	_update_attack(dt)

	# 着地時のつぶれと、つぶれ/伸びの回復。
	var on_floor := is_on_floor()
	if _was_in_air and on_floor:
		_stretch = Vector2(1.25, 0.72)
	_was_in_air = not on_floor

	invincible = maxf(invincible - dt, 0.0)

	# 表示: つぶれ/伸び、向き、ダメージ無敵中の点滅。
	var target := Vector2.ONE
	if velocity.y < -260.0:
		target = Vector2(0.9, 1.1)
	elif velocity.y > 420.0:
		target = Vector2(1.12, 0.88)
	_stretch = _stretch.lerp(target, 0.25)
	visual.scale = Vector2(facing * _stretch.x, _stretch.y)
	visual.modulate.a = 0.35 if (invincible > 0.0 and fmod(invincible, 0.2) < 0.1) else 1.0

	# 歩行アニメーション: 攻撃中はキック表示を優先する。
	if attacking:
		walk_sprite.stop()
		walk_sprite.visible = false
		attack_sprite.visible = true
	else:
		walk_sprite.visible = true
		attack_sprite.visible = false
		if absf(velocity.x) > 10.0:
			if walk_sprite.animation != &"walk":
				walk_sprite.animation = &"walk"
			walk_sprite.play()
		else:
			walk_sprite.stop()
			walk_sprite.animation = &"walk"
			walk_sprite.frame = 0

	# 穴へ落下した場合。
	if global_position.y > KILL_Y:
		_die(true)


func _die(from_pit: bool = false) -> void:
	if state == State.DYING:
		return
	state = State.DYING
	walk_sprite.stop()
	walk_sprite.frame = 0
	_finish_attack()
	Sfx.play("hurt")
	emit_signal("died")
	if from_pit:
		velocity = Vector2(velocity.x * 0.5, 500.0)
	else:
		velocity = Vector2(facing * 140.0, -430.0)
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_callback(hide)


func take_damage(ap: int) -> void:
	if invincible > 0.0 or state != State.ALIVE:
		return
	hp = maxi(hp - maxi(ap, 0), 0)
	hp_changed.emit(hp, MAX_HP)
	Sfx.play("hurt")
	if hp <= 0:
		invincible = 9999.0
		_die(false)
	else:
		invincible = 1.0


func start_attack() -> void:
	if attacking or state != State.ALIVE:
		return
	attacking = true
	_jump_buffer = 0.0
	_attack_elapsed = 0.0
	_attack_hit_targets.clear()
	attack_sprite.animation = &"attack"
	attack_sprite.frame = 0
	attack_sprite.speed_scale = 1.0
	attack_sprite.play()
	Sfx.play("attack")


func _update_attack(dt: float) -> void:
	if not attacking:
		return
	_attack_elapsed += dt
	var frame := mini(int(_attack_elapsed * ATTACK_FPS), ATTACK_FRAME_COUNT - 1)
	attack_sprite.frame = frame
	var active := frame >= ATTACK_ACTIVE_START and frame <= ATTACK_ACTIVE_END
	attack_area.monitoring = active
	attack_area.position.x = facing * 92.0
	if active:
		_resolve_attack_overlaps()
	if _attack_elapsed >= float(ATTACK_FRAME_COUNT) / ATTACK_FPS:
		_finish_attack()


func _finish_attack() -> void:
	attacking = false
	_attack_elapsed = 0.0
	_attack_hit_targets.clear()
	attack_area.set_deferred("monitoring", false)
	attack_sprite.stop()
	attack_sprite.frame = 0


func consume_attack_hit(target: Node) -> bool:
	if not attacking or target in _attack_hit_targets:
		return false
	_attack_hit_targets.append(target)
	return true


func is_attack_active() -> bool:
	return attacking and attack_area.monitoring


func _resolve_attack_overlaps() -> void:
	# 短い攻撃有効時間でも重なりを取りこぼさないよう、攻撃形状を直接問い合わせる。
	var attack_shape_node := attack_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if attack_shape_node != null and attack_shape_node.shape != null:
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = attack_shape_node.shape
		query.transform = attack_shape_node.global_transform
		query.collision_mask = attack_area.collision_mask
		query.collide_with_areas = true
		query.collide_with_bodies = false
		var results := get_world_2d().direct_space_state.intersect_shape(query, 16)
		for result in results:
			_handle_attack_area(result.get("collider") as Area2D)

	# 既存の Area2D 重なり一覧も処理し、通常のシグナル経路を補完する。
	for area in attack_area.get_overlapping_areas():
		_handle_attack_area(area)


func _handle_attack_area(area: Area2D) -> void:
	if area == null or not area.is_in_group("enemy_hurt"):
		return
	var target := area.get_parent()
	if target != null and target.has_method("_on_hurt_area_entered"):
		target._on_hurt_area_entered(attack_area)


func set_hitbox_debug_enabled(value: bool) -> void:
	if _hitbox_debug_draw != null:
		_hitbox_debug_draw.set_enabled(value)


func bounce() -> void:
	if state != State.ALIVE:
		return
	velocity.y = -360.0
	if Input.is_action_pressed("jump"):
		velocity.y = JUMP_VELOCITY * 1.05
	_jump_cut = false


func win() -> void:
	state = State.WIN
	invincible = 9999.0


func respawn(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	state = State.ALIVE
	hp = MAX_HP
	hp_changed.emit(hp, MAX_HP)
	invincible = 2.0
	show()
	visual.rotation = 0.0
	_stretch = Vector2.ONE
	visual.scale = Vector2.ONE
	_finish_attack()
	_jump_cut = false
	_was_in_air = false
