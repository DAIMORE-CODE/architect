class_name MuseumCatalog
extends RefCounted
## MuseumCatalog — каталог предметов музея (Шаг 5a): 20 предметов в 6 категориях.
## Статус «собрано» хранится в GameData.museum_items.

const CATEGORIES: Array[Dictionary] = [
	{"id": "watches", "title": "Часы", "color": Color(0.78, 0.6, 0.25)},
	{"id": "boxes", "title": "Шкатулки", "color": Color(0.55, 0.3, 0.2)},
	{"id": "paintings", "title": "Картины", "color": Color(0.3, 0.5, 0.7)},
	{"id": "jewelry", "title": "Ювелирные украшения", "color": Color(0.6, 0.35, 0.6)},
	{"id": "dishes", "title": "Посуда и фарфор", "color": Color(0.4, 0.6, 0.5)},
	{"id": "instruments", "title": "Музыкальные инструменты", "color": Color(0.5, 0.4, 0.25)},
]

const ITEMS: Array[Dictionary] = [
	{"id": "watch_pocket", "name": "Карманные часы", "category": "watches"},
	{"id": "watch_wall", "name": "Настенные часы", "category": "watches"},
	{"id": "watch_alarm", "name": "Будильник", "category": "watches"},
	{"id": "watch_gold", "name": "Золотые часы", "category": "watches"},
	{"id": "box_wood", "name": "Деревянная шкатулка", "category": "boxes"},
	{"id": "box_lacquer", "name": "Лаковая шкатулка", "category": "boxes"},
	{"id": "box_silver", "name": "Серебряная шкатулка", "category": "boxes"},
	{"id": "box_music", "name": "Шкатулка-музыкалка", "category": "boxes"},
	{"id": "painting_landscape", "name": "Пейзаж", "category": "paintings"},
	{"id": "painting_portrait", "name": "Портрет", "category": "paintings"},
	{"id": "painting_still", "name": "Натюрморт", "category": "paintings"},
	{"id": "jewel_brooch", "name": "Брошь", "category": "jewelry"},
	{"id": "jewel_ring", "name": "Перстень", "category": "jewelry"},
	{"id": "jewel_necklace", "name": "Колье", "category": "jewelry"},
	{"id": "dish_plate", "name": "Тарелка", "category": "dishes"},
	{"id": "dish_vase", "name": "Ваза", "category": "dishes"},
	{"id": "dish_cup", "name": "Чашка", "category": "dishes"},
	{"id": "instr_violin", "name": "Скрипка", "category": "instruments"},
	{"id": "instr_guitar", "name": "Гитара", "category": "instruments"},
	{"id": "instr_accordion", "name": "Гармонь", "category": "instruments"},
]

## Нейтральные описания предметов для «Предмета дня» (без сюжета и заказчиков).
const DESCRIPTIONS: Dictionary = {
	"watch_pocket": "Карманные часы на цепочке. Работа механизма зависит от чистоты деталей.",
	"watch_wall": "Настенные часы с маятником. Важны ровные стрелки и исправный ход.",
	"watch_alarm": "Будильник с двумя звонками. Пружина и колокольчики требуют бережной чистки.",
	"watch_gold": "Золотые часы. Позолота тускнеет и требует аккуратной полировки.",
	"box_wood": "Деревянная шкатулка. Древесину очищают без лишней влаги, чтобы не было трещин.",
	"box_lacquer": "Лаковая шкатулка. Лак чистят мягкой тканью без растворителей.",
	"box_silver": "Серебряная шкатулка. Серебро темнеет, его очищают аккуратно.",
	"box_music": "Шкатулка с музыкальным механизмом. Валик и гребёнку чистят отдельно.",
	"painting_landscape": "Пейзаж. Старый лак и пыль со временем меняют цвета картины.",
	"painting_portrait": "Портрет. Реставрация начинается с очистки поверхности холста.",
	"painting_still": "Натюрморт. Тёмные слои лака снимают очень осторожно.",
	"jewel_brooch": "Брошь с булавкой. Металл и камни очищают по отдельности.",
	"jewel_ring": "Перстень. Оправу чистят, камень не трогают влажными средствами.",
	"jewel_necklace": "Колье из звеньев. Каждое звено очищают и проверяют на целостность.",
	"dish_plate": "Фарфоровая тарелка. Налёт убирают без царапин на глазури.",
	"dish_vase": "Ваза с узким горлом. Внутреннюю часть очищают отдельно.",
	"dish_cup": "Фарфоровая чашка с ручкой. Ручку проверяют на прочность.",
	"instr_violin": "Скрипка. Корпус очищают сухой тканью, лак не трогают влажным.",
	"instr_guitar": "Гитара. Гриф и корпус чистят раздельно.",
	"instr_accordion": "Гармонь с мехами. Мехи чистят мягкой кистью.",
}


static func get_item_by_id(item_id: String) -> Dictionary:
	for item in ITEMS:
		if item["id"] == item_id:
			return item
	return {}


static func get_item_category(item_id: String) -> String:
	return get_item_by_id(item_id).get("category", "")


static func get_description(item_id: String) -> String:
	return DESCRIPTIONS.get(item_id, "")


## Предмет дня: детерминированно по индексу дня цикла (одинаков весь день).
static func get_item_of_the_day(day_index: int) -> Dictionary:
	if ITEMS.is_empty():
		return {}
	return ITEMS[posmod(day_index, ITEMS.size())]


static func get_categories() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for category in CATEGORIES:
		result.append({"id": category["id"], "title": category["title"]})
	return result


static func get_category_color(category_id: String) -> Color:
	for category in CATEGORIES:
		if category["id"] == category_id:
			var color: Color = category["color"]
			return color
	return Color.WHITE


static func next_missing_id() -> String:
	for item in ITEMS:
		var item_id: String = item["id"]
		if not GameData.museum_items.has(item_id):
			return item_id
	return ""


static func count_in_category(category_id: String) -> int:
	var count: int = 0
	for item in ITEMS:
		var item_id: String = item["id"]
		if item["category"] == category_id and GameData.museum_items.has(item_id):
			count += 1
	return count


static func total_in_category(category_id: String) -> int:
	var total: int = 0
	for item in ITEMS:
		if item["category"] == category_id:
			total += 1
	return total
