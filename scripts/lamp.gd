extends Node2D

@onready var light = $PointLight2D
@onready var animated_sprite = $AnimatedSprite2D


# Called when the node enters the scene tree for the first time.
func _ready():
	add_to_group("day_night_responders")
	light.visible = false
	animated_sprite.stop()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func on_day_night_cycle(state):
	if state == "night":
		animated_sprite.play()
		light.visible = true
	elif state == "day":
		animated_sprite.stop()
		light.visible = false
	
