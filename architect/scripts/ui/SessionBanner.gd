extends Label
## SessionBanner — строка сверху этапа со счётчиком «Предмет N/3». Инструкции показывает TutorialPopup.
## Верх строки под верхней панелью (TopBar заканчивается на 56 px) и её высота.
const BASE_TOP: float = 58.0
const BAR_HEIGHT: float = 24.0
const FONT_SIZE: int = 15
const TEXT_COLOR: Color = Color(1.0, 0.965, 0.9, 1.0)
const OUTLINE_COLOR: Color = Color(0.2, 0.14, 0.09, 1.0)
const OUTLINE_SIZE: int = 4

func _init(counter_text: String = "") -> void:
	text = counter_text
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", FONT_SIZE)
	add_theme_color_override("font_color", TEXT_COLOR)
	add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	add_theme_constant_override("outline_size", OUTLINE_SIZE)

func _enter_tree() -> void:
	var top := BASE_TOP + _safe_top_inset()
	offset_top = top
	offset_bottom = top + BAR_HEIGHT

## Отступ от выреза/статус-бара: safe area в пикселях экрана переводится в координаты viewport.
func _safe_top_inset() -> float:
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if safe.size.x <= 0 or screen.y <= 0:
		return 0.0
	var viewport_h := get_viewport_rect().size.y
	return maxf(0.0, float(safe.position.y) * viewport_h / float(screen.y))


