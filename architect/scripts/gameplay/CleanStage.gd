extends Control
## CleanStage — мини-игра «Очистка» (Шаг 3, ядро MVP).
## Игрок водит пальцем/мышью по слою грязи и «стирает» её.
## ФИНАЛЬНАЯ РЕАЛИЗАЦИЯ (по вердикту ревью + тесту пользователя):
##  1) Собственная ImageTexture через create_from_image() — update() НЕ вызывается
##     на импортированной CompressedTexture2D (иначе рантайм-ошибка и зависание).
##  2) Стирание ТОЛЬКО при зажатой ЛКМ (button_mask & MOUSE_BUTTON_MASK_LEFT)
##     или при активном тач-касании. Мышь без клика не стирает.
##  3) Прогресс — простой MVP-счётчик: _brush_hits / TARGET_HITS (без попиксельных
##     вычислений, которые давали clean > total и мгновенные 100%).
##  4) Обновление текстуры батчем в _process() по флагу _tex_dirty.
##  5) Координаты: dirt_texture_rect.to_local(event.global_position) — корректно
##     работает при stretch mode = canvas_items.

signal stage_finished(progress: float)

@onready var dirt_texture_rect: TextureRect = $WorkMargin/WorkArea/DirtLayer
@onready var progress_bar: ProgressBar = $TopBar/Progress
@onready var btn_back: Button = $TopBar/BtnBack

var dirt_image: Image            # рабочий дубликат изображения грязи
var brush_size: float = 40.0
var total_pixels: int = 0        # диагностика: пиксели грязи при старте
var clean_pixels: int = 0        # диагностика: стёртые пиксели

## Порог завершения этапа (85% по ТЗ).
const COMPLETE_THRESHOLD: float = 0.85
## Целевое число успешных движений кисти для прогресса 1.0 (MVP-счётчик).
const TARGET_HITS: int = 50
## Прозрачный цвет для стирания альфа-канала.
const TRANSPARENT := Color(0, 0, 0, 0)

var _tex_dirty := false
var _finished := false
var _brush_hits := 0
var _last_brush_pos := Vector2.INF
var _touch_active := false

func _ready() -> void:
	print("[DEBUG] CleanStage: _ready(), инициализация слоя грязи")
	btn_back.pressed.connect(_on_back_pressed)
	progress_bar.value = 0.0
	progress_bar.max_value = 1.0
	# Создаём СОБСТВЕННУЮ ImageTexture для модификации (БАГ 1).
	var original_image: Image = dirt_texture_rect.texture.get_image()
	if original_image == null:
		push_error("CleanStage: не удалось получить Image из текстуры грязи")
		return
	if original_image.is_compressed():
		original_image.decompress()
	if original_image.get_format() != Image.FORMAT_RGBA8:
		original_image.convert(Image.FORMAT_RGBA8)
	var new_texture := ImageTexture.create_from_image(original_image)
	dirt_texture_rect.texture = new_texture
	dirt_image = original_image
	total_pixels = 0
	for x in range(dirt_image.get_width()):
		for y in range(dirt_image.get_height()):
			if dirt_image.get_pixel(x, y).a > 0.1:
				total_pixels += 1
	print("[DEBUG] CleanStage: слой грязи готов, total_pixels=", total_pixels)

func _process(_delta: float) -> void:
	# Батчим обновление GPU-текстуры только когда есть изменения (БАГ 1 fix).
	if _tex_dirty and dirt_image != null:
		print("CleanStage: обновление текстуры, _tex_dirty = ", _tex_dirty)
		dirt_texture_rect.texture.update(dirt_image)
		_tex_dirty = false
	# Прогресс: простой счётчик стираний (БАГ 3 fix).
	var progress: float = clampf(float(_brush_hits) / float(TARGET_HITS), 0.0, 1.0)
	progress_bar.value = progress
	if progress >= COMPLETE_THRESHOLD and not _finished:
		_finish_stage(progress)

func _input(event: InputEvent) -> void:
	if _finished:
		return
	print("CleanStage: _input вызван, event = ", event.as_text())
	# Мышь: движение С ЗАЖАТОЙ ЛКМ (БАГ 2 fix).
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_apply_brush(event.global_position)
		return
	# Клик мыши: начать/закончить стирание, сброс линии-интерполяции.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_last_brush_pos = Vector2.INF
		if event.pressed:
			_apply_brush(event.global_position)
		return
	# Тач (мобильные/web): касание + драги.
	if event is InputEventScreenTouch:
		_touch_active = event.pressed
		_last_brush_pos = Vector2.INF
		if event.pressed:
			_apply_brush(event.position)
		return
	if event is InputEventScreenDrag and _touch_active:
		_apply_brush(event.position)

func _apply_brush(global_pos: Vector2) -> void:
	# Конвертация глобальных координат в локальные DirtLayer (to_local учитывает
	# трансформы предков и stretch canvas_items).
	var local_pos: Vector2 = dirt_texture_rect.to_local(global_pos)
	print("CleanStage: стирание в точке ", local_pos)
	if dirt_image == null:
		return
	var img_w: int = dirt_image.get_width()
	var img_h: int = dirt_image.get_height()
	# TextureRect stretch_mode=KEEP_ASPECT_CENTERED может оставлять поля —
	# проверяем попадание в границы узла, а затем клампим в границы изображения.
	if local_pos.x < 0.0 or local_pos.y < 0.0 or local_pos.x >= float(img_w) or local_pos.y >= float(img_h):
		return
	# Интерполяция между точками свайпа — непрерывный след без «дырок».
	var center := Vector2i(int(local_pos.x), int(local_pos.y))
	if _last_brush_pos != Vector2.INF:
		_draw_line_bresenham(Vector2i(int(_last_brush_pos.x), int(_last_brush_pos.y)), center)
	else:
		_draw_circle(center)
	_last_brush_pos = local_pos
	_brush_hits += 1
	_tex_dirty = true

func _draw_line_bresenham(start: Vector2i, end: Vector2i) -> void:
	var x0 := start.x
	var y0 := start.y
	var x1 := end.x
	var y1 := end.y
	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx - dy
	while true:
		_draw_circle(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy

func _draw_circle(center: Vector2i) -> void:
	var r := int(brush_size)
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
						clean_pixels += 1

func _finish_stage(progress: float) -> void:
	_finished = true
	set_process_input(false)
	print("[STUB] Очистка завершена на 85%+. Переход к следующему этапу")
	stage_finished.emit(progress)

func _on_back_pressed() -> void:
	get_tree().reload_current_scene()
