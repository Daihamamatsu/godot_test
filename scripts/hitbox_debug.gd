extends Node2D
## 親キャラクターの存在判定・くらい判定・攻撃判定を可視化する。

const BODY_COLOR := Color(0.2, 0.65, 1.0, 0.22)
const BODY_OUTLINE := Color(0.35, 0.8, 1.0, 0.95)
const HURT_COLOR := Color(1.0, 0.2, 0.25, 0.22)
const HURT_OUTLINE := Color(1.0, 0.35, 0.4, 0.95)
const ATTACK_COLOR := Color(1.0, 0.82, 0.1, 0.28)
const ATTACK_OUTLINE := Color(1.0, 0.95, 0.25, 1.0)
const LINE_WIDTH := 3.0

var enabled := false


func set_enabled(value: bool) -> void:
	enabled = value
	visible = value
	queue_redraw()


func _ready() -> void:
	z_index = 10
	visible = false


func _process(_dt: float) -> void:
	if enabled:
		queue_redraw()


func _draw() -> void:
	if not enabled:
		return
	var owner := get_parent()
	if owner == null:
		return

	var body_shape := owner.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body_shape != null:
		_draw_collision_shape(body_shape.shape, body_shape.position, body_shape.rotation, BODY_COLOR, BODY_OUTLINE)

	var hurt_area := owner.get_node_or_null("HurtBox") as Area2D
	if hurt_area == null:
		hurt_area = owner.get_node_or_null("Hurt") as Area2D
	if hurt_area != null:
		var hurt_shape := hurt_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if hurt_shape != null:
			_draw_collision_shape(
				hurt_shape.shape,
				hurt_area.position + hurt_shape.position,
				hurt_area.rotation + hurt_shape.rotation,
				HURT_COLOR,
				HURT_OUTLINE
			)

	var attack_area := owner.get_node_or_null("AttackArea") as Area2D
	if attack_area == null or not owner.has_method("is_attack_active") or not owner.is_attack_active():
		return
	var attack_shape := attack_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if attack_shape != null:
		_draw_collision_shape(attack_shape.shape, attack_area.position + attack_shape.position, attack_area.rotation + attack_shape.rotation, ATTACK_COLOR, ATTACK_OUTLINE)


func _draw_collision_shape(shape: Shape2D, offset: Vector2, rotation: float, fill: Color, outline: Color) -> void:
	if shape == null:
		return
	draw_set_transform(offset, rotation, Vector2.ONE)
	if shape is RectangleShape2D:
		_draw_rectangle((shape as RectangleShape2D).size, fill, outline)
	elif shape is CapsuleShape2D:
		_draw_capsule(shape as CapsuleShape2D, fill, outline)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_rectangle(size: Vector2, fill: Color, outline: Color) -> void:
	var rect := Rect2(-size * 0.5, size)
	draw_rect(rect, fill, true)
	draw_rect(rect, outline, false, LINE_WIDTH)


func _draw_capsule(shape: CapsuleShape2D, fill: Color, outline: Color) -> void:
	var radius := shape.radius
	var half_height := shape.height * 0.5
	var center_distance := maxf(half_height - radius, 0.0)
	var middle_height := maxf(center_distance * 2.0, 0.0)
	var middle := Rect2(Vector2(-radius, -middle_height * 0.5), Vector2(radius * 2.0, middle_height))
	draw_rect(middle, fill, true)
	draw_circle(Vector2(0.0, -center_distance), radius, fill)
	draw_circle(Vector2(0.0, center_distance), radius, fill)

	if center_distance > 0.0:
		draw_line(Vector2(-radius, -center_distance), Vector2(-radius, center_distance), outline, LINE_WIDTH)
		draw_line(Vector2(radius, -center_distance), Vector2(radius, center_distance), outline, LINE_WIDTH)
		draw_arc(Vector2(0.0, -center_distance), radius, PI, TAU, 20, outline, LINE_WIDTH)
		draw_arc(Vector2(0.0, center_distance), radius, 0.0, PI, 20, outline, LINE_WIDTH)
