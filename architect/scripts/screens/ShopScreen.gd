extends Control
## ShopScreen — магазин улучшений и расходников (Шаг 5b).
## Вкладки переключают вид каталога ShopCatalog; покупки идут через GameData.
## Баланс обновляется по GameData.coins_changed; подписки — в _enter_tree(), отписки — в _exit_tree().

signal back_requested

const SHOP_CATALOG := preload("res://scripts/data/ShopCatalog.gd")
const SFX := preload("res://scripts/fx/SfxGenerator.gd")
const HINT_ID: String = "hint"
const CARD_MIN_HEIGHT: int = 88
const BUY_BUTTON_MIN_HEIGHT: int = 56
const CARD_SEPARATION: int = 12
const TITLE_FONT_SIZE: int = 20
const HINT_BUTTON_TEXT: String = "Смотреть рекламу"

var _current_kind: String = SHOP_CATALOG.KIND_UPGRADE

@onready var _coins_label: Label = $Margin/Root/TopRow/Coins
@onready var _tab_upgrades: Button = $Margin/Root/TabRow/TabUpgrades
@onready var _tab_consumables: Button = $Margin/Root/TabRow/TabConsumables
@onready var _list: VBoxContainer = $Margin/Root/Scroll/List


func _enter_tree() -> void:
	var btn_back: Button = $Margin/Root/TopRow/BtnBack
	if not btn_back.pressed.is_connected(_on_back_pressed):
		btn_back.pressed.connect(_on_back_pressed)
	var tab_upgrades: Button = $Margin/Root/TabRow/TabUpgrades
	if not tab_upgrades.pressed.is_connected(_on_tab_upgrades_pressed):
		tab_upgrades.pressed.connect(_on_tab_upgrades_pressed)
	var tab_consumables: Button = $Margin/Root/TabRow/TabConsumables
	if not tab_consumables.pressed.is_connected(_on_tab_consumables_pressed):
		tab_consumables.pressed.connect(_on_tab_consumables_pressed)
	if not GameData.coins_changed.is_connected(_on_coins_changed):
		GameData.coins_changed.connect(_on_coins_changed)


func _exit_tree() -> void:
	var btn_back: Button = $Margin/Root/TopRow/BtnBack
	if btn_back.pressed.is_connected(_on_back_pressed):
		btn_back.pressed.disconnect(_on_back_pressed)
	var tab_upgrades: Button = $Margin/Root/TabRow/TabUpgrades
	if tab_upgrades.pressed.is_connected(_on_tab_upgrades_pressed):
		tab_upgrades.pressed.disconnect(_on_tab_upgrades_pressed)
	var tab_consumables: Button = $Margin/Root/TabRow/TabConsumables
	if tab_consumables.pressed.is_connected(_on_tab_consumables_pressed):
		tab_consumables.pressed.disconnect(_on_tab_consumables_pressed)
	if GameData.coins_changed.is_connected(_on_coins_changed):
		GameData.coins_changed.disconnect(_on_coins_changed)


func _ready() -> void:
	_refresh()


func _on_back_pressed() -> void:
	back_requested.emit()


func _on_tab_upgrades_pressed() -> void:
	_current_kind = SHOP_CATALOG.KIND_UPGRADE
	_refresh()


func _on_tab_consumables_pressed() -> void:
	_current_kind = SHOP_CATALOG.KIND_CONSUMABLE
	_refresh()


func _on_coins_changed(_new_amount: int) -> void:
	_refresh()


func _on_buy_pressed(item: Dictionary) -> void:
	var item_id: String = item["id"]
	var price: int = item["price"]
	if GameData.coins < price:
		SFX.play("no_coins")
		return
	if item["kind"] == SHOP_CATALOG.KIND_UPGRADE:
		GameData.buy_upgrade(item_id, price)
	elif GameData.spend_coins(price):
		GameData.add_consumable(item_id)
	SFX.play("purchase")
	_refresh()


func _on_hint_ad_pressed() -> void:
	YandexSDK.show_rewarded_ad(_on_hint_ad_result)


func _on_hint_ad_result(viewed: bool) -> void:
	if viewed:
		GameData.add_consumable(HINT_ID)
	_refresh()


func _refresh() -> void:
	_coins_label.text = "Монеты: %d" % GameData.coins
	_tab_upgrades.button_pressed = _current_kind == SHOP_CATALOG.KIND_UPGRADE
	_tab_consumables.button_pressed = _current_kind == SHOP_CATALOG.KIND_CONSUMABLE

	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for item in SHOP_CATALOG.get_by_kind(_current_kind):
		_build_card(item)


func _build_card(item: Dictionary) -> void:
	var item_id: String = item["id"]
	var kind: String = item["kind"]
	var price: int = item["price"]

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, CARD_MIN_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", CARD_SEPARATION)
	card.add_child(row)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(texts)

	var title := Label.new()
	title.text = item["title"]
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	texts.add_child(title)

	var desc := Label.new()
	desc.text = item["desc"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(desc)

	var info := Label.new()
	info.text = "%d монет" % price
	if kind == SHOP_CATALOG.KIND_CONSUMABLE:
		info.text += " · В инвентаре: %d" % GameData.get_consumable(item_id)
	texts.add_child(info)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, BUY_BUTTON_MIN_HEIGHT)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if kind == SHOP_CATALOG.KIND_UPGRADE and GameData.has_upgrade(item_id):
		btn.text = "Куплено"
		btn.disabled = true
	elif item_id == HINT_ID:
		btn.text = HINT_BUTTON_TEXT
		btn.pressed.connect(_on_hint_ad_pressed)
	else:
		btn.text = "Купить"
		btn.disabled = GameData.coins < price
		btn.pressed.connect(_on_buy_pressed.bind(item))
	row.add_child(btn)
