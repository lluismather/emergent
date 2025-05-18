extends CanvasModulate

const MINUTES_PER_DAY = 1440
const MINUTES_PER_HOUR = 60
const INGAME_TO_REAL_MINUTE_DURATION = (2 * PI) / MINUTES_PER_DAY
const DAY_START = 6
const DAY_END = 17

@export var gradient:GradientTexture1D
@export var INGAME_SPEED = 20.0
@export var INITIAL_HOUR = 2:
	set(h):
		INITIAL_HOUR = h
		time = INGAME_TO_REAL_MINUTE_DURATION * INITIAL_HOUR * MINUTES_PER_HOUR

var time:float = 0.0
var past_minute = 1.0
var past_hour = 0.0
var cycle = "day"

signal time_tick(day:int, hour:int, minute:int)
signal day_night(state)

func _ready():
	time = INGAME_TO_REAL_MINUTE_DURATION * INITIAL_HOUR * MINUTES_PER_HOUR

func _process(delta):
	time += (delta * INGAME_TO_REAL_MINUTE_DURATION * INGAME_SPEED)
	var value = (sin(time - (PI / 2)) + 1.0) / 2
	self.color = gradient.gradient.sample(value)
	_recalculate_time()

func _recalculate_time():
	var total_minutes = int(time / INGAME_TO_REAL_MINUTE_DURATION)
	
	var day = int(total_minutes) / MINUTES_PER_DAY
	var current_day_minutes = total_minutes % MINUTES_PER_DAY
	
	var hour = int(current_day_minutes) / MINUTES_PER_HOUR
	var minute = int(current_day_minutes % MINUTES_PER_HOUR)
	
	if minute != past_minute:
		past_minute = minute
		time_tick.emit(day, hour, minute)
		if hour != past_hour:
			past_hour = hour
			_determine_day_night(hour)

func _determine_day_night(hour):
	if hour >= DAY_START and hour <= DAY_END and cycle != "day":
		cycle = "day"
		day_night.emit(cycle)
	elif hour < DAY_START or hour > DAY_END and cycle != "night":
		cycle = "night"
		day_night.emit(cycle)
		
