extends Node
class_name ExecutionSystem

# ExecutionSystem - Reusable action execution component
# Can be attached to NPCs, animals, or any object that needs to execute actions

# Signals for communication
signal action_started(action_type: String, action_data: Dictionary)
signal action_completed(action_type: String, success: bool, result: Dictionary)
signal action_interrupted(action_type: String, reason: String)
signal execution_status_changed(status: String, current_action: Dictionary, queue_size: int)
signal movement_update(position: Vector2, velocity: Vector2, is_moving: bool)

# Action priority levels
enum Priority {
	LOW = 0,
	NORMAL = 1,
	HIGH = 2,
	URGENT = 3,
	CRITICAL = 4
}

# Action queue with priority support
var action_queue: Array[Dictionary] = []
var current_action: Dictionary = {}
var action_start_time: float = 0.0

# Reference to the owner object
var owner_object: CharacterBody2D
var active: bool = false

# Movement configuration
var movement_speed: float = 100.0
var rotation_speed: float = 5.0
var arrival_threshold: float = 5.0

# Current state
var status: String = "idle"
var velocity: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var facing_direction: Vector2 = Vector2.DOWN

# Status tracking
var interruptions: Array[Dictionary] = []
var completed_actions: Array[Dictionary] = []

func initialize(character: CharacterBody2D) -> void:
	owner_object = character
	active = true
	status = "idle"
	
	# Connect to owner for updates
	set_process(true)
	
	if DebugConfig and DebugConfig.is_ai_debug():
		DebugConfig.debug_print("ExecutionSystem initialized for %s" % character.name, "ai")
	
	# Emit initial status
	_emit_status_update()

func _ready() -> void:
	# Ensure we're not processing until initialized
	if not owner_object:
		set_process(false)

func _process(delta: float) -> void:
	if not active or not owner_object:
		return
	
	execute(delta)

func execute(delta: float) -> void:
	# Process current action or get next from queue
	if current_action.is_empty() and not action_queue.is_empty():
		_start_next_action()
	
	# Execute current action
	if not current_action.is_empty():
		_execute_current_action(delta)
	
	# Emit movement updates
	if velocity != Vector2.ZERO or status == "moving":
		movement_update.emit(owner_object.global_position, velocity, is_moving())

func _start_next_action() -> void:
	if action_queue.is_empty():
		return
	
	# Sort queue by priority (highest first)
	action_queue.sort_custom(_compare_action_priority)
	
	current_action = action_queue.pop_front()
	action_start_time = Time.get_time_dict_from_system()["unix"]
	
	if DebugConfig and DebugConfig.is_ai_debug():
		DebugConfig.debug_print("Starting action: %s (priority: %d)" % [
			current_action.get("type", "unknown"), 
			current_action.get("priority", Priority.NORMAL)
		], "ai")
	
	# Initialize action based on type
	var action_type = current_action.get("type", "")
	match action_type:
		"move":
			_initialize_move_action()
		"wait":
			_initialize_wait_action()
		"face":
			_initialize_face_action()
		"interact":
			_initialize_interact_action()
		_:
			if DebugConfig and DebugConfig.is_ai_debug():
				DebugConfig.debug_print("Unknown action type: %s" % action_type, "ai")
			_complete_current_action(false)
			return
	
	# Emit signals
	action_started.emit(action_type, current_action)
	_emit_status_update()

func _compare_action_priority(a: Dictionary, b: Dictionary) -> bool:
	return a.get("priority", Priority.NORMAL) > b.get("priority", Priority.NORMAL)

func _execute_current_action(delta: float) -> void:
	var action_type = current_action.get("type", "")
	match action_type:
		"move":
			_execute_move_action(delta)
		"wait":
			_execute_wait_action(delta)
		"face":
			_execute_face_action(delta)
		"interact":
			_execute_interact_action(delta)

# MOVE ACTION IMPLEMENTATION
func _initialize_move_action() -> void:
	target_position = current_action.get("position", owner_object.global_position)
	movement_speed = current_action.get("speed", movement_speed)
	status = "moving"

func _execute_move_action(_delta: float) -> void:
	var distance_to_target = owner_object.global_position.distance_to(target_position)
	
	if distance_to_target <= arrival_threshold:
		# Arrived at destination
		velocity = Vector2.ZERO
		owner_object.velocity = velocity
		status = "idle"
		_complete_current_action(true, {"final_position": owner_object.global_position})
		return
	
	# Move towards target
	var direction = (target_position - owner_object.global_position).normalized()
	velocity = direction * movement_speed
	facing_direction = direction
	
	owner_object.velocity = velocity
	owner_object.move_and_slide()
	
	status = "moving"

# WAIT ACTION IMPLEMENTATION
func _initialize_wait_action() -> void:
	status = "waiting"
	velocity = Vector2.ZERO
	owner_object.velocity = velocity

func _execute_wait_action(_delta: float) -> void:
	var duration = current_action.get("duration", 1.0)
	var elapsed = Time.get_time_dict_from_system()["unix"] - action_start_time
	
	if elapsed >= duration:
		_complete_current_action(true, {"waited_time": elapsed})

# FACE ACTION IMPLEMENTATION
func _initialize_face_action() -> void:
	status = "turning"
	velocity = Vector2.ZERO
	owner_object.velocity = velocity

func _execute_face_action(_delta: float) -> void:
	var target_dir = current_action.get("direction", Vector2.DOWN)
	facing_direction = target_dir
	# For now, complete immediately (could add smooth rotation)
	_complete_current_action(true, {"final_direction": facing_direction})

# INTERACT ACTION IMPLEMENTATION
func _initialize_interact_action() -> void:
	status = "interacting"
	velocity = Vector2.ZERO
	owner_object.velocity = velocity

func _execute_interact_action(_delta: float) -> void:
	var duration = current_action.get("duration", 2.0)
	var elapsed = Time.get_time_dict_from_system()["unix"] - action_start_time
	
	if elapsed >= duration:
		var target = current_action.get("target", "")
		# TODO: Actually interact with target object
		_complete_current_action(true, {
			"target": target,
			"interaction_time": elapsed
		})

func _complete_current_action(success: bool, result: Dictionary = {}) -> void:
	var action_type = current_action.get("type", "unknown")
	
	if DebugConfig and DebugConfig.is_ai_debug():
		DebugConfig.debug_print("Completed action: %s (success: %s)" % [action_type, success], "ai")
	
	# Store completed action for history
	var completed_action = current_action.duplicate()
	completed_action["completed_at"] = Time.get_time_dict_from_system()["unix"]
	completed_action["success"] = success
	completed_action["result"] = result
	completed_actions.append(completed_action)
	
	# Keep only last 10 completed actions
	if completed_actions.size() > 10:
		completed_actions.pop_front()
	
	# Emit completion signal
	action_completed.emit(action_type, success, result)
	
	# Clear current action
	current_action = {}
	action_start_time = 0.0
	
	# Update status
	if action_queue.is_empty():
		status = "idle"
		velocity = Vector2.ZERO
		owner_object.velocity = velocity
	
	_emit_status_update()

# PUBLIC API FOR ADDING ACTIONS
func queue_action(action: Dictionary, priority: Priority = Priority.NORMAL) -> void:
	action["priority"] = priority
	action["queued_at"] = Time.get_time_dict_from_system()["unix"]
	action_queue.append(action)
	
	if DebugConfig and DebugConfig.is_ai_debug():
		DebugConfig.debug_print("Queued action: %s (priority: %d)" % [
			action.get("type", "unknown"), priority
		], "ai")
	
	_emit_status_update()

func queue_move_to(position: Vector2, priority: Priority = Priority.NORMAL, speed: float = -1.0) -> void:
	var action = {"type": "move", "position": position}
	if speed > 0:
		action["speed"] = speed
	queue_action(action, priority)

func queue_wait(duration: float, priority: Priority = Priority.NORMAL) -> void:
	queue_action({"type": "wait", "duration": duration}, priority)

func queue_face_direction(direction: Vector2, priority: Priority = Priority.NORMAL) -> void:
	queue_action({"type": "face", "direction": direction}, priority)

func queue_interact_with(target_id: String, duration: float = 2.0, priority: Priority = Priority.NORMAL) -> void:
	queue_action({"type": "interact", "target": target_id, "duration": duration}, priority)

# ACTION MANAGEMENT
func clear_action_queue(keep_current: bool = false) -> void:
	action_queue.clear()
	
	if not keep_current:
		if not current_action.is_empty():
			interrupt_current_action("Queue cleared")
	
	_emit_status_update()

func interrupt_current_action(reason: String = "") -> void:
	if not current_action.is_empty():
		var interrupted_action = current_action.duplicate()
		interrupted_action["interrupted_at"] = Time.get_time_dict_from_system()["unix"]
		interrupted_action["reason"] = reason
		interruptions.append(interrupted_action)
		
		# Keep only last 5 interruptions
		if interruptions.size() > 5:
			interruptions.pop_front()
		
		if DebugConfig and DebugConfig.is_ai_debug():
			DebugConfig.debug_print("Interrupted action: %s (%s)" % [
				current_action.get("type", "unknown"), reason
			], "ai")
		
		action_interrupted.emit(current_action.get("type", ""), reason)
		
		# Complete the action as unsuccessful
		_complete_current_action(false, {"interruption_reason": reason})

func set_movement_speed(speed: float) -> void:
	movement_speed = speed

func set_arrival_threshold(threshold: float) -> void:
	arrival_threshold = threshold

# STATUS QUERIES
func is_moving() -> bool:
	return status == "moving"

func is_busy() -> bool:
	return not current_action.is_empty() or not action_queue.is_empty()

func get_current_action_type() -> String:
	return current_action.get("type", "")

func get_queued_action_count() -> int:
	return action_queue.size()

func get_velocity() -> Vector2:
	return velocity

func get_facing_direction() -> Vector2:
	return facing_direction

func get_status() -> String:
	return status

# STATE INFORMATION
func get_execution_state() -> Dictionary:
	return {
		"status": status,
		"current_action": current_action.duplicate(),
		"queue_size": action_queue.size(),
		"velocity": {"x": velocity.x, "y": velocity.y},
		"target_position": {"x": target_position.x, "y": target_position.y},
		"facing_direction": {"x": facing_direction.x, "y": facing_direction.y},
		"interruptions": interruptions.duplicate(),
		"recent_completions": completed_actions.slice(-3).duplicate()  # Last 3 completed actions
	}

func _emit_status_update() -> void:
	execution_status_changed.emit(status, current_action, action_queue.size())

func is_active() -> bool:
	return active