extends CharacterBody2D


const SPEED = 150.0
const JUMP_VELOCITY = -100.0

@onready var animated_sprite = $AnimatedSprite2D

# Add perception system to player
var perception_system = null

func _ready():
	# Add to groups so debug UI can find us
	add_to_group("players")
	add_to_group("day_night_responders")
	
	# Initialize perception system
	_initialize_perception_system()

func _initialize_perception_system():
	var PerceptionSystemClass = load("res://scripts/perception_system.gd")
	perception_system = PerceptionSystemClass.new()
	perception_system.initialize(self)

func _process(_delta):
	var direction = Vector2()
	var movement_speed = 1
	
	# if walking, set to slower
	if Input.is_action_pressed("walk"):
		movement_speed = 0.5
		
	if Input.is_action_pressed("sprint"):
		movement_speed = 1.5
		
	# set animation movement speed
	animated_sprite.speed_scale = movement_speed

	# movement animations xaxis
	if Input.is_action_pressed("move_right"):
		direction.x += 1
		animated_sprite.animation = "run_right_left"
		animated_sprite.flip_h = false
	elif Input.is_action_pressed("move_left"):
		direction.x -= 1
		animated_sprite.animation = "run_right_left"
		animated_sprite.flip_h = true
		
	# movement animations yaxis
	if Input.is_action_pressed("move_down"):
		direction.y += 1
		if direction.x == 0:
			animated_sprite.animation = "run_down"
	elif Input.is_action_pressed("move_up"):
		direction.y -= 1
		if direction.x == 0:
			animated_sprite.animation = "run_up"

	# idle animations xyaxis
	if direction == Vector2():
		if velocity.x > 0:
			animated_sprite.animation = "idle_right_left"
			animated_sprite.flip_h = false
		elif velocity.x < 0:
			animated_sprite.animation = "idle_right_left"
			animated_sprite.flip_h = true
		elif velocity.y > 0:
			animated_sprite.animation = "idle_down"
		elif velocity.y < 0:
			animated_sprite.animation = "idle_up"

	# normalise, set speed and move
	direction = direction.normalized()
	velocity = direction * SPEED * movement_speed
	move_and_slide()
	
	# Update perception system
	if perception_system:
		perception_system.update(_delta)

func on_day_night_cycle(state):
	# Pass day/night changes to perception system
	if perception_system:
		perception_system.on_time_change(state)