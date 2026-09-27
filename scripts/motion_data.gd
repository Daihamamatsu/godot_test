extends Resource
class_name MotionData
## 表示、再生、攻撃判定をまとめて調整するモーションデータ。

@export_category("表示")
@export var animation_name: StringName = &"motion"
@export var sprite_frames: SpriteFrames
@export var sprite_scale := Vector2.ONE
@export var sprite_offset := Vector2.ZERO

@export_category("再生")
@export_range(0.1, 120.0, 0.1) var fps := 12.0
@export var loop := true
@export_range(0, 999, 1) var idle_frame := 0
@export_range(0.0, 1000.0, 0.1) var minimum_move_speed := 10.0

@export_category("攻撃")
@export_range(0, 999, 1) var damage := 0
@export_range(0, 999, 1) var active_start_frame := 0
@export_range(0, 999, 1) var active_end_frame := 0
@export_range(0, 999, 1) var prepare_frames := 0
@export_range(0, 999, 1) var grow_frames := 0
@export_range(0, 999, 1) var recovery_end_frame := 0
@export_range(0, 9999, 1) var cooldown_frames := 0
@export var hitbox_position := Vector2.ZERO
@export var hitbox_size := Vector2.ZERO


func frame_count() -> int:
	if sprite_frames == null or not sprite_frames.has_animation(animation_name):
		return 0
	return sprite_frames.get_frame_count(animation_name)


func is_attack_frame(frame: int) -> bool:
	return frame >= active_start_frame and frame <= active_end_frame