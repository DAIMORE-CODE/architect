class_name ButtonFx
extends RefCounted
## Короткая обратная связь: нажатие кнопки и появление экрана (pop-in).
## Твины не хранятся в полях: они привязаны к узлу через meta.

const PRESS_SCALE := Vector2(0.96, 0.96)
const PRESS_DOWN_SEC: float = 0.06
const PRESS_UP_SEC: float = 0.1
const POP_FROM_SCALE := Vector2(0.9, 0.9)
const POP_SEC: float = 0.25
const PRESS_TWEEN_META := "fx_press_tween"

const SFX := preload("res://scripts/fx/SfxGenerator.gd")

static func attach(button: Button) -> void:
	_keep_pivot_centered(button)
	var on_down := _press_down.bind(button)
	if not button.button_down.is_connected(on_down):
		button.button_down.connect(on_down)
	var on_up := _press_up.bind(button)
	if not button.button_up.is_connected(on_up):
		button.button_up.connect(on_up)

static func pop_in(node: Control) -> void:
	_keep_pivot_centered(node)
	node.scale = POP_FROM_SCALE
	node.modulate.a = 0.0
	var tween := node.create_tween().set_parallel(true)
	tween.tween_property(node, "scale", Vector2.ONE, POP_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 1.0, POP_SEC)

static func _keep_pivot_centered(node: Control) -> void:
	node.pivot_offset = node.size / 2.0
	var on_resized := _recenter_pivot.bind(node)
	if not node.resized.is_connected(on_resized):
		node.resized.connect(on_resized)

static func _recenter_pivot(node: Control) -> void:
	node.pivot_offset = node.size / 2.0

static func _press_down(button: Button) -> void:
	SFX.play("click")
	# Предыдущий твин убиваем вручную: иначе быстрые повторные нажатия наложатся друг на друга.
	_kill_press_tween(button)
	var tween := button.create_tween()
	tween.tween_property(button, "scale", PRESS_SCALE, PRESS_DOWN_SEC)
	button.set_meta(PRESS_TWEEN_META, tween)

static func _press_up(button: Button) -> void:
	_kill_press_tween(button)
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2.ONE, PRESS_UP_SEC)
	button.set_meta(PRESS_TWEEN_META, tween)

static func _kill_press_tween(button: Button) -> void:
	if not button.has_meta(PRESS_TWEEN_META):
		return
	var old := button.get_meta(PRESS_TWEEN_META) as Tween
	if old != null and old.is_valid():
		old.kill()
