extends CharacterBody2D


const SPEED = 150.0
const JUMP_VELOCITY = -100.0

@onready var animated_sprite = $AnimatedSprite2D

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
