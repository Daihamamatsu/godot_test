extends Node2D
## レベルを構築し、ゲーム状態（スコア、残機、HUD、クリア・ゲームオーバー）を管理する。

const SPAWN := Vector2(120, 479.5)
const GROUND_TOP := 600.0
const KILL_Y := 720.0

# [x_start, x_end] の地面区間（上面は GROUND_TOP）。
const GROUND_SEGS: Array = [
	[0, 1000],
	[1140, 2100],
	[2260, 3000],
	[3340, 4400],
]
# [x, y_top, width, height] のブロック、浮遊足場、階段。
const BLOCKS: Array = [
	[1600, 540, 160, 60],   # raised block (coins on top)
	[2400, 520, 200, 20],   # floating platform
	[2700, 520, 200, 20],   # floating platform
	[3000, 570, 80, 30],
	[3080, 540, 80, 60],
	[3160, 510, 80, 90],
]
const COINS: Array = [
	Vector2(360, 556), Vector2(430, 556), Vector2(500, 556),
	Vector2(1055, 470),
	Vector2(1660, 496), Vector2(1720, 496),
	Vector2(2175, 470),
	Vector2(2460, 476), Vector2(2540, 476),
	Vector2(2760, 476), Vector2(2840, 476),
	Vector2(3100, 466), Vector2(3150, 466),
	Vector2(3560, 556), Vector2(3630, 556), Vector2(3700, 556),
	Vector2(4000, 556),
]
const ENEMIES: Array = [
	Vector2(760, 544),
	Vector2(1500, 544),
	Vector2(1820, 544),
	Vector2(3400, 544),
	Vector2(3900, 544),
]

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const COIN_SCENE := preload("res://scenes/coin.tscn")

enum GameState { PLAYING, GAME_OVER, CLEAR }

var state: int = GameState.PLAYING
var score := 0
var coin_count := 0
var lives := 3

var world: Node2D
var player: CharacterBody2D
var score_label: Label
var coin_label: Label
var lives_label: Label
var message_label: Label
var sub_label: Label

var _test_mode := false
var _test_frame := 0
var _test_ok := true


func _ready() -> void:
	_test_mode = OS.get_cmdline_args().has("test") or OS.get_cmdline_user_args().has("test")

	_build_background()
	_build_hud()

	world = Node2D.new()
	world.name = "World"
	add_child(world)

	_build_terrain()
	_build_flag()
	_build_items()

	player = PLAYER_SCENE.instantiate()
	world.add_child(player)
	player.position = SPAWN
	player.died.connect(_on_player_died)

	_update_hud()
	_intro()


# ---------------------------------------------------------------- 背景

func _build_background() -> void:
	var bg := Node2D.new()
	bg.name = "Background"
	add_child(bg)

	var sky := ColorRect.new()
	sky.position = Vector2(-60, -260)
	sky.size = Vector2(4520, 1120)
	sky.color = Color(0.45, 0.71, 0.95)
	bg.add_child(sky)

	var parallax := ParallaxBackground.new()
	parallax.name = "ParallaxBackground"
	bg.add_child(parallax)

	var hills := ParallaxLayer.new()
	hills.motion_scale = Vector2(0.5, 0.5)
	parallax.add_child(hills)
	for cx in [500.0, 1400.0, 2300.0, 3200.0, 4100.0]:
		var hill := Polygon2D.new()
		hill.polygon = _hill_poly(cx, 700.0, 760.0, 260.0)
		hill.color = Color(0.5, 0.78, 0.5)
		hills.add_child(hill)

	var forest := Node2D.new()
	forest.name = "MidgroundForest"
	bg.add_child(forest)
	var tree_specs: Array = [
		[120.0, 600.0, 0.82], [330.0, 600.0, 1.05], [570.0, 600.0, 0.7],
		[820.0, 600.0, 1.18], [1080.0, 600.0, 0.9], [1320.0, 600.0, 0.76],
		[1570.0, 600.0, 1.1], [1830.0, 600.0, 0.84], [2070.0, 600.0, 1.0],
		[2340.0, 600.0, 0.72], [2590.0, 600.0, 1.16], [2840.0, 600.0, 0.88],
		[3090.0, 600.0, 0.76], [3350.0, 600.0, 1.08], [3600.0, 600.0, 0.86],
		[3860.0, 600.0, 1.12], [4110.0, 600.0, 0.78], [4330.0, 600.0, 1.0],
	]
	for spec in tree_specs:
		_add_midground_tree(forest, float(spec[0]), float(spec[1]), float(spec[2]))

	var clouds := ParallaxLayer.new()
	clouds.name = "Clouds"
	clouds.motion_scale = Vector2(0.3, 0.3)
	parallax.add_child(clouds)
	var cloud_specs: Array = [
		[300, 150, 1.0], [1100, 100, 0.8], [1900, 180, 1.2],
		[2800, 120, 0.9], [3600, 160, 1.1],
	]
	for c in cloud_specs:
		var cloud := Polygon2D.new()
		cloud.polygon = _cloud_poly(float(c[0]), float(c[1]), float(c[2]))
		cloud.color = Color(1.0, 1.0, 1.0, 0.92)
		clouds.add_child(cloud)


func _add_midground_tree(parent: Node2D, x: float, base_y: float, tree_scale: float) -> void:
	var tree := Node2D.new()
	tree.position = Vector2(x, base_y)
	tree.scale = Vector2(tree_scale, tree_scale)
	parent.add_child(tree)

	var trunk := Polygon2D.new()
	trunk.polygon = PackedVector2Array([
		Vector2(-12, 0), Vector2(14, 0), Vector2(10, -150), Vector2(-8, -150)
	])
	trunk.color = Color(0.25, 0.22, 0.2, 0.9)
	tree.add_child(trunk)

	var foliage_back := Polygon2D.new()
	foliage_back.polygon = _tree_canopy_poly(Vector2(0, -170), 64.0, 54.0)
	foliage_back.color = Color(0.12, 0.38, 0.26, 0.88)
	tree.add_child(foliage_back)

	var foliage_front := Polygon2D.new()
	foliage_front.polygon = _tree_canopy_poly(Vector2(0, -125), 58.0, 50.0)
	foliage_front.color = Color(0.18, 0.5, 0.28, 0.92)
	tree.add_child(foliage_front)


func _tree_canopy_poly(center: Vector2, width: float, height: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(-width * 0.9, height * 0.25),
		center + Vector2(-width * 0.72, -height * 0.2),
		center + Vector2(-width * 0.35, -height * 0.58),
		center + Vector2(0, -height),
		center + Vector2(width * 0.35, -height * 0.58),
		center + Vector2(width * 0.78, -height * 0.16),
		center + Vector2(width * 0.92, height * 0.28),
	])


func _hill_poly(_cx: float, base_y: float, w: float, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 16
	for i in n + 1:
		var t := float(i) / float(n)
		pts.append(Vector2(-w * 0.5 + w * t, -h * sin(PI * t)))
	pts.append(Vector2(w * 0.5, base_y))
	pts.append(Vector2(-w * 0.5, base_y))
	return pts


func _cloud_poly(cx: float, cy: float, s: float) -> PackedVector2Array:
	var base := [
		Vector2(-70, 0), Vector2(-68, -12), Vector2(-52, -20), Vector2(-30, -26),
		Vector2(-10, -34), Vector2(10, -30), Vector2(30, -28), Vector2(50, -18),
		Vector2(66, -10), Vector2(70, 0),
	]
	var pts := PackedVector2Array()
	for p in base:
		pts.append(Vector2(cx, cy) + p * s)
	return pts


func _circle_poly(cx: float, cy: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 12
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	return pts

# ------------------------------------------------------------------- 地形

func _build_terrain() -> void:
	for seg in GROUND_SEGS:
		_add_slab(Vector2(float(seg[0]), GROUND_TOP), Vector2(float(seg[1]) - float(seg[0]), 200), true)
	for b in BLOCKS:
		_add_slab(Vector2(float(b[0]), float(b[1])), Vector2(float(b[2]), float(b[3])), false)
	_add_wall(Vector2(-100, 100), Vector2(80, 660))
	_add_wall(Vector2(4420, 100), Vector2(80, 660))


func _add_slab(pos: Vector2, size: Vector2, is_ground: bool) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	cs.shape = shape
	cs.position = size * 0.5
	body.add_child(cs)

	var dirt_color := Color(0.45, 0.3, 0.16) if is_ground else Color(0.6, 0.42, 0.26)
	var dirt := Polygon2D.new()
	dirt.polygon = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)])
	dirt.color = dirt_color
	body.add_child(dirt)

	var top_color := Color(0.3, 0.72, 0.32) if is_ground else Color(0.78, 0.6, 0.38)
	var top := Polygon2D.new()
	top.polygon = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, 8), Vector2(0, 8)])
	top.color = top_color
	body.add_child(top)

	world.add_child(body)


func _add_wall(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	cs.shape = shape
	cs.position = size * 0.5
	body.add_child(cs)
	world.add_child(body)


func _build_flag() -> void:
	var flag := Node2D.new()
	flag.name = "Flag"
	flag.position = Vector2(4183, 600)
	world.add_child(flag)

	var pole := Polygon2D.new()
	pole.polygon = PackedVector2Array([
		Vector2(-3, 0), Vector2(3, 0), Vector2(3, -140), Vector2(-3, -140)
	])
	pole.color = Color(0.75, 0.78, 0.82)
	flag.add_child(pole)

	var ball := Polygon2D.new()
	ball.polygon = _circle_poly(0.0, -144.0, 7.0)
	ball.color = Color(1.0, 0.8, 0.25)
	flag.add_child(ball)

	var cloth := Polygon2D.new()
	cloth.polygon = PackedVector2Array([
		Vector2(3, -132), Vector2(48, -116), Vector2(3, -98)
	])
	cloth.color = Color(0.2, 0.65, 0.3)
	flag.add_child(cloth)

	var goal := Area2D.new()
	goal.name = "Goal"
	goal.position = Vector2(4187, 470)
	goal.collision_layer = 16
	goal.collision_mask = 2
	var gcs := CollisionShape2D.new()
	var gshape := RectangleShape2D.new()
	gshape.size = Vector2(110, 200)
	gcs.shape = gshape
	goal.add_child(gcs)
	goal.body_entered.connect(_on_goal_body_entered)
	world.add_child(goal)


func _build_items() -> void:
	for c in COINS:
		var coin := COIN_SCENE.instantiate()
		coin.position = c
		coin.collected.connect(_on_coin_collected)
		world.add_child(coin)

	for e in ENEMIES:
		var enemy := ENEMY_SCENE.instantiate()
		enemy.position = e
		enemy.stomped.connect(_on_enemy_stomped)
		world.add_child(enemy)

# ----------------------------------------------------------------------- hud

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	var bar := HBoxContainer.new()
	bar.position = Vector2(16, 8)
	bar.add_theme_constant_override("separation", 48)
	hud.add_child(bar)

	score_label = _make_label(22, Color(1, 1, 1, 0.95))
	bar.add_child(score_label)
	coin_label = _make_label(22, Color(1, 0.85, 0.3, 0.95))
	bar.add_child(coin_label)
	lives_label = _make_label(22, Color(1, 0.5, 0.45, 0.95))
	bar.add_child(lives_label)

	message_label = _make_label(56, Color(1, 0.9, 0.3))
	message_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.label_settings.outline_size = 8
	message_label.visible = false
	hud.add_child(message_label)

	sub_label = _make_label(22, Color(1, 1, 1, 0.9))
	sub_label.anchor_left = 0.0
	sub_label.anchor_right = 1.0
	sub_label.anchor_top = 0.5
	sub_label.anchor_bottom = 1.0
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub_label.visible = false
	hud.add_child(sub_label)

	var hint := _make_label(16, Color(1, 1, 1, 0.75))
	hint.anchor_left = 0.0
	hint.anchor_right = 1.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top = -34.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.text = "← → / A D : Move      SPACE : Jump      R : Restart"
	hud.add_child(hint)


func _make_label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	var settings := LabelSettings.new()
	settings.font_size = size
	settings.font_color = color
	settings.outline_size = 4
	settings.outline_color = Color(0.05, 0.05, 0.08, 0.85)
	label.label_settings = settings
	return label


func _update_hud() -> void:
	score_label.text = "SCORE %06d" % score
	coin_label.text = "COINS %d/%d" % [coin_count, COINS.size()]
	lives_label.text = "LIVES x%d" % lives


func _show_message(msg: String, sub: String = "") -> void:
	message_label.text = msg
	message_label.visible = true
	if sub == "":
		sub_label.text = ""
		sub_label.visible = false
	else:
		sub_label.text = sub
		sub_label.visible = true


func _hide_message() -> void:
	message_label.visible = false
	sub_label.visible = false


func _intro() -> void:
	_show_message("READY?", "← → / A D : Move      SPACE : Jump      R : Restart")
	await get_tree().create_timer(2.0).timeout
	if state == GameState.PLAYING:
		_hide_message()

# ------------------------------------------------------------------- process

func _process(_dt: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return
	if _test_mode:
		_run_test_step()


func _run_test_step() -> void:
	_test_frame += 1
	match _test_frame:
		5:
			_check(_has_bound_key("move_left") and _has_bound_key("move_right") and _has_bound_key("jump") and _has_bound_key("restart"), "input-map")
			_check(player != null and player.is_in_group("player"), "player-ready")
			_check(_midground_forest_ok(), "midground-forest")
			_check(_player_walk_sprite_ok(), "player-sprite")
			_check(_player_collision_ok(), "player-collision")
			_check(_enemy_collision_ok(), "enemy-collision")
			_check(get_tree().get_nodes_in_group("coin").size() >= 10, "coins-placed")
			_check(get_tree().get_nodes_in_group("enemy").size() >= 3, "enemies-placed")
			Input.action_press("move_right")
		30:
			Input.action_press("jump")
		34:
			_check(player.velocity.y < -100.0, "jump-velocity")
			_check(player.global_position.x > 120.0, "move-right")
		45:
			Input.action_release("jump")
			Input.action_release("move_right")
		70:
			_check(player.state == player.State.ALIVE, "player-alive")
			print("TEST SUMMARY: %s" % ("ALL PASS" if _test_ok else "FAILED"))
			get_tree().quit(0 if _test_ok else 1)


# アクションに実キー(keycodeまたはphysical_keycodeがKEY_NONEでない)が
# 少なくとも1つバインドされているか。バインド未定義の形式ミス検出用。
func _has_bound_key(action: String) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.keycode != KEY_NONE or key_event.physical_keycode != KEY_NONE:
				return true
	return false


# 中景の森レイヤーが生成され、複数の木が配置されているか確認する。
func _midground_forest_ok() -> bool:
	var forest := get_node_or_null("Background/ParallaxBackground/MidgroundForest")
	if forest == null:
		forest = get_node_or_null("Background/MidgroundForest")
	return forest is Node2D and forest.get_child_count() >= 10


# プレイヤーに歩行スプライト(AnimatedSprite2D・"walk" が 14 フレームでループ)があるか
# スケールが 1.0(256px 原寸表示)で横縦統一であることを併せて確認する
func _player_walk_sprite_ok() -> bool:
	var sprite := player.get_node_or_null("Visual/WalkSprite")
	if sprite == null or not (sprite is AnimatedSprite2D):
		return false
	var frames := (sprite as AnimatedSprite2D).sprite_frames
	if frames == null or not frames.has_animation("walk"):
		return false
	var sp := sprite as AnimatedSprite2D
	var scale_ok := sp.scale.x == sp.scale.y and absf(sp.scale.x - 1.0) < 0.01
	return frames.get_frame_count("walk") == 14 and frames.get_animation_loop("walk") and scale_ok


# プレイヤーの衝突カプセルが拡大後(半径38.5・高さ241)のものであるか
func _player_collision_ok() -> bool:
	for node in player.find_children("", "CollisionShape2D", true):
		var shape := (node as CollisionShape2D).shape
		if shape is CapsuleShape2D and absf((shape as CapsuleShape2D).radius - 38.5) < 0.1 and absf((shape as CapsuleShape2D).height - 241.0) < 1.0:
			return true
	return false


# 敵の衝突カプセルが 4 倍化後(半径48・高さ112)のものであるか
func _enemy_collision_ok() -> bool:
	for node in get_tree().get_nodes_in_group("enemy"):
		for child in (node as Node2D).find_children("", "CollisionShape2D", true):
			var shape := (child as CollisionShape2D).shape
			if shape is CapsuleShape2D and absf((shape as CapsuleShape2D).radius - 48.0) < 0.1 and absf((shape as CapsuleShape2D).height - 112.0) < 1.0:
				return true
	return false


func _check(cond: bool, test_name: String) -> void:
	print("TEST [%s] %s" % [test_name, "PASS" if cond else "FAIL"])
	if not cond:
		_test_ok = false

# -------------------------------------------------------------------- signals

func _on_coin_collected() -> void:
	if state != GameState.PLAYING:
		return
	coin_count += 1
	score += 100
	_update_hud()


func _on_enemy_stomped() -> void:
	if state != GameState.PLAYING:
		return
	score += 200
	_update_hud()


func _on_goal_body_entered(body: Node2D) -> void:
	if state != GameState.PLAYING or not body.is_in_group("player"):
		return
	state = GameState.CLEAR
	score += 1000
	Sfx.play("clear")
	_update_hud()
	player.win()
	_show_message("COURSE CLEAR!", "SCORE %06d      R : Restart" % score)


func _on_player_died() -> void:
	if state != GameState.PLAYING:
		return
	lives -= 1
	_update_hud()
	if lives <= 0:
		state = GameState.GAME_OVER
		Sfx.play("gameover")
		await get_tree().create_timer(1.4).timeout
		_show_message("GAME OVER", "SCORE %06d      R : Restart" % score)
	else:
		await get_tree().create_timer(1.2).timeout
		if state == GameState.PLAYING:
			player.respawn(SPAWN)
