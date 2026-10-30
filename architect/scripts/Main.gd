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
	var hub := load("res://scenes/screens/HubScreen.tscn").instantiate()
	hub.name = "HubScreen"
	add_child(hub)
	if status_label != null:
		status_label.visible = false
	if ad_test_button != null:
		ad_test_button.visible = false
	_update_status()
	GameData.coins_changed.connect(func(_v): _update_status())
	GameData.energy_changed.connect(func(_c, _m): _update_status())
	# Временная кнопка для проверки stub-рекламы (удалим на Шаге 2).
	ad_test_button.pressed.connect(_on_ad_test_pressed)

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

func _on_ad_test_pressed() -> void:
	ad_test_button.disabled = true
	ad_test_button.text = "Реклама… (stub: 2 сек)"
	YandexSDK.show_rewarded_ad(_on_rewarded)

func _on_rewarded(viewed: bool) -> void:
	ad_test_button.disabled = false
	ad_test_button.text = "Тест rewarded-рекламы"
	if viewed:
		GameData.add_coins(50)
		print("Main: реклама просмотрена (stub), +50 монет")
