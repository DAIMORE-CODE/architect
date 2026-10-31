extends Control
## CleanStage — мини-игра «Очистка» (Шаг 3, ядро MVP).
## Игрок ЗАЖИМАЕТ ЛКМ и водит мышью по слою грязи — грязь стирается.
## КЛЮЧЕВОЕ РЕШЕНИЕ (баги ревью #1/#2/#3): DirtLayer — TextureRect
## (Control-наследник, согласно AGENTS.md) с expand_mode=IGNORE_SIZE и
## stretch_mode=SCALE, растянутый на всю WorkArea. Размер узла ВСЕГДА
## совпадает с областью отрисовки картинки, поэтому перевод координат
## мыши в пиксели изображения тривиален: image = local * image_size / rect.size.
## Пересчёт выполняется при каждом resized (адаптивность при повороте экрана).
## Прогресс — счётчик _brush_hits / TARGET_HITS; инкремент только если кисть
## реально стёрла хотя бы один пиксель (защита от «50 взмахов по чистой зоне»).

signal stage_finished(progress: float)

@onready var work_area: Control = $WorkMargin/WorkArea
@onready var dirt_rect: TextureRect = $WorkMargin/WorkArea/DirtLayer
@onready var progress_bar: ProgressBar = $TopBar/Progress
@onready var btn_back: Button = $TopBar/BtnBack

## Порог завершения этапа (85% по ТЗ).
const COMPLETE_THRESHOLD: float = 0.85
## Целевое число успешных движений кисти для прогресса 1.0 (MVP-счётчик).
const TARGET_HITS: int = 50
## Радиус кисти в пикселях ИЗОБРАЖЕНИЯ.
const BRUSH_RADIUS: int = 24
## Прозрачный цвет для стирания альфа-канала.
const TRANSPARENT := Color(0, 0, 0, 0)
## Флаг debug-логов (перед экспортом на Яндекс — false).
const DEBUG_LOG: bool = false

var dirt_image: Image            # рабочий дубликат изображения грязи
var _tex_dirty: bool = false     # флаг: обновить GPU-текстуру в _process()
var _brush_hits: int = 0         # счётчик стираний для прогресса
var _finished: bool = false      # этап завершён, ввод заблокирован
var _last_brush_pos: Vector2i = Vector2i(-999999, -999999)

func _ready() -> void:
	if not btn_back.pressed.is_connected(_on_back_pressed):
		btn_back.pressed.connect(_on_back_pressed)
	progress_bar.max_value = 1.0
	progress_bar.value = 0.0
	# WorkArea пропускает мышь дальше (PASS), а DirtLayer/ItemClean стоят на STOP.
	# Ввод обрабатывается глобальным _input() этого скрипта; guard по границам
	# рабочей области (_is_inside_work_area) отсекает свайпы по фону/TopBar.
	work_area.mouse_filter = Control.MOUSE_FILTER_PASS
	# Создаём СОБСТВЕННУЮ ImageTexture: update() нельзя вызывать на
	# импортированной CompressedTexture2D (иначе рантайм-ошибка).
	var original_image: Image = dirt_rect.texture.get_image()
	if original_image == null:
		push_error("CleanStage: не удалось получить Image из текстуры грязи")
		return
	original_image.decompress()
	if original_image.get_format() != Image.FORMAT_RGBA8:
		original_image.convert(Image.FORMAT_RGBA8)
	dirt_rect.texture = ImageTexture.create_from_image(original_image)
	dirt_image = original_image
	# Адаптивность: пересчитываем раскладку слоя грязи при любом resize
	# (поворот устройства, ресайз окна, первый resize на web).
	work_area.resized.connect(_update_dirt_layout)
	# Раскладку применяем отложенно: узлы с якорями перезаписывают size ПОСЛЕ
	# _ready(), прямой вызов породил бы предупреждение Godot.
	_update_dirt_layout.call_deferred()

## Вызывается из _ready и по сигналу resized: подгоняем TextureRect
## точно под WorkArea. Координатный пересчёт в _apply_brush опирается
## на dirt_rect.size, поэтому отдельный «масштаб» хранить не нужно.
func _update_dirt_layout() -> void:
	# Привязка к родителю через якоря (не через size) — без предупреждения
	# движка и с автоматическим отслеживанием ресайза/поворота экрана.
	dirt_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	if DEBUG_LOG and dirt_image != null:
		print("[CleanStage] image=%dx%d rect=%s" % [
			dirt_image.get_width(), dirt_image.get_height(), str(dirt_rect.size)])

func _process(_delta: float) -> void:
	if _tex_dirty:
		dirt_rect.texture.update(dirt_image)
		_tex_dirty = false
	if _finished:
		return
	var progress: float = clampf(float(_brush_hits) / float(TARGET_HITS), 0.0, 1.0)
	progress_bar.value = progress
	if progress >= COMPLETE_THRESHOLD:
		_finish_stage(progress)

func _input(event: InputEvent) -> void:
	if _finished:
		return
	# Стирание ТОЛЬКО при зажатой ЛКМ (никакой реакции на простое движение).
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			if not _is_inside_work_area(event.global_position):
				return
			_apply_brush(_global_to_rect(event.global_position))
		return
	# Клик ЛКМ — начать стирание (первая точка без интерполяции линии).
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_last_brush_pos = Vector2i(-999999, -999999)
			if _is_inside_work_area(event.global_position):
				_apply_brush(_global_to_rect(event.global_position))
		else:
			_last_brush_pos = Vector2i(-999999, -999999)
		return
	# Тач (Android/web): касание + драги.
	if event is InputEventScreenTouch:
		_last_brush_pos = Vector2i(-999999, -999999)
		if event.pressed and _is_inside_work_area(event.position):
			_apply_brush(_global_to_rect(event.position))
		return
	if event is InputEventScreenDrag:
		if _is_inside_work_area(event.position):
			_apply_brush(_global_to_rect(event.position))

## Guard: свайпы по фону/TopBar не должны стирать грязь «на расстоянии».
func _is_inside_work_area(global_pos: Vector2) -> bool:
	return work_area.get_global_rect().has_point(global_pos)

## Global -> локальные координаты TextureRect (у Control-а нет to_local()).
func _global_to_rect(global_pos: Vector2) -> Vector2:
	return global_pos - dirt_rect.get_global_position()

func _apply_brush(rect_pos: Vector2) -> void:
	if dirt_image == null:
		return
	var img_w: int = dirt_image.get_width()
	var img_h: int = dirt_image.get_height()
	# Локальные координаты TextureRect -> пиксели изображения.
	# stretch_mode=SCALE гарантирует линейное соответствие rect.size <-> image.
	if dirt_rect.size.x <= 0.0 or dirt_rect.size.y <= 0.0:
		return
	var ix: int = int(rect_pos.x * float(img_w) / dirt_rect.size.x)
	var iy: int = int(rect_pos.y * float(img_h) / dirt_rect.size.y)
	if ix < 0 or iy < 0 or ix >= img_w or iy >= img_h:
		return
	var center := Vector2i(ix, iy)
	var erased_any := false
	# Интерполяция между точками свайпа — непрерывный след без «дырок».
	if _last_brush_pos != Vector2i(-999999, -999999):
		erased_any = _draw_line_bresenham(_last_brush_pos, center)
	else:
		erased_any = _stamp_circle(center)
	_last_brush_pos = center
	# Прогресс растёт только когда кисть реально что-то стёрла
	# (замок от бесконечных проходов по уже чистой зоне).
	if erased_any:
		_brush_hits += 1
		_tex_dirty = true

func _draw_line_bresenham(start: Vector2i, end: Vector2i) -> bool:
	var x0 := start.x
	var y0 := start.y
	var x1 := end.x
	var y1 := end.y
	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx - dy
	var erased_any := false
	while true:
		if _stamp_circle(Vector2i(x0, y0)):
			erased_any = true
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy
	return erased_any

func _stamp_circle(center: Vector2i) -> bool:
	var r := BRUSH_RADIUS
	var img_w := dirt_image.get_width()
	var img_h := dirt_image.get_height()
	var erased_any := false
	for x in range(-r, r + 1):
		for y in range(-r, r + 1):
			if x * x + y * y <= r * r:
				var px := center.x + x
				var py := center.y + y
				if px >= 0 and px < img_w and py >= 0 and py < img_h:
					if dirt_image.get_pixel(px, py).a > 0.0:
						dirt_image.set_pixel(px, py, TRANSPARENT)
						erased_any = true
	return erased_any

func _finish_stage(progress: float) -> void:
	_finished = true
	set_process_input(false)
	print("[STUB] Очистка завершена на 85%+. Переход к следующему этапу")
	stage_finished.emit(progress)

func _on_back_pressed() -> void:
	get_tree().reload_current_scene()
