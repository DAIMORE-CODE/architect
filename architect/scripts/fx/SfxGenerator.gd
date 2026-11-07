class_name SfxGenerator
extends RefCounted

const MIX_RATE: int = 22050
const AMPLITUDE: float = 0.3
const SCRAPE_AMPLITUDE: float = 0.18
const ATTACK_SEC: float = 0.005
const SCRAPE_DURATION: float = 0.08
const POLISH_DURATION: float = 0.12
const POLISH_DECAY: float = 30.0
const FAIL_DURATION: float = 0.15
const COMPLETE_NOTE_DURATION: float = 0.1
const STITCH_DURATION: float = 0.05
const STITCH_DECAY: float = 60.0
const SCRAPE_SMOOTHING: float = 0.3
const PCM_SCALE: float = 32767.0
const BUS_NAME: String = "SFX"
const PLAY_THROTTLE_MS: int = 100
const MAX_VOICES: int = 4
const RELEASE_SEC: float = 0.03
const MUSIC_BUS_NAME: String = "Music"
const MUSIC_VOLUME_DB: float = -18.0
const MUSIC_LOOP_SEC: float = 16.0
const MUSIC_STEP_SEC: float = 0.4
const MUSIC_NOTE_AMP: float = 0.12
const MUSIC_PAD_AMP: float = 0.04
const MUSIC_ATTACK_SEC: float = 0.01
const MUSIC_CHORD_C: Array[float] = [261.63, 329.63, 392.0]
const MUSIC_CHORD_AM: Array[float] = [220.0, 261.63, 329.63]

static var _cache: Dictionary = {}
static var _music_cache: AudioStreamWAV = null
static var _last_play_ms: Dictionary = {}
static var _voices: int = 0

static func get_stream(kind: String) -> AudioStreamWAV:
	if not _cache.has(kind):
		var samples: PackedFloat32Array = _synthesize(kind)
		if samples.is_empty():
			push_warning("SfxGenerator: неизвестный звук '%s'" % kind)
			return null
		_cache[kind] = _to_wav(samples)
	return _cache[kind]

## Одноразовое воспроизведение: троттлинг по виду звука и лимит одновременных голосов.
## Плеер создаётся на корне дерева и удаляется по таймеру после окончания звука.
static func play(kind: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var now: int = Time.get_ticks_msec()
	if now - int(_last_play_ms.get(kind, -PLAY_THROTTLE_MS)) < PLAY_THROTTLE_MS:
		return
	if _voices >= MAX_VOICES:
		return
	var stream := get_stream(kind)
	if stream == null:
		return
	_last_play_ms[kind] = now
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = BUS_NAME
	tree.root.add_child(player)
	_voices += 1
	player.finished.connect(func() -> void:
		_voices -= 1
		player.queue_free()
	)
	player.play()

## Создаёт шину SFX (если её нет) и применяет громкость из настроек.
static func setup_audio() -> void:
	var idx: int = _ensure_bus(BUS_NAME)
	var volume: float = clampf(float(SaveManager.get_setting("sfx_volume")) / 100.0, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, volume <= 0.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(volume, 0.0001)))
	_ensure_bus(MUSIC_BUS_NAME)
	var music_idx: int = _ensure_bus(MUSIC_BUS_NAME)
	var music_volume: float = clampf(float(SaveManager.get_setting("music_volume")) / 100.0, 0.0, 1.0)
	AudioServer.set_bus_volume_db(music_idx, linear_to_db(maxf(music_volume, 0.0001)))
	apply_music_enabled(bool(SaveManager.get_setting("music_enabled")))

## Музыка выключается отключением шины, плеер при этом продолжает работать.
static func apply_music_enabled(enabled: bool) -> void:
	AudioServer.set_bus_mute(_ensure_bus(MUSIC_BUS_NAME), not enabled)

static func _ensure_bus(bus_name: String) -> int:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")
	return idx

## Вибрация только на Android и только если она включена в настройках.
static func vibrate(ms: int) -> void:
	if OS.has_feature("android") and bool(SaveManager.get_setting("vibration")):
		Input.vibrate_handheld(ms)

static func _synthesize(kind: String) -> PackedFloat32Array:
	match kind:
		"scrape":
			return _noise(SCRAPE_DURATION, SCRAPE_AMPLITUDE)
		"polish":
			return _tone(880.0, POLISH_DURATION, AMPLITUDE, POLISH_DECAY)
		"fail":
			return _tone(220.0, FAIL_DURATION, AMPLITUDE, 0.0)
		"stitch":
			return _tone(1400.0, STITCH_DURATION, AMPLITUDE * 0.5, STITCH_DECAY)
		"complete":
			return _sequence([[660.0, COMPLETE_NOTE_DURATION, AMPLITUDE, 0.0], [990.0, COMPLETE_NOTE_DURATION, AMPLITUDE, 0.0]])
		"snap":
			return _tone(520.0, 0.075, 0.22, 40.0)
		"click":
			return _tone(1000.0, 0.05, 0.2, 80.0)
		"no_coins":
			return _sequence([[330.0, 0.12, 0.3, 10.0], [262.0, 0.14, 0.3, 8.0]])
		"purchase":
			return _sequence([[660.0, 0.08, 0.3, 20.0], [880.0, 0.12, 0.3, 15.0]])
		"latch":
			return _tone(1500.0, 0.05, 0.25, 70.0)
		"wrong":
			return _tone(180.0, 0.12, 0.25, 12.0)
		"star":
			return _tone(1320.0, 0.12, 0.25, 25.0)
		"coin":
			return _sequence([[1760.0, 0.06, 0.2, 40.0], [2350.0, 0.1, 0.2, 30.0]])
		"unlock":
			return _sequence([[523.0, 0.1, 0.3, 10.0], [659.0, 0.1, 0.3, 10.0], [784.0, 0.2, 0.3, 8.0]])
		"reward":
			return _sequence([[784.0, 0.1, 0.3, 0.0], [988.0, 0.1, 0.3, 0.0], [1175.0, 0.2, 0.3, 5.0]])
	return PackedFloat32Array()

static func _sequence(notes: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for note: Array in notes:
		out.append_array(_tone(note[0], note[1], note[2], note[3]))
	return out

static func _tone(freq: float, duration: float, amp: float, decay: float) -> PackedFloat32Array:
	var n: int = int(MIX_RATE * duration)
	var attack_n: int = maxi(int(MIX_RATE * ATTACK_SEC), 1)
	var release_n: int = maxi(int(MIX_RATE * RELEASE_SEC), 1)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		var t: float = float(i) / float(MIX_RATE)
		var env: float = _envelope(i, n, attack_n, release_n) * exp(-decay * t)
		out[i] = sin(TAU * freq * t) * amp * env
	return out

static func _noise(duration: float, amp: float) -> PackedFloat32Array:
	var n: int = int(MIX_RATE * duration)
	var attack_n: int = maxi(int(MIX_RATE * ATTACK_SEC), 1)
	var release_n: int = maxi(int(MIX_RATE * RELEASE_SEC), 1)
	var out := PackedFloat32Array()
	out.resize(n)
	var smoothed: float = 0.0
	for i in range(n):
		smoothed = lerpf(smoothed, randf_range(-1.0, 1.0), SCRAPE_SMOOTHING)
		out[i] = smoothed * amp * _envelope(i, n, attack_n, release_n)
	return out

## Атака в начале и спад до нуля в конце — без щелчков.
static func _envelope(i: int, n: int, attack_n: int, release_n: int) -> float:
	var attack: float = minf(float(i) / float(attack_n), 1.0)
	var release: float = minf(float(n - i) / float(release_n), 1.0)
	return minf(attack, release)

static func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * PCM_SCALE))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav

## Зацикленная фоновая музыка: два аккорда по 8 с, арпеджио по 0.4 с и мягкий пэд.
static func get_music_stream() -> AudioStreamWAV:
	if _music_cache == null:
		_music_cache = _to_wav(_build_music())
		_music_cache.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_music_cache.loop_end = _music_cache.data.size() / 2
	return _music_cache

static func _build_music() -> PackedFloat32Array:
	var total: int = int(MIX_RATE * MUSIC_LOOP_SEC)
	var out := PackedFloat32Array()
	out.resize(total)
	var chord_n: int = total / 2
	var step_n: int = int(MIX_RATE * MUSIC_STEP_SEC)
	var chords: Array[Array] = [MUSIC_CHORD_C, MUSIC_CHORD_AM]
	for c in range(chords.size()):
		var tones: Array[float] = chords[c]
		var start: int = c * chord_n
		for f in tones:
			_add_pad(out, start, chord_n, f)
		var arp: Array[float] = [tones[0], tones[1], tones[2], tones[0] * 2.0]
		for s in range(chord_n / step_n):
			_add_note(out, start + s * step_n, step_n, arp[s % arp.size()])
	return out

static func _add_pad(out: PackedFloat32Array, start: int, length: int, freq: float) -> void:
	for i in range(length):
		var t: float = float(i) / float(MIX_RATE)
		var env: float = sin(PI * float(i) / float(length))
		out[start + i] += sin(TAU * freq * t) * MUSIC_PAD_AMP * env

static func _add_note(out: PackedFloat32Array, start: int, length: int, freq: float) -> void:
	var attack_n: int = maxi(int(MIX_RATE * MUSIC_ATTACK_SEC), 1)
	for i in range(length):
		var t: float = float(i) / float(MIX_RATE)
		var env: float = minf(float(i) / float(attack_n), 1.0) * (1.0 - float(i) / float(length))
		out[start + i] += sin(TAU * freq * t) * MUSIC_NOTE_AMP * env
