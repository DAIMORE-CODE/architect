extends Control
## Main — корневая сцена-роутер экранов.
## Стартовая последовательность: notify_game_ready() (требование модерации Яндекса),
## показ HubScreen, маршрутизация Hub <-> CleanStage.
## Исправления ревью Шага 3: _clear_screen() УНИЧТОЖАЕТ предыдущий экран ДО
## подключения сигналов — нет утечки экранов при навигации Hub <-> CleanStage
## и нет двойного срабатывания stage_finished (CONNECT_ONE_SHOT).

const CLEAN_STAGE_SCENE := "res://scenes/gameplay/CleanStage.tscn"
const ASSEMBLY_STAGE_SCENE := "res://scenes/gameplay/AssemblyStage.tscn"
const POLISH_STAGE_SCENE := "res://scenes/gameplay/PolishStage.tscn"
const RESULT_SCREEN_SCENE := "res://scenes/ui/ResultScreen.tscn"
const MUSEUM_SCREEN_SCENE := "res://scenes/screens/MuseumScreen.tscn"
const SHOP_SCREEN_SCENE := "res://scenes/screens/ShopScreen.tscn"
const DAILY_REWARD_SCREEN_SCENE := "res://scenes/screens/DailyRewardScreen.tscn"
const MUSEUM_CATALOG := preload("res://scripts/data/MuseumCatalog.gd")
const HUB_SCENE := "res://scenes/screens/HubScreen.tscn"
const WORKSHOP_THEME := preload("res://scripts/ui/WorkshopTheme.gd")
const SFX := preload("res://scripts/fx/SfxGenerator.gd")
const SETTINGS_SCREEN := preload("res://scripts/screens/SettingsScreen.gd")
const RESULT_SCRIPT := preload("res://scripts/ui/ResultScreen.gd")
const BANNER_SCRIPT := preload("res://scripts/ui/SessionBanner.gd")
const SESSION_SIZE: int = 3
const EASY_ITEM_COUNT: int = 3
const CATEGORY_REWARD_COINS: int = 50
const STAGE_TITLE_FONT_SIZE: int = 36
const STAGE_TITLE_COLOR := Color(1.0, 0.965, 0.9, 1.0)
const STAGE_TITLE_OUTLINE := Color(0.2, 0.14, 0.09, 1.0)
const STAGE_TITLE_OUTLINE_SIZE: int = 6
const STAGE_TITLE_FADE: float = 0.25
const STAGE_TITLE_HOLD: float = 0.5
const TUTORIAL_CLEAN_KEY := "tutorial_clean"
const TUTORIAL_ASSEMBLY_KEY := "tutorial_assembly"
const TUTORIAL_POLISH_KEY := "tutorial_polish"
const TUTORIAL_CLEAN_TEXT := "Проведи пальцем, чтобы стереть грязь."
const TUTORIAL_ASSEMBLY_TEXT := "Перетащи осколки на нужные места. Неверный отскакивает."
const TUTORIAL_POLISH_TEXT := "Веди иглу по дыркам, чтобы заштопать ткань."
const CLEAN_FUSE_SEC: float = 30.0
const ASSEMBLY_FUSE_SEC: float = 20.0
const POLISH_FUSE_SEC: float = 15.0

var _session_items: Array[Dictionary] = []
var _session_index: int = 0
var _item_texture: Texture2D
var _item_texture_id: String = ""
var _session_coins: int = 0
var _session_stars: Array[int] = []
var _session_progress: Array[float] = []
var _fuse: StageTimer = null
var _music_player: AudioStreamPlayer = null
var _fade: ColorRect
var _fade_tween: Tween = null
const FADE_SEC: float = 0.2

@onready var status_label: Label = $CenterBox/StatusLabel
@onready var ad_test_button: Button = $CenterBox/AdTestButton

func _ready() -> void:
	# Автозагрузки (DayCycle -> GameData -> SaveManager -> YandexSDK) уже
	# инициализированы к этому моменту — порядок задан в project.godot.
	theme = WORKSHOP_THEME.build()
	SFX.setup_audio()
	_start_music()
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	add_child(_fade)
	YandexSDK.notify_game_ready()
	if status_label != null:
		status_label.visible = false
	if ad_test_button != null:
		ad_test_button.visible = false
	_route_to_hub()

func _exit_tree() -> void:
	if _music_player != null:
		_music_player.stop()

func _start_music() -> void:
	if not bool(SaveManager.get_setting("music_enabled")):
		return
	if _music_player == null:
		_music_player = AudioStreamPlayer.new()
		_music_player.stream = SFX.get_music_stream()
		_music_player.bus = SFX.MUSIC_BUS_NAME
		_music_player.volume_db = SFX.MUSIC_VOLUME_DB
		add_child(_music_player)
	_music_player.play()

func _on_music_toggled(pressed: bool) -> void:
	SFX.apply_music_enabled(pressed)
	if pressed:
		_start_music()
	elif _music_player != null:
		_music_player.stop()

func _route_to_clean() -> void:
	_session_progress.clear()
	_clear_screen()  # УНИЧТОЖАЕТ предыдущий экран ДО подключения сигнала
	var stage := _load_scene(CLEAN_STAGE_SCENE)
	if stage == null:
		return
	stage.stage_finished.connect(_on_clean_finished, CONNECT_ONE_SHOT)
	stage.back_requested.connect(_route_to_hub, CONNECT_ONE_SHOT)
	stage.item_texture = _current_item_texture()
	stage.easy_mode = _is_easy_item()
	_setup_stage_chrome(stage, CLEAN_FUSE_SEC, TUTORIAL_CLEAN_KEY, TUTORIAL_CLEAN_TEXT)
	_show_node(stage, true)

func _route_to_assembly() -> void:
	_clear_screen()
	var stage := _load_scene(ASSEMBLY_STAGE_SCENE)
	if stage == null:
		return
	stage.stage_finished.connect(_on_assembly_finished, CONNECT_ONE_SHOT)
	stage.back_requested.connect(_route_to_hub, CONNECT_ONE_SHOT)
	stage.item_texture = _current_item_texture()
	if _session_index < _session_items.size():
		stage.item_id = str(_session_items[_session_index]["id"])
	_setup_stage_chrome(stage, ASSEMBLY_FUSE_SEC, TUTORIAL_ASSEMBLY_KEY, TUTORIAL_ASSEMBLY_TEXT)
	_show_node(stage, true)

func _route_to_polish() -> void:
	_clear_screen()
	var stage := _load_scene(POLISH_STAGE_SCENE)
	if stage == null:
		return
	stage.stage_finished.connect(_on_polish_finished, CONNECT_ONE_SHOT)
	stage.back_requested.connect(_route_to_hub, CONNECT_ONE_SHOT)
	stage.easy_mode = _is_easy_item()
	_setup_stage_chrome(stage, POLISH_FUSE_SEC, TUTORIAL_POLISH_KEY, TUTORIAL_POLISH_TEXT)
	_show_node(stage, true)

func _route_to_hub() -> void:
	_clear_screen()
	var hub_scene := load(HUB_SCENE) as PackedScene
	if hub_scene == null:
		push_error("Main: не удалось загрузить HubScreen.tscn")
		return
	var hub: Control = hub_scene.instantiate()
	hub.name = "HubScreen"
	hub.clean_requested.connect(_start_session, CONNECT_ONE_SHOT)
	hub.museum_requested.connect(_route_to_museum, CONNECT_ONE_SHOT)
	hub.shop_requested.connect(_route_to_shop, CONNECT_ONE_SHOT)
	hub.daily_requested.connect(_route_to_daily, CONNECT_ONE_SHOT)
	hub.settings_requested.connect(_route_to_settings, CONNECT_ONE_SHOT)
	_show_node(hub)

func _route_to_settings() -> void:
	_clear_screen()
	var settings: Control = SETTINGS_SCREEN.new()
	settings.back_requested.connect(_route_to_hub, CONNECT_ONE_SHOT)
	if not settings.music_toggled.is_connected(_on_music_toggled):
		settings.music_toggled.connect(_on_music_toggled)
	_show_node(settings)

func _route_to_daily() -> void:
	_clear_screen()
	var daily := _load_scene(DAILY_REWARD_SCREEN_SCENE)
	if daily == null:
		return
	daily.back_requested.connect(_route_to_hub, CONNECT_ONE_SHOT)
	_show_node(daily)

func _route_to_shop() -> void:
	_clear_screen()
	var shop := _load_scene(SHOP_SCREEN_SCENE)
	if shop == null:
		return
	shop.back_requested.connect(_route_to_hub, CONNECT_ONE_SHOT)
	_show_node(shop)

func _route_to_museum() -> void:
	_clear_screen()
	var museum := _load_scene(MUSEUM_SCREEN_SCENE)
	if museum == null:
		return
	museum.back_requested.connect(_route_to_hub, CONNECT_ONE_SHOT)
	_show_node(museum)

func _clear_screen() -> void:
	if _fuse != null and is_instance_valid(_fuse):
		_fuse.stop()
	_fuse = null
	for c in get_children():
		if c is Control and c.name != "CenterBox" and c != _fade:
			c.queue_free()

func _load_scene(path: String) -> Control:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Main: не удалось загрузить сцену: " + path)
		return null
	var node := packed.instantiate() as Control
	if node == null:
		push_error("Main: корень сцены не Control: " + path)
		return null
	return node

## Экран показывается с затемнением: фон гаснет за FADE_SEC, пока идёт затемнение, ввод заблокирован.
func _show_node(node: Control, pop_in: bool = false) -> void:
	add_child(node)
	_attach_button_fx(node)
	if pop_in:
		ButtonFx.pop_in(node)
	move_child(_fade, get_child_count() - 1)
	_fade_in()

func _attach_button_fx(node: Control) -> void:
	if node is Button:
		ButtonFx.attach(node)
	for b in node.find_children("*", "Button", true, false):
		ButtonFx.attach(b)

func _fade_in() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade.modulate.a = 1.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "modulate:a", 0.0, FADE_SEC)
	_fade_tween.tween_callback(func() -> void: _fade.mouse_filter = Control.MOUSE_FILTER_IGNORE)

func _route_to_result() -> void:
	_clear_screen()
	var result := _load_scene(RESULT_SCREEN_SCENE)
	if result == null:
		return
	result.item_texture = _current_item_texture()
	result.setup(_session_progress, _session_index + 1, SESSION_SIZE)
	result.sell_requested.connect(_on_result_coins, CONNECT_ONE_SHOT)
	result.double_requested.connect(_on_result_coins, CONNECT_ONE_SHOT)
	result.museum_requested.connect(_on_result_museum, CONNECT_ONE_SHOT)
	_show_node(result, true)

func _route_to_summary() -> void:
	_clear_screen()
	GameData.register_session_completed()
	if not SaveManager.onboarding_done:
		SaveManager.onboarding_done = true
		SaveManager.request_save()
	var result := _load_scene(RESULT_SCREEN_SCENE)
	if result == null:
		return
	result.setup_summary(_session_stars, _session_coins)
	result.hub_requested.connect(_route_to_hub, CONNECT_ONE_SHOT)
	_show_node(result)

func _start_session() -> void:
	_session_items = _pick_session_items()
	_session_index = 0
	_session_coins = 0
	_session_stars.clear()
	_route_to_clean()

func _pick_session_items() -> Array[Dictionary]:
	var missing: Array[Dictionary] = []
	var owned: Array[Dictionary] = []
	for raw in MUSEUM_CATALOG.ITEMS:
		var item: Dictionary = raw
		if GameData.is_in_museum(item["id"]):
			owned.append(item)
		else:
			missing.append(item)
	missing.shuffle()
	owned.shuffle()
	var picked: Array[Dictionary] = []
	for item in missing + owned:
		if picked.size() >= SESSION_SIZE:
			break
		picked.append(item)
	return picked

func _advance_session() -> void:
	_session_index += 1
	if _session_index < SESSION_SIZE:
		_route_to_clean()
	else:
		_route_to_summary()

func _current_item_texture() -> Texture2D:
	if _session_index >= _session_items.size():
		return null
	var id: String = _session_items[_session_index]["id"]
	if id == _item_texture_id and _item_texture != null:
		return _item_texture
	var img := ItemArt.load_cutout(id)
	if img == null:
		return null
	_item_texture_id = id
	_item_texture = ImageTexture.create_from_image(img)
	return _item_texture

## Общая обвязка этапа: счётчик, фитиль и попап обучения. Фитиль стартует после закрытия попапа.
func _setup_stage_chrome(stage: Control, fuse_sec: float, tutorial_key: String, tutorial_text: String) -> void:
	var counter := "Предмет %d/%d" % [_session_index + 1, SESSION_SIZE]
	stage.add_child(BANNER_SCRIPT.new(counter))
	_fuse = StageTimer.new(fuse_sec)
	_fuse.expired.connect(_on_stage_expired, CONNECT_ONE_SHOT)
	stage.add_child(_fuse)
	if SaveManager.is_tutorial_seen(tutorial_key):
		_fuse.start()
		return
	stage.set_process_input(false)
	var popup := TutorialPopup.new(tutorial_text)
	stage.add_child(popup)
	_attach_button_fx(popup)
	popup.closed.connect(_on_tutorial_closed.bind(stage, _fuse, tutorial_key), CONNECT_ONE_SHOT)

func _on_tutorial_closed(stage: Control, fuse: StageTimer, tutorial_key: String) -> void:
	SaveManager.mark_tutorial_seen(tutorial_key)
	if is_instance_valid(stage):
		stage.set_process_input(true)
	if is_instance_valid(fuse):
		fuse.start()

## Время вышло: предмет не отреставрирован, награды и запись в музей нет, сессия идёт дальше.
func _on_stage_expired() -> void:
	SFX.play("fail")
	_advance_session()

## Заголовок этапа: появляется и гаснет за ~1 с, не перехватывает ввод.
func _attach_stage_title(stage: Control, title: String) -> void:
	var label := Label.new()
	label.text = title
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", STAGE_TITLE_FONT_SIZE)
	label.add_theme_color_override("font_color", STAGE_TITLE_COLOR)
	label.add_theme_color_override("font_outline_color", STAGE_TITLE_OUTLINE)
	label.add_theme_constant_override("outline_size", STAGE_TITLE_OUTLINE_SIZE)
	label.modulate.a = 0.0
	stage.add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "modulate:a", 1.0, STAGE_TITLE_FADE)
	tween.tween_interval(STAGE_TITLE_HOLD)
	tween.tween_property(label, "modulate:a", 0.0, STAGE_TITLE_FADE)
	tween.tween_callback(label.queue_free)

func _is_easy_item() -> bool:
	return GameData.items_completed < EASY_ITEM_COUNT

func _on_result_coins(amount: int) -> void:
	if amount > 0:
		GameData.add_coins(amount)
		SFX.play("coin")
	_session_coins += amount
	_advance_session()

func _on_result_museum() -> void:
	if _session_index < _session_items.size():
		var item_id: String = _session_items[_session_index]["id"]
		GameData.add_to_museum(item_id)
		SFX.play("unlock")
		_grant_category_reward(item_id)
	_advance_session()

## Награда за полную категорию музея — один раз на категорию.
func _grant_category_reward(item_id: String) -> void:
	var category_id := MUSEUM_CATALOG.get_item_category(item_id)
	if category_id.is_empty() or GameData.is_category_rewarded(category_id):
		return
	if MUSEUM_CATALOG.count_in_category(category_id) < MUSEUM_CATALOG.total_in_category(category_id):
		return
	GameData.mark_category_rewarded(category_id)
	GameData.add_coins(CATEGORY_REWARD_COINS)
	SFX.play("coin")

func _on_clean_finished(progress: float) -> void:
	_session_progress.append(progress)
	_route_to_assembly()

func _on_assembly_finished(progress: float) -> void:
	_session_progress.append(progress)
	_route_to_polish()

func _on_polish_finished(progress: float) -> void:
	_session_progress.append(progress)
	GameData.register_item_completed()
	_session_stars.append(RESULT_SCRIPT.calc_stars(_session_progress))
	_route_to_result()

func _update_status() -> void:
	if status_label == null:
		return
	var sdk_mode := "web" if OS.has_feature("web") else "stub"
	var day_num := DayCycle.get_day_index() + 1
	var info := "Монеты: %d | Энергия: %d/%d | День: %d | SDK: %s" % [
		GameData.coins,
		GameData.energy_current,
		GameData.MAX_ENERGY_PER_DAY,
		day_num,
		sdk_mode,
	]
	status_label.text = "Мастерская реставрации\n" + info
