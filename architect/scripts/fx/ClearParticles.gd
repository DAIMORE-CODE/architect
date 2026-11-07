class_name ClearParticles
extends RefCounted

const LIFETIME: float = 0.4
const EXPLOSIVENESS: float = 0.9
const VELOCITY_MIN: float = 60.0
const VELOCITY_MAX: float = 120.0
const SCALE_MIN: float = 2.0
const SCALE_MAX: float = 4.0
const CLEANUP_PADDING: float = 0.1

static func burst(parent: Node, at: Vector2, color: Color, amount: int = 12) -> void:
	var layer := parent as CanvasItem
	if layer == null or not layer.is_inside_tree():
		return
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.emitting = true
	particles.amount = amount
	particles.lifetime = LIFETIME
	particles.explosiveness = EXPLOSIVENESS
	particles.spread = 180.0
	particles.initial_velocity_min = VELOCITY_MIN
	particles.initial_velocity_max = VELOCITY_MAX
	particles.scale_amount_min = SCALE_MIN
	particles.scale_amount_max = SCALE_MAX
	particles.color = color
	particles.position = at
	layer.add_child(particles)
	particles.finished.connect(particles.queue_free)
	layer.get_tree().create_timer(LIFETIME + CLEANUP_PADDING).timeout.connect(_free_if_valid.bind(particles))

static func _free_if_valid(node: CPUParticles2D) -> void:
	if is_instance_valid(node):
		node.queue_free()
