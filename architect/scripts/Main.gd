extends Control
## Main — корневая сцена-роутер экранов. Шаг 1: минимальный каркас.
## Здесь происходит стартовая последовательность: загрузка сейва (SaveManager),
## инициализация SDK (YandexSDK) и уведомление портала Яндекса о готовности
## игры через notify_game_ready() — обязательное требование модерации.

@onready var status_label: Label = $CenterBox/StatusLabel
@onready var ad_test_button: Button = $CenterBox/AdTestButton

func _ready() -> void:
	# Автозагрузки (DayCycle -> GameData -> SaveManager -> YandexSDK) уже
	# инициализированы к этому моменту — порядок задан в project.godot.
	YandexSDK.notify_game_ready()
	# Шаг 2: главный экран игры (Hub). Старый статус-каркас Шага 1 скрыт.
	var hub_scene := load("res://scenes/screens/HubScreen.tscn") as PackedScene
	if hub_scene == null:
		push_error("Main: не удалось загрузить HubScreen.tscn")
		return
	var hub: Control = hub_scene.instantiate()
	hub.name = "HubScreen"
	add_child(hub)
	# Подключаем мини-игру «Очистка» (Шаг 3): переход по сигналу Hub,
	# возврат — кнопкой «Назад» внутри CleanStage (reload_current_scene).
	var clean_scene := load("res://scenes/gameplay/CleanStage.tscn") as PackedScene
	if clean_scene != null:
		var on_clean := func() -> void:
			var stage: Control = clean_scene.instantiate()
			stage.name = "CleanStage"
			add_child(stage)
		hub.clean_requested.connect(on_clean)
	else:
		push_warning("Main: не удалось загрузить CleanStage.tscn (шаг 3)")
	if status_label != null:
		status_label.visible = false
	if ad_test_button != null:
		ad_test_button.visible = false
	_update_status()

func _update_status() -> void:
	var sdk_mode := "web" if OS.has_feature("web") else "stub"
	var day_num := DayCycle.get_day_index() + 1
	var info := "Монеты: %d | Энергия: %d/%d | День: %d | SDK: %s" % [
		GameData.coins,
		GameData.energy_current,
		GameData.MAX_ENERGY_PER_DAY,
		day_num,
		sdk_mode,
	]
	status_label.text = "Мастерская реставрации — Шаг 1 (каркас)\n" + info
