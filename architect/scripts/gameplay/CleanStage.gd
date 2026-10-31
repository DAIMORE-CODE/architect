extends Control
## CleanStage — мини-игра «Очистка» (Шаг 3, ядро MVP).
## Игрок ЗАЖИМАЕТ ЛКМ и водит мышью по слою грязи — грязь стирается.
## КЛЮЧЕВОЕ РЕШЕНИЕ (баг «грязь не стирается визуально»):
##  TextureRect c stretch_mode=SCALE НЕ совпадает с размером изображения,
##  поэтому вместо него используется Sprite2D c centered=false и scale =
##  размер_узла / размер_картинки. Тогда трансформация текстуры точно
##  совпадает с расчётом координат кисти: local -> image = local * inv_scale.
## Прогресс — простой счётчик _brush_hits / TARGET_HITS (без попиксельных
## подсчётов, дававших clean > total и мгновенные 100%).

signal stage_finished(progress: float)

@onready var dirt_sprite: Sprite2D = $WorkMargin/WorkArea/DirtLayer
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
	dirt_sprite.scale = Vector2.ONE
	# Создаём СОБСТВЕННУЮ ImageTexture: update() нельзя вызывать на
	# импортированной CompressedTexture2D (иначе рантайм-ошибка).
	var original_image: Image = dirt_sprite.texture.get_image()
	if original_image == null:
		push_error("CleanStage: не удалось получить Image из текстуры грязи")
		return
	original_image.decompress()
	if original_image.get_format() != Image.FORMAT_RGBA8:
		original_image.convert(Image.FORMAT_RGBA8)
	var new_texture := ImageTexture.create_from_image(original_image)
	dirt_sprite.texture = new_texture
	dirt_image = original_image
	# Масштаб = размер узла / размер изображения: картинка пиксель-в-пиксель
	# ложится на область DirtLayer, координаты мыши переводятся точно.
	var node_size := dirt_sprite.get_parent().size
	dirt_sprite.scale = Vector2(node_size.x / float(dirt_image.get_width()),
		node_size.y / float(dirt_image.get_height()))
	print("[DEBUG] CleanStage: слой грязи готов, image=%dx%d, scale=%s" % [
		dirt_image.get_width(), dirt_image.get_height(), str(dirt_sprite.scale)])

func _process(_delta: float) -> void:
	if _tex_dirty:
		dirt_sprite.texture.update(dirt_image)
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
			var local_pos: Vector2 = dirt_sprite.to_local(event.global_position)
			_apply_brush(local_pos)
		return
	# Клик ЛКМ — начать стирание (первая точка без интерполяции линии).
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var press_pos: Vector2 = dirt_sprite.to_local(event.global_position)
			_last_brush_pos = Vector2i(-999999, -999999)
			_apply_brush(press_pos)
		else:
			_last_brush_pos = Vector2i(-999999, -999999)
		return
	# Тач (Android/web): касание + драги.
	if event is InputEventScreenTouch:
		_last_brush_pos = Vector2i(-999999, -999999)
		if event.pressed:
			_apply_brush(dirt_sprite.to_local(event.position))
		return
	if event is InputEventScreenDrag:
		_apply_brush(dirt_sprite.to_local(event.position))

func _apply_brush(sprite_pos: Vector2) -> void:
	if dirt_image == null:
		return
	# sprite_pos (локальные координаты Sprite2D) -> пиксели изображения.
	var img_w: int = dirt_image.get_width()
	var img_h: int = dirt_image.get_height()
	var ix: int = int(sprite_pos.x * float(img_w) / dirt_sprite.size.x)
	var iy: int = int(sprite_pos.y * float(img_h) / dirt_sprite.size.y)
	if ix < 0 or iy < 0 or ix >= img_w or iy >= img_h:
		return
	var center := Vector2i(ix, iy)
	# Интерполяция между точками свайпа — непрерывный след без «дырок».
	if _last_brush_pos != Vector2i(-999999, -999999):
		_draw_line_bresenham(_last_brush_pos, center)
	else:
		_stamp_circle(center)
	_last_brush_pos = center
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
		_stamp_circle(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy

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

func _finish_stage(progress: float) -> void:
	_finished = true
	set_process_input(false)
	print("[STUB] Очистка завершена на 85%+. Переход к следующему этапу")
	stage_finished.emit(progress)

func _on_back_pressed() -> void:
	get_tree().reload_current_scene()
