class_name Sfx
extends Node
## Procedurally synthesised sound effects (no audio files needed yet).
## Placeholder quality by design: swap in real samples later by name.

const RATE := 22050
var streams := {}
var _players: Array = []
var _last := {}
var master_db := -6.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 24:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_build()

func play(name: String, volume_db: float = 0.0, pitch_var: float = 0.08, world_pos = null) -> void:
	if not streams.has(name):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(name, -1000)) < 30:
		return
	_last[name] = now
	var vol := volume_db
	if world_pos != null and FX.camera:
		var d: float = (world_pos as Vector2).distance_to(FX.camera.get_screen_center_position())
		vol -= clampf((d - 300.0) / 40.0, 0.0, 30.0)
		if vol < -40.0:
			return
	for p in _players:
		if not p.playing:
			p.stream = streams[name]
			p.volume_db = vol + master_db
			p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
			p.play()
			return

# ---------------- synthesis ----------------

func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	# Normalise every sound to the same peak; loudness is set per call in play().
	var peak := 0.0001
	for x in samples:
		peak = maxf(peak, absf(x))
	var gain := 0.8 / peak
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		# short fade-out so nothing clicks at the end
		var tail := minf(1.0, float(samples.size() - i) / 200.0)
		var v := int(clampf(samples[i] * gain * tail, -1.0, 1.0) * 32000.0)
		bytes.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w

func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b

## Adds a tone that sweeps f0->f1 with an exponential decay envelope.
func _tone(b: PackedFloat32Array, f0: float, f1: float, amp: float, decay: float, start: float = 0.0, shape: String = "sine", attack: float = 0.004) -> void:
	var phase := 0.0
	var s0 := int(start * RATE)
	for i in range(s0, b.size()):
		var t := float(i - s0) / RATE
		var k := t / (float(b.size() - s0) / RATE)
		var f := lerpf(f0, f1, k)
		phase += TAU * f / RATE
		var env := exp(-t * decay) * minf(1.0, t / attack)
		var v := 0.0
		match shape:
			"sine": v = sin(phase)
			"square": v = 1.0 if sin(phase) > 0.0 else -1.0
			"saw": v = fmod(phase / TAU, 1.0) * 2.0 - 1.0
			"tri": v = asin(sin(phase)) * 0.6366
		b[i] += v * amp * env

## Low-passed noise with decay. lp: 0..1 (smaller = darker).
func _noise(b: PackedFloat32Array, amp: float, decay: float, lp: float, start: float = 0.0, lp_end: float = -1.0) -> void:
	var y := 0.0
	var s0 := int(start * RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234 + int(amp * 1000) + int(decay)
	for i in range(s0, b.size()):
		var t := float(i - s0) / RATE
		var k := t / (float(b.size() - s0) / RATE)
		var a := lerpf(lp, lp_end if lp_end >= 0.0 else lp, k)
		y += (rng.randf_range(-1.0, 1.0) - y) * a
		b[i] += y * amp * exp(-t * decay) * minf(1.0, t / 0.003)

func _build() -> void:
	var b: PackedFloat32Array
	b = _buf(0.18); _tone(b, 260, 720, 0.35, 18, 0, "tri"); _noise(b, 0.25, 20, 0.15, 0, 0.6)
	streams["bolt"] = _wav(b)
	b = _buf(0.14); _tone(b, 150, 55, 0.7, 28); _noise(b, 0.5, 40, 0.25)
	streams["hit"] = _wav(b)
	b = _buf(0.25); _tone(b, 180, 50, 0.8, 18); _noise(b, 0.6, 25, 0.4); _tone(b, 2400, 1800, 0.25, 30, 0, "square")
	streams["crit"] = _wav(b)
	b = _buf(0.2); _noise(b, 0.7, 16, 0.08, 0, 0.55)
	streams["slash"] = _wav(b)
	b = _buf(0.6); _tone(b, 90, 40, 0.7, 7); _noise(b, 0.45, 6, 0.6, 0, 0.05); _tone(b, 1600, 2600, 0.08, 6, 0, "sine")
	streams["nova"] = _wav(b)
	b = _buf(0.25)
	for k in 6:
		_noise(b, 0.45, 60, 0.9, k * 0.035)
	_tone(b, 3000, 900, 0.12, 14, 0, "square")
	streams["zap"] = _wav(b)
	b = _buf(0.5); _tone(b, 70, 45, 0.5, 5); _noise(b, 0.5, 5, 0.06)
	streams["ground"] = _wav(b)
	b = _buf(0.35); _noise(b, 0.6, 10, 0.12, 0, 0.03); _tone(b, 110, 60, 0.3, 14)
	streams["die"] = _wav(b)
	b = _buf(0.18); _tone(b, 140, 90, 0.6, 22, 0, "saw"); _noise(b, 0.3, 30, 0.2)
	streams["hurt"] = _wav(b)
	b = _buf(0.22); _noise(b, 0.45, 14, 0.05, 0, 0.35)
	streams["dodge"] = _wav(b)
	b = _buf(0.9); _tone(b, 70, 30, 1.0, 4.5); _noise(b, 0.8, 5, 0.3, 0, 0.04)
	streams["boom"] = _wav(b)
	b = _buf(0.12); _tone(b, 1200, 1500, 0.25, 30)
	streams["pickup"] = _wav(b)
	b = _buf(0.25); _tone(b, 880, 880, 0.3, 14)
	streams["drop_magic"] = _wav(b)
	b = _buf(0.7); _tone(b, 660, 660, 0.3, 6); _tone(b, 990, 990, 0.25, 6, 0.09); _tone(b, 1320, 1320, 0.12, 8, 0.09)
	streams["drop_rare"] = _wav(b)
	b = _buf(1.6)
	for f in [220.0, 277.2, 329.6, 440.0]:
		_tone(b, f, f, 0.2, 2.2, 0, "tri")
	_tone(b, 1760, 1760, 0.12, 4, 0.15); _tone(b, 2217, 2217, 0.1, 4, 0.3); _tone(b, 2637, 2637, 0.1, 4, 0.45)
	streams["drop_unique"] = _wav(b)
	b = _buf(1.0)
	var notes := [523.3, 659.3, 784.0, 1046.5]
	for i in notes.size():
		_tone(b, notes[i], notes[i], 0.28, 4, i * 0.09, "tri")
	streams["levelup"] = _wav(b)
	b = _buf(1.4); _tone(b, 200, 420, 0.3, 2.5, 0, "tri"); _tone(b, 300, 630, 0.2, 2.5, 0, "sine"); _noise(b, 0.2, 3, 0.05, 0, 0.3)
	streams["portal"] = _wav(b)
	b = _buf(0.3); _tone(b, 300, 200, 0.35, 10, 0, "sine"); _noise(b, 0.25, 12, 0.1)
	streams["flask"] = _wav(b)
	b = _buf(0.5); _tone(b, 60, 140, 0.45, 3.5, 0, "saw"); _noise(b, 0.25, 4, 0.04)
	streams["windup"] = _wav(b)
