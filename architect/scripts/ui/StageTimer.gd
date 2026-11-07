class_name StageTimer
extends Control
## Фитиль времени справа от этапа: высота уменьшается, по истечении времени сигнализирует expired.

signal expired

const FUSE_WIDTH: float = 12.0
const FUSE_COLOR: Color = Color(0.25, 0.18, 0.12, 1.0)
const SPARK_COLOR: Color = Color(1.0, 0.75, 0.2, 1.0)
const SPARK_RADIUS: float = 7.0
const SPARK_PULSE: float = 2.0
const SPARK_SPEED: float = 18.0
const STRIP_WIDTH: float = 40.0
const RIGHT_OFFSET: float = 20.0
const TOP_OFFSET: float = 80.0
const BOTTOM_OFFSET: float = 140.0

var _duration: float = 1.0
var _elapsed: float = 0.0
var _running: bool = false
var _time: float = 0.0

func _init(duration_sec: float) -> void:
	_duration = maxf(duration_sec, 0.1)
	set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	offset_left = -RIGHT_OFFSET - STRIP_WIDTH
	offset_right = -RIGHT_OFFSET
	offset_top = TOP_OFFSET
	offset_bottom = -BOTTOM_OFFSET
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func start() -> void:
	_running = true

func stop() -> void:
	_running = false

func _process(delta: float) -> void:
	_time += delta
	if _running:
		_elapsed += delta
		if _elapsed >= _duration:
			_running = false
			queue_redraw()
			expired.emit()
			return
	queue_redraw()

func _draw() -> void:
	var remain := clampf(1.0 - _elapsed / _duration, 0.0, 1.0)
	if remain <= 0.0:
		return
	var base := Vector2(size.x * 0.5, size.y)
	var tip := Vector2(base.x, base.y - size.y * remain)
	draw_line(base, tip, FUSE_COLOR, FUSE_WIDTH)
	var pulse := sin(_time * SPARK_SPEED) * SPARK_PULSE
	draw_circle(tip, SPARK_RADIUS + pulse, SPARK_COLOR)
