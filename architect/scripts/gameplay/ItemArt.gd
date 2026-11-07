class_name ItemArt
extends RefCounted

const ART_MAX_SIDE: int = 512
const BG_TOLERANCE: float = 0.12

## Загружает арт предмета через импорт, уменьшает и вырезает фон.
static func load_cutout(id: String) -> Image:
	var tex := load("res://assets/items/%s.png" % id) as Texture2D
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var longest := maxi(img.get_width(), img.get_height())
	if longest > ART_MAX_SIDE:
		var k := float(ART_MAX_SIDE) / float(longest)
		img.resize(roundi(img.get_width() * k), roundi(img.get_height() * k), Image.INTERPOLATE_BILINEAR)
	remove_background(img)
	return img

## Иконка интерфейса (assets/ui): кремовый фон убирается той же заливкой от краёв.
static func load_icon(path: String) -> Texture2D:
	var tex := load(path) as Texture2D
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	remove_background(img)
	return ImageTexture.create_from_image(img)

## Заливка от краёв: пиксели, близкие к цвету фона (среднее по углам), становятся прозрачными.
static func remove_background(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var bg := (img.get_pixel(0, 0) + img.get_pixel(w - 1, 0) + img.get_pixel(0, h - 1) + img.get_pixel(w - 1, h - 1)) * 0.25
	var visited := PackedByteArray()
	visited.resize(w * h)
	visited.fill(0)
	var stack := PackedInt32Array()
	for x in range(w):
		stack.append(x)
		stack.append((h - 1) * w + x)
	for y in range(h):
		stack.append(y * w)
		stack.append(y * w + w - 1)
	while not stack.is_empty():
		var i: int = stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		if visited[i] == 1:
			continue
		visited[i] = 1
		var x: int = i % w
		var y: int = floori(float(i) / float(w))
		var c := img.get_pixel(x, y)
		if not _is_background(c, bg):
			continue
		img.set_pixel(x, y, Color(c.r, c.g, c.b, 0.0))
		if x > 0:
			stack.append(i - 1)
		if x < w - 1:
			stack.append(i + 1)
		if y > 0:
			stack.append(i - w)
		if y < h - 1:
			stack.append(i + w)

static func _is_background(c: Color, bg: Color) -> bool:
	return Vector3(c.r - bg.r, c.g - bg.g, c.b - bg.b).length() < BG_TOLERANCE
