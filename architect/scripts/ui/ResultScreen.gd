extends Control
## ResultScreen — экран результата сессии (Шаг 4c).
## Показывает звёзды, награду и три действия. Каждое действие завершает сессию.

signal sell_requested(reward: int)
signal museum_requested
signal double_requested(reward: int)
signal hub_requested

const BASE_REWARD: int = 10
const RATING_3_MIN: float = 0.95
const RATING_2_MIN: float = 0.75
const STARS_MAX: int = 3
const STAR_SOUND_STEP: float = 0.25
const SFX := preload("res://scripts/fx/SfxGenerator.gd")

var _progresses: Array[float] = []
var _stars: int = 1
var _reward: int = BASE_REWARD
var _item_number: int = 1
var _total_items: int = 1
var _summary_mode: bool = false
var _summary_stars: Array[int] = []
var _summary_coins: int = 0
## Арт предмета сессии для превью; задаётся Main до добавления экрана в дерево.
var item_texture: Texture2D

@onready var _stars_label: Label = $Margin/CenterBox/Stars
@onready var _summary_label: Label = $Margin/CenterBox/Summary
@onready var _reward_label: Label = $Margin/CenterBox/Reward
@onready var _status_label: Label = $Margin/CenterBox/Status
@onready var _item_preview: TextureRect = $Margin/CenterBox/ItemPreview

static func calc_stars(progresses: Array[float]) -> int:
	if progresses.is_empty():
		return 1
	var total: float = 0.0
	for p in progresses:
		total += p
	var average: float = total / float(progresses.size())
	if average >= RATING_3_MIN:
		return 3
	if average >= RATING_2_MIN:
		return 2
	return 1

static func calc_reward(stars: int) -> int:
	return BASE_REWARD * stars

static func stars_text(stars: int) -> String:
	return "★".repeat(stars) + "☆".repeat(STARS_MAX - stars)

func setup(progresses: Array[float], item_number: int = 1, total_items: int = 1) -> void:
	_progresses = progresses.duplicate()
	_stars = calc_stars(_progresses)
	_reward = calc_reward(_stars)
	_item_number = item_number
	_total_items = total_items
	_summary_mode = false
	if is_node_ready():
		_refresh()

func setup_summary(stars_per_item: Array[int], total_coins: int) -> void:
	_summary_stars = stars_per_item.duplicate()
	_summary_coins = total_coins
	_summary_mode = true
	if is_node_ready():
		_refresh()

func _enter_tree() -> void:
	var btn_hub: Button = $Margin/CenterBox/Buttons/BtnHub
	if not btn_hub.pressed.is_connected(_on_hub_pressed):
		btn_hub.pressed.connect(_on_hub_pressed)
	var btn_sell: Button = $Margin/CenterBox/Buttons/BtnSell
	if not btn_sell.pressed.is_connected(_on_sell_pressed):
		btn_sell.pressed.connect(_on_sell_pressed)
	var btn_museum: Button = $Margin/CenterBox/Buttons/BtnMuseum
	if not btn_museum.pressed.is_connected(_on_museum_pressed):
		btn_museum.pressed.connect(_on_museum_pressed)
	var btn_double: Button = $Margin/CenterBox/Buttons/BtnDouble
	if not btn_double.pressed.is_connected(_on_double_pressed):
		btn_double.pressed.connect(_on_double_pressed)

func _exit_tree() -> void:
	var btn_hub: Button = $Margin/CenterBox/Buttons/BtnHub
	if btn_hub.pressed.is_connected(_on_hub_pressed):
		btn_hub.pressed.disconnect(_on_hub_pressed)
	var btn_sell: Button = $Margin/CenterBox/Buttons/BtnSell
	if btn_sell.pressed.is_connected(_on_sell_pressed):
		btn_sell.pressed.disconnect(_on_sell_pressed)
	var btn_museum: Button = $Margin/CenterBox/Buttons/BtnMuseum
	if btn_museum.pressed.is_connected(_on_museum_pressed):
		btn_museum.pressed.disconnect(_on_museum_pressed)
	var btn_double: Button = $Margin/CenterBox/Buttons/BtnDouble
	if btn_double.pressed.is_connected(_on_double_pressed):
		btn_double.pressed.disconnect(_on_double_pressed)

func _ready() -> void:
	_refresh()
	_play_star_sounds()

func _play_star_sounds() -> void:
	var total: int = _stars
	if _summary_mode:
		total = 0
		for s in _summary_stars:
			total += s
	for i in total:
		get_tree().create_timer(STAR_SOUND_STEP * i).timeout.connect(SFX.play.bind("star"))

func _refresh() -> void:
	var btn_sell: Button = $Margin/CenterBox/Buttons/BtnSell
	var btn_museum: Button = $Margin/CenterBox/Buttons/BtnMuseum
	var btn_double: Button = $Margin/CenterBox/Buttons/BtnDouble
	var btn_hub: Button = $Margin/CenterBox/Buttons/BtnHub
	var title: Label = $Margin/CenterBox/Title
	_item_preview.texture = item_texture
	_item_preview.visible = not _summary_mode and item_texture != null
	if _summary_mode:
		title.text = "Сессия завершена"
		var parts: PackedStringArray = []
		for i in _summary_stars.size():
			parts.append("Предмет %d: %s" % [i + 1, stars_text(_summary_stars[i])])
		_stars_label.text = "  ".join(parts)
		_summary_label.text = "Предметов реставрировано: %d" % _summary_stars.size()
		_reward_label.text = "Итого за сессию: %d монет" % _summary_coins
		_status_label.text = ""
		btn_sell.visible = false
		btn_museum.visible = false
		btn_double.visible = false
		btn_hub.visible = true
		return
	title.text = "Предмет %d из %d" % [_item_number, _total_items]
	_stars_label.text = stars_text(_stars)
	_summary_label.text = "Очистка: %d%% · Сборка: %d%% · Полировка: %d%%" % [_percent(0), _percent(1), _percent(2)]
	_reward_label.text = "Награда: %d монет" % _reward
	btn_sell.visible = true
	btn_museum.visible = true
	btn_double.visible = true
	btn_hub.visible = false

func _percent(index: int) -> int:
	if index >= _progresses.size():
		return 0
	return int(round(_progresses[index] * 100.0))

func _on_sell_pressed() -> void:
	sell_requested.emit(_reward)

func _on_double_pressed() -> void:
	YandexSDK.show_rewarded_ad(_on_double_ad_result)

func _on_double_ad_result(viewed: bool) -> void:
	if viewed:
		_status_label.text = ""
		double_requested.emit(_reward * 2)
	else:
		_status_label.text = "Реклама недоступна, награда не удвоена"

func _on_museum_pressed() -> void:
	museum_requested.emit()

func _on_hub_pressed() -> void:
	hub_requested.emit()
