extends CharacterBody2D

const SPEED = 100.0

@onready var animated_sprite = $AnimatedSprite2D

# Core NPC subsystems - wrapper classes that load actual MCP server implementations
# These systems provide the foundation for autonomous NPC behavior:
# - PerceptionSystem: Environmental awareness and object detection
# - ExecutionSystem: Action execution and movement control  
# - InflectionSystem: Decision trigger detection and timing
var perception_system = PerceptionSystemWrapper.new()
var execution_system = ExecutionSystemWrapper.new()
var inflection_system = InflectionSystemWrapper.new()

# Decision Manager for LLM-based decision making
# Coordinates with Ollama to make intelligent decisions based on NPC context
var decision_manager: DecisionManager

# Placeholder systems (not yet implemented as separate files)
var needs_system = NeedsSystem.new()
var personality_system = PersonalitySystem.new()
var memory_system = MemorySystem.new()
var goals_system = GoalsSystem.new()
var planning_system = PlanningSystem.new()
var social_system = SocialSystem.new()
var identity_system = IdentitySystem.new()
var emotion_system = EmotionSystem.new()
var reputation_system = ReputationSystem.new()
var resource_system = ResourceSystem.new()
var theory_of_mind_system = TheoryOfMindSystem.new()

# Current state (minimal for now)
var current_goal = null
var current_action = null

# Decision making
var decision_timer: Timer
var decision_interval: float = 2.0 # Check for decisions every 2 seconds

# NPC Identity
@export var npc_id: String = "npc_001"
@export var npc_name: String = "Unnamed NPC"
@export var npc_role: String = "Villager"

func _ready():
	# Initialize all subsystems
	_initialize_all_systems()
	
	# Initialize decision manager
	_initialize_decision_manager()
	
	# Add to groups
	add_to_group("day_night_responders")
	add_to_group("npcs")
	
	print("NPC initialized: ", npc_name, " (", npc_role, ")")

func _initialize_all_systems():
	# Initialize each system
	print("[NPC] Initializing systems for %s..." % npc_name)
	
	perception_system.initialize(self)
	print("[NPC] Perception system initialized: %s" % perception_system.is_active())
	
	needs_system.initialize(self)
	personality_system.initialize(self)
	memory_system.initialize(self)
	goals_system.initialize(self)
	planning_system.initialize(self)
	social_system.initialize(self)
	identity_system.initialize(self)
	
	# Initialize ExecutionSystem using wrapper
	execution_system.initialize(self)
	print("[NPC] Execution system initialized: %s" % execution_system.is_active())
	
	# Connect to ExecutionSystem signals (through wrapper)
	if execution_system.execution_mcp:
		execution_system.execution_mcp.action_started.connect(_on_action_started)
		execution_system.execution_mcp.action_completed.connect(_on_action_completed)
		execution_system.execution_mcp.action_interrupted.connect(_on_action_interrupted)
		execution_system.execution_mcp.execution_status_changed.connect(_on_execution_status_changed)
		execution_system.execution_mcp.movement_update.connect(_on_movement_update)
	
	emotion_system.initialize(self)
	reputation_system.initialize(self)
	resource_system.initialize(self)
	inflection_system.initialize(self)
	theory_of_mind_system.initialize(self)
	
	print("[NPC] All systems initialized for %s" % npc_name)

func _initialize_decision_manager():
	"""Initialize and connect the decision manager"""
	decision_manager = $DecisionManager
	if decision_manager:
		# Connect decision manager signals
		decision_manager.decision_made.connect(_on_decision_made)
		decision_manager.decision_failed.connect(_on_decision_failed)
		print("[NPC] Decision manager initialized for %s" % npc_name)
		
		# Set up decision timer
		_setup_decision_timer()
	else:
		print("[NPC] Warning: Decision manager not found for %s" % npc_name)
	
	# Wait a frame to ensure all systems are properly initialized
	await get_tree().process_frame
	
	# Verify perception system is active
	if perception_system:
		print("[NPC] Perception system status for %s: active=%s" % [npc_name, perception_system.is_active()])

func _setup_decision_timer():
	"""Set up a timer to periodically trigger decision making"""
	decision_timer = Timer.new()
	decision_timer.name = "DecisionTimer"
	decision_timer.wait_time = decision_interval
	decision_timer.autostart = true
	decision_timer.timeout.connect(_on_decision_timer_timeout)
	add_child(decision_timer)
	print("[NPC] Decision timer set up for %s (%.1f seconds)" % [npc_name, decision_interval])

func _process(delta):
	# Update all subsystems
	perception_system.update(delta)
	needs_system.update(delta)
	emotion_system.update(delta)
	memory_system.update(delta)
	
	# Check for inflection points
	if inflection_system.should_make_decision():
		_make_decision()
	
	# ExecutionSystem handles its own processing as a component
	
	# Update visual representation
	_update_animation()

func _make_decision():
	"""Make a decision using the decision manager.
	
	This method is called when the inflection system determines it's time
	for the NPC to make a new decision. It gathers comprehensive context
	from all AI subsystems and sends a request to the LLM via DecisionManager.
	
	Decision Flow:
	1. Build context from perception, needs, goals, etc.
	2. Send request to DecisionManager
	3. DecisionManager queries LLM asynchronously
	4. Response handled in _on_decision_made() callback
	5. Decision executed via ExecutionSystem
	"""
	if not decision_manager:
		print("[NPC] No decision manager available for %s" % npc_name)
		return
	
	# Get current context for decision making
	var context = _build_decision_context()
	
	# Request decision from LLM
	var success = decision_manager.request_decision(self, context, 1)
	if success:
		print("[NPC] Decision requested for %s" % npc_name)
	else:
		print("[NPC] Decision request failed for %s" % npc_name)

func _build_decision_context() -> Dictionary:
	"""Build context dictionary for decision making.
	
	Gathers comprehensive information about the NPC's current state,
	environment, and capabilities to inform LLM decision making.
	
	Returns:
		Dictionary: Rich context including available actions, nearby objects,
				   current needs, goals, emotional state, and time of day
	"""
	var context = {}
	
	# Safely build context with error handling
	context["available_actions"] = _get_available_actions()
	context["current_needs"] = _get_current_needs()
	
	# Safely get nearby objects
	var nearby_objects = []
	if perception_system and perception_system.is_active():
		nearby_objects = _get_nearby_objects()
	else:
		nearby_objects = _get_fallback_nearby_objects()
	context["nearby_objects"] = nearby_objects
	
	context["current_goals"] = _get_current_goals()
	context["emotional_state"] = _get_emotional_state()
	context["time_of_day"] = _get_time_of_day()
	
	return context

func _get_available_actions() -> Array[String]:
	"""Get list of actions the NPC can currently perform"""
	var actions: Array[String] = []
	
	# Basic movement actions
	actions.append("move_to_location")
	actions.append("wait")
	actions.append("idle")
	
	# Interaction actions (if nearby objects exist)
	var nearby = _get_nearby_objects()
	if nearby.size() > 0:
		actions.append("interact_with_object")
		actions.append("examine_object")
	
	# Social actions (if other NPCs are nearby)
	var npcs = get_tree().get_nodes_in_group("npcs")
	if npcs.size() > 1: # More than just self
		actions.append("greet_npc")
		actions.append("converse_with_npc")
	
	return actions

func _get_current_needs() -> String:
	"""Get current needs that might influence decisions"""
	if needs_system and needs_system.is_active():
		var needs_state = needs_system.get_state()
		if needs_state.size() > 0:
			return str(needs_state)
	return "Basic needs (hunger, rest, social)"

func _get_nearby_objects() -> Array[String]:
	"""Get nearby objects that the NPC can interact with"""
	var object_names: Array[String] = []
	
	if perception_system and perception_system.is_active():
		var nearby = perception_system.get_nearby_objects("", 50.0)
		if nearby and nearby.has("objects") and nearby.objects is Array:
			for obj in nearby.objects:
				if obj and obj.has("name"):
					object_names.append(str(obj.name))
		else:
			print("[NPC] Warning: Invalid perception data format for %s" % npc_name)
	else:
		print("[NPC] Warning: Perception system not active for %s" % npc_name)
	
	# If no objects found from perception, use fallback
	if object_names.size() == 0:
		object_names = _get_fallback_nearby_objects()
	
	return object_names

func _get_fallback_nearby_objects() -> Array[String]:
	"""Get fallback nearby objects when perception system is not available"""
	var fallback_objects: Array[String] = []
	
	# Look for common objects in the scene
	var scene = get_tree().current_scene
	if scene:
		# Look for lamps, torches, trees, etc.
		var search_nodes = ["Lamp", "Torch", "Tree", "LevelExit"]
		for node_name in search_nodes:
			var nodes = scene.get_tree().get_nodes_in_group(node_name.to_lower())
			for node in nodes:
				if node != self and node.global_position.distance_to(global_position) < 100:
					fallback_objects.append(str(node_name))
	
	# If no specific objects found, return generic ones
	if fallback_objects.size() == 0:
		fallback_objects.append("GenericObject")
		fallback_objects.append("Environment")
	
	return fallback_objects

func _get_current_goals() -> String:
	"""Get current goals that should influence decisions"""
	if goals_system and goals_system.is_active():
		var goals_state = goals_system.get_state()
		if goals_state.has("short_term") and goals_state.short_term.size() > 0:
			return str(goals_state.short_term[0])
		elif goals_state.has("mid_term") and goals_state.mid_term.size() > 0:
			return str(goals_state.mid_term[0])
	return "No specific goals"

func _get_emotional_state() -> String:
	"""Get current emotional state"""
	if emotion_system and emotion_system.is_active():
		var emotion_state = emotion_system.get_state()
		if emotion_state.has("current_mood"):
			return emotion_state.current_mood
	return "Neutral"

func _get_time_of_day() -> String:
	"""Get current time of day"""
	var time_dict = Time.get_time_dict_from_system()
	return AIUtils.get_time_period_name(time_dict.hour).capitalize()

# Decision Manager signal handlers
func _on_decision_made(npc_id: String, decision: Dictionary, context_hash: String):
	"""Handle when a decision is made by the LLM"""
	if npc_id != npc_name:
		return
	
	print("[NPC] Decision made for %s: call %s.%s (%s)" % [npc_name, decision.get("server", "Unknown"), decision.get("tool", "Unknown"), decision.get("reason", "Unknown")])
	
	# Execute the MCP tool decision
	_execute_mcp_decision(decision)

func _on_decision_failed(npc_id: String, error: String):
	"""Handle when a decision request fails"""
	if npc_id != npc_name:
		return
	
	print("[NPC] Decision failed for %s: %s" % [npc_name, error])
	
	# Fallback to default behavior
	_execute_fallback_behavior()

func _on_decision_timer_timeout():
	"""Called when the decision timer expires"""
	# Don't make decisions if we're currently moving
	if execution_system and execution_system.is_moving():
		print("[NPC] %s skipping decision - currently moving" % npc_name)
		return
		
	if inflection_system and inflection_system.should_make_decision():
		_make_decision()
	elif execution_system and execution_system.is_idle():
		# If idle and no inflection point, make a decision anyway
		_make_decision()

func _execute_mcp_decision(decision: Dictionary):
	"""Execute a MCP tool decision made by the LLM.
	
	Calls the specified MCP server tool with the provided arguments.
	
	Args:
		decision: Dictionary containing MCP decision with fields:
				 - server: String name of MCP server
				 - tool: String name of tool to execute
				 - args: Dictionary of tool arguments
				 - reason: String explanation for the choice
	"""
	var server = decision.get("server", "")
	var tool = decision.get("tool", "")
	var args = decision.get("args", {})
	var reason = decision.get("reason", "")
	
	print("[NPC] %s executing MCP decision: %s.%s (%s)" % [npc_name, server, tool, reason])
	
	# Convert arguments for specific tools
	var converted_args = _convert_mcp_args(tool, args)
	
	# Execute the MCP tool
	var result = execute_mcp_tool(server, tool, converted_args)
	
	if result.has("error"):
		print("[NPC] %s MCP tool execution failed: %s" % [npc_name, result.error])
		_execute_fallback_behavior()
	else:
		print("[NPC] %s MCP tool execution succeeded: %s" % [npc_name, result])

func _convert_mcp_args(tool: String, args: Dictionary) -> Dictionary:
	"""Convert arguments to proper types for MCP tool execution"""
	var converted_args = args.duplicate()
	
	# Convert position dictionary to Vector2 for movement tools
	if tool == "queue_move_to" and args.has("position"):
		var pos = args.position
		if pos is Dictionary and pos.has("x") and pos.has("y"):
			converted_args["position"] = Vector2(pos.x, pos.y)
	
	return converted_args

func _handle_move_action(action: String, priority: int):
	"""Handle movement-related actions"""
	# Extract target location from action description
	var target_pos = _extract_target_position(action)
	if target_pos != Vector2.ZERO:
		move_to(target_pos, priority)
	else:
		# Move to a random nearby location
		var random_pos = _get_random_nearby_position()
		move_to(random_pos, priority)

func _handle_wait_action(duration: float, priority: int):
	"""Handle waiting/idle actions"""
	wait_for(duration, priority)

func _handle_interaction_action(action: String, priority: int):
	"""Handle interaction with objects"""
	var nearby_objects = _get_nearby_objects()
	if nearby_objects.size() > 0:
		var target_object = nearby_objects[0] # Interact with first nearby object
		interact_with(target_object, 3.0, priority)
	else:
		# No objects nearby, wait instead
		wait_for(2.0, priority)

func _handle_social_action(action: String, priority: int):
	"""Handle social interactions with other NPCs"""
	var npcs = get_tree().get_nodes_in_group("npcs")
	var found_npc = false
	for npc in npcs:
		if npc != self and npc.global_position.distance_to(global_position) < 100:
			# Move towards the other NPC
			move_to(npc.global_position, priority)
			found_npc = true
			break
	
	if not found_npc:
		# No NPCs nearby, wait instead
		wait_for(3.0, priority)

func _extract_target_position(action: String) -> Vector2:
	"""Extract target position from action description (placeholder)"""
	# This is a simplified implementation
	# In a real system, you might parse the action text more intelligently
	return Vector2.ZERO

func _get_random_nearby_position() -> Vector2:
	"""Get a random position within walking distance"""
	var random_angle = randf() * TAU
	var random_distance = randf_range(20, 80)
	return global_position + Vector2(cos(random_angle), sin(random_angle)) * random_distance

func _execute_fallback_behavior():
	"""Execute fallback behavior when decision making fails"""
	print("[NPC] %s executing fallback behavior" % npc_name)
	
	# Simple fallback: wait for a bit, then move to a random location
	wait_for(2.0, 1)
	var random_pos = _get_random_nearby_position()
	move_to(random_pos, 1)

# ExecutionSystem signal handlers
func _on_action_started(action_type: String, action_data: Dictionary):
	if DebugConfig and DebugConfig.is_ai_debug():
		DebugConfig.debug_print("NPC %s started action: %s" % [npc_name, action_type], "ai")

func _on_action_completed(action_type: String, success: bool, result: Dictionary):
	if DebugConfig and DebugConfig.is_ai_debug():
		DebugConfig.debug_print("NPC %s completed action: %s (success: %s)" % [npc_name, action_type, success], "ai")
	
	# When movement completes, make a new decision quickly
	if action_type == "move" and success:
		print("[NPC] %s completed movement, triggering new decision" % npc_name)
		# Add a small delay to prevent immediate decision spam
		get_tree().create_timer(1.0).timeout.connect(_make_decision)

func _on_action_interrupted(action_type: String, reason: String):
	if DebugConfig and DebugConfig.is_ai_debug():
		DebugConfig.debug_print("NPC %s action interrupted: %s (%s)" % [npc_name, action_type, reason], "ai")

func _on_execution_status_changed(status: String, current_action: Dictionary, queue_size: int):
	# Update current_action for compatibility
	current_action = current_action

func _on_movement_update(position: Vector2, velocity: Vector2, is_moving: bool):
	# This is called when the ExecutionSystem updates movement
	# We can use this for additional processing if needed
	pass

func _update_animation():
	# Basic animation system using ExecutionSystem data
	if execution_system and execution_system.is_moving():
		var move_velocity = Vector2.ZERO
		if execution_system.execution_mcp:
			move_velocity = execution_system.execution_mcp.get_velocity()
		
		if abs(move_velocity.x) > abs(move_velocity.y):
			animated_sprite.animation = "run_right_left"
			animated_sprite.flip_h = move_velocity.x < 0
		else:
			if move_velocity.y > 0:
				animated_sprite.animation = "run_down"
			else:
				animated_sprite.animation = "run_up"
	else:
		# Idle animations
		if animated_sprite.animation.begins_with("run_"):
			if animated_sprite.animation == "run_right_left":
				animated_sprite.animation = "idle_right_left"
			elif animated_sprite.animation == "run_down":
				animated_sprite.animation = "idle_down"
			elif animated_sprite.animation == "run_up":
				animated_sprite.animation = "idle_up"

func on_day_night_cycle(state):
	# Pass to relevant systems
	perception_system.on_time_change(state)
	needs_system.on_time_change(state)

# Public API for controlling NPC actions
func move_to(target_position: Vector2, priority: ExecutionSystemMCP.Priority = ExecutionSystemMCP.Priority.NORMAL):
	if execution_system and execution_system.execution_mcp:
		execution_system.execution_mcp.queue_move_to(target_position, priority)

func wait_for(duration: float, priority: ExecutionSystemMCP.Priority = ExecutionSystemMCP.Priority.NORMAL):
	if execution_system and execution_system.execution_mcp:
		execution_system.execution_mcp.queue_wait(duration, priority)

func interact_with(target_id: String, duration: float = 2.0, priority: ExecutionSystemMCP.Priority = ExecutionSystemMCP.Priority.NORMAL):
	if execution_system and execution_system.execution_mcp:
		execution_system.execution_mcp.queue_interact_with(target_id, duration, priority)

func clear_all_actions():
	if execution_system and execution_system.execution_mcp:
		execution_system.execution_mcp.clear_action_queue()

func interrupt_current_action(reason: String = "Manual interrupt"):
	if execution_system and execution_system.execution_mcp:
		execution_system.execution_mcp.interrupt_current_action(reason)

func get_execution_status() -> Dictionary:
	if execution_system:
		return execution_system.get_execution_state()
	return {}

# Decision making control
func trigger_decision():
	"""Manually trigger a decision (useful for testing)"""
	print("[NPC] Manually triggering decision for %s" % npc_name)
	_make_decision()

func set_decision_interval(interval: float):
	"""Set how often the NPC should make decisions"""
	decision_interval = interval
	if decision_timer:
		decision_timer.wait_time = interval
		print("[NPC] Decision interval set to %.1f seconds for %s" % [interval, npc_name])

func get_decision_manager() -> DecisionManager:
	"""Get the decision manager instance"""
	return decision_manager

# Debug and testing methods
func test_perception_system() -> Dictionary:
	"""Test the perception system and return debug information"""
	var debug_info = {
		"perception_system_exists": perception_system != null,
		"perception_system_active": false,
		"perception_mcp_exists": false,
		"perception_methods": [],
		"test_result": {}
	}
	
	if perception_system:
		debug_info.perception_system_active = perception_system.is_active()
		
		if perception_system.perception_mcp:
			debug_info.perception_mcp_exists = true
			
			# Check what methods are available
			var methods = perception_system.perception_mcp.get_method_list()
			for method in methods:
				debug_info.perception_methods.append(method.name)
			
			# Test the get_nearby_objects method
			if perception_system.perception_mcp.has_method("mcp_tool_get_nearby_objects"):
				debug_info.test_result = perception_system.perception_mcp.mcp_tool_get_nearby_objects("", 50.0)
			else:
				debug_info.test_result = {"error": "Method mcp_tool_get_nearby_objects not found"}
		else:
			debug_info.test_result = {"error": "perception_mcp is null"}
	else:
		debug_info.test_result = {"error": "perception_system is null"}
	
	return debug_info

func force_perception_update():
	"""Force an update of the perception system"""
	if perception_system and perception_system.is_active():
		print("[NPC] Forcing perception update for %s" % npc_name)
		perception_system.update(0.0)
		
		# Test getting nearby objects
		var nearby = _get_nearby_objects()
		print("[NPC] Nearby objects for %s: %s" % [npc_name, nearby])
	else:
		print("[NPC] Cannot force perception update - system not active")

func test_nearby_objects() -> Array[String]:
	"""Test method to verify nearby objects functionality"""
	print("[NPC] Testing nearby objects for %s" % npc_name)
	
	# Test the main method
	var result = _get_nearby_objects()
	print("[NPC] Main method result: %s (type: %s)" % [result, typeof(result)])
	
	# Test the fallback method
	var fallback = _get_fallback_nearby_objects()
	print("[NPC] Fallback method result: %s (type: %s)" % [fallback, typeof(fallback)])
	
	return result

# Export current NPC state as comprehensive JSON
func get_full_state() -> Dictionary:
	return {
		"id": npc_id,
		"name": npc_name,
		"identity": identity_system.get_state(),
		"personality": personality_system.get_state(),
		"needs": needs_system.get_state(),
		"emotion": emotion_system.get_state(),
		"relationships": social_system.get_relationships_state(),
		"memory": memory_system.get_state(),
		"goals": goals_system.get_state(),
		"planning": planning_system.get_state(),
		"social_norms": reputation_system.get_state(),
		"resource_inventory": resource_system.get_state(),
		"execution_state": execution_system.get_execution_state() if execution_system else {},
		"decision_cache": planning_system.get_decision_cache(),
		"inflection_triggers": inflection_system.get_state(),
		"theory_of_mind_response": theory_of_mind_system.get_latest_response(),
		"last_inner_narrative": planning_system.get_last_narrative()
	}

# Debug info (simplified for now)
func get_debug_info():
	return {
		"name": npc_name,
		"role": npc_role,
		"current_goal": current_goal,
		"systems_active": _count_active_systems(),
		"decision_manager": decision_manager != null,
		"decision_timer": decision_timer != null,
		"last_decision_time": _get_last_decision_time()
	}

func _get_last_decision_time() -> String:
	"""Get when the last decision was made"""
	if decision_manager:
		var npc_id = npc_name
		var last_time = decision_manager.last_decision_time.get(npc_id, 0.0)
		if last_time > 0:
			var current_time = Time.get_unix_time_from_system()
			var time_since = current_time - last_time
			return "%.1f seconds ago" % time_since
	return "Never"

func get_decision_statistics() -> Dictionary:
	"""Get statistics about decision making"""
	if not decision_manager:
		return {"error": "No decision manager"}
	
	var stats = {
		"total_decisions": decision_manager.decision_cache.size(),
		"last_decision": _get_last_decision_time(),
		"decision_interval": decision_interval,
		"cooldown_active": decision_manager._is_in_cooldown(npc_name),
		"pending_decisions": decision_manager.pending_decisions.size()
	}
	
	# Add cached decisions
	var cached = decision_manager.get_cached_decisions()
	if cached.size() > 0:
		stats["recent_decisions"] = []
		var count = 0
		for context_hash in cached:
			if count < 5: # Show last 5 decisions
				var decision = cached[context_hash]
				stats.recent_decisions.append({
					"action": decision.get("action", "Unknown"),
					"goal": decision.get("goal", "Unknown"),
					"priority": decision.get("priority", 1)
				})
				count += 1
	
	return stats

func _count_active_systems() -> int:
	var count = 0
	if perception_system.is_active(): count += 1
	if needs_system.is_active(): count += 1
	if personality_system.is_active(): count += 1
	if memory_system.is_active(): count += 1
	if goals_system.is_active(): count += 1
	if planning_system.is_active(): count += 1
	if social_system.is_active(): count += 1
	if identity_system.is_active(): count += 1
	if execution_system and execution_system.is_active(): count += 1
	if emotion_system.is_active(): count += 1
	if reputation_system.is_active(): count += 1
	if resource_system.is_active(): count += 1
	return count

# ============================================================================
# MCP SERVER DISCOVERY AND ACCESS
# ============================================================================
# This section provides the interface for LLMs to discover and interact with
# the NPC's AI subsystems. Each system exposes tools (actions) and resources
# (data) that can be used for decision making and context building.

func get_available_mcp_servers() -> Dictionary:
	"""Get all available MCP servers for LLM discovery"""
	var servers = {}
	
	# Perception System MCP Server
	if perception_system and perception_system.perception_mcp:
		servers["perception"] = {
			"name": "perception",
			"description": "Environmental awareness and object detection",
			"server_info": perception_system.perception_mcp.get_server_info(),
			"tools": perception_system.perception_mcp.get_available_tools(),
			"resources": perception_system.perception_mcp.get_available_resources()
		}
	
	# Execution System MCP Server
	if execution_system and execution_system.execution_mcp:
		servers["execution"] = {
			"name": "execution",
			"description": "Action execution and movement control",
			"server_info": execution_system.execution_mcp.get_server_info(),
			"tools": execution_system.execution_mcp.get_available_tools(),
			"resources": execution_system.execution_mcp.get_available_resources()
		}
	
	# Inflection System MCP Server
	if inflection_system and inflection_system.inflection_mcp:
		servers["inflection"] = {
			"name": "inflection",
			"description": "Decision trigger detection and timing",
			"server_info": inflection_system.inflection_mcp.get_server_info(),
			"tools": inflection_system.inflection_mcp.get_available_tools(),
			"resources": inflection_system.inflection_mcp.get_available_resources()
		}
	
	return servers

func execute_mcp_tool(server_name: String, tool_name: String, args: Dictionary = {}) -> Dictionary:
	"""Execute a tool on a specific MCP server"""
	match server_name:
		"perception":
			if perception_system and perception_system.perception_mcp:
				return perception_system.perception_mcp.execute_tool(tool_name, args)
		"execution":
			if execution_system and execution_system.execution_mcp:
				return execution_system.execution_mcp.execute_tool(tool_name, args)
		"inflection":
			if inflection_system and inflection_system.inflection_mcp:
				return inflection_system.inflection_mcp.execute_tool(tool_name, args)
		_:
			return {"error": "Unknown MCP server", "server": server_name}
	
	return {"error": "MCP server not available", "server": server_name}

func get_mcp_resource(server_name: String, resource_name: String) -> Dictionary:
	"""Get a resource from a specific MCP server"""
	match server_name:
		"perception":
			if perception_system and perception_system.perception_mcp:
				return perception_system.perception_mcp.get_resource(resource_name)
		"execution":
			if execution_system and execution_system.execution_mcp:
				return execution_system.execution_mcp.get_resource(resource_name)
		"inflection":
			if inflection_system and inflection_system.inflection_mcp:
				return inflection_system.inflection_mcp.get_resource(resource_name)
		_:
			return {"error": "Unknown MCP server", "server": server_name}
	
	return {"error": "MCP server not available", "server": server_name}

func get_npc_context_for_llm() -> Dictionary:
	"""Get comprehensive NPC context formatted for LLM decision making"""
	var context = {
		"timestamp": Time.get_unix_time_from_system(),
		"npc_identity": {
			"id": npc_id,
			"name": npc_name,
			"role": npc_role
		},
		"available_systems": get_available_mcp_servers(),
		"current_state": get_full_state()
	}
	
	# Add quick access to key information
	if perception_system and perception_system.perception_mcp:
		context["current_perception"] = perception_system.perception_mcp.get_resource("perception_snapshot")
	
	if execution_system and execution_system.execution_mcp:
		context["current_execution"] = execution_system.execution_mcp.get_resource("execution_state")
	
	if inflection_system and inflection_system.inflection_mcp:
		context["decision_triggers"] = inflection_system.inflection_mcp.get_resource("inflection_state")
	
	return context

# ============================================================================
# SUBSYSTEM CLASSES (Empty shells ready for implementation)
# ============================================================================

class PerceptionSystemWrapper:
	var perception_mcp
	var active = false
	
	func initialize(npc: CharacterBody2D):
		# Load the perception system dynamically
		var PerceptionSystemClass = load("res://src/systems/ai/scripts/perception_system.gd")
		if PerceptionSystemClass:
			perception_mcp = PerceptionSystemClass.new()
			perception_mcp.name = "PerceptionSystemMCP"
			npc.add_child(perception_mcp)
			var world = npc.get_tree().current_scene
			active = perception_mcp.initialize(npc, world)
			print("[PerceptionSystemWrapper] Initialized for %s, active: %s" % [npc.name, active])
		else:
			print("[PerceptionSystemWrapper] Failed to load perception system class")
			active = false
	
	func update(delta):
		if perception_mcp:
			perception_mcp.update(delta)
	
	func on_time_change(_state):
		pass
	
	func is_active() -> bool:
		return active
	
	# MCP Tool Access
	func get_nearby_objects(filter_type: String = "", max_distance: float = -1.0) -> Dictionary:
		if perception_mcp and perception_mcp.has_method("mcp_tool_get_nearby_objects"):
			var result = perception_mcp.mcp_tool_get_nearby_objects(filter_type, max_distance)
			# Ensure the result has the expected structure
			if result and result.has("objects"):
				return result
			else:
				return {"objects": [], "error": "Invalid result format"}
		return {"objects": [], "error": "Perception system not initialized"}
	
	func get_environment() -> Dictionary:
		if perception_mcp:
			return perception_mcp.mcp_tool_get_environment()
		return {"error": "Perception system not initialized"}
	
	func find_object(object_id: String = "", object_type: String = "") -> Dictionary:
		if perception_mcp:
			return perception_mcp.mcp_tool_find_object(object_id, object_type)
		return {"matches": [], "error": "Perception system not initialized"}
	
	func get_spatial_analysis() -> Dictionary:
		if perception_mcp:
			return perception_mcp.mcp_tool_get_spatial_analysis()
		return {"error": "Perception system not initialized"}
	
	func get_perception_snapshot() -> Dictionary:
		if perception_mcp:
			return perception_mcp.mcp_resource_perception_snapshot()
		return {"error": "Perception system not initialized"}

class ExecutionSystemWrapper:
	var execution_mcp
	var npc_ref: CharacterBody2D
	var active = false
	
	func initialize(npc: CharacterBody2D):
		npc_ref = npc
		# Load the execution system dynamically
		var ExecutionSystemClass = load("res://src/systems/ai/scripts/execution_system.gd")
		execution_mcp = ExecutionSystemClass.new()
		execution_mcp.name = "ExecutionSystemMCP"
		npc.add_child(execution_mcp)
		active = execution_mcp.initialize(npc)
	
	func update(delta):
		# ExecutionSystem handles its own processing as a component
		pass
	
	func is_idle() -> bool:
		if execution_mcp:
			return execution_mcp.is_idle()
		return true
	
	func queue_action(action_type: String, action_data: Dictionary, priority: int = 1):
		if execution_mcp:
			execution_mcp.queue_action_by_type(action_type, action_data, priority)
	
	func is_moving() -> bool:
		if execution_mcp:
			return execution_mcp.is_moving()
		return false
	
	func is_busy() -> bool:
		if execution_mcp:
			return execution_mcp.is_busy()
		return false
	
	func get_status() -> String:
		if execution_mcp:
			return execution_mcp.get_status()
		return "idle"
	
	func get_state() -> Dictionary:
		if execution_mcp:
			return execution_mcp.get_state()
		return {"error": "Execution system not initialized"}
	
	func is_active() -> bool:
		return active
	
	# MCP Tool Access
	func queue_move_to_mcp(position: Vector2, priority: int = 1, speed: float = -1.0) -> Dictionary:
		if execution_mcp:
			return execution_mcp.execute_tool("queue_move_to", {
				"position": position,
				"priority": priority,
				"speed": speed
			})
		return {"error": "Execution system not initialized"}
	
	func queue_wait_mcp(duration: float, priority: int = 1) -> Dictionary:
		if execution_mcp:
			return execution_mcp.execute_tool("queue_wait", {
				"duration": duration,
				"priority": priority
			})
		return {"error": "Execution system not initialized"}
	
	func queue_interact_with_mcp(target_id: String, duration: float = 2.0, priority: int = 1) -> Dictionary:
		if execution_mcp:
			return execution_mcp.execute_tool("queue_interact_with", {
				"target_id": target_id,
				"duration": duration,
				"priority": priority
			})
		return {"error": "Execution system not initialized"}
	
	func get_execution_state_mcp() -> Dictionary:
		if execution_mcp:
			return execution_mcp.get_resource("execution_state")
		return {"error": "Execution system not initialized"}
	
	func get_movement_status_mcp() -> Dictionary:
		if execution_mcp:
			return execution_mcp.get_resource("movement_status")
		return {"error": "Execution system not initialized"}
	
	func get_action_history_mcp() -> Dictionary:
		if execution_mcp:
			return execution_mcp.get_resource("action_history")
		return {"error": "Execution system not initialized"}
	
	func get_queue_status_mcp() -> Dictionary:
		if execution_mcp:
			return execution_mcp.get_resource("queue_status")
		return {"error": "Execution system not initialized"}

class InflectionSystemWrapper:
	var inflection_mcp
	var npc_ref: CharacterBody2D
	var active = false
	
	func initialize(npc: CharacterBody2D):
		npc_ref = npc
		# Create the inflection system as a Node
		inflection_mcp = InflectionSystemMCP.new()
		inflection_mcp.name = "InflectionSystemMCP"
		npc.add_child(inflection_mcp)
		active = inflection_mcp.initialize(npc)
	
	func should_make_decision() -> bool:
		if inflection_mcp:
			return inflection_mcp.should_make_decision()
		return false
	
	func get_state() -> Dictionary:
		if inflection_mcp:
			return inflection_mcp.get_state()
		return {"error": "Inflection system not initialized"}
	
	func is_active() -> bool:
		return active
	
	# MCP Tool Access
	func check_should_decide_mcp() -> Dictionary:
		if inflection_mcp:
			return inflection_mcp.execute_tool("check_should_decide")
		return {"error": "Inflection system not initialized"}
	
	func evaluate_triggers_mcp() -> Dictionary:
		if inflection_mcp:
			return inflection_mcp.execute_tool("evaluate_triggers")
		return {"error": "Inflection system not initialized"}
	
	func force_decision_check_mcp() -> Dictionary:
		if inflection_mcp:
			return inflection_mcp.execute_tool("force_decision_check")
		return {"error": "Inflection system not initialized"}
	
	func get_inflection_state_mcp() -> Dictionary:
		if inflection_mcp:
			return inflection_mcp.get_resource("inflection_state")
		return {"error": "Inflection system not initialized"}
	
	func get_decision_timing_mcp() -> Dictionary:
		if inflection_mcp:
			return inflection_mcp.get_resource("decision_timing")
		return {"error": "Inflection system not initialized"}
	
	func get_trigger_analysis_mcp() -> Dictionary:
		if inflection_mcp:
			return inflection_mcp.get_resource("trigger_analysis")
		return {"error": "Inflection system not initialized"}

class NeedsSystem:
	var npc_ref: CharacterBody2D
	var needs = {}
	var active = false
	
	func initialize(npc: CharacterBody2D):
		npc_ref = npc
		active = true
	
	func update(_delta):
		pass
	
	func on_time_change(_state):
		pass
	
	func has_need(need_name: String) -> bool:
		return needs.has(need_name)
	
	func get_need_value(need_name: String) -> float:
		return needs.get(need_name, 0.5)
	
	func get_state() -> Dictionary:
		return needs.duplicate()
	
	func is_active() -> bool:
		return active

class PersonalitySystem:
	var npc_ref: CharacterBody2D
	var traits = {}
	var likes = []
	var dislikes = []
	var moral_values = {}
	var active = false
	
	func initialize(npc: CharacterBody2D):
		npc_ref = npc
		active = true
	
	func get_state() -> Dictionary:
		return {
			"traits": traits,
			"likes": likes,
			"dislikes": dislikes,
			"moral_values": moral_values
		}
	
	func is_active() -> bool:
		return active

class MemorySystem:
	var npc_ref: CharacterBody2D
	var short_term_memories = []
	var long_term_memories = []
	var active = false
	
	func initialize(npc: CharacterBody2D):
		npc_ref = npc
		active = true
	
	func update(_delta):
		pass
	
	func get_state() -> Dictionary:
		return {
			"short_term": short_term_memories,
			"long_term": long_term_memories
		}
	
	func is_active() -> bool:
		return active

class GoalsSystem:
	var npc_ref: CharacterBody2D
	var long_term_goals = []
	var mid_term_goals = []
	var short_term_goals = []
	var active = false
	
	func initialize(npc: CharacterBody2D):
		npc_ref = npc
		active = true
	
	func get_state() -> Dictionary:
		return {
			"long_term": long_term_goals,
			"mid_term": mid_term_goals,
			"short_term": short_term_goals
		}
	
	func is_active() -> bool:
		return active

class PlanningSystem:
	var npc_ref: CharacterBody2D
	var current_goal = null
	var candidate_goals = []
	var decomposed_actions = []
	var decision_cache = {}
	var last_narrative = ""
	var active = false
	
	func initialize(npc: CharacterBody2D):
		npc_ref = npc
		active = true
	
	func get_state() -> Dictionary:
		return {
			"current_goal": current_goal,
			"candidate_goals": candidate_goals,
			"decomposed_actions": decomposed_actions
		}
	
	func get_decision_cache() -> Dictionary:
		return decision_cache
	
	func get_last_narrative() -> String:
		return last_narrative
	
	func is_active() -> bool:
		return active

class SocialSystem:
	var npc_ref: CharacterBody2D
	var relationships = {}
	var active = false
	
	func initialize(npc: CharacterBody2D):
		npc_ref = npc
		active = true
	
	func get_relationships_state() -> Dictionary:
		return relationships.duplicate()
	
	func is_active() -> bool:
		return active

class IdentitySystem:
	var npc_ref: CharacterBody2D
	var role = ""
	var family = []
	var status = ""
	var skills = {}
	var cultural_background = ""
	var active = false
	
	func initialize(npc: CharacterBody2D):
		npc_ref = npc
		active = true
	
	func get_state() -> Dictionary:
		return {
			"role": role,
			"family": family,
			"status": status,
			"skills": skills,
			"cultural_background": cultural_background
		}
	
	func is_active() -> bool:
		return active

class EmotionSystem:
	var npc_ref: CharacterBody2D
	var current_mood = ""
	var modifiers = {}
	var last_updated = ""
	var active = false
	
	func initialize(npc: CharacterBody2D):
		npc_ref = npc
		active = true
	
	func update(_delta):
		pass
	
	func get_state() -> Dictionary:
		return {
			"current_mood": current_mood,
			"modifiers": modifiers,
			"last_updated": last_updated
		}
	
	func is_active() -> bool:
		return active

class ReputationSystem:
	var npc_ref: CharacterBody2D
	var reputation = 50
	var community_expectations = []
	var active = false
	
	func initialize(npc: CharacterBody2D):
		npc_ref = npc
		active = true
	
	func get_state() -> Dictionary:
		return {
			"reputation": reputation,
			"community_expectations": community_expectations
		}
	
	func is_active() -> bool:
		return active

class ResourceSystem:
	var npc_ref: CharacterBody2D
	var items = {}
	var energy = 100
	var time_budget = 100
	var active = false
	
	func initialize(npc: CharacterBody2D):
		npc_ref = npc
		active = true
	
	func get_state() -> Dictionary:
		return {
			"items": items,
			"energy": energy,
			"time_budget": time_budget
		}
	
	func is_active() -> bool:
		return active


class TheoryOfMindSystem:
	var npc_ref: CharacterBody2D
	var latest_response = {}
	var active = false
	
	func initialize(npc: CharacterBody2D):
		npc_ref = npc
		active = true
	
	func get_latest_response() -> Dictionary:
		return latest_response
	
	func is_active() -> bool:
		return active
