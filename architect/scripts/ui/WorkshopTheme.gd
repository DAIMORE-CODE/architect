class_name WorkshopTheme
extends RefCounted
## WorkshopTheme — визуальная тема «Тёплая мастерская» (Шаг 7a, D-018/D-019).
## Палитра задана константами здесь. Тема строится один раз в Main._ready()
## и применяется ко всему дереву экранов через поле theme корневого Control.

const BG_MAIN := Color(0.914, 0.863, 0.769, 1.0)
const BG_GRADIENT_END := Color(0.847, 0.769, 0.627, 1.0)
const WOOD_DARK := Color(0.420, 0.290, 0.184, 1.0)
const BTN_NORMAL := Color(0.659, 0.455, 0.247, 1.0)
const BTN_HOVER := Color(0.725, 0.526, 0.314, 1.0)
const BTN_PRESSED := Color(0.549, 0.373, 0.200, 1.0)
const BTN_DISABLED := Color(0.725, 0.659, 0.561, 1.0)
const COPPER_GOLD := Color(0.851, 0.643, 0.255, 1.0)
const TEXT_MAIN := Color(0.231, 0.165, 0.110, 1.0)
const TEXT_ON_DARK := Color(1.0, 0.965, 0.902, 1.0)
const PANEL_BG := Color(0.961, 0.922, 0.851, 1.0)
const PANEL_BORDER := Color(0.549, 0.416, 0.275, 1.0)
const DANGER := Color(0.753, 0.224, 0.169, 1.0)

const PANEL_RADIUS := 14
const PANEL_BORDER_WIDTH := 2
const BUTTON_RADIUS := 12
const BUTTON_CONTENT_MARGIN := 10
const PRIMARY_BUTTON_TYPE := "PrimaryButton"
const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const ACCENT_HOVER := Color(0.901, 0.693, 0.305, 1.0)
const ACCENT_PRESSED := Color(0.801, 0.593, 0.205, 1.0)

static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = load(FONT_PATH) as Font
	_setup_button(theme)
	_setup_panel(theme)
	_setup_label(theme)
	_setup_progress_bar(theme)
	return theme

static func _flat(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(BUTTON_RADIUS)
	sb.set_content_margin_all(10)
	return sb

static func _setup_button(theme: Theme) -> void:
	theme.set_stylebox("normal", "Button", _flat(BTN_NORMAL))
	theme.set_stylebox("hover", "Button", _flat(BTN_HOVER))
	theme.set_stylebox("pressed", "Button", _flat(BTN_PRESSED))
	theme.set_stylebox("disabled", "Button", _flat(BTN_DISABLED))
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_border_width_all(PANEL_BORDER_WIDTH)
	focus.border_color = WOOD_DARK
	focus.set_corner_radius_all(BUTTON_RADIUS)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_color("font_color", "Button", TEXT_ON_DARK)
	theme.set_color("font_hover_color", "Button", TEXT_ON_DARK)
	theme.set_color("font_pressed_color", "Button", TEXT_ON_DARK)
	theme.set_color("font_focus_color", "Button", TEXT_ON_DARK)
	theme.set_color("font_disabled_color", "Button", TEXT_MAIN)
	_setup_primary_button(theme)

static func _setup_primary_button(theme: Theme) -> void:
	theme.set_type_variation(PRIMARY_BUTTON_TYPE, "Button")
	theme.set_stylebox("normal", PRIMARY_BUTTON_TYPE, _flat(COPPER_GOLD))
	theme.set_stylebox("hover", PRIMARY_BUTTON_TYPE, _flat(ACCENT_HOVER))
	theme.set_stylebox("pressed", PRIMARY_BUTTON_TYPE, _flat(ACCENT_PRESSED))
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(color_name, PRIMARY_BUTTON_TYPE, WOOD_DARK)

static func _setup_panel(theme: Theme) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_corner_radius_all(PANEL_RADIUS)
	sb.set_border_width_all(PANEL_BORDER_WIDTH)
	sb.border_color = PANEL_BORDER
	sb.set_content_margin_all(8)
	theme.set_stylebox("panel", "PanelContainer", sb)

static func _setup_label(theme: Theme) -> void:
	theme.set_color("font_color", "Label", TEXT_MAIN)

static func _setup_progress_bar(theme: Theme) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = PANEL_BG
	bg.set_corner_radius_all(PANEL_RADIUS)
	bg.set_border_width_all(PANEL_BORDER_WIDTH)
	bg.border_color = PANEL_BORDER
	var fill := StyleBoxFlat.new()
	fill.bg_color = COPPER_GOLD
	fill.set_corner_radius_all(PANEL_RADIUS)
	theme.set_stylebox("background", "ProgressBar", bg)
	theme.set_stylebox("fill", "ProgressBar", fill)
