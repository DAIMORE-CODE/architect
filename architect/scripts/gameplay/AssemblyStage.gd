extends Control
## AssemblyStage — мини-игра «Сборка» (Шаг 4a).
## Игрок перетаскивает детали из лотка на их места в силуэте предмета.

signal stage_finished(progress: float)
signal back_requested

## Порог прилипания: доля стороны силуэта (0.25 = половина размера слота).
const SNAP_RATIO: float = 0.25
const RETURN_TIME: float = 0.25
const SNAP_ANIM_TIME: float = 0.15
const TRAY_SCALE_RATIO: float = 0.8
const TRAY_FIT_RATIO: float = 0.9
const TRAY_TOP_RATIO: float = 0.7
const BOARD_FIT: float = 0.92
const SILHOUETTE_ALPHA: float = 0.25
const SILHOUETTE_TINT: Color = Color(1.0, 0.97, 0.9)
const SLOT_ALPHA: float = 0.08
const PICKUP_SCALE: float = 1.05
const PICKUP_SEC: float = 0.08
const SPARK_COLOR: Color = Color(0.85, 0.65, 0.25)
const SPARK_AMOUNT: int = 11
const PULSE_SCALE: float = 1.04
const PULSE_SEC: float = 0.12
const POINTER_MOUSE: int = -1
const NO_POINTER: int = -2
const HINT_ID: String = "hint"
const HINT_LOOPS: int = 3
const HINT_PULSE_TIME: float = 0.3
const HINT_COLOR: Color = Color(1.0, 0.95, 0.4, 1.0)
const SFX := preload("res://scripts/fx/SfxGenerator.gd")

var misses: int = 0
## id предмета сессии, задаётся Main до добавления сцены в дерево.
var item_id: String = ""
## Полная картинка предмета: полупрозрачный силуэт-ориентир.
var item_texture: Texture2D

@onready var progress_bar: ProgressBar = $TopBar/Progress
@onready var _work_area: Control = $WorkMargin/WorkArea
@onready var _slot_layer: Control = $WorkMargin/WorkArea/SlotLayer
@onready var _piece_layer: Control = $WorkMargin/WorkArea/PieceLayer

var _shards: Array[Dictionary] = []
var _pieces: Array[TextureRect] = []
var _slots: Array[ColorRect] = []
var _silhouette: TextureRect = null
var _board_side: float = 0.0
var _board_pos: Vector2 = Vector2.ZERO
var _home_pos: Array[Vector2] = []
var _home_size: Array[Vector2] = []
var _placed_pos: Array[Vector2] = []
var _placed_size: Array[Vector2] = []
var _target_center: Array[Vector2] = []
var _placed: Array[bool] = []
var _busy: Array[bool] = []
var _placed_count: int = 0
var _finished: bool = false
var _active_pointer: int = NO_POINTER
var _dragged: TextureRect = null
var _grab_offset: Vector2 = Vector2.ZERO
var _hint_index: int = -1
var _hint_tween: Tween = null

func _enter_tree() -> void:
	var back: Button = $TopBar/BtnBack
	if not back.pressed.is_connected(_on_back_pressed):
		back.pressed.connect(_on_back_pressed)
	var area: Control = $WorkMargin/WorkArea
	if not area.resized.is_connected(_layout):
		area.resized.connect(_layout)

func _exit_tree() -> void:
	var back: Button = $TopBar/BtnBack
	if back.pressed.is_connected(_on_back_pressed):
		back.pressed.disconnect(_on_back_pressed)
	var area: Control = $WorkMargin/WorkArea
	if area.resized.is_connected(_layout):
		area.resized.disconnect(_layout)
	for piece: TextureRect in _pieces:
		var cb := _on_piece_gui_input.bind(piece)
		if piece.gui_input.is_connected(cb):
			piece.gui_input.disconnect(cb)

func _ready() -> void:
	_shards = ShardCatalog.load_shards(item_id)
	if _shards.is_empty():
		_finished = true
		set_process_input(false)
		call_deferred("_emit_finished")
		return
	_add_silhouette()
	_build_pieces()
	_layout()
	if GameData.use_consumable(HINT_ID):
		_show_hint()

## Силуэт предмета в квадратной доске: ориентир, куда ставить осколки.
func _add_silhouette() -> void:
	_silhouette = TextureRect.new()
	_silhouette.texture = item_texture
	_silhouette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_silhouette.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_silhouette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_silhouette.modulate = Color(SILHOUETTE_TINT, SILHOUETTE_ALPHA)
	_work_area.add_child(_silhouette)
	_work_area.move_child(_silhouette, 0)

## Подсветка следующей неустановленной детали (3 пульса), одна подсказка = одна деталь.
func _show_hint() -> void:
	for i in range(_pieces.size()):
		if not _placed[i]:
			_hint_index = i
			_hint_tween = _pieces[i].create_tween()
			_hint_tween.set_loops(HINT_LOOPS)
			_hint_tween.tween_property(_pieces[i], "modulate", HINT_COLOR, HINT_PULSE_TIME)
			_hint_tween.tween_property(_pieces[i], "modulate", Color.WHITE, HINT_PULSE_TIME)
			return

func _stop_hint() -> void:
	if _hint_tween != null:
		_hint_tween.kill()
		_hint_tween = null
	if _hint_index >= 0:
		_pieces[_hint_index].modulate = Color.WHITE
		_hint_index = -1

func _build_pieces() -> void:
	for i in range(_shards.size()):
		var slot := ColorRect.new()
		slot.color = Color(1.0, 1.0, 1.0, SLOT_ALPHA)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_slot_layer.add_child(slot)
		_slots.append(slot)

		var piece := TextureRect.new()
		piece.texture = _shards[i]["texture"] as Texture2D
		piece.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		piece.stretch_mode = TextureRect.STRETCH_SCALE
		piece.mouse_filter = Control.MOUSE_FILTER_STOP
		_piece_layer.add_child(piece)
		_pieces.append(piece)
		piece.gui_input.connect(_on_piece_gui_input.bind(piece))

		_home_pos.append(Vector2.ZERO)
		_home_size.append(Vector2.ZERO)
		_placed_pos.append(Vector2.ZERO)
		_placed_size.append(Vector2.ZERO)
		_target_center.append(Vector2.ZERO)
		_placed.append(false)
		_busy.append(false)

## Доска — квадрат в верхней части WorkArea; осколки в лотке (нижние 30%).
## Слот i — квадрант i доски, осколок встаёт в позицию: доска + offset × (сторона / SHEET_SIZE).
func _layout() -> void:
	if _pieces.is_empty():
		return
	var w: float = _work_area.size.x
	var h: float = _work_area.size.y
	if w <= 0.0 or h <= 0.0:
		return
	var top_h: float = TRAY_TOP_RATIO * h
	_board_side = BOARD_FIT * minf(w, top_h)
	_board_pos = Vector2((w - _board_side) * 0.5, (top_h - _board_side) * 0.5)
	var half: float = _board_side * 0.5
	var placed_scale: float = _board_side / float(ShardCatalog.SHEET_SIZE)
	if _silhouette != null:
		_silhouette.position = _board_pos
		_silhouette.size = Vector2(_board_side, _board_side)
		_silhouette.pivot_offset = _silhouette.size * 0.5
	var tray_cell := Vector2(w / float(_pieces.size()), h - top_h)
	for i in range(_pieces.size()):
		var col: int = i % 2
		var row: int = i / 2
		var quad_origin := Vector2(col, row) * float(ShardCatalog.QUAD)
		var tex_size: Vector2 = (_shards[i]["texture"] as Texture2D).get_size()

		var slot: ColorRect = _slots[i]
		slot.position = _board_pos + Vector2(col, row) * half
		slot.size = Vector2(half, half)

		_placed_size[i] = tex_size * placed_scale
		_placed_pos[i] = _board_pos + (quad_origin + (_shards[i]["offset"] as Vector2)) * placed_scale
		_target_center[i] = _placed_pos[i] + _placed_size[i] * 0.5

		var fit: float = minf(tray_cell.x, tray_cell.y) * TRAY_FIT_RATIO / maxf(tex_size.x, tex_size.y)
		var tray_scale: float = minf(placed_scale * TRAY_SCALE_RATIO, fit)
		_home_size[i] = tex_size * tray_scale
		_home_pos[i] = Vector2(tray_cell.x * (float(i) + 0.5) - _home_size[i].x * 0.5, top_h + (tray_cell.y - _home_size[i].y) * 0.5)

		var piece: TextureRect = _pieces[i]
		if _placed[i]:
			piece.position = _placed_pos[i]
			piece.size = _placed_size[i]
		elif piece != _dragged and not _busy[i]:
			piece.position = _home_pos[i]
			piece.size = _home_size[i]
		piece.pivot_offset = piece.size * 0.5

func _on_piece_gui_input(event: InputEvent, piece: TextureRect) -> void:
	if _finished or _dragged != null or _active_pointer != NO_POINTER:
		return
	var idx: int = _pieces.find(piece)
	if _placed[idx] or _busy[idx]:
		return
	var mouse_event := event as InputEventMouseButton
	var touch_event := event as InputEventScreenTouch
	var pointer: int = NO_POINTER
	var local_pos: Vector2 = Vector2.ZERO
	if mouse_event != null and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		pointer = POINTER_MOUSE
		local_pos = mouse_event.position
	elif touch_event != null and touch_event.pressed:
		pointer = touch_event.index
		local_pos = touch_event.position
	else:
		return
	_active_pointer = pointer
	_dragged = piece
	_grab_offset = local_pos
	piece.move_to_front()
	piece.pivot_offset = piece.size * 0.5
	piece.create_tween().tween_property(piece, "scale", Vector2.ONE * PICKUP_SCALE, PICKUP_SEC)
	piece.accept_event()

func _input(event: InputEvent) -> void:
	if _dragged == null:
		return
	var motion := event as InputEventMouseMotion
	var drag := event as InputEventScreenDrag
	var mouse_button := event as InputEventMouseButton
	var touch := event as InputEventScreenTouch
	if motion != null and _active_pointer == POINTER_MOUSE:
		if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			_end_drag()
			return
		_drag_to(motion.position)
	elif drag != null and drag.index == _active_pointer:
		_drag_to(drag.position)
	elif mouse_button != null and _active_pointer == POINTER_MOUSE and mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
		_drag_to(mouse_button.position)
		_end_drag()
	elif touch != null and touch.index == _active_pointer and not touch.pressed:
		_drag_to(touch.position)
		_end_drag()

func _drag_to(pointer: Vector2) -> void:
	_dragged.position = _to_layer_local(pointer) - _grab_offset

func _to_layer_local(pointer: Vector2) -> Vector2:
	return _piece_layer.get_global_transform_with_canvas().affine_inverse() * pointer

func _end_drag() -> void:
	var piece: TextureRect = _dragged
	var idx: int = _pieces.find(piece)
	_dragged = null
	_active_pointer = NO_POINTER
	var center: Vector2 = piece.position + piece.size * 0.5
	var snap_ratio: float = SNAP_RATIO * (1.3 if GameData.has_upgrade("precise_assembly") else 1.0)
	var snap_radius: float = snap_ratio * _board_side
	if center.distance_to(_target_center[idx]) <= snap_radius:
		_snap(idx)
	else:
		_return_home(idx)

func _snap(idx: int) -> void:
	if idx == _hint_index:
		_stop_hint()
	var piece: TextureRect = _pieces[idx]
	_placed[idx] = true
	_slots[idx].visible = false
	piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
	piece.pivot_offset = _placed_size[idx] * 0.5
	var tween := piece.create_tween()
	tween.set_parallel(true)
	tween.tween_property(piece, "position", _placed_pos[idx], SNAP_ANIM_TIME)
	tween.tween_property(piece, "size", _placed_size[idx], SNAP_ANIM_TIME)
	tween.tween_property(piece, "scale", Vector2.ONE, SNAP_ANIM_TIME)

	_placed_count += 1
	progress_bar.value = float(_placed_count) / float(_pieces.size())
	SFX.play("latch")
	SFX.vibrate(15)
	ClearParticles.burst(_piece_layer, _target_center[idx], SPARK_COLOR, SPARK_AMOUNT)
	if _placed_count == _pieces.size():
		_complete()

func _return_home(idx: int) -> void:
	misses += 1
	_busy[idx] = true
	var piece: TextureRect = _pieces[idx]
	var tween := piece.create_tween()
	tween.set_parallel(true)
	tween.tween_property(piece, "position", _home_pos[idx], RETURN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(piece, "scale", Vector2.ONE, RETURN_TIME)
	tween.chain().tween_callback(func() -> void: _busy[idx] = false)

func _complete() -> void:
	if _finished:
		return
	_finished = true
	set_process_input(false)
	SFX.play("complete")
	SFX.vibrate(40)
	if _silhouette == null:
		call_deferred("_emit_finished")
		return
	var pulse := _silhouette.create_tween()
	pulse.tween_property(_silhouette, "scale", Vector2.ONE * PULSE_SCALE, PULSE_SEC)
	pulse.tween_property(_silhouette, "scale", Vector2.ONE, PULSE_SEC)
	pulse.tween_callback(func() -> void: call_deferred("_emit_finished"))

func _emit_finished() -> void:
	stage_finished.emit(1.0)

func _on_back_pressed() -> void:
	back_requested.emit()
