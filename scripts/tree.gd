extends StaticBody2D

@export var grow_factor: float = 1.5

var original_scale: Vector2
var is_grown: bool = false

func _ready() -> void:
    original_scale = scale
    add_to_group("spell_targets")

func apply_spell_effect(name: String, duration: float) -> void:
    if name == "grow" and not is_grown:
        is_grown = true
        scale = original_scale * grow_factor

func remove_spell_effect(name: String) -> void:
    if name == "grow" and is_grown:
        is_grown = false
        scale = original_scale