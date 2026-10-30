extends Control
## CleanStage — мини-игра «Очистка» (Шаг 3, ядро MVP).
## Игрок водит пальцем/мышью по слою грязи и «стирает» её.
## Механика тактильная: грязь хранится в Image с альфа-каналом,
## кисть обнуляет альфа в радиусе brush_size, текстура обновляется через update().
## Прогресс для MVP — приближённый: подсчёт успешных «стираний» (erase_hits),
## полная попиксельная проверка — оптимизация позже (Timer каждые 0.5 сек).

signal stage_finished(progress: float)

@onready var dirt_texture_rect: TextureRect = $WorkArea/DirtLayer
@onready var progress_bar: ProgressBar = $TopBar/Progress
@onready var btn_back: Button = $TopBar/BtnBack

var dirt_image: Image
var is_erasing: bool = false
var brush_size: float = 40.0
var total_pixels: int = 0
var clean_pixels: int = 0

## Целевое количество «успешных стираний» для 100% прогресса.
const TARGET_HITS: int = 50
## Порог завершения этапа (85% по ТЗ).
const COMPLETE_THRESHOLD: float = 0.85
## Шаг растеризации следа кисти (меньше диаметра — сплошной след на свайпах).
const DITHER_STEP_RATIO: float = 0.6

var _erase_hits: int = 0
var _finished: bool = false
var _last_erase_pos: Vector2 = Vector2.INF

func _ready() -> void:
	# get_image() возвращает копию — исходная импорт-текстура не мутируется.
	dirt_image = dirt_texture_rect.texture.get_image()
	if dirt_image == null:
		push_error("CleanStage: у DirtLayer отсутствует текстура Image")
		return
	if dirt_image.is_compressed():
		dirt_image.decompress()
	if dirt_image.get_format() != Image.FORMAT_RGBA8:
		dirt_image.convert(Image.FORMAT_RGBA8)
	total_pixels = dirt_image.get_width() * dirt_image.get_height()
	progress_bar.value = 0.0
	btn_back.pressed.connect(_on_back_pressed)

func _input(event: InputEvent) -> void:
	if _finished:
		return
	# Мышь (ПК): press/release + motion при зажатой ЛКМ.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_erasing = event.pressed
		if event.pressed:
			_try_erase(event.global_position)
		return
	# Тач (мобильные): касание + драги.
	if event is InputEventScreenTouch:
		is_erasing = event.pressed
		if event.pressed:
			_try_erase(event.position)
		return
	if event is InputEventScreenDrag and is_erasing:
		_try_erase(event.position)

func _try_erase(global_pos: Vector2) -> void:
	var local_pos: Vector2 = dirt_texture_rect.get_global_transform_with_canvas().affine_inverse() * global_pos
	if not Rect2(Vector2.ZERO, dirt_texture_rect.size).has_point(local_pos):
		return
	# Интерполяция между предыдущей и текущей точкой — непрерывный след
	# даже при быстрых свайпах на мобильных.
	var dist: float = local_pos.distance_to(_last_erase_pos) if _last_erase_pos.x < INF * 0.5 else 0.0
	var step: float = maxf(brush_size * DITHER_STEP_RATIO, 2.0)
	if dist > step:
		var steps := int(dist / step) + 1
		for i in range(1, steps + 1):
			_erase_circle(_last_erase_pos.lerp(local_pos, float(i) / float(steps)))
	else:
		_erase_circle(local_pos)
	_last_erase_pos = local_pos
	_erase_hits += 1
	_update_progress()

func _erase_circle(center: Vector2) -> void:
	var cx: int = int(center.x)
	var cy: int = int(center.y)
	var r: int = int(brush_size)
	var transparent := Color(0, 0, 0, 0)
	var r_sq: int = r * r
	# Ограничиваем цикл границами изображения — set_pixel вне границ недопустим.
	var x0: int = maxi(cx - r, 0)
	var x1: int = mini(cx + r, dirt_image.get_width() - 1)
	var y0: int = maxi(cy - r, 0)
	var y1: int = mini(cy + r, dirt_image.get_height() - 1)
	var erased_any := false
	for y in range(y0, y1 + 1):
		var dy: int = y - cy
		for x in range(x0, x1 + 1):
			var dx: int = x - cx
			if dx * dx + dy * dy <= r_sq and dirt_image.get_pixel(x, y).a > 0.0:
				dirt_image.set_pixel(x, y, transparent)
				erased_any = true
	if erased_any:
		dirt_texture_rect.texture.update(dirt_image)

func _update_progress() -> void:
	var progress: float = minf(float(_erase_hits) / float(TARGET_HITS), 1.0)
	progress_bar.value = progress
	if progress >= COMPLETE_THRESHOLD and not _finished:
		_finish_stage(progress)

func _finish_stage(progress: float) -> void:
	_finished = true
	is_erasing = false
	set_process_input(false)
	print("[STUB] Очистка завершена на 85%+. Переход к следующему этапу")
	stage_finished.emit(progress)

func _on_back_pressed() -> void:
	# Шаг 3: возврат в Hub через перезагрузку корневой сцены (роутер Main.tscn).
	get_tree().reload_current_scene()
