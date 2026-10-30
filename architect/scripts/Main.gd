extends Control
## Main — корневая сцена-роутер экранов.
## Стартовая последовательность: notify_game_ready() (требование модерации Яндекса),
## показ HubScreen, маршрутизация Hub <-> CleanStage.
## Исправления ревью Шага 3: _clear_screen() УНИЧТОЖАЕТ предыдущий экран ДО
## подключения сигналов — нет утечки экранов при навигации Hub <-> CleanStage
## и нет двойного срабатывания stage_finished (CONNECT_ONE_SHOT).

const CLEAN_STAGE_SCENE := "res://scenes/gameplay/CleanStage.tscn"
const HUB_SCENE := "res://scenes/screens/HubScreen.tscn"

@onready var status_label: Label = $CenterBox/StatusLabel
@onready var ad_test_button: Button = $CenterBox/AdTestButton

func _ready() -> void:
	# Автозагрузки (DayCycle -> GameData -> SaveManager -> YandexSDK) уже
	# инициализированы к этому моменту — порядок задан в project.godot.
	YandexSDK.notify_game_ready()
	if status_label != null:
		status_label.visible = false
	if ad_test_button != null:
		ad_test_button.visible = false
	_route_to_hub()

func _route_to_clean() -> void:
	_clear_screen()  # УНИЧТОЖАЕТ предыдущий экран ДО подключения сигнала
	var stage := _load_scene(CLEAN_STAGE_SCENE)
	if stage == null:
		return
	stage.stage_finished.connect(_on_clean_finished, CONNECT_ONE_SHOT)
	_show_node(stage)

func _route_to_hub() -> void:
	_clear_screen()
	var hub_scene := load(HUB_SCENE) as PackedScene
	if hub_scene == null:
		push_error("Main: не удалось загрузить HubScreen.tscn")
		return
	var hub: Control = hub_scene.instantiate()
	hub.name = "HubScreen"
	hub.clean_requested.connect(_route_to_clean, CONNECT_ONE_SHOT)
	_show_node(hub)

func _clear_screen() -> void:
	for c in get_children():
		if c is Control and c.name != "CenterBox":
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

func _show_node(node: Control) -> void:
	add_child(node)

func _on_clean_finished(progress: float) -> void:
	print("[STUB] Этап очистки завершён, прогресс=%.2f. Шаг 4: экран рейтинга" % progress)

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
