extends Control
## HubScreen — главный экран игры (Шаг 2). Адаптивный UI: все элементы внутри
## MarginContainer + VBox/HBox контейнеров, растянутых на весь экран, поэтому
## интерфейс корректно выглядит и на десктопе (16:9), и в портрете на мобильном.
## Данные читаются из автозагрузок GameData / DayCycle.
## ВАЖНО (код-ревью): HUD_TopBar — единственный источник истины для монет и
## энергии; HubScreen НЕ трогает их лейблы напрямую. Подписка на сигналы —
## в _enter_tree(), отписка — в _exit_tree() (без утечек при смене экранов).

# --- Привязка узлов (явные пути, @onready вместо @export) -------------------

@onready var top_bar: CanvasItem = $RootMargin/VBox/TopBar
@onready var btn_start: Button = $RootMargin/VBox/ButtonsBox/BtnStart
@onready var btn_museum: Button = $RootMargin/VBox/ButtonsBox/BtnMuseum
@onready var btn_shop: Button = $RootMargin/VBox/ButtonsBox/BtnShop
@onready var btn_daily: Button = $RootMargin/VBox/ButtonsBox/BtnDaily
@onready var daily_dot: ColorRect = $RootMargin/VBox/ButtonsBox/BtnDaily/DailyDot

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
					[btn_shop, _on_shop_pressed], [btn_daily, _on_daily_pressed]]:
		var b: Button = pair[0]
		if b != null and not b.pressed.is_connected(pair[1]):
			b.pressed.connect(pair[1])

	# Основная кнопка — визуально выделена (акцентный цвет).
	if btn_start != null:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.75, 0.45, 0.16)
		sb.set_corner_radius_all(12)
		sb.set_content_margin_all(10)
		btn_start.add_theme_stylebox_override("normal", sb)
		var sb_hover := sb.duplicate() as StyleBoxFlat
		sb_hover.bg_color = Color(0.85, 0.55, 0.22)
		btn_start.add_theme_stylebox_override("hover", sb_hover)
		btn_start.add_theme_stylebox_override("pressed", sb_hover)

	# Первичное заполнение (только то, чем владеет этот экран).
	_refresh_daily_badge()

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
	# Красная точка видна, только если награду ещё не забрали сегодня;
	# сама кнопка блокируется, когда награда недоступна.
	if daily_dot != null:
		daily_dot.visible = DayCycle.is_daily_reward_available()
	if btn_daily != null:
		btn_daily.disabled = not DayCycle.is_daily_reward_available()

# --- Обработчики кнопок -------------------------------------------------------

func _on_start_pressed() -> void:
	if not GameData.can_play():
		# Диалог «Энергия исчерпана: смотреть рекламу / подождать» реализуем на Шаге 6.
		print("[STUB] Показать диалог нехватки энергии")
		return
	GameData.spend_energy()
	# Экран очистки (мини-игра «Очистка», старые часы) реализуем на Шаге 3.
	print("[STUB] Переход на экран очистки")

func _on_museum_pressed() -> void:
	# Музей — Шаг 5.
	print("[STUB] Переход в Музей (коллекция: %d)" % GameData.get_museum_count())

func _on_shop_pressed() -> void:
	# Магазин улучшений — Шаг 5.
	print("[STUB] Переход в Магазин")

func _on_daily_pressed() -> void:
	# Экран ежедневной награды — Шаг 5. Пока просто проверяем доступность.
	if DayCycle.is_daily_reward_available():
		print("[STUB] Открыть экран ежедневной награды (день цикла: %d)" % DayCycle.get_current_cycle_day())
	else:
		print("[STUB] Награда уже получена сегодня — кнопка неактивна до следующего дня")
