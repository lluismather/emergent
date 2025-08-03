extends Node2D

const SPEED = 100
const BOUNDARY_MIN = Vector2(-400, -150)
const BOUNDARY_MAX = Vector2(-210, 50)

enum State { WALKING, IDLE, SLEEPING, LIE_DOWN, NOD_ON_WAKE, NOD_OFF, STAND_UP }
var state = State.IDLE

var idle_timer = 0.0
var idle_duration = 0.0

var target_position = Vector2.ZERO
var night_time = false

@onready var animated_sprite = $CharacterBody2D/AnimatedSprite2D

# Called when the node enters the scene tree for the first time.
func _ready():
	add_to_group("day_night_responders")
	add_to_group("animals")
	add_to_group("perceivable_objects")
	animated_sprite.connect("animation_finished", Callable(self, "_on_animation_finished"))
	pick_new_destination()
	
func on_day_night_cycle(cycle_state):
	target_position = position
	night_time = (cycle_state == "night")
	

func _on_animation_finished():
	match state:
		State.LIE_DOWN:
			enter_nod_off_state()
		State.NOD_OFF:
			enter_sleep_state()
		State.NOD_ON_WAKE:
			enter_stand_up_state()
		State.STAND_UP:
			pick_new_destination()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if night_time:
		match state:
			State.WALKING:
				enter_lie_down_state()
			State.IDLE:
				enter_lie_down_state()
	else:
		match state:
			State.WALKING:
				move_toward_target(delta)
			State.IDLE:
				idle_timer += delta
				if idle_timer >= idle_duration:
					if randi() % 4 == 0:
						enter_lie_down_state()
					else:
						pick_new_destination()
			State.SLEEPING:
				enter_stand_up_state()

func pick_new_destination ():
	target_position = Vector2(
		randf_range(BOUNDARY_MIN.x, BOUNDARY_MAX.x),
		randf_range(BOUNDARY_MIN.y, BOUNDARY_MAX.y)
	);
	state = State.WALKING;
	set_direction();
	animated_sprite.animation = "walk_left_right";
	animated_sprite.play();
	
func move_toward_target (delta):
	var direction = (target_position - position).normalized()
	var distance_to_target = position.distance_to(target_position)
	
	if distance_to_target < SPEED * delta:
		position = target_position
		enter_idle_state()
	else:
		position += direction * SPEED * delta

func set_direction():
	animated_sprite.flip_h = (target_position.x >= position.x)

func enter_idle_state():
	state = State.IDLE
	animated_sprite.animation = "idle"
	animated_sprite.play()
	idle_timer = 0.0
	idle_duration = randf_range(3.0, 6.0)
	
func enter_lie_down_state():
	state = State.LIE_DOWN
	animated_sprite.animation = "lie_down"
	animated_sprite.play()
	
func enter_nod_off_state():
	state = State.NOD_OFF
	animated_sprite.animation = "nod_off_wake_up"
	animated_sprite.play()
	
func enter_sleep_state():
	state = State.SLEEPING
	animated_sprite.animation = "sleep"
	animated_sprite.play()
	if not night_time:
		await get_tree().create_timer(randf_range(5.0, 10.0)).timeout
		enter_stand_up_state()
	
func enter_nod_on_wake_state():
	state = State.NOD_ON_WAKE
	animated_sprite.animation = "nod_off_wake_up"
	animated_sprite.play()
	animated_sprite.playback_speed = -1.0
	animated_sprite.frame = animated_sprite.sprite_frames.get_frame_count("nod_off_wake_up") - 1
	
func enter_stand_up_state():
	state = State.STAND_UP
	animated_sprite.animation = "stand_up"
	animated_sprite.play()
	
