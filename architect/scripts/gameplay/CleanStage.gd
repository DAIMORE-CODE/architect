extends Control
## CleanStage — мини-игра «Очистка» (Шаг 3, ядро MVP).
## Игрок ЗАЖИМАЕТ ЛКМ и водит мышью по слою грязи — грязь стирается.
## DirtLayer — TextureRect (имя ссылки в коде: dirt_texture_rect),
## expand_mode=IGNORE_SIZE + stretch_mode=SCALE, растянут на всю WorkArea:
## размер узла всегда совпадает с областью отрисовки картинки, поэтому
## маппинг координат клика в пиксели изображения линеен (см. _apply_brush —
## код из ТЗ ревьюера, используется ТОЧЬ-В-ТОЧЬ).
## Прогресс — попиксельный подсчёт (_recompute_total_pixels/_update_progress,
## тоже код из ТЗ ревьюера): cleaned / total, порог завершения 0.85.
## Обновление GPU-текстуры батчится в _process() по флагу _tex_dirty.

signal stage_finished(progress: float)

@onready var work_area: Control = $WorkMargin/WorkArea
@onready var dirt_texture_rect: TextureRect = $WorkMargin/WorkArea/DirtLayer
@onready var progress_bar: ProgressBar = $TopBar/Progress
@onready var btn_back: Button = $TopBar/BtnBack

## Порог завершения этапа (85% по ТЗ).
const COMPLETE_THRESHOLD: float = 0.85
## Радиус кисти в пикселях ИЗОБРАЖЕНИЯ.
const BRUSH_RADIUS: int = 24
## Прозрачный цвет для стирания альфа-канала.
const TRANSPARENT := Color(0, 0, 0, 0)
## Флаг debug-логов (перед экспортом на Яндекс — false).
const DEBUG_LOG: bool = false

var dirt_image: Image            # рабочий дубликат изображения грязи
var total_pixels: int = 0        # число непрозрачных пикселей грязи на старте
var _tex_dirty: bool = false     # флаг: обновить GPU-текстуру в _process()
var _finished: bool = false      # этап завершён, ввод заблокирован

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
	var original_image: Image = dirt_texture_rect.texture.get_image()
	if original_image == null:
		push_error("CleanStage: не удалось получить Image из текстуры грязи")
		return
	original_image.decompress()
	if original_image.get_format() != Image.FORMAT_RGBA8:
		original_image.convert(Image.FORMAT_RGBA8)
	dirt_texture_rect.texture = ImageTexture.create_from_image(original_image)
	dirt_image = original_image
	# Считаем базовое число непрозрачных пикселей грязи (для прогресса).
	_recompute_total_pixels.call_deferred()
	if DEBUG_LOG and dirt_image != null:
		print("[CleanStage] image=%dx%d total_pixels=%d" % [
			dirt_image.get_width(), dirt_image.get_height(), total_pixels])

func _process(_delta: float) -> void:
	if _tex_dirty:
		dirt_texture_rect.texture.update(dirt_image)
		_tex_dirty = false
		_update_progress()

func _input(event: InputEvent) -> void:
	if _finished:
		return
	# Стирание ТОЛЬКО при зажатой ЛКМ (никакой реакции на простое движение).
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			if _is_inside_work_area(event.global_position):
				_apply_brush(event.global_position)
		return
	# Клик ЛКМ — стереть первую точку свайпа.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _is_inside_work_area(event.global_position):
			_apply_brush(event.global_position)
		return
	# Тач (Android/web): касание + драги.
	if event is InputEventScreenTouch:
		if event.pressed and _is_inside_work_area(event.position):
			_apply_brush(event.position)
		return
	if event is InputEventScreenDrag:
		if _is_inside_work_area(event.position):
			_apply_brush(event.position)

## Guard: свайпы по фону/TopBar не должны стирать грязь «на расстоянии».
func _is_inside_work_area(global_pos: Vector2) -> bool:
	return work_area.get_global_rect().has_point(global_pos)

# ---------------------------------------------------------------------------
# 1. Исправленный маппинг координат (бьет ровно в пиксели TextureRect).
#    Код из ТЗ ревьюера — используется ТОЧЬ-В-ТОЧЬ.
# ---------------------------------------------------------------------------
func _apply_brush(global_pos: Vector2) -> void:
	if dirt_image == null:
		return
	
	# Получаем координаты относительно левого верхнего угла TextureRect.
	# В Godot 4.x у Control метода to_local() НЕТ (он есть только у Node2D);
	# use-case идентичен: make_canvas_position_local() переводит глобальную
	# позицию канваса в локальные координаты контрола.
	var local_pos = dirt_texture_rect.make_canvas_position_local(global_pos)
	
	# Защита: если клик за пределами прямоугольника, игнорируем
	if local_pos.x < 0 or local_pos.y < 0 or local_pos.x > dirt_texture_rect.size.x or local_pos.y > dirt_texture_rect.size.y:
		return
		
	var img_w = dirt_image.get_width()
	var img_h = dirt_image.get_height()
	var rect_w = dirt_texture_rect.size.x
	var rect_h = dirt_texture_rect.size.y
	
	# Масштабируем координаты клика под реальный размер изображения в пикселях
	var pixel_x = int(local_pos.x * (float(img_w) / rect_w))
	var pixel_y = int(local_pos.y * (float(img_h) / rect_h))
	
	# Рисуем кистью
	_stamp_circle(Vector2i(pixel_x, pixel_y))
	_tex_dirty = true

# ---------------------------------------------------------------------------
# 2. Исправленный подсчет пикселей (гарантированно не пустой цикл).
#    Код из ТЗ ревьюера — используется ТОЧЬ-В-ТОЧЬ.
# ---------------------------------------------------------------------------
func _recompute_total_pixels() -> void:
	total_pixels = 0
	var img_w = dirt_image.get_width()
	var img_h = dirt_image.get_height()
	for x in range(img_w):
		for y in range(img_h):
			if dirt_image.get_pixel(x, y).a > 0.1:
				total_pixels += 1

# ---------------------------------------------------------------------------
# 3. Обновление прогресса. Вызывается из _process() после стирания.
#    Код из ТЗ ревьюера + одна строка защиты от повторного вызова _finish_stage.
# ---------------------------------------------------------------------------
func _update_progress() -> void:
	if total_pixels == 0:
		return
	
	# Считаем сколько пикселей осталось
	var current_pixels = 0
	var img_w = dirt_image.get_width()
	var img_h = dirt_image.get_height()
	for x in range(img_w):
		for y in range(img_h):
			if dirt_image.get_pixel(x, y).a > 0.1:
				current_pixels += 1
				
	var cleaned = total_pixels - current_pixels
	var progress = float(cleaned) / float(total_pixels)
	progress_bar.value = clampf(progress, 0.0, 1.0)
	
	if progress >= 0.85 and not _finished:
		_finish_stage()

## Кисть: обнуляем альфу пикселей в круге радиуса BRUSH_RADIUS.
func _stamp_circle(center: Vector2i) -> void:
	var r := BRUSH_RADIUS
	var img_w := dirt_image.get_width()
	var img_h := dirt_image.get_height()
	for x in range(-r, r + 1):
		for y in range(-r, r + 1):
			if x * x + y * y <= r * r:
				var px := center.x + x
				var py := center.y + y
				if px >= 0 and px < img_w and py >= 0 and py < img_h:
					if dirt_image.get_pixel(px, py).a > 0.0:
						dirt_image.set_pixel(px, py, TRANSPARENT)

func _finish_stage() -> void:
	_finished = true
	set_process_input(false)
	print("[STUB] Очистка завершена на 85%+. Переход к следующему этапу")
	stage_finished.emit(clampf(progress_bar.value, 0.0, 1.0))

func _on_back_pressed() -> void:
	get_tree().reload_current_scene()
