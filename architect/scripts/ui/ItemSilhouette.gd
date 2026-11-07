class_name ItemSilhouette
extends Control
## ItemSilhouette — форма предмета музея (Шаг 7b), рисуется процедурно без текстур.
## Формы заданы в координатах 0..1 внутри квадрата и рисуются слоями по порядку:
## fill — заливка, hole — вырез цвета фона, line — штрих.

const WORKSHOP_THEME := preload("res://scripts/ui/WorkshopTheme.gd")
const LOCKED_COLOR := Color(0.290, 0.227, 0.173, 1.0)
const SHADE_FACTOR := 0.75
const SIDE_RATIO := 0.8
const OUTLINE_WIDTH := 2.0
const ARC_STEPS := 20
const CORNER_STEPS := 5

var _item_id: String = ""
var _color: Color = Color.WHITE
var _found: bool = false


func setup(item_id: String, category_color: Color, found: bool) -> void:
	_item_id = item_id
	_color = category_color
	_found = found
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var ops: Array[Dictionary] = _ops_for(_item_id)
	if ops.is_empty():
		return
	var side: float = minf(size.x, size.y) * SIDE_RATIO
	var origin: Vector2 = (size - Vector2(side, side)) * 0.5
	var fill_color: Color = _color if _found else LOCKED_COLOR
	var edge_color: Color = Color(_color.r * SHADE_FACTOR, _color.g * SHADE_FACTOR, _color.b * SHADE_FACTOR, 1.0)
	var detail_color: Color = edge_color if _found else WORKSHOP_THEME.PANEL_BG
	for op in ops:
		var kind: String = op["kind"]
		var pts: PackedVector2Array = _to_px(op["pts"], origin, side)
		if kind == "fill":
			draw_colored_polygon(pts, fill_color)
			if _found:
				_outline(pts, edge_color)
		elif kind == "hole":
			draw_colored_polygon(pts, WORKSHOP_THEME.PANEL_BG)
			if _found:
				_outline(pts, edge_color)
		else:
			draw_polyline(pts, detail_color, OUTLINE_WIDTH)


func _outline(pts: PackedVector2Array, color: Color) -> void:
	if pts.is_empty():
		return
	var closed: PackedVector2Array = pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, color, OUTLINE_WIDTH)


func _to_px(src: PackedVector2Array, origin: Vector2, side: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in src:
		result.append(origin + p * side)
	return result


static func _f(pts: PackedVector2Array) -> Dictionary:
	return {"kind": "fill", "pts": pts}


static func _h(pts: PackedVector2Array) -> Dictionary:
	return {"kind": "hole", "pts": pts}


static func _l(pts: PackedVector2Array) -> Dictionary:
	return {"kind": "line", "pts": pts}


static func _seg(a: Vector2, b: Vector2) -> PackedVector2Array:
	return PackedVector2Array([a, b])


static func _poly(points: Array[Vector2]) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in points:
		pts.append(p)
	return pts


static func _ellipse(cx: float, cy: float, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(ARC_STEPS):
		var a: float = TAU * float(i) / float(ARC_STEPS)
		pts.append(Vector2(cx + rx * cos(a), cy + ry * sin(a)))
	return pts


static func _circle(cx: float, cy: float, r: float) -> PackedVector2Array:
	return _ellipse(cx, cy, r, r)


static func _rect(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])


static func _rrect(x: float, y: float, w: float, h: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var centers: Array[Vector2] = [
		Vector2(x + w - r, y + r),
		Vector2(x + w - r, y + h - r),
		Vector2(x + r, y + h - r),
		Vector2(x + r, y + r),
	]
	var starts: Array[float] = [-PI / 2.0, 0.0, PI / 2.0, PI]
	for c in range(4):
		for i in range(CORNER_STEPS + 1):
			var a: float = starts[c] + (PI / 2.0) * float(i) / float(CORNER_STEPS)
			pts.append(centers[c] + Vector2(r * cos(a), r * sin(a)))
	return pts


static func _arc(cx: float, cy: float, r: float, a0: float, a1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(ARC_STEPS + 1):
		var a: float = lerpf(a0, a1, float(i) / float(ARC_STEPS))
		pts.append(Vector2(cx + r * cos(a), cy + r * sin(a)))
	return pts


static func _ring_arc(cx: float, cy: float, r_out: float, r_in: float, a0: float, a1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(ARC_STEPS + 1):
		var a: float = lerpf(a0, a1, float(i) / float(ARC_STEPS))
		pts.append(Vector2(cx + r_out * cos(a), cy + r_out * sin(a)))
	for i in range(ARC_STEPS, -1, -1):
		var a: float = lerpf(a0, a1, float(i) / float(ARC_STEPS))
		pts.append(Vector2(cx + r_in * cos(a), cy + r_in * sin(a)))
	return pts


static func _frame() -> Array[Dictionary]:
	return [
		_f(_rect(0.08, 0.08, 0.84, 0.84)),
		_h(_rect(0.2, 0.2, 0.6, 0.6)),
	]


static func _ops_for(item_id: String) -> Array[Dictionary]:
	match item_id:
		"watch_pocket": return _watch_pocket()
		"watch_wall": return _watch_wall()
		"watch_alarm": return _watch_alarm()
		"watch_gold": return _watch_gold()
		"box_wood": return _box_wood()
		"box_lacquer": return _box_lacquer()
		"box_silver": return _box_silver()
		"box_music": return _box_music()
		"painting_landscape": return _painting_landscape()
		"painting_portrait": return _painting_portrait()
		"painting_still": return _painting_still()
		"jewel_brooch": return _jewel_brooch()
		"jewel_ring": return _jewel_ring()
		"jewel_necklace": return _jewel_necklace()
		"dish_plate": return _dish_plate()
		"dish_vase": return _dish_vase()
		"dish_cup": return _dish_cup()
		"instr_violin": return _instr_violin()
		"instr_guitar": return _instr_guitar()
		"instr_accordion": return _instr_accordion()
	var empty: Array[Dictionary] = []
	return empty


static func _watch_pocket() -> Array[Dictionary]:
	return [
		_f(_circle(0.5, 0.56, 0.32)),
		_f(_rect(0.44, 0.14, 0.12, 0.12)),
		_l(_seg(Vector2(0.5, 0.56), Vector2(0.5, 0.36))),
		_l(_seg(Vector2(0.5, 0.56), Vector2(0.64, 0.56))),
	]


static func _watch_wall() -> Array[Dictionary]:
	return [
		_f(_circle(0.5, 0.5, 0.42)),
		_f(_rect(0.46, 0.0, 0.08, 0.1)),
		_l(_seg(Vector2(0.5, 0.5), Vector2(0.5, 0.22))),
		_l(_seg(Vector2(0.5, 0.5), Vector2(0.7, 0.5))),
	]


static func _watch_alarm() -> Array[Dictionary]:
	return [
		_f(_circle(0.5, 0.6, 0.3)),
		_f(_circle(0.22, 0.2, 0.13)),
		_f(_circle(0.78, 0.2, 0.13)),
		_l(_seg(Vector2(0.5, 0.6), Vector2(0.5, 0.42))),
		_l(_seg(Vector2(0.5, 0.6), Vector2(0.64, 0.6))),
	]


static func _watch_gold() -> Array[Dictionary]:
	return [
		_f(_circle(0.5, 0.62, 0.3)),
		_f(_rect(0.46, 0.12, 0.08, 0.1)),
		_l(_arc(0.5, 0.62, 0.42, PI * 1.15, PI * 1.85)),
		_l(_seg(Vector2(0.5, 0.62), Vector2(0.5, 0.42))),
	]


static func _box_wood() -> Array[Dictionary]:
	return [
		_f(_rect(0.12, 0.42, 0.76, 0.44)),
		_f(_poly([Vector2(0.12, 0.42), Vector2(0.2, 0.22), Vector2(0.8, 0.22), Vector2(0.88, 0.42)])),
		_l(_seg(Vector2(0.12, 0.66), Vector2(0.88, 0.66))),
	]


static func _box_lacquer() -> Array[Dictionary]:
	return [
		_f(_rrect(0.1, 0.36, 0.8, 0.5, 0.12)),
		_f(_poly([Vector2(0.5, 0.1), Vector2(0.66, 0.24), Vector2(0.5, 0.38), Vector2(0.34, 0.24)])),
	]


static func _box_silver() -> Array[Dictionary]:
	return [
		_f(_rect(0.12, 0.4, 0.76, 0.46)),
		_f(_rect(0.12, 0.26, 0.76, 0.16)),
		_h(_rect(0.42, 0.46, 0.16, 0.18)),
	]


static func _box_music() -> Array[Dictionary]:
	return [
		_f(_rect(0.1, 0.5, 0.8, 0.36)),
		_f(_rect(0.1, 0.4, 0.8, 0.12)),
		_f(_rect(0.36, 0.14, 0.28, 0.26)),
		_f(_ellipse(0.5, 0.14, 0.14, 0.05)),
		_l(_seg(Vector2(0.2, 0.68), Vector2(0.8, 0.68))),
	]


static func _painting_landscape() -> Array[Dictionary]:
	var ops := _frame()
	ops.append(_f(_poly([Vector2(0.2, 0.8), Vector2(0.42, 0.38), Vector2(0.62, 0.8)])))
	ops.append(_f(_poly([Vector2(0.44, 0.8), Vector2(0.66, 0.46), Vector2(0.8, 0.8)])))
	return ops


static func _painting_portrait() -> Array[Dictionary]:
	var ops := _frame()
	ops.append(_f(_ellipse(0.5, 0.42, 0.13, 0.17)))
	ops.append(_f(_ellipse(0.5, 0.8, 0.24, 0.12)))
	return ops


static func _painting_still() -> Array[Dictionary]:
	var ops := _frame()
	ops.append(_f(_poly([Vector2(0.26, 0.6), Vector2(0.74, 0.6), Vector2(0.66, 0.74), Vector2(0.34, 0.74)])))
	ops.append(_f(_circle(0.4, 0.5, 0.08)))
	ops.append(_f(_circle(0.56, 0.48, 0.09)))
	return ops


static func _jewel_brooch() -> Array[Dictionary]:
	return [
		_f(_circle(0.5, 0.5, 0.34)),
		_h(_circle(0.5, 0.5, 0.18)),
		_l(_seg(Vector2(0.2, 0.8), Vector2(0.8, 0.2))),
	]


static func _jewel_ring() -> Array[Dictionary]:
	return [
		_f(_ellipse(0.5, 0.58, 0.4, 0.3)),
		_h(_ellipse(0.5, 0.58, 0.24, 0.16)),
		_f(_circle(0.5, 0.22, 0.09)),
	]


static func _jewel_necklace() -> Array[Dictionary]:
	var ops: Array[Dictionary] = []
	for i in range(7):
		var a: float = lerpf(PI * 0.2, PI * 0.8, float(i) / 6.0)
		ops.append(_f(_circle(0.5 - 0.42 * cos(a), 0.05 + 0.5 * sin(a), 0.06)))
	ops.append(_f(_circle(0.5, 0.7, 0.09)))
	return ops


static func _dish_plate() -> Array[Dictionary]:
	return [
		_f(_ellipse(0.5, 0.52, 0.42, 0.22)),
		_h(_ellipse(0.5, 0.52, 0.26, 0.12)),
	]


static func _dish_vase() -> Array[Dictionary]:
	return [
		_f(_poly([
			Vector2(0.42, 0.1), Vector2(0.58, 0.1), Vector2(0.58, 0.26), Vector2(0.74, 0.44),
			Vector2(0.8, 0.7), Vector2(0.7, 0.9), Vector2(0.3, 0.9), Vector2(0.2, 0.7),
			Vector2(0.26, 0.44), Vector2(0.42, 0.26),
		])),
		_l(_seg(Vector2(0.24, 0.6), Vector2(0.76, 0.6))),
	]


static func _dish_cup() -> Array[Dictionary]:
	return [
		_f(_poly([Vector2(0.14, 0.3), Vector2(0.86, 0.3), Vector2(0.74, 0.72), Vector2(0.26, 0.72)])),
		_f(_ring_arc(0.8, 0.5, 0.16, 0.09, -PI / 2.0, PI / 2.0)),
		_f(_rect(0.16, 0.74, 0.68, 0.06)),
	]


static func _instr_violin() -> Array[Dictionary]:
	return [
		_f(_ellipse(0.5, 0.66, 0.26, 0.24)),
		_f(_ellipse(0.5, 0.4, 0.19, 0.16)),
		_f(_rect(0.46, 0.04, 0.08, 0.4)),
		_f(_circle(0.5, 0.04, 0.06)),
		_l(_seg(Vector2(0.4, 0.62), Vector2(0.6, 0.62))),
	]


static func _instr_guitar() -> Array[Dictionary]:
	return [
		_f(_circle(0.42, 0.66, 0.24)),
		_f(_circle(0.62, 0.42, 0.18)),
		_f(_rect(0.5, 0.04, 0.08, 0.44)),
		_f(_rect(0.48, 0.0, 0.12, 0.08)),
		_h(_circle(0.42, 0.66, 0.08)),
	]


static func _instr_accordion() -> Array[Dictionary]:
	var ops: Array[Dictionary] = [
		_f(_rect(0.14, 0.3, 0.72, 0.5)),
		_f(_rect(0.2, 0.14, 0.26, 0.16)),
		_f(_rect(0.54, 0.14, 0.26, 0.16)),
	]
	for y in [0.42, 0.54, 0.66]:
		ops.append(_l(_seg(Vector2(0.14, y), Vector2(0.86, y))))
	return ops
