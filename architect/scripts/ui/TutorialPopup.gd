class_name TutorialPopup
extends Control
## Попап «Как играть»: затемняет этап и перехватывает ввод до нажатия «Понятно».

signal closed

const PANEL_WIDTH: float = 440.0
const TITLE_TEXT: String = "Как играть"
const TITLE_SIZE: int = 28
const BODY_SIZE: int = 22
const SHADE_COLOR: Color = Color(0.12, 0.08, 0.05, 0.6)
const CONTENT_SEPARATION: int = 18
const BUTTON_MIN_HEIGHT: float = 72.0

var _body_text: String
var _ok_button: Button

func _init(body_text: String) -> void:
	_body_text = body_text
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var shade := ColorRect.new()
	shade.color = SHADE_COLOR
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", CONTENT_SEPARATION)
	panel.add_child(box)

	var title := Label.new()
	title.text = TITLE_TEXT
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	box.add_child(title)

	var body := Label.new()
	body.text = _body_text
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", BODY_SIZE)
	box.add_child(body)

	_ok_button = Button.new()
	_ok_button.text = "Понятно"
	_ok_button.custom_minimum_size = Vector2(0.0, BUTTON_MIN_HEIGHT)
	box.add_child(_ok_button)

func _enter_tree() -> void:
	if not _ok_button.pressed.is_connected(_on_ok_pressed):
		_ok_button.pressed.connect(_on_ok_pressed)

func _exit_tree() -> void:
	if _ok_button.pressed.is_connected(_on_ok_pressed):
		_ok_button.pressed.disconnect(_on_ok_pressed)

func _on_ok_pressed() -> void:
	closed.emit()
	queue_free()
