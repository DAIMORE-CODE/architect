class_name ShardCatalog
extends RefCounted
## Осколки предмета: лист assets/shards/<id>_sheet.png делится на 2×2 квадранта.

const SHARD_COUNT: int = 4
const SHEET_SIZE: int = 1024
const QUAD: int = 512
const SHEET_DIR: String = "res://assets/shards/"

static var _cache: Dictionary = {}

## Возвращает 4 осколка (по одному на квадрант) или пустой массив, если лист не найден.
static func load_shards(item_id: String) -> Array[Dictionary]:
	if _cache.has(item_id):
		return _cache[item_id]
	var result: Array[Dictionary] = []
	var path := "%s%s_sheet.png" % [SHEET_DIR, item_id]
	if not FileAccess.file_exists(path):
		push_error("Shard sheet missing: " + path)
		return result
	var tex := load(path) as Texture2D
	if tex == null:
		push_error("Shard sheet failed to load: " + path)
		return result
	var sheet := tex.get_image()
	if sheet == null:
		push_error("Shard sheet has no image data: " + path)
		return result
	sheet.convert(Image.FORMAT_RGBA8)
	for quad in range(SHARD_COUNT):
		result.append(_cut_quad(sheet, quad))
	_cache[item_id] = result
	return result

static func _cut_quad(sheet: Image, quad: int) -> Dictionary:
	var col: int = quad % 2
	var row: int = quad >> 1
	var img := sheet.get_region(Rect2i(col * QUAD, row * QUAD, QUAD, QUAD))
	ItemArt.remove_background(img)
	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		used = Rect2i(0, 0, QUAD, QUAD)
	var cropped := img.get_region(used)
	return {
		"texture": ImageTexture.create_from_image(cropped),
		"offset": Vector2(used.position),
		"quad": quad,
	}
