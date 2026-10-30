extends Control
## CleanStage — мини-игра «Очистка» (Шаг 3, ядро MVP).
## Игрок водит пальцем/мышью по слою грязи и «стирает» её.
## Исправления ревью Шага 3:
##  1) КРИТИЧНО: собственная ImageTexture через ImageTexture.create_from_image()
##     + работа с дубликатом Image. Вызов texture.update() на импортированной
##     CompressedTexture2D приводил к ошибке рантайма и зависанию прогресса.
##  2) Обновление текстуры батчем в _process, не чаще 30 Гц (_tex_dirty + троттлинг).
##  3) Обработка InputEventMouseMotion — свайпы мышью тоже стирают.
##  4) Честный подсчёт стёртых пикселей: прогресс = очищенная площадь / площадь
##     грязи, пересчёт раз в 0.5 с через Timer (не каждый кадр).

signal stage_finished(progress: float)

@onready var dirt_texture_rect: TextureRect = $WorkMargin/WorkArea/DirtLayer
@onready var progress_bar: ProgressBar = $TopBar/Progress
@onready var btn_back: Button = $TopBar/BtnBack

var dirt_image: Image            # рабочий дубликат изображения грязи
var dirt_texture: ImageTexture   # собственная текстура для DirtLayer
var is_erasing: bool = false
var brush_size: float = 40.0
var total_pixels: int = 0        # пиксели грязи при старте (знаменатель прогресса)
var clean_pixels: int = 0        # уже стёртые пиксели

## Порог завершения этапа (85% по ТЗ).
const COMPLETE_THRESHOLD: float = 0.85
## Шаг растеризации следа кисти (меньше диаметра — сплошной след на свайпах).
const DITHER_STEP_RATIO: float = 0.6
## Батч-обновление GPU-текстуры: не чаще одного раза в этот интервал (~30 Гц).
const TEXTURE_UPDATE_INTERVAL: float = 1.0 / 30.0
## Интервал честного пересчёта прогресса (Timer), сек.
const PROGRESS_RECOUNT_INTERVAL: float = 0.5
## Прозрачный цвет для стирания альфа-канала.
const TRANSPARENT := Color(0, 0, 0, 0)

var _tex_dirty := false
var _last_update_time: float = -100.0
var _finished: bool = false
var _last_erase_pos: Vector2 = Vector2.INF
var _progress_timer: Timer

func _ready() -> void:
	btn_back.pressed.connect(_on_back_pressed)
	_init_dirt_layer()
	progress_bar.value = 0.0
	# Пересчёт прогресса раз в 0.5 с — не убиваем FPS на мобильных.
	_progress_timer = Timer.new()
	_progress_timer.wait_time = PROGRESS_RECOUNT_INTERVAL
	_progress_timer.one_shot = false
	_progress_timer.autostart = true
	_progress_timer.timeout.connect(_recount_progress)
	add_child(_progress_timer)

func _init_dirt_layer() -> void:
	var source := dirt_texture_rect.texture
	if source == null:
		push_error("CleanStage: у DirtLayer отсутствует текстура")
		return
	# get_image() возвращает копию — исходный импорт не мутируется.
	dirt_image = source.get_image()
	if dirt_image == null:
		push_error("CleanStage: не удалось получить Image из текстуры грязи")
		return
	if dirt_image.is_compressed():
		dirt_image.decompress()
	if dirt_image.get_format() != Image.FORMAT_RGBA8:
		dirt_image.convert(Image.FORMAT_RGBA8)
	total_pixels = 0
	for y in range(dirt_image.get_height()):
		for x in range(dirt_image.get_width()):
			if dirt_image.get_pixel(x, y).a > 0.0:
				total_pixels += 1
	if total_pixels <= 0:
		push_error("CleanStage: слой грязи пуст — прогресс не рассчитывается")
		total_pixels = 1
	# Создаём СОБСТВЕННУЮ ImageTexture: update() допустим только на ней,
	# но не на импортированной CompressedTexture2D.
	dirt_texture = ImageTexture.create_from_image(dirt_image)
	dirt_texture_rect.texture = dirt_texture

func _process(_delta: float) -> void:
	# Батчим обновление GPU-текстуры: максимум ~30 Гц.
	if _tex_dirty and dirt_texture != null:
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last_update_time >= TEXTURE_UPDATE_INTERVAL:
			dirt_texture.update(dirt_image)
			_tex_dirty = false
			_last_update_time = now

func _input(event: InputEvent) -> void:
	if _finished:
		return
	# Мышь (ПК): press/release; motion — свайп курсором (в т.ч. без удержания ЛКМ).
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_erasing = event.pressed
		_last_erase_pos = Vector2.INF
		if event.pressed:
			_try_erase(event.global_position)
		return
	if event is InputEventMouseMotion:
		_try_erase(event.global_position)
		return
	# Тач (мобильные): касание + драги.
	if event is InputEventScreenTouch:
		is_erasing = event.pressed
		_last_erase_pos = Vector2.INF
		if event.pressed:
			_try_erase(event.position)
		return
	if event is InputEventScreenDrag:
		_try_erase(event.position)

func _try_erase(global_pos: Vector2) -> void:
	var local_pos: Vector2 = dirt_texture_rect.get_global_transform_with_canvas().affine_inverse() * global_pos
	if not Rect2(Vector2.ZERO, dirt_texture_rect.size).has_point(local_pos):
		return
	# Интерполяция между предыдущей и текущей точкой — непрерывный след
	# даже при быстрых свайпах (мышь и тач).
	var dist: float = local_pos.distance_to(_last_erase_pos) if _last_erase_pos.x < INF * 0.5 else 0.0
	var step: float = maxf(brush_size * DITHER_STEP_RATIO, 2.0)
	if dist > step:
		var steps := int(dist / step) + 1
		for i in range(1, steps + 1):
			_erase_circle(_last_erase_pos.lerp(local_pos, float(i) / float(steps)))
	else:
		_erase_circle(local_pos)
	_last_erase_pos = local_pos

func _erase_circle(center: Vector2) -> void:
	var cx: int = int(center.x)
	var cy: int = int(center.y)
	var r: int = int(brush_size)
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
				dirt_image.set_pixel(x, y, TRANSPARENT)
				erased_any = true
	if erased_any:
		_tex_dirty = true

func _recount_progress() -> void:
	if _finished or dirt_image == null:
		return
	clean_pixels = 0
	for y in range(dirt_image.get_height()):
		for x in range(dirt_image.get_width()):
			if dirt_image.get_pixel(x, y).a <= 0.0:
				clean_pixels += 1
	var progress: float = clampf(float(clean_pixels) / float(total_pixels), 0.0, 1.0)
	progress_bar.value = progress
	if progress >= COMPLETE_THRESHOLD:
		_finish_stage(progress)

func _finish_stage(progress: float) -> void:
	_finished = true
	is_erasing = false
	set_process_input(false)
	_progress_timer.stop()
	print("[STUB] Очистка завершена на 85%+. Переход к следующему этапу")
	stage_finished.emit(progress)

func _on_back_pressed() -> void:
	# Возврат в Hub через перезагрузку корневой сцены (роутер Main.tscn).
	# Роутер уничтожает экраны перед показом новых — утечек нет.
	get_tree().reload_current_scene()
