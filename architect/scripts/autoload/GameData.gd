extends Node
## GameData — автозагрузка (Singleton) глобальных данных игры.
## Хранит монеты, энергию, коллекцию, купленные улучшения и расходники.
## Сохранение/загрузку выполняет SaveManager (scripts/autoload/SaveManager.gd).

signal coins_changed(new_amount: int)
signal energy_changed(current: int, maximum: int)
signal collection_changed(item_id: String)
signal data_loaded

const START_COINS: int = 100

const MAX_ENERGY_PER_DAY: int = 5   # базовое дневное ограничение (ТЗ: 5)
const SESSION_ENERGY_COST: int = 2  # стоимость одной сессии из нескольких предметов (D-022)

var _loading := false

var coins: int = START_COINS:
	set(value):
		coins = maxi(0, value)
		coins_changed.emit(coins)
		if not _loading:
			SaveManager.request_save()

var energy_current: int = MAX_ENERGY_PER_DAY:
	set(value):
		energy_current = maxi(0, value)
		energy_changed.emit(energy_current, get_energy_max())
		if not _loading:
			SaveManager.request_save()

## id предметов, сданных в музей: { "watch_rusty_01": true, ... }
var museum_items: Dictionary = {}

## Купленные постоянные улучшения инструментов: { "clean_speed_lvl1": true, ... }
var upgrades: Dictionary = {}

## Купленные расходники (одноразовые): { "polish": 1, "hint": 2 }
var consumables: Dictionary = {}

## Сколько предметов реставрировано за всё время (для лёгкого режима первых предметов).
var items_completed: int = 0

## Категории, за которые уже выдана награда: { "watches": true, ... }
var rewarded_categories: Dictionary = {}

## Завершённые сессии за текущий день; sessions_day — индекс дня, к которому относится счётчик.
var sessions_today: int = 0
var sessions_day: int = -1

func _ready() -> void:
	DayCycle.new_day.connect(_on_new_day)

func _on_new_day(day_index: int) -> void:
	reset_energy()
	print("GameData: новый день %d, энергия сброшена" % day_index)

# --- Монеты -----------------------------------------------------------------

func add_coins(amount: int) -> void:
	coins += amount

func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	return true

# --- Энергия ----------------------------------------------------------------

func can_play() -> bool:
	return energy_current >= SESSION_ENERGY_COST

func spend_energy() -> bool:
	if not can_play():
		return false
	energy_current -= SESSION_ENERGY_COST
	return true

func add_energy(amount: int = 1) -> void:
	# Например, после просмотра rewarded-рекламы: +1 попытка сверх дневного лимита.
	energy_current += amount

func get_energy_max() -> int:
	return maxi(MAX_ENERGY_PER_DAY, energy_current)

func reset_energy() -> void:
	energy_current = MAX_ENERGY_PER_DAY

# --- Музей ------------------------------------------------------------------

func add_to_museum(item_id: String) -> bool:
	if museum_items.has(item_id):
		return false
	museum_items[item_id] = true
	collection_changed.emit(item_id)
	SaveManager.request_save()
	return true

func is_in_museum(item_id: String) -> bool:
	return museum_items.has(item_id)

func get_museum_count() -> int:
	return museum_items.size()

# --- Улучшения и расходники ---------------------------------------------------

func has_upgrade(upgrade_id: String) -> bool:
	return upgrades.has(upgrade_id)

func buy_upgrade(upgrade_id: String, price: int) -> bool:
	if has_upgrade(upgrade_id) or not spend_coins(price):
		return false
	upgrades[upgrade_id] = true
	SaveManager.request_save()
	return true

func get_consumable(consumable_id: String) -> int:
	return consumables.get(consumable_id, 0)

func add_consumable(consumable_id: String, count: int = 1) -> void:
	consumables[consumable_id] = get_consumable(consumable_id) + count
	SaveManager.request_save()

func use_consumable(consumable_id: String) -> bool:
	if get_consumable(consumable_id) <= 0:
		return false
	consumables[consumable_id] -= 1
	SaveManager.request_save()
	return true

func register_item_completed() -> void:
	items_completed += 1
	SaveManager.request_save()

func register_session_completed() -> void:
	_sync_sessions_day()
	sessions_today += 1
	SaveManager.request_save()

func get_sessions_today() -> int:
	_sync_sessions_day()
	return sessions_today

func _sync_sessions_day() -> void:
	var day := DayCycle.get_day_index()
	if sessions_day != day:
		sessions_day = day
		sessions_today = 0

func is_category_rewarded(category_id: String) -> bool:
	return rewarded_categories.has(category_id)

func mark_category_rewarded(category_id: String) -> void:
	rewarded_categories[category_id] = true
	SaveManager.request_save()

# --- Сериализация (для SaveManager) -------------------------------------------

func to_dict() -> Dictionary:
	return {
		"coins": coins,
		"energy_current": energy_current,
		"museum_items": museum_items,
		"upgrades": upgrades,
		"consumables": consumables,
		"items_completed": items_completed,
		"rewarded_categories": rewarded_categories,
		"sessions_today": sessions_today,
		"sessions_day": sessions_day,
	}

func from_dict(data: Dictionary) -> void:
	_loading = true
	coins = int(data.get("coins", START_COINS))
	energy_current = int(data.get("energy_current", MAX_ENERGY_PER_DAY))
	if typeof(data.get("museum_items", {})) == TYPE_DICTIONARY:
		museum_items = data["museum_items"]
	if typeof(data.get("upgrades", {})) == TYPE_DICTIONARY:
		upgrades = data["upgrades"]
	if typeof(data.get("consumables", {})) == TYPE_DICTIONARY:
		consumables = data["consumables"]
	items_completed = int(data.get("items_completed", 0))
	if typeof(data.get("rewarded_categories", {})) == TYPE_DICTIONARY:
		rewarded_categories = data.get("rewarded_categories", {})
	sessions_today = int(data.get("sessions_today", 0))
	sessions_day = int(data.get("sessions_day", -1))
	_loading = false
	data_loaded.emit()
