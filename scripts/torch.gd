extends Node2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var light = $PointLight2D

var light_scale = 1.0

func _ready():
	animated_sprite.play()
	light.visible = true
	light.texture_scale = light_scale


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	light.texture_scale = light_scale
	flicker()

func on_day_night_cycle(state):
	if state == "night":
		animated_sprite.play()
		light.visible = true
	elif state == "day":
		animated_sprite.stop()
		light.visible = false

func flicker():
	await get_tree().create_timer(randf_range(1.0, 2.0)).timeout
	light_scale = randf_range(0.95, 1.05)
	
