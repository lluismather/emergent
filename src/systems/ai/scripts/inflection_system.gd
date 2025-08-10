# InflectionSystem - MCP Server for decision trigger detection
# Detects when an entity should make decisions and provides trigger analysis

extends MCPServerBase
class_name InflectionSystemMCP

signal inflection_triggered(triggers: Array[String])

var last_decision_time: float = 0.0
var last_checked_context: String = ""
var active_triggers: Array[String] = []

# Configurable parameters
var decision_cooldown: float = 2.0 # Minimum seconds between decisions (reduced for more frequent updates)
var routine_check_interval: float = 8.0 # Routine decision interval (reduced from 30s to 8s)
var perception_sensitivity: float = 1.5 # How sensitive to perception changes (increased sensitivity)

func initialize(entity: Node) -> bool:
	"""Initialize the inflection system for any entity"""
	# Initialize MCP server base
	var success = super.initialize(entity)
	
	last_decision_time = Time.get_unix_time_from_system()
	return success

func should_make_decision() -> bool:
	"""Main method to check if entity should make a decision"""
	if not active or not entity_ref:
		return false
		
	var current_time = Time.get_unix_time_from_system()
	
	# Respect cooldown to prevent decision thrashing
	if current_time - last_decision_time < decision_cooldown:
		return false
		
	# Clear and evaluate triggers
	active_triggers.clear()
	_evaluate_triggers(current_time)
	
	# If we have triggers, it's time to decide
	if active_triggers.size() > 0:
		last_decision_time = current_time
		inflection_triggered.emit(active_triggers)
		return true
		
	return false

func _evaluate_triggers(current_time: float):
	"""Evaluate all possible inflection triggers"""
	
	# Trigger 1: Routine time-based decisions
	if current_time - last_decision_time > routine_check_interval:
		active_triggers.append("routine_check")
	
	# Trigger 2: Environmental context changes (day/night, weather, etc.)
	var current_context = _get_environmental_context()
	if current_context != last_checked_context:
		active_triggers.append("environmental_change")
		last_checked_context = current_context
	
	# Trigger 3: Entity is idle (no current actions)
	if _is_entity_idle():
		active_triggers.append("idle_state")
	
	# Trigger 4: Significant perception changes
	if _has_perception_change():
		active_triggers.append("perception_change")
	
	# Trigger 5: Goal completion or failure
	if _has_goal_state_change():
		active_triggers.append("goal_state_change")
	
	# Trigger 6: Need threshold crossed (if entity has needs system)
	if _has_need_threshold_crossed():
		active_triggers.append("need_threshold")

func _get_environmental_context() -> String:
	"""Get current environmental state (day/night, season, weather, etc.)"""
	var context_parts = []
	
	# Check for day/night cycle
	var day_night_cycle = entity_ref.get_tree().get_first_node_in_group("day_night_cycle")
	if day_night_cycle and day_night_cycle.has_method("get_current_state"):
		context_parts.append(day_night_cycle.get_current_state())
	
	# Add location context if available
	if entity_ref.has_method("get_current_location"):
		context_parts.append(entity_ref.get_current_location())
	
	return "_".join(context_parts)

func _is_entity_idle() -> bool:
	"""Check if entity is currently idle (no active actions)"""
	# Check for execution system
	if entity_ref.has_method("get") and entity_ref.get("execution_system"):
		var exec_system = entity_ref.get("execution_system")
		if exec_system and exec_system.has_method("is_idle"):
			return exec_system.is_idle()
	
	# Fallback: check if entity has current_action property
	if entity_ref.has_method("get") and entity_ref.get("current_action") == null:
		return true
		
	return false

func _has_perception_change() -> bool:
	"""Check if perception system detected significant changes"""
	if entity_ref.has_method("get") and entity_ref.get("perception_system"):
		var perception_system = entity_ref.get("perception_system")
		if perception_system and perception_system.has_method("has_context_changed"):
			return perception_system.has_context_changed()
	return false

func _has_goal_state_change() -> bool:
	"""Check if goals have completed, failed, or changed priority"""
	if entity_ref.has_method("get") and entity_ref.get("goals_system"):
		var goals_system = entity_ref.get("goals_system")
		if goals_system and goals_system.has_method("has_state_changed"):
			return goals_system.has_state_changed()
	return false

func _has_need_threshold_crossed() -> bool:
	"""Check if any needs have crossed critical thresholds"""
	if entity_ref.has_method("get") and entity_ref.get("needs_system"):
		var needs_system = entity_ref.get("needs_system")
		if needs_system and needs_system.has_method("has_critical_need"):
			return needs_system.has_critical_need()
	return false

func get_current_needs() -> String:
	"""Get a description of current needs for the DecisionManager"""
	# This is a placeholder - in a full implementation, this would query a needs system
	# For now, return basic needs that all entities have
	var needs = []
	
	# Check if entity is idle (might be bored)
	if _is_entity_idle():
		needs.append("activity")
	
	# Check if entity has been in same location for a while (might want to explore)
	var current_time = Time.get_unix_time_from_system()
	if current_time - last_decision_time > routine_check_interval * 2:
		needs.append("exploration")
	
	# Add basic survival needs
	needs.append("social_interaction")
	needs.append("purpose")
	
	return ", ".join(needs) if needs.size() > 0 else "content"

# Configuration methods
func set_decision_cooldown(seconds: float):
	"""Configure minimum time between decisions"""
	decision_cooldown = seconds

func set_routine_interval(seconds: float):
	"""Configure routine decision check interval"""
	routine_check_interval = seconds

func set_perception_sensitivity(sensitivity: float):
	"""Configure how sensitive to perception changes (0.0 - 2.0)"""
	perception_sensitivity = clamp(sensitivity, 0.0, 2.0)

# State access methods
func get_active_triggers() -> Array[String]:
	"""Get current active triggers"""
	return active_triggers.duplicate()

func get_last_decision_time() -> float:
	"""Get timestamp of last decision"""
	return last_decision_time

func is_active() -> bool:
	"""Check if system is active"""
	return active

func set_active(is_active: bool):
	"""Enable/disable the inflection system"""
	super.set_active(is_active)

func get_state() -> Dictionary:
	"""Get full system state for debugging/persistence"""
	return {
		"active": active,
		"last_decision_time": last_decision_time,
		"last_checked_context": last_checked_context,
		"active_triggers": active_triggers,
		"decision_cooldown": decision_cooldown,
		"routine_check_interval": routine_check_interval
	}

# ============================================================================
# MCP SERVER INTERFACE IMPLEMENTATION
# ============================================================================

func _register_tools():
	"""Register available tools for AI to discover and use"""
	register_tool("check_should_decide", "Check if entity should make a decision now")
	
	register_tool("evaluate_triggers", "Evaluate all decision triggers and get detailed analysis")
	
	register_tool("set_decision_cooldown", "Configure minimum time between decisions", {
		"seconds": {"type": "number", "description": "Cooldown duration in seconds"}
	}, ["seconds"])
	
	register_tool("set_routine_interval", "Configure routine decision check interval", {
		"seconds": {"type": "number", "description": "Routine interval in seconds"}
	}, ["seconds"])
	
	register_tool("force_decision_check", "Force immediate decision trigger evaluation")

func _register_resources():
	"""Register available resources for AI to access"""
	register_resource("inflection_state", "Current inflection system state and triggers")
	register_resource("decision_timing", "Information about decision timing and cooldowns")
	register_resource("trigger_analysis", "Detailed analysis of current decision triggers")
	register_resource("configuration", "Current inflection system configuration")

func _execute_tool_internal(tool_name: String, args: Dictionary) -> Dictionary:
	"""Execute inflection tools"""
	match tool_name:
		"check_should_decide":
			return mcp_tool_check_should_decide()
		"evaluate_triggers":
			return mcp_tool_evaluate_triggers()
		"set_decision_cooldown":
			return mcp_tool_set_decision_cooldown(
				args.get("seconds", decision_cooldown)
			)
		"set_routine_interval":
			return mcp_tool_set_routine_interval(
				args.get("seconds", routine_check_interval)
			)
		"force_decision_check":
			return mcp_tool_force_decision_check()
		_:
			return {"error": "Unknown tool", "tool": tool_name}

func _get_resource_internal(resource_name: String) -> Dictionary:
	"""Get inflection resources"""
	match resource_name:
		"inflection_state":
			return mcp_resource_inflection_state()
		"decision_timing":
			return mcp_resource_decision_timing()
		"trigger_analysis":
			return mcp_resource_trigger_analysis()
		"configuration":
			return mcp_resource_configuration()
		_:
			return {"error": "Unknown resource", "resource": resource_name}

# ============================================================================
# MCP SERVER INTERFACE - TOOLS
# ============================================================================

func mcp_tool_check_should_decide() -> Dictionary:
	"""Tool: Check if entity should make a decision"""
	var should_decide = should_make_decision()
	return {
		"should_decide": should_decide,
		"active_triggers": active_triggers.duplicate(),
		"trigger_count": active_triggers.size(),
		"last_decision_time": last_decision_time,
		"time_since_last_decision": Time.get_unix_time_from_system() - last_decision_time,
		"cooldown_remaining": max(0, decision_cooldown - (Time.get_unix_time_from_system() - last_decision_time))
	}

func mcp_tool_evaluate_triggers() -> Dictionary:
	"""Tool: Detailed trigger evaluation"""
	var current_time = Time.get_unix_time_from_system()
	active_triggers.clear()
	_evaluate_triggers(current_time)
	
	return {
		"timestamp": current_time,
		"active_triggers": active_triggers.duplicate(),
		"trigger_details": {
			"routine_check": current_time - last_decision_time > routine_check_interval,
			"environmental_change": _get_environmental_context() != last_checked_context,
			"idle_state": _is_entity_idle(),
			"perception_change": _has_perception_change(),
			"goal_state_change": _has_goal_state_change(),
			"need_threshold": _has_need_threshold_crossed()
		},
		"environmental_context": _get_environmental_context(),
		"last_checked_context": last_checked_context
	}

func mcp_tool_set_decision_cooldown(seconds: float) -> Dictionary:
	"""Tool: Set decision cooldown"""
	var old_cooldown = decision_cooldown
	set_decision_cooldown(seconds)
	return {
		"success": true,
		"old_cooldown": old_cooldown,
		"new_cooldown": decision_cooldown
	}

func mcp_tool_set_routine_interval(seconds: float) -> Dictionary:
	"""Tool: Set routine check interval"""
	var old_interval = routine_check_interval
	set_routine_interval(seconds)
	return {
		"success": true,
		"old_interval": old_interval,
		"new_interval": routine_check_interval
	}

func mcp_tool_force_decision_check() -> Dictionary:
	"""Tool: Force immediate decision check"""
	# Temporarily bypass cooldown
	var old_last_decision = last_decision_time
	last_decision_time = 0.0
	
	var result = should_make_decision()
	
	# If no decision was triggered, restore the old timestamp
	if not result:
		last_decision_time = old_last_decision
	
	return {
		"forced_check": true,
		"decision_triggered": result,
		"active_triggers": active_triggers.duplicate(),
		"bypassed_cooldown": true
	}

# ============================================================================
# MCP SERVER INTERFACE - RESOURCES
# ============================================================================

func mcp_resource_inflection_state() -> Dictionary:
	"""Resource: Current inflection system state"""
	return {
		"timestamp": Time.get_unix_time_from_system(),
		"active": active,
		"entity": entity_ref.name if entity_ref else "unknown",
		"last_decision_time": last_decision_time,
		"last_checked_context": last_checked_context,
		"active_triggers": active_triggers.duplicate(),
		"time_since_last_decision": Time.get_unix_time_from_system() - last_decision_time,
		"ready_for_decision": Time.get_unix_time_from_system() - last_decision_time >= decision_cooldown
	}

func mcp_resource_decision_timing() -> Dictionary:
	"""Resource: Decision timing information"""
	var current_time = Time.get_unix_time_from_system()
	var time_since_last = current_time - last_decision_time
	
	return {
		"timestamp": current_time,
		"last_decision_time": last_decision_time,
		"time_since_last_decision": time_since_last,
		"decision_cooldown": decision_cooldown,
		"routine_check_interval": routine_check_interval,
		"cooldown_remaining": max(0, decision_cooldown - time_since_last),
		"time_until_routine_check": max(0, routine_check_interval - time_since_last),
		"in_cooldown": time_since_last < decision_cooldown,
		"routine_check_due": time_since_last >= routine_check_interval
	}

func mcp_resource_trigger_analysis() -> Dictionary:
	"""Resource: Detailed trigger analysis"""
	var current_time = Time.get_unix_time_from_system()
	var environmental_context = _get_environmental_context()
	
	return {
		"timestamp": current_time,
		"trigger_states": {
			"routine_check": {
				"active": current_time - last_decision_time > routine_check_interval,
				"time_until": max(0, routine_check_interval - (current_time - last_decision_time))
			},
			"environmental_change": {
				"active": environmental_context != last_checked_context,
				"current_context": environmental_context,
				"previous_context": last_checked_context
			},
			"idle_state": {
				"active": _is_entity_idle(),
				"description": "Entity has no active actions or goals"
			},
			"perception_change": {
				"active": _has_perception_change(),
				"description": "Significant changes detected in environment"
			},
			"goal_state_change": {
				"active": _has_goal_state_change(),
				"description": "Goals completed, failed, or priority changed"
			},
			"need_threshold": {
				"active": _has_need_threshold_crossed(),
				"description": "Critical need thresholds have been crossed"
			}
		},
		"total_active_triggers": active_triggers.size(),
		"active_trigger_names": active_triggers.duplicate()
	}

func mcp_resource_configuration() -> Dictionary:
	"""Resource: Current configuration"""
	return {
		"timestamp": Time.get_unix_time_from_system(),
		"decision_cooldown": decision_cooldown,
		"routine_check_interval": routine_check_interval,
		"perception_sensitivity": perception_sensitivity,
		"server_info": get_server_info()
	}