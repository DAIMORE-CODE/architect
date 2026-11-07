extends Control
## HubScreen — главный экран игры (Шаг 2). Адаптивный UI: все элементы внутри
## MarginContainer + VBox/HBox контейнеров, растянутых на весь экран, поэтому
## интерфейс корректно выглядит и на десктопе (16:9), и в портрете на мобильном.
## Данные читаются из автозагрузок GameData / DayCycle.
## ВАЖНО (код-ревью): HUD_TopBar — единственный источник истины для монет и
## энергии; HubScreen НЕ трогает их лейблы напрямую. Подписка на сигналы —
## в _enter_tree(), отписка — в _exit_tree() (без утечек при смене экранов).

## Сигнал перехода на этап очистки (подключается роутером Main.gd, Шаг 3).
signal clean_requested
## Сигнал перехода в Музей (подключается роутером Main.gd, Шаг 5a).
signal museum_requested
## Сигнал перехода в Магазин (подключается роутером Main.gd, Шаг 5b).
signal shop_requested
## Сигнал перехода на экран ежедневной награды (подключается роутером Main.gd, Шаг 5c).
signal daily_requested
## Сигнал перехода на экран настроек (подключается роутером Main.gd, Шаг 7c).
signal settings_requested

# --- Привязка узлов (явные пути, @onready вместо @export) -------------------

@onready var top_bar: CanvasItem = $RootMargin/VBox/TopBar
@onready var btn_start: Button = $RootMargin/VBox/ButtonsBox/BtnStart
@onready var btn_museum: Button = $RootMargin/VBox/ButtonsBox/BtnMuseum
@onready var btn_shop: Button = $RootMargin/VBox/ButtonsBox/BtnShop
@onready var btn_daily: Button = $RootMargin/VBox/ButtonsBox/BtnDaily
@onready var daily_dot: Panel = $RootMargin/VBox/ButtonsBox/BtnDaily/DailyDot
@onready var btn_energy_ad: Button = $RootMargin/VBox/BtnEnergyAd
@onready var workbench_title: Label = $RootMargin/VBox/WorkbenchArea/Workbench/WorkbenchTitle
@onready var workbench_subtitle: Label = $RootMargin/VBox/WorkbenchArea/Workbench/WorkbenchSubtitle
@onready var workbench_area: Control = $RootMargin/VBox/WorkbenchArea
var stats_label: Label

const WORKSHOP_THEME := preload("res://scripts/ui/WorkshopTheme.gd")
const MUSEUM_CATALOG := preload("res://scripts/data/MuseumCatalog.gd")
const SFX := preload("res://scripts/fx/SfxGenerator.gd")
const SETTINGS_BUTTON_TEXT := "Настройки"
const SETTINGS_BUTTON_MIN_HEIGHT := 72.0
func _enter_tree() -> void:
	GameData.coins_changed.connect(_on_coins_changed)
	GameData.energy_changed.connect(_on_energy_changed)
	DayCycle.daily_reward_state_changed.connect(_on_daily_reward_changed)

func _exit_tree() -> void:
	if GameData.coins_changed.is_connected(_on_coins_changed):
		GameData.coins_changed.disconnect(_on_coins_changed)
	if GameData.energy_changed.is_connected(_on_energy_changed):
		GameData.energy_changed.disconnect(_on_energy_changed)
	if DayCycle.daily_reward_state_changed.is_connected(_on_daily_reward_changed):
		DayCycle.daily_reward_state_changed.disconnect(_on_daily_reward_changed)

func _ready() -> void:
	# Обработка кнопок (connect не создаёт дубль, если уже привязан в редакторе).
	for pair in [[btn_start, _on_start_pressed], [btn_museum, _on_museum_pressed],
					[btn_shop, _on_shop_pressed], [btn_daily, _on_daily_pressed],
					[btn_energy_ad, _on_energy_ad_pressed]]:
		var b: Button = pair[0]
		if b != null and not b.pressed.is_connected(pair[1]):
			b.pressed.connect(pair[1])

	# Основная кнопка «Начать»: вариация PrimaryButton из WorkshopTheme (золотой акцент).
	if btn_start != null:
		btn_start.theme_type_variation = WORKSHOP_THEME.PRIMARY_BUTTON_TYPE

	# Первичное заполнение (только то, чем владеет этот экран).
	_refresh_workbench()
	_add_stats_label()
	_refresh_daily_badge()
	_add_settings_button()

## Предмет дня: название и нейтральное описание, одинаковые весь игровой день.
func _refresh_workbench() -> void:
	var item := MUSEUM_CATALOG.get_item_of_the_day(DayCycle.get_day_index())
	if item.is_empty():
		return
	workbench_title.text = "Предмет дня: %s" % item["name"]
	workbench_subtitle.text = MUSEUM_CATALOG.get_description(item["id"])

func _add_stats_label() -> void:
	var box := $RootMargin/VBox as VBoxContainer
	stats_label = Label.new()
	stats_label.name = "StatsLabel"
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(stats_label)
	box.move_child(stats_label, workbench_area.get_index() + 1)
	stats_label.text = "Сессий сегодня: %d | В музее: %d/%d" % [
		GameData.get_sessions_today(),
		GameData.get_museum_count(),
		MUSEUM_CATALOG.ITEMS.size(),
	]

func _add_settings_button() -> void:
	var box := $RootMargin/VBox as VBoxContainer
	var btn_settings := Button.new()
	btn_settings.name = "BtnSettings"
	btn_settings.text = SETTINGS_BUTTON_TEXT
	btn_settings.custom_minimum_size = Vector2(0.0, SETTINGS_BUTTON_MIN_HEIGHT)
	btn_settings.pressed.connect(_on_settings_pressed)
	box.add_child(btn_settings)

# --- Реакция на сигналы ------------------------------------------------------

func _on_coins_changed(_new_amount: int) -> void:
	# Монеты отображает HUD_TopBar (единственный источник истины) — здесь ничего не делаем.
	pass

func _on_energy_changed(_current: int, _maximum: int) -> void:
	# Энергию отображает HUD_TopBar (единственный источник истины) — здесь ничего не делаем.
	pass

func _on_daily_reward_changed() -> void:
	_refresh_daily_badge()

func _refresh_daily_badge() -> void:
	# Красная точка видна, только если награду ещё не забрали сегодня.
	if daily_dot != null:
		daily_dot.visible = DayCycle.is_daily_reward_available()

# --- Обработчики кнопок -------------------------------------------------------

func _on_start_pressed() -> void:
	if not GameData.can_play():
		# Диалог «Энергия исчерпана: смотреть рекламу / подождать» реализуем на финальном этапе (см. D-019).
		return
	GameData.spend_energy()
	# Шаг 3: переход на мини-игру «Очистка» — сигнал подхватывает роутер Main.gd.
	clean_requested.emit()

func _on_museum_pressed() -> void:
	museum_requested.emit()

func _on_shop_pressed() -> void:
	shop_requested.emit()

func _on_daily_pressed() -> void:
	daily_requested.emit()

func _on_settings_pressed() -> void:
	SFX.play("click")
	settings_requested.emit()

func _on_energy_ad_pressed() -> void:
	YandexSDK.show_rewarded_ad(_on_energy_ad_result)

func _on_energy_ad_result(viewed: bool) -> void:
	if viewed:
		GameData.add_energy(1)

