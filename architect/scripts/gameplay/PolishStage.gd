extends Control
## PolishStage — штопка (D-020), третий этап сессии.
## Шесть дыр в ткани, у каждой свой таймер огонька. Игла, проведённая через горящую
## дыру не слишком быстро, зашивает её. Таймер истёк — дыра обугливается (промах).

signal stage_finished(progress: float)
signal back_requested

const HOLE_COUNT: int = 6
const EASY_HOLE_COUNT: int = 4
## Нормализованные центры дыр относительно изображения fabric_holes.png.
const HOLE_POSITIONS: Array[Vector2] = [
	Vector2(0.261, 0.312),
	Vector2(0.532, 0.307),
	Vector2(0.360, 0.476),
	Vector2(0.635, 0.481),
	Vector2(0.270, 0.676),
	Vector2(0.528, 0.670),
]
const FUSE_TIME: float = 2.0
const QUICK_HANDS_BONUS: float = 0.3
## Задержка между стартами огоньков соседних дыр, чтобы они не горели все сразу.
const STAGGER_STEP: float = 0.7
## Скорость иглы в ширинах этапа в секунду; быстрее — проход не засчитывается.
const SWIPE_MAX_SPEED: float = 2.5
const HOLE_RADIUS_RATIO: float = 0.045
const RING_RADIUS_RATIO: float = 0.07
const HIT_RADIUS_RATIO: float = 0.085
const NEEDLE_RADIUS: float = 5.0
const SEW_TWEEN_TIME: float = 0.2
const STITCH_COOLDOWN: float = 0.15
const BURST_COUNT: int = 16
const BURST_COLOR: Color = Color(1.0, 0.9, 0.5)
const HOLE_COLOR: Color = Color(0.1, 0.08, 0.06, 0.9)
const TRACK_COLOR: Color = Color(0.3, 0.22, 0.15, 0.8)
const FUSE_COLOR: Color = Color(1.0, 0.55, 0.15)
const SPARK_COLOR: Color = Color(1.0, 0.9, 0.4)
const CHAR_COLOR: Color = Color(0.05, 0.04, 0.03)
const THREAD_COLOR: Color = Color(0.9, 0.85, 0.7)
const NEEDLE_COLOR: Color = Color(0.8, 0.8, 0.85)
const HOLE_PENDING: int = 0
const HOLE_BURNING: int = 1
const HOLE_SEWN: int = 2
const HOLE_CHARRED: int = 3
const MOUSE_HOLD: int = -1
const NO_HOLD: int = -2
const SFX := preload("res://scripts/fx/SfxGenerator.gd")
const FX := preload("res://scripts/fx/ClearParticles.gd")
const VIBRATE_STITCH_MS: int = 15
const VIBRATE_COMPLETE_MS: int = 40

var misses: int = 0
var polished_count: int = 0

var _finished: bool = false
var easy_mode: bool = false
var hole_count: int = HOLE_COUNT
var _elapsed: float = 0.0
var _fuse_time: float = FUSE_TIME
var _hole_state: Array[int] = []
var _hole_left: Array[float] = []
var _hole_anim: Array[float] = []
var _last_sewn: int = -1
var _needle_pos: Vector2 = Vector2.ZERO
var _holding: bool = false
var _hold_id: int = NO_HOLD
var _stitch_cooldown: float = 0.0
var _sfx_player: AudioStreamPlayer
var _stitch_player: AudioStreamPlayer

@onready var progress_bar: ProgressBar = $TopBar/Progress
@onready var _background: TextureRect = $Background
@onready var _overlay: Control = $Overlay

func _enter_tree() -> void:
	var back: Button = $TopBar/BtnBack
	if not back.pressed.is_connected(_on_back_pressed):
		back.pressed.connect(_on_back_pressed)
	var overlay: Control = $Overlay
	if not overlay.draw.is_connected(_on_overlay_draw):
		overlay.draw.connect(_on_overlay_draw)
	if not overlay.resized.is_connected(_on_overlay_resized):
		overlay.resized.connect(_on_overlay_resized)

func _exit_tree() -> void:
	var back: Button = $TopBar/BtnBack
	if back.pressed.is_connected(_on_back_pressed):
		back.pressed.disconnect(_on_back_pressed)
	var overlay: Control = $Overlay
	if overlay.draw.is_connected(_on_overlay_draw):
		overlay.draw.disconnect(_on_overlay_draw)
	if overlay.resized.is_connected(_on_overlay_resized):
		overlay.resized.disconnect(_on_overlay_resized)
	_stop_sounds()

func _ready() -> void:
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = SFX.BUS_NAME
	add_child(_sfx_player)
	_stitch_player = AudioStreamPlayer.new()
	_stitch_player.bus = SFX.BUS_NAME
	add_child(_stitch_player)
	if GameData.has_upgrade("quick_hands"):
		_fuse_time = FUSE_TIME * (1.0 + QUICK_HANDS_BONUS)
	if easy_mode:
		hole_count = EASY_HOLE_COUNT
	for i in range(hole_count):
		_hole_state.append(HOLE_PENDING)
		_hole_left.append(_fuse_time)
		_hole_anim.append(1.0)
	_needle_pos = _overlay.size * 0.5
	if GameData.use_consumable("polish"):
		_apply_polish_bonus.call_deferred()
	_overlay.queue_redraw()

func _stop_sounds() -> void:
	if _sfx_player != null:
		_sfx_player.stop()
	if _stitch_player != null:
		_stitch_player.stop()

func _apply_polish_bonus() -> void:
	if not _finished and _hole_state[0] == HOLE_PENDING:
		_sew(0)

func _process(delta: float) -> void:
	if _finished:
		return
	_elapsed += delta
	_stitch_cooldown = maxf(_stitch_cooldown - delta, 0.0)
	for i in range(hole_count):
		if _hole_state[i] == HOLE_PENDING and _elapsed >= float(i) * STAGGER_STEP:
			_hole_state[i] = HOLE_BURNING
			_hole_left[i] = _fuse_time
		elif _hole_state[i] == HOLE_BURNING:
			_hole_left[i] -= delta
			if _hole_left[i] <= 0.0:
				_char(i)
	_overlay.queue_redraw()

func _input(event: InputEvent) -> void:
	if _finished:
		return
	var mouse_button := event as InputEventMouseButton
	var touch := event as InputEventScreenTouch
	var motion := event as InputEventMouseMotion
	var drag := event as InputEventScreenDrag
	if mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_LEFT:
		if mouse_button.pressed:
			_begin_hold(MOUSE_HOLD, mouse_button.position)
		elif _holding and _hold_id == MOUSE_HOLD:
			_end_hold()
	elif touch != null:
		if touch.pressed:
			_begin_hold(touch.index, touch.position)
		elif touch.index == _hold_id:
			_end_hold()
	elif motion != null:
		var local := _to_overlay(motion.position)
		_needle_pos = local
		if _holding and _hold_id == MOUSE_HOLD:
			if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
				_end_hold()
			else:
				_try_pass(local, _swipe_speed(motion.velocity, motion.relative))
	elif drag != null:
		var local := _to_overlay(drag.position)
		_needle_pos = local
		if _holding and drag.index == _hold_id:
			_try_pass(local, _swipe_speed(drag.velocity, drag.relative))

func _begin_hold(id: int, pos: Vector2) -> void:
	if _holding:
		return
	_holding = true
	_hold_id = id
	_needle_pos = _to_overlay(pos)

func _end_hold() -> void:
	_holding = false
	_hold_id = NO_HOLD

## Скорость в px/s: берём event.velocity; если она нулевая, считаем relative / delta кадра.
func _swipe_speed(velocity: Vector2, relative: Vector2) -> float:
	if velocity.length() > 0.0:
		return velocity.length()
	return relative.length() / maxf(get_process_delta_time(), 0.001)

func _try_pass(local: Vector2, speed: float) -> void:
	var target := _burning_hole_at(local)
	if target < 0:
		return
	if _stitch_cooldown <= 0.0:
		_stitch_cooldown = STITCH_COOLDOWN
		_play(_stitch_player, "stitch")
	if speed / maxf(_overlay.size.x, 1.0) > SWIPE_MAX_SPEED:
		return
	_sew(target)

func _burning_hole_at(local: Vector2) -> int:
	var hit_radius := _image_rect().size.x * HIT_RADIUS_RATIO
	for i in range(hole_count):
		if _hole_state[i] == HOLE_BURNING and local.distance_to(_hole_center(i)) <= hit_radius:
			return i
	return -1

func _sew(i: int) -> void:
	_hole_state[i] = HOLE_SEWN
	_last_sewn = i
	polished_count += 1
	progress_bar.value = float(polished_count) / float(hole_count)
	_play(_sfx_player, "polish")
	FX.burst(_overlay, _hole_center(i), BURST_COLOR, BURST_COUNT)
	SFX.vibrate(VIBRATE_STITCH_MS)
	create_tween().tween_method(_set_hole_anim.bind(i), 1.0, 0.0, SEW_TWEEN_TIME)
	_check_done()

func _char(i: int) -> void:
	_hole_state[i] = HOLE_CHARRED
	misses += 1
	_play(_sfx_player, "fail")
	_check_done()

func _set_hole_anim(value: float, i: int) -> void:
	_hole_anim[i] = value

func _check_done() -> void:
	for state in _hole_state:
		if state == HOLE_PENDING or state == HOLE_BURNING:
			return
	_complete()

func _complete() -> void:
	if _finished:
		return
	_finished = true
	set_process(false)
	set_process_input(false)
	_play(_sfx_player, "complete")
	SFX.vibrate(VIBRATE_COMPLETE_MS)
	stage_finished.emit(float(polished_count) / float(hole_count))

func _play(player: AudioStreamPlayer, kind: String) -> void:
	player.stream = SFX.get_stream(kind)
	player.play()

func _on_back_pressed() -> void:
	_stop_sounds()
	back_requested.emit()

func _on_overlay_resized() -> void:
	_overlay.queue_redraw()

## Изображение вписано с сохранением пропорций (как KEEP_ASPECT_CENTERED у фона).
func _image_rect() -> Rect2:
	var area := _overlay.size
	var tex := _background.texture
	if tex == null:
		return Rect2(Vector2.ZERO, area)
	var tex_size := tex.get_size()
	var factor := minf(area.x / tex_size.x, area.y / tex_size.y)
	var draw_size := tex_size * factor
	return Rect2((area - draw_size) * 0.5, draw_size)

func _hole_center(i: int) -> Vector2:
	var rect := _image_rect()
	return rect.position + HOLE_POSITIONS[i] * rect.size

func _to_overlay(pos: Vector2) -> Vector2:
	return _overlay.get_global_transform().affine_inverse() * pos

func _on_overlay_draw() -> void:
	var r_hole := _image_rect().size.x * HOLE_RADIUS_RATIO
	var r_ring := _image_rect().size.x * RING_RADIUS_RATIO
	for i in range(hole_count):
		var c := _hole_center(i)
		match _hole_state[i]:
			HOLE_PENDING:
				_overlay.draw_circle(c, r_hole, HOLE_COLOR)
			HOLE_BURNING:
				var ratio := clampf(_hole_left[i] / _fuse_time, 0.0, 1.0)
				var start_angle := -PI * 0.5
				var head_angle := start_angle + TAU * ratio
				_overlay.draw_circle(c, r_hole, HOLE_COLOR)
				_overlay.draw_arc(c, r_ring, 0.0, TAU, 32, TRACK_COLOR, 3.0)
				_overlay.draw_arc(c, r_ring, start_angle, head_angle, 32, FUSE_COLOR, 4.0)
				_overlay.draw_circle(c + Vector2.from_angle(head_angle) * r_ring, 3.0, SPARK_COLOR)
			HOLE_SEWN:
				var anim := _hole_anim[i]
				if anim > 0.0:
					_overlay.draw_circle(c, r_hole * anim, HOLE_COLOR)
					_overlay.draw_arc(c, r_ring * (2.0 - anim), 0.0, TAU, 32, Color(SPARK_COLOR, anim), 3.0)
			HOLE_CHARRED:
				_overlay.draw_circle(c, r_hole, CHAR_COLOR)
				_overlay.draw_arc(c, r_ring, 0.0, TAU, 32, CHAR_COLOR, 3.0)
	if _last_sewn >= 0:
		_overlay.draw_line(_needle_pos, _hole_center(_last_sewn), THREAD_COLOR, 2.0)
	_overlay.draw_circle(_needle_pos, NEEDLE_RADIUS, NEEDLE_COLOR)
