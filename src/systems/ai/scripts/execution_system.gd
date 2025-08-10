# ExecutionSystem - MCP Server for action execution and movement
extends MCPServerBase
class_name ExecutionSystemMCP

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

# Movement configuration
var movement_speed: float = 50.0  # Slower movement for more visible updates
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

func initialize(entity: Node) -> bool:
	# Initialize MCP server base
	super._init("execution")
	var success = super.initialize(entity)
	
	# Cast to CharacterBody2D for execution system
	if entity is CharacterBody2D:
		owner_object = entity as CharacterBody2D
		status = "idle"
		
		# Connect to owner for updates
		set_process(true)
		
		if DebugConfig and DebugConfig.is_ai_debug():
			var msg = AIUtils.format_debug_message("ExecutionMCP", entity.name, "System initialized successfully")
			DebugConfig.debug_print(msg, "ai")
		
		# Emit initial status
		_emit_status_update()
		return true
	else:
		if DebugConfig and DebugConfig.is_ai_debug():
			var msg = AIUtils.format_debug_message("ExecutionMCP", AIUtils.safe_get_entity_name(entity), "Requires CharacterBody2D, got " + entity.get_class())
			DebugConfig.debug_print(msg, "ai")
		return false

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
	action_start_time = Time.get_unix_time_from_system()
	
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
	var elapsed = Time.get_unix_time_from_system() - action_start_time
	
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
	var elapsed = Time.get_unix_time_from_system() - action_start_time
	
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
		var entity_name = AIUtils.safe_get_entity_name(owner_object)
		var msg = AIUtils.format_debug_message("ExecutionMCP", entity_name, "Completed action: %s (success: %s)" % [action_type, success])
		DebugConfig.debug_print(msg, "ai")
	
	# Store completed action for history
	var completed_action = current_action.duplicate()
	completed_action["completed_at"] = Time.get_unix_time_from_system()
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
	action["queued_at"] = Time.get_unix_time_from_system()
	action_queue.append(action)
	
	if DebugConfig and DebugConfig.is_ai_debug():
		var entity_name = AIUtils.safe_get_entity_name(owner_object)
		var msg = AIUtils.format_debug_message("ExecutionMCP", entity_name, "Queued action: %s (priority: %s)" % [
			action.get("type", "unknown"), AIUtils.priority_to_string(priority)
		])
		DebugConfig.debug_print(msg, "ai")
	
	_emit_status_update()

# Wrapper for NPC compatibility
func queue_action_by_type(action_type: String, action_data: Dictionary, priority: int = 1) -> void:
	var action = action_data.duplicate()
	action["type"] = action_type
	queue_action(action, Priority.values()[clamp(priority, 0, 4)])

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
		interrupted_action["interrupted_at"] = Time.get_unix_time_from_system()
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

func is_idle() -> bool:
	return status == "idle"

func is_busy() -> bool:
	return not current_action.is_empty() or not action_queue.is_empty()

func get_current_action_type() -> String:
	return current_action.get("type", "")

func get_current_action() -> Dictionary:
	"""Get the current action dictionary"""
	return current_action.duplicate()

func get_queued_action_count() -> int:
	return action_queue.size()

func get_velocity() -> Vector2:
	return velocity

func get_facing_direction() -> Vector2:
	return facing_direction

func get_status() -> String:
	return status

func get_state() -> Dictionary:
	return get_execution_state()

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
		"recent_completions": completed_actions.slice(-3).duplicate() # Last 3 completed actions
	}

func _emit_status_update() -> void:
	execution_status_changed.emit(status, current_action, action_queue.size())

func is_active() -> bool:
	return active

# ============================================================================
# MCP SERVER INTERFACE IMPLEMENTATION
# ============================================================================

func _register_tools():
	"""Register available tools for AI to discover and use"""
	register_tool("queue_move_to", "Queue movement to a specific position", {
		"position": {"type": "vector2", "description": "Target position to move to"},
		"priority": {"type": "number", "description": "Action priority (0-4, default 1)"},
		"speed": {"type": "number", "description": "Movement speed override"}
	}, ["position"])
	
	register_tool("queue_wait", "Queue a wait/pause action", {
		"duration": {"type": "number", "description": "Duration to wait in seconds"},
		"priority": {"type": "number", "description": "Action priority (0-4, default 1)"}
	}, ["duration"])
	
	register_tool("queue_interact_with", "Queue interaction with target object", {
		"target_id": {"type": "string", "description": "ID of target to interact with"},
		"duration": {"type": "number", "description": "Interaction duration in seconds"},
		"priority": {"type": "number", "description": "Action priority (0-4, default 1)"}
	}, ["target_id"])
	
	register_tool("queue_face_direction", "Queue facing a specific direction", {
		"direction": {"type": "vector2", "description": "Direction to face"},
		"priority": {"type": "number", "description": "Action priority (0-4, default 1)"}
	}, ["direction"])
	
	register_tool("clear_action_queue", "Clear all queued actions", {
		"keep_current": {"type": "boolean", "description": "Keep current action running"}
	})
	
	register_tool("interrupt_current_action", "Interrupt the currently executing action", {
		"reason": {"type": "string", "description": "Reason for interruption"}
	})
	
	register_tool("set_movement_speed", "Configure movement speed", {
		"speed": {"type": "number", "description": "New movement speed"}
	}, ["speed"])

func _register_resources():
	"""Register available resources for AI to access"""
	register_resource("execution_state", "Current execution system state and queue")
	register_resource("movement_status", "Current movement and velocity information")
	register_resource("action_history", "Recent completed and interrupted actions")
	register_resource("queue_status", "Current action queue information")

func _execute_tool_internal(tool_name: String, args: Dictionary) -> Dictionary:
	"""Execute execution tools"""
	match tool_name:
		"queue_move_to":
			return mcp_tool_queue_move_to(
				args.get("position", Vector2.ZERO),
				args.get("priority", Priority.NORMAL),
				args.get("speed", -1.0)
			)
		"queue_wait":
			return mcp_tool_queue_wait(
				args.get("duration", 1.0),
				args.get("priority", Priority.NORMAL)
			)
		"queue_interact_with":
			return mcp_tool_queue_interact_with(
				args.get("target_id", ""),
				args.get("duration", 2.0),
				args.get("priority", Priority.NORMAL)
			)
		"queue_face_direction":
			return mcp_tool_queue_face_direction(
				args.get("direction", Vector2.DOWN),
				args.get("priority", Priority.NORMAL)
			)
		"clear_action_queue":
			return mcp_tool_clear_action_queue(
				args.get("keep_current", false)
			)
		"interrupt_current_action":
			return mcp_tool_interrupt_current_action(
				args.get("reason", "Manual interrupt")
			)
		"set_movement_speed":
			return mcp_tool_set_movement_speed(
				args.get("speed", 100.0)
			)
		_:
			return {"error": "Unknown tool", "tool": tool_name}

func _get_resource_internal(resource_name: String) -> Dictionary:
	"""Get execution resources"""
	match resource_name:
		"execution_state":
			return mcp_resource_execution_state()
		"movement_status":
			return mcp_resource_movement_status()
		"action_history":
			return mcp_resource_action_history()
		"queue_status":
			return mcp_resource_queue_status()
		_:
			return {"error": "Unknown resource", "resource": resource_name}

# ============================================================================
# MCP SERVER INTERFACE - TOOLS
# ============================================================================

func mcp_tool_queue_move_to(position: Vector2, priority: int = Priority.NORMAL, speed: float = -1.0) -> Dictionary:
	"""Tool: Queue movement to position"""
	queue_move_to(position, priority, speed)
	return {
		"success": true,
		"action_queued": "move",
		"target_position": {"x": position.x, "y": position.y},
		"priority": priority,
		"queue_size": action_queue.size(),
		"estimated_duration": _estimate_travel_time(position, speed if speed > 0 else movement_speed)
	}

func mcp_tool_queue_wait(duration: float, priority: int = Priority.NORMAL) -> Dictionary:
	"""Tool: Queue wait action"""
	queue_wait(duration, priority)
	return {
		"success": true,
		"action_queued": "wait",
		"duration": duration,
		"priority": priority,
		"queue_size": action_queue.size()
	}

func mcp_tool_queue_interact_with(target_id: String, duration: float = 2.0, priority: int = Priority.NORMAL) -> Dictionary:
	"""Tool: Queue interaction with target"""
	queue_interact_with(target_id, duration, priority)
	return {
		"success": true,
		"action_queued": "interact",
		"target_id": target_id,
		"duration": duration,
		"priority": priority,
		"queue_size": action_queue.size()
	}

func mcp_tool_queue_face_direction(direction: Vector2, priority: int = Priority.NORMAL) -> Dictionary:
	"""Tool: Queue face direction action"""
	queue_face_direction(direction, priority)
	return {
		"success": true,
		"action_queued": "face",
		"direction": {"x": direction.x, "y": direction.y},
		"priority": priority,
		"queue_size": action_queue.size()
	}

func mcp_tool_clear_action_queue(keep_current: bool = false) -> Dictionary:
	"""Tool: Clear action queue"""
	var cleared_count = action_queue.size()
	clear_action_queue(keep_current)
	return {
		"success": true,
		"cleared_actions": cleared_count,
		"kept_current": keep_current,
		"new_queue_size": action_queue.size()
	}

func mcp_tool_interrupt_current_action(reason: String = "Manual interrupt") -> Dictionary:
	"""Tool: Interrupt current action"""
	var had_action = not current_action.is_empty()
	var interrupted_action = current_action.get("type", "none")
	interrupt_current_action(reason)
	return {
		"success": true,
		"had_action": had_action,
		"interrupted_action": interrupted_action,
		"reason": reason,
		"new_status": status
	}

func mcp_tool_set_movement_speed(speed: float) -> Dictionary:
	"""Tool: Set movement speed"""
	var old_speed = movement_speed
	set_movement_speed(speed)
	return {
		"success": true,
		"old_speed": old_speed,
		"new_speed": movement_speed
	}

# ============================================================================
# MCP SERVER INTERFACE - RESOURCES
# ============================================================================

func mcp_resource_execution_state() -> Dictionary:
	"""Resource: Complete execution state"""
	return {
		"timestamp": Time.get_unix_time_from_system(),
		"status": status,
		"active": active,
		"current_action": current_action.duplicate(),
		"queue_size": action_queue.size(),
		"next_actions": action_queue.slice(0, 3).map(func(a): return a.get("type", "unknown")),
		"configuration": {
			"movement_speed": movement_speed,
			"rotation_speed": rotation_speed,
			"arrival_threshold": arrival_threshold
		},
		"entity": {
			"name": owner_object.name if owner_object else "unknown",
			"position": owner_object.global_position if owner_object else Vector2.ZERO
		}
	}

func mcp_resource_movement_status() -> Dictionary:
	"""Resource: Current movement information"""
	return {
		"timestamp": Time.get_unix_time_from_system(),
		"is_moving": is_moving(),
		"velocity": {"x": velocity.x, "y": velocity.y, "magnitude": velocity.length()},
		"position": owner_object.global_position if owner_object else Vector2.ZERO,
		"target_position": {"x": target_position.x, "y": target_position.y} if target_position != Vector2.ZERO else null,
		"facing_direction": {"x": facing_direction.x, "y": facing_direction.y},
		"distance_to_target": owner_object.global_position.distance_to(target_position) if owner_object and target_position != Vector2.ZERO else 0.0,
		"movement_progress": _calculate_movement_progress()
	}

func mcp_resource_action_history() -> Dictionary:
	"""Resource: Recent action history"""
	return {
		"timestamp": Time.get_unix_time_from_system(),
		"completed_actions": completed_actions.duplicate(),
		"interruptions": interruptions.duplicate(),
		"total_completed": completed_actions.size(),
		"total_interrupted": interruptions.size(),
		"success_rate": _calculate_success_rate()
	}

func mcp_resource_queue_status() -> Dictionary:
	"""Resource: Current queue status"""
	var queue_by_priority = {}
	var queue_by_type = {}
	
	for action in action_queue:
		var priority = action.get("priority", Priority.NORMAL)
		var type = action.get("type", "unknown")
		
		queue_by_priority[priority] = queue_by_priority.get(priority, 0) + 1
		queue_by_type[type] = queue_by_type.get(type, 0) + 1
	
	return {
		"timestamp": Time.get_unix_time_from_system(),
		"total_queued": action_queue.size(),
		"by_priority": queue_by_priority,
		"by_type": queue_by_type,
		"next_action": action_queue[0].get("type", "none") if action_queue.size() > 0 else "none",
		"estimated_completion_time": _estimate_queue_completion_time()
	}

# ============================================================================
# UTILITY METHODS FOR MCP RESOURCES
# ============================================================================

func _estimate_travel_time(target: Vector2, speed: float) -> float:
	"""Estimate time to reach target position"""
	if not owner_object:
		return 0.0
	return AIUtils.estimate_travel_time(owner_object.global_position, target, speed)

func _calculate_movement_progress() -> float:
	"""Calculate progress towards current movement target (0.0 - 1.0)"""
	if not is_moving() or not owner_object or target_position == Vector2.ZERO:
		return 0.0
	
	# This would require knowing the start position, which we don't track currently
	# For now, return distance-based approximation
	var current_distance = owner_object.global_position.distance_to(target_position)
	return max(0.0, 1.0 - (current_distance / 100.0)) # Rough approximation

func _calculate_success_rate() -> float:
	"""Calculate action success rate based on history"""
	var total_actions = completed_actions.size() + interruptions.size()
	if total_actions == 0:
		return 1.0
	return float(completed_actions.size()) / float(total_actions)

func _estimate_queue_completion_time() -> float:
	"""Estimate time to complete all queued actions"""
	var total_time = 0.0
	for action in action_queue:
		match action.get("type", ""):
			"move":
				var target = action.get("position", Vector2.ZERO)
				var speed = action.get("speed", movement_speed)
				total_time += _estimate_travel_time(target, speed)
			"wait":
				total_time += action.get("duration", 1.0)
			"interact":
				total_time += action.get("duration", 2.0)
			"face":
				total_time += 0.1 # Instant for now
			_:
				total_time += 1.0 # Default estimate
	return total_time
