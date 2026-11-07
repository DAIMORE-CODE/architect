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
signal back_requested

@onready var dirt_texture_rect: TextureRect = $WorkMargin/WorkArea/DirtLayer
@onready var progress_bar: ProgressBar = $TopBar/Progress
@onready var btn_back: Button = $TopBar/BtnBack

var dirt_image: Image            # рабочий дубликат изображения грязи
var dirt_texture: ImageTexture   # собственная текстура для DirtLayer
var is_erasing: bool = false
var brush_size: float = 40.0
var total_pixels: int = 0        # пиксели грязи при старте (знаменатель прогресса)
var dirt_left: int = 0           # оставшиеся пиксели грязи (уменьшается при стирании)

## Порог завершения этапа (95% по D-013).
const COMPLETE_THRESHOLD: float = 0.95
## Шаг растеризации следа кисти (меньше диаметра — сплошной след на свайпах).
const DITHER_STEP_RATIO: float = 0.6
## Батч-обновление GPU-текстуры: не чаще одного раза в этот интервал (~30 Гц).
const TEXTURE_UPDATE_INTERVAL: float = 1.0 / 30.0
## Интервал честного пересчёта прогресса (Timer), сек.
const PROGRESS_RECOUNT_INTERVAL: float = 0.5
## Прозрачный цвет для стирания альфа-канала.
const TRANSPARENT := Color(0, 0, 0, 0)
## Частицы стирания: не чаще одного всплеска в этот интервал, сек.
const BURST_INTERVAL: float = 0.08
const BURST_COLOR := Color(0.45, 0.35, 0.25)
const SFX := preload("res://scripts/fx/SfxGenerator.gd")
const FX := preload("res://scripts/fx/ClearParticles.gd")
## Звук скрэба: не чаще одного проигрывания в этот интервал, сек.
const SCRAPE_INTERVAL: float = 0.12
## Грязный слой строится из арта предмета: по большой стороне не больше этого размера.
const DIRT_MAX_SIDE: int = 256
const GRIME_COLOR := Color(0.32, 0.24, 0.16)
const GRIME_MIX: float = 0.7
const GRIME_NOISE: float = 0.05

## Арт текущего предмета сессии, задаётся Main до добавления сцены в дерево.
var item_texture: Texture2D

const EASY_CLEAR_CHANCE: float = 0.2
var easy_mode: bool = false
var _tex_dirty := false
var _last_update_time: float = -100.0
var _finished: bool = false
var _last_erase_pos: Vector2 = Vector2.INF  # в пикселях изображения
var _progress_timer: Timer
var _last_burst_time: float = -100.0
var _last_scrape_time: float = -100.0
var _erased_this_frame: bool = false
var _scrape_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer

func _ready() -> void:
	btn_back.pressed.connect(_on_back_pressed)
	_scrape_player = AudioStreamPlayer.new()
	_scrape_player.stream = SFX.get_stream("scrape")
	_scrape_player.bus = SFX.BUS_NAME
	add_child(_scrape_player)
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = SFX.BUS_NAME
	add_child(_sfx_player)
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
	if item_texture != null:
		($WorkMargin/WorkArea/ItemClean as TextureRect).texture = item_texture
		dirt_image = _make_dirt_from_item(item_texture)
	else:
		var source := dirt_texture_rect.texture
		if source == null:
			push_error("CleanStage: у DirtLayer отсутствует текстура")
			return
		# get_image() возвращает копию — исходный импорт не мутируется.
		dirt_image = _to_rgba(source.get_image())
		total_pixels = 0
		for y in range(dirt_image.get_height()):
			for x in range(dirt_image.get_width()):
				if dirt_image.get_pixel(x, y).a > 0.0:
					total_pixels += 1
	if dirt_image == null:
		push_error("CleanStage: не удалось получить Image из текстуры грязи")
		return
	if total_pixels <= 0:
		push_error("CleanStage: слой грязи пуст — прогресс не рассчитывается")
		total_pixels = 1
	dirt_left = total_pixels
	# Создаём СОБСТВЕННУЮ ImageTexture: update() допустим только на ней,
	# но не на импортированной CompressedTexture2D.
	dirt_texture = ImageTexture.create_from_image(dirt_image)
	dirt_texture_rect.texture = dirt_texture

func _to_rgba(img: Image) -> Image:
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img

## Грязь = арт предмета (фон уже вырезан в ItemArt), подкрашенный в цвет налёта с шумом.
## Подсчёт непрозрачных пикселей идёт в том же проходе, что и подкраска.
func _make_dirt_from_item(tex: Texture2D) -> Image:
	var img := _to_rgba(tex.get_image())
	if img == null:
		return null
	var longest := maxi(img.get_width(), img.get_height())
	if longest > DIRT_MAX_SIDE:
		var k := float(DIRT_MAX_SIDE) / float(longest)
		img.resize(roundi(img.get_width() * k), roundi(img.get_height() * k), Image.INTERPOLATE_BILINEAR)
	total_pixels = 0
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			if easy_mode and randf() < EASY_CLEAR_CHANCE:
				img.set_pixel(x, y, Color(c.r, c.g, c.b, 0.0))
				continue
			total_pixels += 1
			var n := randf_range(-GRIME_NOISE, GRIME_NOISE)
			var grime := Color(GRIME_COLOR.r + n, GRIME_COLOR.g + n, GRIME_COLOR.b + n, 1.0)
			var rgb := c.lerp(grime, GRIME_MIX)
			img.set_pixel(x, y, Color(rgb.r, rgb.g, rgb.b, c.a))
	return img

func _process(_delta: float) -> void:
	if _erased_this_frame:
		_erased_this_frame = false
		_try_play_scrape()
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
	# Мышь (ПК): press/release; motion — свайп курсором С УДЕРЖАНИЕМ ЛКМ.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_erasing = event.pressed
		_last_erase_pos = Vector2.INF
		if event.pressed:
			_apply_brush(event.global_position)
		return
	if event is InputEventMouseMotion:
		# Без удержания ЛКМ курсор не должен стирать (иначе грязь пропадает «сама»).
		if is_erasing:
			_apply_brush(event.global_position)
		return
	# Тач (мобильные): касание + драги.
	if event is InputEventScreenTouch:
		is_erasing = event.pressed
		_last_erase_pos = Vector2.INF
		if event.pressed:
			_apply_brush(event.position)
		return
	if event is InputEventScreenDrag:
		_apply_brush(event.position)

func _apply_brush(global_pos: Vector2) -> void:
	if dirt_image == null or _finished:
		return
	# Локальные координаты относительно DirtLayer (TextureRect, stretch = Scale).
	var local_pos: Vector2 = dirt_texture_rect.get_global_transform().affine_inverse() * global_pos
	var rect_size: Vector2 = dirt_texture_rect.size
	if local_pos.x < 0.0 or local_pos.y < 0.0 or local_pos.x > rect_size.x or local_pos.y > rect_size.y:
		return
	# Переводим координаты в пиксели изображения и размер кисти — тоже в пиксели.
	var scale_x: float = float(dirt_image.get_width()) / rect_size.x
	var scale_y: float = float(dirt_image.get_height()) / rect_size.y
	var img_pos := Vector2(local_pos.x * scale_x, local_pos.y * scale_y)
	var img_radius: float = brush_size * (scale_x + scale_y) * 0.5 * (1.25 if GameData.has_upgrade("soft_brush") else 1.0)
	# Интерполяция между предыдущей и текущей точкой — непрерывный след на свайпах.
	var has_last: bool = _last_erase_pos.is_finite()
	var dist: float = img_pos.distance_to(_last_erase_pos) if has_last else 0.0
	var step: float = maxf(img_radius * DITHER_STEP_RATIO, 2.0)
	if dist > step:
		var steps: int = int(dist / step) + 1
		for i in range(1, steps + 1):
			_erase_circle(_last_erase_pos.lerp(img_pos, float(i) / float(steps)), img_radius)
	else:
		_erase_circle(img_pos, img_radius)
	_last_erase_pos = img_pos

func _erase_circle(center: Vector2, radius: float) -> void:
	var cx: int = int(center.x)
	var cy: int = int(center.y)
	var r: int = maxi(int(radius), 1)
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
				dirt_left -= 1
				erased_any = true
	if erased_any:
		_tex_dirty = true
		_erased_this_frame = true
		var now: float = Time.get_ticks_msec() / 1000.0
		if now - _last_burst_time >= BURST_INTERVAL:
			_last_burst_time = now
			var px_to_rect := Vector2(dirt_texture_rect.size.x / float(dirt_image.get_width()), dirt_texture_rect.size.y / float(dirt_image.get_height()))
			FX.burst(dirt_texture_rect, center * px_to_rect, BURST_COLOR)

func _try_play_scrape() -> void:
	if not is_erasing or _finished or _scrape_player.stream == null:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_scrape_time >= SCRAPE_INTERVAL:
		_last_scrape_time = now
		_scrape_player.play()

func _recount_progress() -> void:
	if _finished or dirt_image == null:
		return
	# Прогресс = доля стёртых пикселей от исходного количества грязи.
	var progress: float = clampf(1.0 - float(dirt_left) / float(total_pixels), 0.0, 1.0)
	progress_bar.value = progress
	if progress >= COMPLETE_THRESHOLD:
		_finish_stage(progress)

func _finish_stage(progress: float) -> void:
	_finished = true
	is_erasing = false
	set_process_input(false)
	_progress_timer.stop()
	_scrape_player.stop()
	_sfx_player.stream = SFX.get_stream("complete")
	_sfx_player.play()
	SFX.vibrate(40)
	stage_finished.emit(progress)

func _exit_tree() -> void:
	_stop_sounds()

func _stop_sounds() -> void:
	if _scrape_player != null:
		_scrape_player.stop()
	if _sfx_player != null:
		_sfx_player.stop()

func _on_back_pressed() -> void:
	_stop_sounds()
	back_requested.emit()
