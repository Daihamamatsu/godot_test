extends Node
## Procedural retro sound effects, generated entirely in code (no audio assets).
## Usage: Sfx.play("jump")

const RATE := 44100

var _sounds: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.volume_db = -8.0
		add_child(p)
		_players.append(p)

	_sounds["jump"] = _finish(_tone(280.0, 720.0, 0.14, 0.5, 0))
	_sounds["coin"] = _finish(_cat([
		_tone(987.77, 987.77, 0.07, 0.5, 1),
		_tone(1318.51, 1318.51, 0.22, 0.5, 1),
	]))
	_sounds["stomp"] = _finish(_tone(220.0, 55.0, 0.12, 0.6, 2))
	_sounds["hurt"] = _finish(_tone(500.0, 90.0, 0.35, 0.5, 2))
	_sounds["clear"] = _finish(_cat([
		_tone(523.25, 523.25, 0.09, 0.4, 1),
		_tone(659.25, 659.25, 0.09, 0.4, 1),
		_tone(783.99, 783.99, 0.09, 0.4, 1),
		_tone(1046.5, 1046.5, 0.28, 0.4, 1),
	]))
	_sounds["gameover"] = _finish(_cat([
		_tone(493.88, 493.88, 0.14, 0.4, 1),
		_tone(392.0, 392.0, 0.14, 0.4, 1),
		_tone(329.63, 329.63, 0.14, 0.4, 1),
		_tone(261.63, 196.0, 0.4, 0.4, 1),
	]))


func play(id: String) -> void:
	var stream: AudioStreamWAV = _sounds.get(id)
	if stream == null:
		push_warning("Sfx: unknown sound id '%s'" % id)
		return
	var free_player: AudioStreamPlayer = null
	for p in _players:
		if not p.playing:
			free_player = p
			break
	if free_player == null:
		free_player = _players[0]
	free_player.stream = stream
	free_player.play()


## Builds one tone as 16-bit PCM interleaved into stereo frames (4 bytes/frame).
## wave: 0 = square, 1 = sine, 2 = triangle.
func _tone(f0: float, f1: float, dur: float, vol: float, wave: int) -> PackedByteArray:
	var n := int(RATE * dur)
	var out := PackedByteArray()
	out.resize(n * 4)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n)
		var f := lerpf(f0, f1, t)
		phase += f / float(RATE)
		var env := 1.0 - t
		var v := clampi(int(_wave(wave, phase) * vol * env * 30000.0), -32768, 32767)
		var o := i * 4
		out[o] = v & 0xFF
		out[o + 1] = (v >> 8) & 0xFF
		out[o + 2] = v & 0xFF
		out[o + 3] = (v >> 8) & 0xFF
	return out


func _wave(wave: int, phase: float) -> float:
	var p := fposmod(phase, 1.0)
	match wave:
		0:
			return 1.0 if p < 0.5 else -1.0
		1:
			return sin(phase * TAU)
		2:
			return 2.0 * absf(2.0 * p - 1.0) - 1.0
	return 0.0


func _cat(parts: Array) -> PackedByteArray:
	var out := PackedByteArray()
	for part in parts:
		out.append_array(part)
	return out


func _finish(data: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = true
	wav.data = data
	return wav
