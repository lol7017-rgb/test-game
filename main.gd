extends Node2D

func _ready() -> void:
	var target_grid := $Target/BlockGrid as ShipGrid
	target_grid.build_demo_ship()
