extends Control
## DailyRewardScreen — экран ежедневной награды (Шаг 5c, D-017).
## Состояние дней берётся из DayCycle; подписка на daily_reward_state_changed — в _enter_tree().

signal back_requested

const SFX := preload("res://scripts/fx/SfxGenerator.gd")
const WORKSHOP_THEME := preload("res://scripts/ui/WorkshopTheme.gd")
const ITEM_ART := preload("res://scripts/gameplay/ItemArt.gd")
const GRID_COLUMNS: int = 4
const CARD_MIN_HEIGHT: int = 96
const CARD_FONT_SIZE: int = 14
const CARD_CORNER_RADIUS: int = 8
const COIN_ICON_SIZE: int = 32
const SEVENTH_DAY_INDEX: int = 6
const COLOR_RECEIVED: Color = WORKSHOP_THEME.BG_GRADIENT_END
const COLOR_TODAY: Color = WORKSHOP_THEME.PANEL_BG
const COLOR_LOCKED: Color = WORKSHOP_THEME.PANEL_BG

const STATE_RECEIVED: int = 0
const STATE_TODAY: int = 1
const STATE_LOCKED: int = 2

@onready var _grid: GridContainer = $Margin/Root/Grid
@onready var _message: Label = $Margin/Root/Message
@onready var _btn_claim: Button = $Margin/Root/BtnClaim

var _coin_texture: Texture2D = null


func _enter_tree() -> void:
	var btn_back: Button = $Margin/Root/TopRow/BtnBack
	if not btn_back.pressed.is_connected(_on_back_pressed):
		btn_back.pressed.connect(_on_back_pressed)
	var btn_claim: Button = $Margin/Root/BtnClaim
	if not btn_claim.pressed.is_connected(_on_claim_pressed):
		btn_claim.pressed.connect(_on_claim_pressed)
	if not DayCycle.daily_reward_state_changed.is_connected(_refresh):
		DayCycle.daily_reward_state_changed.connect(_refresh)


func _exit_tree() -> void:
	var btn_back: Button = $Margin/Root/TopRow/BtnBack
	if btn_back.pressed.is_connected(_on_back_pressed):
		btn_back.pressed.disconnect(_on_back_pressed)
	var btn_claim: Button = $Margin/Root/BtnClaim
	if btn_claim.pressed.is_connected(_on_claim_pressed):
		btn_claim.pressed.disconnect(_on_claim_pressed)
	if DayCycle.daily_reward_state_changed.is_connected(_refresh):
		DayCycle.daily_reward_state_changed.disconnect(_refresh)


func _ready() -> void:
	_coin_texture = ITEM_ART.load_icon("res://assets/ui/icon_coin.png")
	_refresh()


func _on_back_pressed() -> void:
	back_requested.emit()


func _on_claim_pressed() -> void:
	var index: int = DayCycle.get_today_index()
	if not DayCycle.claim_daily_reward():
		return
	var text: String = "+%d монет" % DayCycle.REWARD_COINS[index]
	if index == SEVENTH_DAY_INDEX:
		text += "\n+ Полироль"
	SFX.play("reward")
	_message.text = text


func _refresh() -> void:
	if not is_node_ready():
		return
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()

	var available: bool = DayCycle.is_daily_reward_available()
	var today_index: int = DayCycle.get_today_index()
	for i in range(DayCycle.DAILY_CYCLE_LENGTH):
		_grid.add_child(_build_card(i, _card_state(i, today_index, available)))

	_btn_claim.disabled = not available


func _card_state(index: int, today_index: int, available: bool) -> int:
	if index < today_index or (index == today_index and not available):
		return STATE_RECEIVED
	if index == today_index:
		return STATE_TODAY
	return STATE_LOCKED


func _build_card(index: int, state: int) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, CARD_MIN_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _card_style(state))

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(box)

	box.add_child(_make_label("День %d" % (index + 1), CARD_FONT_SIZE + 2))
	box.add_child(_make_coin_row(DayCycle.REWARD_COINS[index]))
	if index == SEVENTH_DAY_INDEX:
		box.add_child(_make_label("+ Полироль", CARD_FONT_SIZE))
	box.add_child(_make_label(_state_text(state), CARD_FONT_SIZE))
	return card


func _card_style(state: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _state_color(state)
	style.set_corner_radius_all(CARD_CORNER_RADIUS)
	style.set_border_width_all(WORKSHOP_THEME.PANEL_BORDER_WIDTH)
	style.border_color = WORKSHOP_THEME.PANEL_BORDER
	if state == STATE_TODAY:
		style.set_border_width_all(3)
		style.border_color = WORKSHOP_THEME.COPPER_GOLD
	return style


func _make_coin_row(coins: int) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(COIN_ICON_SIZE, COIN_ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _coin_texture
	row.add_child(icon)
	row.add_child(_make_label(str(coins), CARD_FONT_SIZE))
	return row


func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", WORKSHOP_THEME.TEXT_MAIN)
	return label


func _state_color(state: int) -> Color:
	match state:
		STATE_RECEIVED:
			return COLOR_RECEIVED
		STATE_TODAY:
			return COLOR_TODAY
		_:
			return COLOR_LOCKED


func _state_text(state: int) -> String:
	match state:
		STATE_RECEIVED:
			return "получено"
		STATE_TODAY:
			return "доступно сегодня"
		_:
			return "не открыто"
