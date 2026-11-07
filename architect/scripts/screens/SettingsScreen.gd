extends Control
## SettingsScreen — громкость эффектов и вибрация (Шаг 7c). Строится кодом, без .tscn.
## Значения сохраняются через SaveManager; громкость применяется к шине SFX.

const SFX := preload("res://scripts/fx/SfxGenerator.gd")
const SCREEN_MARGIN: int = 32
const SECTION_SEPARATION: int = 24
const ROW_MIN_HEIGHT: float = 56.0
const BUTTON_MIN_HEIGHT: float = 72.0
const TITLE_FONT_SIZE: int = 36
const VOLUME_STEP: float = 5.0

signal back_requested
signal music_toggled(pressed: bool)

var _sfx_slider: HSlider
var _sfx_value: Label
var _music_slider: HSlider
var _music_value: Label
var _vibration_toggle: CheckButton
var _music_toggle: CheckButton
var _back_button: Button

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, SCREEN_MARGIN)
	add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", SECTION_SEPARATION)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Настройки"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	box.add_child(title)

	var volume_caption := Label.new()
	volume_caption.text = "Громкость эффектов"
	box.add_child(volume_caption)

	var sfx_row := HBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", SECTION_SEPARATION)
	box.add_child(sfx_row)

	_sfx_slider = HSlider.new()
	_sfx_slider.min_value = 0.0
	_sfx_slider.max_value = 100.0
	_sfx_slider.step = VOLUME_STEP
	_sfx_slider.value = float(SaveManager.get_setting("sfx_volume"))
	_sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sfx_slider.custom_minimum_size = Vector2(0.0, ROW_MIN_HEIGHT)
	sfx_row.add_child(_sfx_slider)

	_sfx_value = Label.new()
	_sfx_value.text = "%d%%" % int(_sfx_slider.value)
	_sfx_value.custom_minimum_size = Vector2(72.0, 0.0)
	_sfx_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sfx_row.add_child(_sfx_value)

	var music_caption := Label.new()
	music_caption.text = "Громкость музыки"
	box.add_child(music_caption)

	var music_row := HBoxContainer.new()
	music_row.add_theme_constant_override("separation", SECTION_SEPARATION)
	box.add_child(music_row)

	_music_slider = HSlider.new()
	_music_slider.min_value = 0.0
	_music_slider.max_value = 100.0
	_music_slider.step = VOLUME_STEP
	_music_slider.value = float(SaveManager.get_setting("music_volume"))
	_music_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_music_slider.custom_minimum_size = Vector2(0.0, ROW_MIN_HEIGHT)
	music_row.add_child(_music_slider)

	_music_value = Label.new()
	_music_value.text = "%d%%" % int(_music_slider.value)
	_music_value.custom_minimum_size = Vector2(72.0, 0.0)
	_music_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	music_row.add_child(_music_value)

	_vibration_toggle = CheckButton.new()
	_vibration_toggle.text = "Вибрация (Android)"
	_vibration_toggle.button_pressed = bool(SaveManager.get_setting("vibration"))
	_vibration_toggle.custom_minimum_size = Vector2(0.0, ROW_MIN_HEIGHT)
	box.add_child(_vibration_toggle)

	_music_toggle = CheckButton.new()
	_music_toggle.text = "Музыка"
	_music_toggle.button_pressed = bool(SaveManager.get_setting("music_enabled"))
	_music_toggle.custom_minimum_size = Vector2(0.0, ROW_MIN_HEIGHT)
	box.add_child(_music_toggle)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	_back_button = Button.new()
	_back_button.text = "Назад"
	_back_button.custom_minimum_size = Vector2(0.0, BUTTON_MIN_HEIGHT)
	box.add_child(_back_button)

func _enter_tree() -> void:
	if not _sfx_slider.value_changed.is_connected(_on_sfx_volume_changed):
		_sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	if not _music_slider.value_changed.is_connected(_on_music_volume_changed):
		_music_slider.value_changed.connect(_on_music_volume_changed)
	if not _vibration_toggle.toggled.is_connected(_on_vibration_toggled):
		_vibration_toggle.toggled.connect(_on_vibration_toggled)
	if not _music_toggle.toggled.is_connected(_on_music_toggled):
		_music_toggle.toggled.connect(_on_music_toggled)
	if not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)

func _exit_tree() -> void:
	if _sfx_slider.value_changed.is_connected(_on_sfx_volume_changed):
		_sfx_slider.value_changed.disconnect(_on_sfx_volume_changed)
	if _music_slider.value_changed.is_connected(_on_music_volume_changed):
		_music_slider.value_changed.disconnect(_on_music_volume_changed)
	if _vibration_toggle.toggled.is_connected(_on_vibration_toggled):
		_vibration_toggle.toggled.disconnect(_on_vibration_toggled)
	if _music_toggle.toggled.is_connected(_on_music_toggled):
		_music_toggle.toggled.disconnect(_on_music_toggled)
	if _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.disconnect(_on_back_pressed)

func _on_sfx_volume_changed(value: float) -> void:
	SaveManager.set_setting("sfx_volume", int(value))
	_sfx_value.text = "%d%%" % int(value)
	SFX.setup_audio()

func _on_music_volume_changed(value: float) -> void:
	SaveManager.set_setting("music_volume", int(value))
	_music_value.text = "%d%%" % int(value)
	SFX.setup_audio()

func _on_vibration_toggled(pressed: bool) -> void:
	SaveManager.set_setting("vibration", pressed)

func _on_music_toggled(pressed: bool) -> void:
	SaveManager.set_setting("music_enabled", pressed)
	music_toggled.emit(pressed)

func _on_back_pressed() -> void:
	back_requested.emit()
