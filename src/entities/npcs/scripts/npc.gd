extends CharacterBody2D

const SPEED = 100.0

@onready var animated_sprite = $AnimatedSprite2D

# Core NPC subsystems
var perception_system = PerceptionSystem.new()
var needs_system = NeedsSystem.new()
var personality_system = PersonalitySystem.new()
var memory_system = MemorySystem.new()
var goals_system = GoalsSystem.new()
var planning_system = PlanningSystem.new()
var social_system = SocialSystem.new()
var identity_system = IdentitySystem.new()
var execution_system: ExecutionSystem = null  # Will be created as component
var emotion_system = EmotionSystem.new()
var reputation_system = ReputationSystem.new()
var resource_system = ResourceSystem.new()
var inflection_system = InflectionSystem.new()
var theory_of_mind_system = TheoryOfMindSystem.new()

# Current state (minimal for now)
var current_goal = null
var current_action = null

# NPC Identity
@export var npc_id: String = "npc_001"
@export var npc_name: String = "Unnamed NPC"
@export var npc_role: String = "Villager"

func _ready():
	# Initialize all subsystems
	_initialize_all_systems()
	
	# Add to groups
	add_to_group("day_night_responders")
	add_to_group("npcs")
	
	print("NPC initialized: ", npc_name, " (", npc_role, ")")

func _initialize_all_systems():
	# Initialize each system
	perception_system.initialize(self)
	needs_system.initialize(self)
	personality_system.initialize(self)
	memory_system.initialize(self)
	goals_system.initialize(self)
	planning_system.initialize(self)
	social_system.initialize(self)
	identity_system.initialize(self)
	
	# Create ExecutionSystem as a component
	execution_system = ExecutionSystem.new()
	execution_system.name = "ExecutionSystem"
	add_child(execution_system)
	execution_system.initialize(self)
	
	# Connect to ExecutionSystem signals
	execution_system.action_started.connect(_on_action_started)
	execution_system.action_completed.connect(_on_action_completed)
	execution_system.action_interrupted.connect(_on_action_interrupted)
	execution_system.execution_status_changed.connect(_on_execution_status_changed)
	execution_system.movement_update.connect(_on_movement_update)
	
	emotion_system.initialize(self)
	reputation_system.initialize(self)
	resource_system.initialize(self)
	inflection_system.initialize(self)
	theory_of_mind_system.initialize(self)

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
	# This will eventually coordinate with MCP servers and LLM
	# For now, it's empty
	pass

# ExecutionSystem signal handlers
func _on_action_started(action_type: String, action_data: Dictionary):
	if DebugConfig and DebugConfig.is_ai_debug():
		DebugConfig.debug_print("NPC %s started action: %s" % [npc_name, action_type], "ai")

func _on_action_completed(action_type: String, success: bool, result: Dictionary):
	if DebugConfig and DebugConfig.is_ai_debug():
		DebugConfig.debug_print("NPC %s completed action: %s (success: %s)" % [npc_name, action_type, success], "ai")

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
		var move_velocity = execution_system.get_velocity()
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
func move_to(target_position: Vector2, priority: ExecutionSystem.Priority = ExecutionSystem.Priority.NORMAL):
	if execution_system:
		execution_system.queue_move_to(target_position, priority)

func wait_for(duration: float, priority: ExecutionSystem.Priority = ExecutionSystem.Priority.NORMAL):
	if execution_system:
		execution_system.queue_wait(duration, priority)

func interact_with(target_id: String, duration: float = 2.0, priority: ExecutionSystem.Priority = ExecutionSystem.Priority.NORMAL):
	if execution_system:
		execution_system.queue_interact_with(target_id, duration, priority)

func clear_all_actions():
	if execution_system:
		execution_system.clear_action_queue()

func interrupt_current_action(reason: String = "Manual interrupt"):
	if execution_system:
		execution_system.interrupt_current_action(reason)

func get_execution_status() -> Dictionary:
	if execution_system:
		return execution_system.get_execution_state()
	return {}

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
		"systems_active": _count_active_systems()
	}

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
# SUBSYSTEM CLASSES (Empty shells ready for implementation)
# ============================================================================

class PerceptionSystem:
	var perception_mcp
	var active = false
	
	func initialize(npc: CharacterBody2D):
		# Load the perception system dynamically
		var PerceptionSystemClass = load("res://src/systems/ai/scripts/perception_system.gd")
		perception_mcp = PerceptionSystemClass.new()
		perception_mcp.initialize(npc)
		active = true
	
	func update(delta):
		if perception_mcp:
			perception_mcp.update(delta)
	
	func on_time_change(_state):
		pass
	
	func is_active() -> bool:
		return active
	
	# MCP Tool Access
	func get_nearby_objects(filter_type: String = "", max_distance: float = -1.0) -> Dictionary:
		if perception_mcp:
			return perception_mcp.mcp_tool_get_nearby_objects(filter_type, max_distance)
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

class InflectionSystem:
	var npc_ref: CharacterBody2D
	var last_checked = ""
	var active_triggers = []
	var priority_queue = []
	var active = false
	
	func initialize(npc: CharacterBody2D):
		npc_ref = npc
		active = true
	
	func should_make_decision() -> bool:
		return false  # Will implement decision triggers later
	
	func get_state() -> Dictionary:
		return {
			"last_checked": last_checked,
			"active_triggers": active_triggers,
			"priority_queue": priority_queue
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