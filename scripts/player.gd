extends CharacterBody2D
## Simple Mario-style platformer character.

signal died

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

@onready var visual: Node2D = $Visual

var state: int = State.ALIVE
var facing := 1
var invincible := 0.0

var _coyote := 0.0
var _jump_buffer := 0.0
var _jump_cut := false
var _was_in_air := false
var _stretch := Vector2.ONE


func _ready() -> void:
	add_to_group("player")


func _physics_process(dt: float) -> void:
	if state == State.DYING:
		# Tumble in place (still collides with the level while falling).
		velocity.y = minf(velocity.y + FALL_GRAVITY * dt, MAX_FALL_SPEED)
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * dt)
		visual.rotation += dt * 7.0
		move_and_slide()
		return

	var dir := 0.0
	if state == State.ALIVE:
		dir = Input.get_axis("move_left", "move_right")

	# --- Horizontal movement ---
	if dir != 0.0:
		var accel := ACCEL if is_on_floor() else AIR_ACCEL
		velocity.x = move_toward(velocity.x, dir * MOVE_SPEED, accel * dt)
		facing = 1 if dir > 0.0 else -1
	else:
		var decel := FRICTION if is_on_floor() else AIR_ACCEL * 0.6
		velocity.x = move_toward(velocity.x, 0.0, decel * dt)

	# --- Jump buffering + coyote time ---
	if Input.is_action_just_pressed("jump") and state == State.ALIVE:
		_jump_buffer = JUMP_BUFFER_TIME
	else:
		_jump_buffer = maxf(_jump_buffer - dt, 0.0)

	if is_on_floor():
		_coyote = COYOTE_TIME
		_jump_cut = false
	else:
		_coyote = maxf(_coyote - dt, 0.0)

	if _jump_buffer > 0.0 and _coyote > 0.0 and state == State.ALIVE:
		velocity.y = JUMP_VELOCITY
		_jump_buffer = 0.0
		_coyote = 0.0
		_stretch = Vector2(0.82, 1.18)
		Sfx.play("jump")

	# Variable jump height: cut the rise when the jump key is released early.
	if state == State.ALIVE and not Input.is_action_pressed("jump") and velocity.y < 0.0 and not _jump_cut:
		velocity.y *= 0.45
		_jump_cut = true

	# Victory hop.
	if state == State.WIN and is_on_floor():
		velocity.y = -260.0

	# Gravity (heavier while falling for a snappier arc).
	var gravity := GRAVITY if velocity.y < 0.0 else FALL_GRAVITY
	velocity.y = minf(velocity.y + gravity * dt, MAX_FALL_SPEED)

	move_and_slide()

	# Landing squash + squash/stretch recovery.
	var on_floor := is_on_floor()
	if _was_in_air and on_floor:
		_stretch = Vector2(1.25, 0.72)
	_was_in_air = not on_floor

	invincible = maxf(invincible - dt, 0.0)

	# Visuals: squash & stretch + direction flip + invincibility blink.
	var target := Vector2.ONE
	if velocity.y < -260.0:
		target = Vector2(0.9, 1.1)
	elif velocity.y > 420.0:
		target = Vector2(1.12, 0.88)
	_stretch = _stretch.lerp(target, 0.25)
	visual.scale = Vector2(facing * _stretch.x, _stretch.y)
	visual.modulate.a = 0.35 if (invincible > 0.0 and fmod(invincible, 0.2) < 0.1) else 1.0

	# Fell into a pit.
	if global_position.y > KILL_Y:
		_die(true)


func _die(from_pit: bool = false) -> void:
	if state == State.DYING:
		return
	state = State.DYING
	Sfx.play("hurt")
	emit_signal("died")
	if from_pit:
		velocity = Vector2(velocity.x * 0.5, 500.0)
	else:
		velocity = Vector2(facing * 140.0, -430.0)
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_callback(hide)


func take_damage() -> void:
	if invincible > 0.0 or state != State.ALIVE:
		return
	invincible = 9999.0
	_die(false)


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
	invincible = 2.0
	show()
	visual.rotation = 0.0
	_stretch = Vector2.ONE
	visual.scale = Vector2.ONE
	_jump_cut = false
	_was_in_air = false
