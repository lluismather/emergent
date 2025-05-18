extends Node2D

@onready var day_night_cycle = $DayNightCycle


# Called when the node enters the scene tree for the first time.
func _ready():
	day_night_cycle.day_night.connect(_on_day_night_cycle)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass
	
func _on_day_night_cycle(state):
	get_tree().call_group("day_night_responders", "on_day_night_cycle", state)
