extends Control
## HubScreen — главный экран игры (Шаг 2). Адаптивный UI: все элементы внутри
## MarginContainer + VBox/HBox контейнеров, растянутых на весь экран, поэтому
## интерфейс корректно выглядит и на десктопе (16:9), и в портрете на мобильном.
## Данные читаются из автозагрузок GameData / DayCycle; обновление HUD — по сигналам.

# --- Ссылки на узлы (через @export, чтобы можно было переназначить в инспекторе) ---

@export var top_bar: CanvasItem          # компонент HUD_TopBar (сцена scenes/ui/HUD_TopBar.tscn)
@export var btn_start: Button            # «Начать реставрацию» — основная кнопка
@export var btn_museum: Button           # «Музей»
@export var btn_shop: Button             # «Магазин»
@export var btn_daily: Button            # «Ежедневная награда»
@export var daily_dot: Control           # красная точка на кнопке daily

# Необязательные ссылки (если top_bar не задан — ищем стандартные имена узлов)
@export var lbl_coins: Label
@export var lbl_energy: Label

func _ready() -> void:
	# Если ссылки не назначены в инспекторе — находим узлы по стандартным именам.
	if top_bar == null:
		top_bar = get_node_or_null("RootMargin/VBox/TopBar")
	if btn_start == null:
		btn_start = get_node_or_null("RootMargin/VBox/ButtonsBox/BtnStart") as Button
	if btn_museum == null:
		btn_museum = get_node_or_null("RootMargin/VBox/ButtonsBox/BtnMuseum") as Button
	if btn_shop == null:
		btn_shop = get_node_or_null("RootMargin/VBox/ButtonsBox/BtnShop") as Button
	if btn_daily == null:
		btn_daily = get_node_or_null("RootMargin/VBox/ButtonsBox/BtnDaily") as Button
	if daily_dot == null:
		daily_dot = get_node_or_null("RootMargin/VBox/ButtonsBox/BtnDaily/DailyDot")

	# Если HUD_TopBar вложен отдельной сценой — находим его дочерние лейблы.
	if top_bar != null and lbl_coins == null:
		lbl_coins = top_bar.get_node_or_null("CoinsBox/CoinsLabel") as Label
	if top_bar != null and lbl_energy == null:
		lbl_energy = top_bar.get_node_or_null("EnergyBox/EnergyLabel") as Label

	# Подписка на сигналы автозагрузок — HUD обновляется автоматически.
	GameData.coins_changed.connect(_on_coins_changed)
	GameData.energy_changed.connect(_on_energy_changed)
	DayCycle.daily_reward_state_changed.connect(_refresh_daily_badge)

	# Обработка кнопок (дублирующая привязка через код безопасна:
	# если сигнал уже подключён в редакторе — connect не создаёт дубль).
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

	# Первичное заполнение.
	_refresh_all()

func _refresh_all() -> void:
	_update_coins(GameData.coins)
	_update_energy(GameData.energy_current, GameData.MAX_ENERGY_PER_DAY)
	_refresh_daily_badge()

# --- Обновление HUD ---------------------------------------------------------

func _update_coins(amount: int) -> void:
	if lbl_coins != null:
		lbl_coins.text = "🪙 %d" % amount

func _update_energy(current: int, maximum: int) -> void:
	if lbl_energy != null:
		lbl_energy.text = "⚡ %d/%d" % [current, maximum]

func _on_coins_changed(new_amount: int) -> void:
	_update_coins(new_amount)

func _on_energy_changed(current: int, maximum: int) -> void:
	_update_energy(current, maximum)

func _refresh_daily_badge() -> void:
	# Красная точка видна, только если награду ещё не забрали сегодня.
	if daily_dot != null:
		daily_dot.visible = DayCycle.is_daily_reward_available()

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
