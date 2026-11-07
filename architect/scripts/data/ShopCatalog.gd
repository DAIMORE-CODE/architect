class_name ShopCatalog
extends RefCounted
## ShopCatalog — каталог магазина (Шаг 5b): постоянные улучшения и расходники.

const KIND_UPGRADE: String = "upgrade"
const KIND_CONSUMABLE: String = "consumable"

const ITEMS: Array[Dictionary] = [
	{"id": "soft_brush", "title": "Мягкая щётка", "desc": "Шире радиус очистки", "price": 60, "kind": "upgrade"},
	{"id": "precise_assembly", "title": "Точная сборка", "desc": "Шире радиус защёлкивания деталей", "price": 80, "kind": "upgrade"},
	{"id": "quick_hands", "title": "Быстрые руки", "desc": "+0.3 с к окну фитиля на полировке", "price": 100, "kind": "upgrade"},
	{"id": "polish", "title": "Полироль", "desc": "+1 стартовый блик на полировке", "price": 25, "kind": "consumable"},
	{"id": "hint", "title": "Подсказка", "desc": "Подсвечивает следующую деталь на сборке", "price": 0, "kind": "consumable"},
]


## Возвращает товары заданного вида в порядке каталога.
static func get_by_kind(kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in ITEMS:
		if item["kind"] == kind:
			result.append(item)
	return result
