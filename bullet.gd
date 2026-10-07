extends Area2D

var velocity := Vector2.ZERO
var shooter: Node2D = null
var life := 2.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += velocity * delta
	life -= delta
	if life <= 0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body != shooter and body.has_method("hit_at"):
		body.hit_at(global_position)
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 3.0, Color(1.0, 0.9, 0.4))
