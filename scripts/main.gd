extends Node2D
## レベルを構築し、ゲーム状態（スコア、残機、HUD、クリア・ゲームオーバー）を管理する。

const SPAWN := Vector2(120, 479.5)
const GROUND_TOP := 600.0
const KILL_Y := 720.0
const MIDGROUND_SCROLL_FACTOR := 0.72

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
const MIDGROUND_FOREST_TEXTURE := preload("res://assets/background/midground_forest.png")

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
var hp_bar: ProgressBar
var hp_label: Label
var message_label: Label
var sub_label: Label
var hitbox_debug_label: Label
var midground_forest: Node2D
var midground_camera_origin := Vector2.ZERO
var hitbox_debug_enabled := false

var _test_mode := false
var _test_frame := 0
var _test_ok := true
var _test_camera_origin := Vector2.ZERO
var _test_forest_origin := Vector2.ZERO
var _test_forest_y_origin := 0.0


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
	player.hp_changed.connect(_on_player_hp_changed)
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		midground_camera_origin = camera.get_screen_center_position()
		_fit_midground_to_screen_bottom(camera)

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

	midground_forest = Node2D.new()
	midground_forest.name = "MidgroundForest"
	bg.add_child(midground_forest)
	_add_midground_forest_tiles()

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


func _add_midground_forest_tiles() -> void:
	var tile_width := float(MIDGROUND_FOREST_TEXTURE.get_width())
	var tile_height := float(MIDGROUND_FOREST_TEXTURE.get_height())
	var first_tile_x := -tile_width
	var tile_count := 5
	for i in tile_count:
		var forest_tile := Sprite2D.new()
		forest_tile.texture = MIDGROUND_FOREST_TEXTURE
		forest_tile.position = Vector2(
			first_tile_x + tile_width * (float(i) + 0.5),
			GROUND_TOP - tile_height * 0.5
		)
		forest_tile.flip_h = i % 2 == 1
		forest_tile.name = "ForestTile%d" % i
		midground_forest.add_child(forest_tile)


func _fit_midground_to_screen_bottom(camera: Camera2D) -> void:
	var screen_bottom := camera.get_screen_center_position().y + get_viewport_rect().size.y * 0.5 / camera.zoom.y
	midground_forest.position.y = screen_bottom - GROUND_TOP


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
	bar.add_theme_constant_override("separation", 28)
	hud.add_child(bar)

	score_label = _make_label(22, Color(1, 1, 1, 0.95))
	bar.add_child(score_label)
	coin_label = _make_label(22, Color(1, 0.85, 0.3, 0.95))
	bar.add_child(coin_label)
	lives_label = _make_label(22, Color(1, 0.5, 0.45, 0.95))
	bar.add_child(lives_label)

	var hp_title := _make_label(22, Color(1, 1, 1, 0.95))
	hp_title.text = "HP"
	bar.add_child(hp_title)
	hp_bar = ProgressBar.new()
	hp_bar.name = "PlayerHPBar"
	hp_bar.custom_minimum_size = Vector2(220, 24)
	hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_bar.show_percentage = false
	hp_bar.add_theme_stylebox_override("background", _make_bar_style(Color(0.12, 0.08, 0.08, 0.9), 6))
	hp_bar.add_theme_stylebox_override("fill", _make_bar_style(Color(0.2, 0.82, 0.25), 6))
	bar.add_child(hp_bar)
	hp_label = _make_label(22, Color(1, 1, 1, 0.95))
	bar.add_child(hp_label)

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
	hint.text = "← → / A D : Move      SPACE : Jump      J : Attack      P : Hitbox View      R : Restart"
	hud.add_child(hint)

	hitbox_debug_label = _make_label(18, Color(1.0, 0.9, 0.25, 0.95))
	hitbox_debug_label.position = Vector2(16, 48)
	hitbox_debug_label.text = "HITBOX VIEW: OFF"
	hitbox_debug_label.visible = false
	hud.add_child(hitbox_debug_label)


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


func _make_bar_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


func _update_hud() -> void:
	score_label.text = "SCORE %06d" % score
	coin_label.text = "COINS %d/%d" % [coin_count, COINS.size()]
	lives_label.text = "LIVES x%d" % lives
	if player != null:
		_update_player_hp_hud(player.hp, player.MAX_HP)


func _on_player_hp_changed(current_hp: int, maximum_hp: int) -> void:
	_update_player_hp_hud(current_hp, maximum_hp)


func _update_player_hp_hud(current_hp: int, maximum_hp: int) -> void:
	if hp_bar == null or hp_label == null:
		return
	hp_bar.max_value = maximum_hp
	hp_bar.value = current_hp
	hp_label.text = "%d/%d" % [current_hp, maximum_hp]
	var ratio := clampf(float(current_hp) / float(maximum_hp), 0.0, 1.0)
	hp_bar.add_theme_stylebox_override("fill", _make_bar_style(Color(0.9, 0.16, 0.12).lerp(Color(0.2, 0.82, 0.25), ratio), 6))


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
	_show_message("READY?", "← → / A D : Move      SPACE : Jump      J : Attack      P : Hitbox View      R : Restart")
	await get_tree().create_timer(2.0).timeout
	if state == GameState.PLAYING:
		_hide_message()

# ------------------------------------------------------------------- process

func _process(_dt: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return
	if Input.is_action_just_pressed("toggle_hitbox_debug"):
		_set_hitbox_debug_enabled(not hitbox_debug_enabled)
	_update_midground_scroll()
	if _test_mode:
		_run_test_step()


func _set_hitbox_debug_enabled(value: bool) -> void:
	hitbox_debug_enabled = value
	if hitbox_debug_label != null:
		hitbox_debug_label.text = "HITBOX VIEW: ON" if value else "HITBOX VIEW: OFF"
		hitbox_debug_label.visible = value
	for node in get_tree().get_nodes_in_group("player"):
		if node.has_method("set_hitbox_debug_enabled"):
			node.set_hitbox_debug_enabled(value)
	for node in get_tree().get_nodes_in_group("enemy"):
		if node.has_method("set_hitbox_debug_enabled"):
			node.set_hitbox_debug_enabled(value)


func _update_midground_scroll() -> void:
	if midground_forest == null or player == null:
		return
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	var camera_delta := camera.get_screen_center_position() - midground_camera_origin
	# 中景の奥行き差は横スクロールだけに適用し、ジャンプでは木を上下させない。
	midground_forest.position.x = camera_delta.x * (1.0 - MIDGROUND_SCROLL_FACTOR)


func _run_test_step() -> void:
	_test_frame += 1
	match _test_frame:
		5:
			_check(_has_bound_key("move_left") and _has_bound_key("move_right") and _has_bound_key("jump") and _has_bound_key("restart") and _has_bound_key("attack") and _has_bound_key("toggle_hitbox_debug"), "input-map")
			_check(player != null and player.is_in_group("player"), "player-ready")
			_check(_midground_forest_ok(), "midground-forest")
			_check(_midground_reaches_screen_bottom(), "midground-screen-bottom")
			_test_camera_origin = (player.get_node("Camera2D") as Camera2D).get_screen_center_position()
			_test_forest_origin = midground_forest.position
			_test_forest_y_origin = midground_forest.position.y
			_check(_player_walk_sprite_ok(), "player-sprite")
			_check(_player_collision_ok(), "player-collision")
			_check(_enemy_collision_ok(), "enemy-collision")
			_check(_hitbox_visualization_nodes_ok(), "hitbox-visualization-nodes")
			_check(_hitbox_toggle_ok(), "hitbox-toggle")
			_check(player.MAX_HP == 100 and player.hp == 100, "player-hp")
			_check(_player_hp_hud_ok(), "player-hp-hud")
			_check(_enemy_hp_ok(), "enemy-hp")
			_check(_damage_system_ok(), "damage-system")
			_check(_attack_system_ok(), "attack-system")
			_check(_attack_input_lock_ok(), "attack-input-lock")
			_check(_enemy_hit_motion_ok(), "enemy-hit-motion")
			_check(get_tree().get_nodes_in_group("coin").size() >= 10, "coins-placed")
			_check(get_tree().get_nodes_in_group("enemy").size() >= 3, "enemies-placed")
			Input.action_press("move_right")
		30:
			Input.action_press("jump")
		34:
			_check(player.velocity.y < -100.0, "jump-velocity")
			_check(player.global_position.x > 120.0, "move-right")
			_check(absf(midground_forest.position.y - _test_forest_y_origin) < 0.01, "midground-jump-height")
			_check(absf(midground_forest.position.x - _test_forest_origin.x) < 0.01, "midground-before-camera-scroll")
		45:
			Input.action_release("jump")
		80:
			Input.action_release("move_right")
			player.global_position = Vector2(1200.0, SPAWN.y)
			player.velocity = Vector2.ZERO
		120:
			_check(_camera_has_scrolled(), "camera-scroll-started")
			_check(_midground_scroll_is_slower(), "midground-scroll")
		140:
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
	if not forest is Node2D or forest.get_child_count() < 4:
		return false
	var first_tile := forest.get_child(0) as Sprite2D
	var second_tile := forest.get_child(1) as Sprite2D
	return first_tile != null and second_tile != null \
		and first_tile.texture == MIDGROUND_FOREST_TEXTURE \
		and not first_tile.flip_h and second_tile.flip_h


# 中景画像の下端が、現在の画面下端まで届いているか確認する。
func _midground_reaches_screen_bottom() -> bool:
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null or midground_forest == null:
		return false
	var screen_bottom := camera.get_screen_center_position().y + get_viewport_rect().size.y * 0.5 / camera.zoom.y
	var tile := midground_forest.get_child(0) as Sprite2D
	if tile == null or tile.texture == null:
		return false
	var tile_bottom := midground_forest.global_position.y + tile.position.y + tile.texture.get_height() * 0.5
	return absf(tile_bottom - screen_bottom) < 0.1


# カメラが動いたとき、中景の移動量が近景より小さいか確認する。
func _midground_scroll_is_slower() -> bool:
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return false
	var camera_delta := camera.get_screen_center_position() - _test_camera_origin
	var forest_delta := midground_forest.position - _test_forest_origin
	if absf(camera_delta.x) < 1.0:
		return false
	return absf(forest_delta.x) < absf(camera_delta.x)


# カメラの左端リミットを越えて、実際に画面がスクロールしたか確認する。
func _camera_has_scrolled() -> bool:
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return false
	return absf(camera.get_screen_center_position().x - _test_camera_origin.x) >= 1.0


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


func _hitbox_visualization_nodes_ok() -> bool:
	if player == null or player.get_node_or_null("HitboxDebug") == null:
		return false
	var enemies := get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		return false
	for enemy in enemies:
		if enemy.get_node_or_null("HitboxDebug") == null:
			return false
	return player.get_node_or_null("CollisionShape2D") is CollisionShape2D \
		and player.get_node_or_null("HurtBox/CollisionShape2D") is CollisionShape2D \
		and player.get_node_or_null("AttackArea/CollisionShape2D") is CollisionShape2D \
		and enemies[0].get_node_or_null("CollisionShape2D") is CollisionShape2D \
		and enemies[0].get_node_or_null("Hurt/CollisionShape2D") is CollisionShape2D


func _hitbox_toggle_ok() -> bool:
	_set_hitbox_debug_enabled(true)
	var enabled_ok: bool = hitbox_debug_enabled and _all_hitbox_debug_nodes_visible()
	_set_hitbox_debug_enabled(false)
	var disabled_ok: bool = not hitbox_debug_enabled and not _all_hitbox_debug_nodes_visible()
	return enabled_ok and disabled_ok


func _all_hitbox_debug_nodes_visible() -> bool:
	var nodes := get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("enemy")
	if nodes.is_empty():
		return false
	for node in nodes:
		var debug_draw := node.get_node_or_null("HitboxDebug") as Node2D
		if debug_draw == null or not debug_draw.visible:
			return false
	return true


func _player_hp_hud_ok() -> bool:
	return hp_bar != null and hp_label != null and hp_bar.max_value == 100.0 and hp_bar.value == 100.0 and hp_label.text == "100/100"


func _enemy_hp_ok() -> bool:
	var enemies := get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		return false
	var enemy := enemies[0]
	return enemy.MAX_HP == 100 and enemy.hp == 100 and enemy.STOMP_AP == 50 and enemy.get_node_or_null("HPBar") is ProgressBar and enemy.get_node_or_null("Hurt") is Area2D


func _damage_system_ok() -> bool:
	var enemies := get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		return false
	var enemy := enemies[0]
	var player_hp_before: int = player.hp
	var enemy_position_before: Vector2 = enemy.global_position
	player.global_position = enemy.global_position + Vector2(0.0, 150.0)
	enemy._on_hurt_body_entered(player)
	var contact_damage_removed: bool = player.hp == player_hp_before
	player.global_position = SPAWN
	enemy.global_position = enemy_position_before
	player.respawn(SPAWN)
	enemy.take_damage(enemy.STOMP_AP)
	var enemy_damage_ok: bool = enemy.hp == 50 and not enemy.dead
	return contact_damage_removed and enemy_damage_ok


func _attack_system_ok() -> bool:
	var enemies := get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		return false
	var enemy := enemies[0]
	var attack_area := player.get_node_or_null("AttackArea") as Area2D
	var attack_sprite := player.get_node_or_null("Visual/AttackSprite") as AnimatedSprite2D
	var player_hurt := player.get_node_or_null("HurtBox") as Area2D
	var enemy_hurt := enemy.get_node_or_null("Hurt") as Area2D
	if attack_area == null or attack_sprite == null or player_hurt == null or enemy_hurt == null:
		return false
	var frames_ok: bool = attack_sprite.sprite_frames != null and attack_sprite.sprite_frames.get_frame_count("attack") == player.ATTACK_FRAME_COUNT
	var active_window_ok: bool = player.ATTACK_ACTIVE_START == 7 and player.ATTACK_ACTIVE_END == 8 and player.ATTACK_ACTIVE_END - player.ATTACK_ACTIVE_START + 1 == 2
	var collision_ok: bool = attack_area.collision_layer == 8 and enemy_hurt.collision_mask == 10 and player_hurt.collision_mask == 4
	var hp_before: int = enemy.hp
	player.start_attack()
	attack_area.monitoring = true
	enemy._on_hurt_area_entered(attack_area)
	var hit_once: bool = enemy.hp == hp_before - player.ATTACK_AP
	enemy._on_hurt_area_entered(attack_area)
	var hit_once_only: bool = enemy.hp == hp_before - player.ATTACK_AP
	player._finish_attack()
	enemy.hp = hp_before
	enemy.hp_changed.emit(enemy.hp, enemy.MAX_HP)
	enemy.hitstun = 0.0
	enemy.modulate.a = 1.0
	return frames_ok and active_window_ok and collision_ok and hit_once and hit_once_only


func _attack_input_lock_ok() -> bool:
	var position_before: Vector2 = player.global_position
	player.velocity = Vector2(120.0, 0.0)
	player._jump_buffer = player.JUMP_BUFFER_TIME
	player.start_attack()
	player._physics_process(1.0 / 60.0)
	var movement_locked: bool = is_zero_approx(player.global_position.x - position_before.x) and is_zero_approx(player.velocity.x)
	var jump_locked: bool = player.velocity.y >= 0.0 and is_zero_approx(player._jump_buffer)
	var attack_still_active: bool = player.attacking
	player._finish_attack()
	player.respawn(SPAWN)
	return movement_locked and jump_locked and attack_still_active


func _enemy_hit_motion_ok() -> bool:
	var enemies := get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		return false
	var enemy := enemies[0]
	var attacker := player
	var start_position: Vector2 = enemy.global_position
	var start_hp: int = enemy.hp
	attacker.global_position = start_position + Vector2(-120.0, 0.0)
	enemy.receive_attack_damage(attacker.ATTACK_AP, attacker)
	var hp_ok: bool = enemy.hp == start_hp - attacker.ATTACK_AP
	var knockback_ok: bool = enemy.velocity.x > 0.0
	var alpha_ok: bool = is_equal_approx(enemy.modulate.a, enemy.HITSTUN_ALPHA)
	var hitstun_ok: bool = enemy.hitstun > 0.0
	enemy._physics_process(0.1)
	var moved_ok: bool = enemy.global_position.x > start_position.x
	enemy.hitstun = 0.0
	enemy.modulate.a = 1.0
	enemy.global_position = start_position
	enemy.velocity = Vector2.ZERO
	attacker.global_position = SPAWN
	return hp_ok and knockback_ok and alpha_ok and hitstun_ok and moved_ok


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
