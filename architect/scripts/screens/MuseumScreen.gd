extends Control
## MuseumScreen — экран музея. Найденные предметы показывают арт assets/items, остальные — силуэты.
## Данные берутся из MuseumCatalog и GameData; подписка на collection_changed — в _enter_tree().

signal back_requested

const GRID_COLUMNS: int = 4
const GRID_SEPARATION: int = 8
const CELL_FONT_SIZE: int = 12
const CELL_MIN_HEIGHT: int = 96
const CELL_CORNER_RADIUS: int = 8
const CELL_SEPARATION: int = 4
const WORKSHOP_THEME := preload("res://scripts/ui/WorkshopTheme.gd")
const ITEM_SILHOUETTE := preload("res://scripts/ui/ItemSilhouette.gd")
const CATALOG := preload("res://scripts/data/MuseumCatalog.gd")
const ITEM_ART := preload("res://scripts/gameplay/ItemArt.gd")

var _art_cache: Dictionary = {}

@onready var _count_label: Label = $Margin/Root/TopRow/Title
@onready var _categories_box: VBoxContainer = $Margin/Root/Scroll/Categories


func _enter_tree() -> void:
	var btn_back: Button = $Margin/Root/TopRow/BtnBack
	if not btn_back.pressed.is_connected(_on_back_pressed):
		btn_back.pressed.connect(_on_back_pressed)
	if not GameData.collection_changed.is_connected(_on_collection_changed):
		GameData.collection_changed.connect(_on_collection_changed)


func _exit_tree() -> void:
	var btn_back: Button = $Margin/Root/TopRow/BtnBack
	if btn_back.pressed.is_connected(_on_back_pressed):
		btn_back.pressed.disconnect(_on_back_pressed)
	if GameData.collection_changed.is_connected(_on_collection_changed):
		GameData.collection_changed.disconnect(_on_collection_changed)


func _ready() -> void:
	_refresh()


func _on_back_pressed() -> void:
	back_requested.emit()


func _on_collection_changed(_item_id: String) -> void:
	_refresh()


func _refresh() -> void:
	for child in _categories_box.get_children():
		_categories_box.remove_child(child)
		child.queue_free()

	var collected: int = 0
	for category in CATALOG.get_categories():
		var category_id: String = category["id"]
		var category_title: String = category["title"]
		var count: int = CATALOG.count_in_category(category_id)
		collected += count
		_build_category(category_id, category_title, count, CATALOG.total_in_category(category_id))

	_count_label.text = "Музей (%d/%d)" % [collected, CATALOG.ITEMS.size()]


func _build_category(category_id: String, category_title: String, count: int, total: int) -> void:
	var header := Label.new()
	header.text = "%s %d/%d" % [category_title, count, total]
	_categories_box.add_child(header)

	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.min_value = 0.0
	bar.max_value = float(total)
	bar.value = float(count)
	bar.show_percentage = false
	_categories_box.add_child(bar)

	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", GRID_SEPARATION)
	grid.add_theme_constant_override("v_separation", GRID_SEPARATION)
	_categories_box.add_child(grid)

	var color: Color = CATALOG.get_category_color(category_id)
	for item in CATALOG.ITEMS:
		if item["category"] != category_id:
			continue
		var item_id: String = item["id"]
		var item_name: String = item["name"]
		grid.add_child(_build_cell(item_id, item_name, color))


func _get_art_texture(item_id: String) -> Texture2D:
	if not _art_cache.has(item_id):
		var img := ITEM_ART.load_cutout(item_id)
		_art_cache[item_id] = ImageTexture.create_from_image(img) if img != null else null
	return _art_cache[item_id]


func _build_cell(item_id: String, item_name: String, color: Color) -> Control:
	var found: bool = GameData.museum_items.has(item_id)

	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(0, CELL_MIN_HEIGHT)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = WORKSHOP_THEME.PANEL_BG
	style.set_corner_radius_all(CELL_CORNER_RADIUS)
	cell.add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", CELL_SEPARATION)
	cell.add_child(column)

	var visual: Control
	if found:
		var art := TextureRect.new()
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		art.size_flags_vertical = Control.SIZE_EXPAND_FILL
		art.custom_minimum_size = Vector2(0, CELL_MIN_HEIGHT * 0.6)
		art.texture = _get_art_texture(item_id)
		visual = art
	else:
		var silhouette: ITEM_SILHOUETTE = ITEM_SILHOUETTE.new()
		silhouette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		silhouette.size_flags_vertical = Control.SIZE_EXPAND_FILL
		silhouette.custom_minimum_size = Vector2(0, CELL_MIN_HEIGHT * 0.6)
		silhouette.setup(item_id, color, false)
		visual = silhouette
	column.add_child(visual)

	var label := Label.new()
	label.text = item_name
	label.visible = found
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.add_theme_font_size_override("font_size", CELL_FONT_SIZE)
	label.add_theme_color_override("font_color", WORKSHOP_THEME.TEXT_MAIN)
	column.add_child(label)
	return cell
