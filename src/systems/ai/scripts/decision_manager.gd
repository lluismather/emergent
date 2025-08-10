# DecisionManager - Orchestrates LLM-based decision making for NPCs
# 
# This system bridges the gap between NPCs and Large Language Models (LLMs)
# by managing decision requests, context gathering, and response handling.
#
# Key Features:
# - Sends structured prompts to Ollama (or other LLM providers)
# - Caches decisions to avoid redundant LLM calls
# - Manages cooldown periods to prevent API spam
# - Provides rich context from NPC systems for informed decisions
#
# Decision Flow:
# 1. NPC requests decision via request_decision()
# 2. Context is gathered from MCP servers (perception, execution, etc.)
# 3. Structured prompt is sent to LLM via HTTP request
# 4. LLM response is parsed and validated
# 5. Decision is cached and emitted to NPC for execution
#
# Integration:
# - Attached as child node to NPCs in the scene tree
# - Connected via signals for asynchronous decision handling
# - Requires Ollama server running locally (default: localhost:11434)

extends Node
class_name DecisionManager

# Configuration
var ollama_url: String = "http://localhost:11434/api/generate"
var decision_cooldown: float = 0.5 # Very short cooldown for responsive movement
var max_cache_size: int = 100 # Maximum cached decisions to keep

# Decision caching with timestamps for expiry
var decision_cache: Dictionary = {}
var cache_timestamps: Dictionary = {}
var cache_expiry_seconds: float = 5.0 # Cache expires after 5 seconds
var last_decision_time: Dictionary = {} # Per NPC
var pending_decisions: Array[Dictionary] = []

# HTTP client for Ollama
var http_client: HTTPRequest
var is_request_in_progress: bool = false

# Signal for when decisions are made
signal decision_made(npc_id: String, decision: Dictionary, context_hash: String)
signal decision_failed(npc_id: String, error: String)

func _ready():
	http_client = HTTPRequest.new()
	add_child(http_client)
	http_client.request_completed.connect(_on_http_request_completed)

func request_decision(npc: Node, context: Dictionary, priority: int = 1) -> bool:
	"""Request a decision from the LLM for an NPC.
	
	This is the main entry point for NPCs to request AI-driven decisions.
	The method handles caching, cooldown management, and asynchronous LLM requests.
	
	Args:
		npc: The NPC node requesting a decision
		context: Rich context dictionary with available actions, needs, etc.
		priority: Priority level (1-5) for urgent decisions
	
	Returns:
		bool: True if request was sent, False if cached/queued
	
	Signals Emitted:
		- decision_made(npc_id, decision, context_hash) on success
		- decision_failed(npc_id, error) on failure
	"""
	var npc_id = npc.npc_name if "npc_name" in npc else npc.name
	
	# Check cooldown
	if _is_in_cooldown(npc_id):
		print("[DecisionManager] %s is in cooldown, queuing decision" % npc_id)
		_queue_decision(npc, context, priority)
		return false
	
	# Check cache with expiry to allow some reuse but ensure freshness
	var context_hash = _hash_context(context)
	var current_time = Time.get_unix_time_from_system()
	
	if decision_cache.has(context_hash):
		var cache_time = cache_timestamps.get(context_hash, 0.0)
		var cache_age = current_time - cache_time
		
		if cache_age < cache_expiry_seconds:
			var cached_decision = decision_cache.get(context_hash)
			print("[DecisionManager] Using recent cached decision for %s (age: %.1fs)" % [npc_id, cache_age])
			decision_made.emit(npc_id, cached_decision, context_hash)
			return true
		else:
			# Cache expired, remove it
			print("[DecisionManager] Cache expired for %s (age: %.1fs)" % [npc_id, cache_age])
			decision_cache.erase(context_hash)
			cache_timestamps.erase(context_hash)
	
	# Build and send prompt
	var prompt = _build_decision_prompt(npc, context)
	var success = _send_ollama_request(npc_id, prompt, context_hash)
	
	if success:
		last_decision_time[npc_id] = Time.get_unix_time_from_system()
	
	return success

func _build_decision_prompt(npc: Node, context: Dictionary) -> String:
	"""Build a structured prompt for the LLM based on NPC context.
	
	This creates a comprehensive prompt that includes NPC personality,
	current needs, available actions, and world state discovered through MCP servers.
	The prompt is designed to elicit structured JSON responses from the LLM.
	
	Args:
		npc: The NPC node to build context for
		context: Context dictionary from the NPC's decision request
	
	Returns:
		str: Formatted prompt string ready for LLM consumption
	"""
	
	# Extract NPC state
	var npc_state = _extract_npc_state(npc)
	var world_context = _extract_world_context()
	
	# Get real available actions and locations through MCP servers
	var mcp_data = _gather_mcp_context(npc)
	
	# Get perception-based movement options
	var movement_options = _generate_movement_options(npc, mcp_data.get("perception", {}))
	
	# Build the prompt using real MCP data and perception-based movement
	var prompt = """You are deciding what to do next.

Your Context:
- Name: %s
- Role: %s
- Current Position: %s
- Current Needs: %s

World Context:
- Time: %s
- Current Environment: %s

Available Movement Options (within perception range):
%s

Available MCP Tools:
- queue_move_to: Move to a specific position (server: execution)
- queue_wait: Wait for a duration (server: execution)  
- queue_interact_with: Interact with nearby objects (server: execution)

Current Perception Data:
%s

Current Execution State:
%s

Choose a movement action for the NPC. Use queue_move_to with one of the movement options or queue_wait if no movement is desired.

Respond with ONLY a JSON object in this exact format:
{
  "tool": "queue_move_to",
  "server": "execution",
  "args": {"position": {"x": 300, "y": 400}, "priority": 1},
  "reason": "brief_reason_for_choice"
}""" % [
		npc_state.get("name", "Unknown"),
		npc_state.get("personality", "Unknown Role"),
		_format_position(npc.global_position if npc else Vector2.ZERO),
		npc_state.get("needs", "None"),
		world_context.get("time", "Unknown"),
		world_context.get("location", "Unknown"),
		movement_options,
		_format_perception_data(mcp_data.get("perception", {})),
		_format_execution_state(mcp_data.get("execution", {}))
	]
	
	return prompt

func _extract_npc_state(npc: Node) -> Dictionary:
	"""Extract relevant state information from an NPC.
	
	Gathers personality, needs, relationships, and goals from the NPC's
	various AI subsystems via MCP server interfaces.
	
	Args:
		npc: The NPC node to extract state from
	
	Returns:
		Dictionary: Comprehensive NPC state for prompt building
	"""
	var state = {}
	
	# Basic info
	state["name"] = npc.npc_name if "npc_name" in npc else npc.name
	state["personality"] = npc.npc_role if "npc_role" in npc else "Wizard" # Use NPC role or fallback
	
	# Get needs from inflection system if available
	if npc.has_node("InflectionSystemMCP"):
		var inflection = npc.get_node("InflectionSystemMCP")
		if inflection.has_method("get_current_needs"):
			state["needs"] = inflection.get_current_needs()
		else:
			state["needs"] = "Basic needs (hunger, rest, social)"
	
	# Get relationships
	state["relationships"] = "No relationships tracked yet"
	
	# Get recent memory
	state["recent_memory"] = "No recent events"
	
	# Get current goals
	if npc.has_node("ExecutionSystemMCP"):
		var execution = npc.get_node("ExecutionSystemMCP")
		if execution.has_method("get_current_action_type"):
			var current_action = execution.get_current_action_type()
			state["current_goals"] = current_action if current_action else "Idle"
		else:
			state["current_goals"] = "Unknown"
	
	return state

func _extract_world_context() -> Dictionary:
	"""Extract current world context"""
	var context = {}
	
	# Time of day
	var time_dict = Time.get_time_dict_from_system()
	context["time"] = AIUtils.get_game_time_string(time_dict.hour, time_dict.minute)
	context["time_period"] = AIUtils.get_time_period_name(time_dict.hour)
	
	# Location (hardcoded for now)
	context["location"] = "Game World"
	
	# Nearby objects (would come from perception system)
	context["nearby_objects"] = "Various objects"
	
	# Current goals
	context["current_goals"] = "None"
	
	return context

func _gather_mcp_context(npc: Node) -> Dictionary:
	"""Gather available MCP tools and resources from the NPC"""
	var mcp_data = {
		"tools": {},
		"resources": {},
		"perception": {},
		"execution": {}
	}
	
	# Get available MCP servers from the NPC
	if npc.has_method("get_available_mcp_servers"):
		var servers = npc.get_available_mcp_servers()
		
		# Collect all available tools and resources
		for server_name in servers:
			var server_info = servers[server_name]
			mcp_data.tools[server_name] = server_info.get("tools", {})
			mcp_data.resources[server_name] = server_info.get("resources", {})
		
		# Get current state from key systems
		if npc.has_method("get_mcp_resource"):
			mcp_data.perception = npc.get_mcp_resource("perception", "perception_snapshot")
			mcp_data.execution = npc.get_mcp_resource("execution", "execution_state")
	
	return mcp_data

func _format_position(pos: Vector2) -> String:
	"""Format position for display"""
	return "(%d, %d)" % [pos.x, pos.y]

func _format_available_tools(tools_by_server: Dictionary) -> String:
	"""Format available MCP tools for the prompt"""
	var tool_descriptions = []
	
	for server_name in tools_by_server:
		var server_tools = tools_by_server[server_name]
		tool_descriptions.append("Server '%s':" % server_name)
		
		for tool_name in server_tools:
			var tool_info = server_tools[tool_name]
			var params = tool_info.get("parameters", {})
			var param_list = []
			for param in params:
				param_list.append("%s: %s" % [param, params[param].get("type", "unknown")])
			
			tool_descriptions.append("  - %s: %s (params: %s)" % [
				tool_name,
				tool_info.get("description", "No description"),
				", ".join(param_list) if param_list.size() > 0 else "none"
			])
	
	return "\n".join(tool_descriptions) if tool_descriptions.size() > 0 else "No tools available"

func _format_available_resources(resources_by_server: Dictionary) -> String:
	"""Format available MCP resources for the prompt"""
	var resource_descriptions = []
	
	for server_name in resources_by_server:
		var server_resources = resources_by_server[server_name]
		resource_descriptions.append("Server '%s':" % server_name)
		
		for resource_name in server_resources:
			var resource_info = server_resources[resource_name]
			resource_descriptions.append("  - %s: %s" % [
				resource_name,
				resource_info.get("description", "No description")
			])
	
	return "\n".join(resource_descriptions) if resource_descriptions.size() > 0 else "No resources available"

func _format_perception_data(perception_data: Dictionary) -> String:
	if perception_data.has("error"):
		return "Perception not available: %s" % perception_data.error

	var data: Dictionary = perception_data.get("perception_data", perception_data)
	var parts := []

	var objs = data.get("nearby_objects", [])
	if objs is Array and objs.size() > 0:
		var labels := []
		for i in range(min(10, objs.size())):
			var obj: Dictionary = objs[i]
			var name = obj.get("properties", {}).get("name", obj.get("id", obj.get("type", "object")))
			var d = obj.get("distance")
			var pos = obj.get("position")
			var pos_str = ""
			if pos is Vector2:
				pos_str = _format_position(pos)
			elif pos is Array and pos.size() >= 2:
				pos_str = "(%d, %d)" % [int(pos[0]), int(pos[1])]
			else:
				pos_str = "(?, ?)"
			var label = "%s %s" % [name, pos_str]
			if d != null:
				label = "%s (~%d u)" % [label, int(round(float(d)))]
			labels.append(label)
		parts.append("Nearby: " + ", ".join(labels))
	else:
		parts.append("Nearby: none")

	# Environment
	var env: Dictionary = data.get("environmental", data.get("environment", {}))
	if env.size() > 0:
		var bits := []
		if env.has("weather"): bits.append(str(env.weather))
		if env.has("lighting"): bits.append(str(env.lighting))
		if env.has("crowd_density"): bits.append("crowd=" + str(env.crowd_density))
		if env.has("noise_level"): bits.append("noise=" + str(env.noise_level))
		if env.has("temperature"): bits.append("temp=" + str(env.temperature))
		if bits.size() > 0:
			parts.append("Env: " + ", ".join(bits))

	# Time
	if data.has("temporal"):
		var t: Dictionary = data.temporal
		var time_str = t.get("game_time", "%02d:%02d" % [int(t.get("hour", 0)), int(t.get("minute", 0))])
		parts.append("Time: %s" % time_str)

	return "\n".join(parts)

func _format_execution_state(execution_data: Dictionary) -> String:
	"""Format execution state for the prompt"""
	if execution_data.has("error"):
		return "Execution state not available: %s" % execution_data.error
	
	var parts = []
	if execution_data.has("status"):
		parts.append("Status: %s" % execution_data.status)
	
	if execution_data.has("current_action") and not execution_data.current_action.is_empty():
		var action = execution_data.current_action
		parts.append("Current action: %s" % action.get("type", "unknown"))
	
	if execution_data.has("queue_size"):
		parts.append("Actions queued: %d" % execution_data.queue_size)
	
	return "\n".join(parts) if parts.size() > 0 else "Idle, no current actions"

func _generate_movement_options(npc: Node, perception_data: Dictionary) -> String:
	"""Generate movement options within the NPC's perception circle"""
	var options = []
	var npc_position = npc.global_position if npc else Vector2.ZERO
	var perception_radius = 100.0 # Default perception radius
	
	# Try to get actual perception radius from the system
	if npc.has_method("get_mcp_resource"):
		var perception_info = npc.get_mcp_resource("perception", "perception_snapshot")
		if perception_info.has("radius"):
			perception_radius = perception_info.radius
	
	# pass bounds to the options
	options.append("Within perception circle (%.1f units radius) around (%d, %d):" % [
		perception_radius, npc_position.x, npc_position.y
	])
	
	# Add option to stay in place
	options.append("Current position (%d, %d) - Stay in place" % [npc_position.x, npc_position.y])
	
	# Add nearby objects as movement targets if available
	if perception_data.has("nearby_objects"):
		var objects = perception_data.nearby_objects
		if objects is Array:
			for obj in objects.slice(0, 3): # Max 3 object targets
				if obj.has("position"):
					var obj_pos = obj.position
					var obj_name = obj.get("properties", {}).get("name", obj.get("id", obj.get("type", "object")))
					options.append("Near %s (%d, %d) - Interact opportunity" % [obj_name, obj_pos.x, obj_pos.y])
	
	return "\n".join(options.map(func(opt): return "- " + opt))

func _send_ollama_request(npc_id: String, prompt: String, context_hash: String) -> bool:
	"""Send a request to Ollama"""
	# Check if a request is already in progress
	if is_request_in_progress:
		print("[DecisionManager] Request already in progress, queuing decision for %s" % npc_id)
		return false
	
	var headers = ["Content-Type: application/json"]
	var body = {
		# "model": "gpt-oss:20b", # Use the available model
		"model": "llama3.1:8b", # Use the available model
		"prompt": prompt,
		"stream": false,
		# "format": "json",
		# "options": {"num_predict": 64}
	}
	
	var json_body = JSON.stringify(body)
	
	# print("[DecisionManager] Sending LLM request for %s:" % npc_id)
	# print("[DecisionManager] Model: %s" % body.model)
	# print("[DecisionManager] Prompt length: %d characters" % prompt.length())
	print("=====================================================")
	print("Sending:")
	print("[DecisionManager] Full prompt:\n%s" % prompt)
	print("=====================================================")
	
	# Store context for response handling
	pending_decisions.append({
		"npc_id": npc_id,
		"context_hash": context_hash,
		"timestamp": Time.get_unix_time_from_system()
	})
	
	# Mark request as in progress
	is_request_in_progress = true
	
	var error = http_client.request(ollama_url, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		print("[DecisionManager] Failed to send request to Ollama: %s" % error)
		is_request_in_progress = false # Reset state on failure
		return false
	
	return true

func _on_http_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	"""Handle Ollama response"""
	print("[DecisionManager] Received LLM response - Result: %s, Code: %s" % [result, response_code])
	
	# Reset the request state
	is_request_in_progress = false
	
	if result != HTTPRequest.RESULT_SUCCESS:
		print("[DecisionManager] HTTP request failed: %s" % result)
		return
	
	if response_code != 200:
		print("[DecisionManager] HTTP response error: %s" % response_code)
		return
	
	# Parse response
	var response_text = body.get_string_from_utf8()
	print("[DecisionManager] Raw response length: %d characters" % response_text.length())
	print("====================================================")
	print("[DecisionManager] Raw response:\n%s" % response_text)
	print("====================================================")
	
	var json = JSON.new()
	var parse_result = json.parse(response_text)
	
	if parse_result != OK:
		print("[DecisionManager] Failed to parse JSON response")
		return
	
	var response_data = json.data
	var response_text_content = response_data.get("response", "")
	print("[DecisionManager] Extracted response content: %s" % response_text_content)
	
	# Extract JSON from response (Ollama might wrap it in markdown)
	var json_start = response_text_content.find("{")
	var json_end = response_text_content.rfind("}")
	
	if json_start == -1 or json_end == -1:
		print("[DecisionManager] No JSON found in response")
		return
	
	var json_content = response_text_content.substr(json_start, json_end - json_start + 1)
	var decision_parse = json.parse(json_content)
	
	if decision_parse != OK:
		print("[DecisionManager] Failed to parse decision JSON")
		return
	
	var decision = json.data
	
	# Validate decision format
	if not _validate_decision(decision):
		print("[DecisionManager] Invalid decision format received")
		return
	
	# Find the corresponding pending decision
	var pending_decision = null
	for pd in pending_decisions:
		if pd.get("timestamp") > Time.get_unix_time_from_system() - 30: # Within 30 seconds
			pending_decision = pd
			break
	
	if not pending_decision:
		print("[DecisionManager] No matching pending decision found")
		return
	
	# Don't cache movement decisions to ensure fresh random locations each time
	var context_hash = pending_decision.get("context_hash")
	# decision_cache[context_hash] = decision  # Disabled caching for movement decisions
	
	# Clean up cache if needed
	_cleanup_cache()
	
	# Emit signal using the found pending decision
	var npc_id = pending_decision.get("npc_id")
	decision_made.emit(npc_id, decision, context_hash)
	
	# Remove the processed pending decision
	pending_decisions.erase(pending_decision)
	
	print("[DecisionManager] Decision made for %s: call %s.%s (%s)" % [npc_id, decision.get("server", "Unknown"), decision.get("tool", "Unknown"), decision.get("reason", "Unknown")])

func _validate_decision(decision: Dictionary) -> bool:
	"""Validate that a decision has the required format for MCP tool calls"""
	var required_fields = ["tool", "server", "reason"]
	
	for field in required_fields:
		if not decision.has(field):
			print("[DecisionManager] Missing required field: %s" % field)
			return false
	
	# Validate server and tool exist
	var server = decision.get("server", "")
	var tool = decision.get("tool", "")
	
	# Valid servers and tools for movement decisions
	var valid_servers = ["execution"] # Focus on execution for movement
	if not server in valid_servers:
		print("[DecisionManager] Invalid server: %s (must be one of: %s)" % [server, valid_servers])
		return false
	
	var valid_tools = ["queue_move_to", "queue_wait", "queue_interact_with"]
	if not tool in valid_tools:
		print("[DecisionManager] Invalid tool: %s (must be one of: %s)" % [ tool , valid_tools])
		return false
	
	# Args field is optional but should be a dictionary if present
	if decision.has("args") and not decision.args is Dictionary:
		print("[DecisionManager] Args must be a dictionary")
		return false
	
	# Specific validation for queue_move_to
	if tool == "queue_move_to":
		var args = decision.get("args", {})
		if not args.has("position"):
			print("[DecisionManager] queue_move_to requires position argument")
			return false
		var pos = args.position
		if not (pos.has("x") and pos.has("y")):
			print("[DecisionManager] position must have x and y coordinates")
			return false
	
	return true

func _is_in_cooldown(npc_id: String) -> bool:
	"""Check if an NPC is in cooldown period"""
	var last_time = last_decision_time.get(npc_id, 0.0)
	var current_time = Time.get_unix_time_from_system()
	return (current_time - last_time) < decision_cooldown

func _queue_decision(npc: Node, context: Dictionary, priority: int):
	"""Queue a decision for later processing"""
	pending_decisions.append({
		"npc": npc,
		"context": context,
		"priority": priority,
		"timestamp": Time.get_unix_time_from_system()
	})
	
	# Sort by priority (highest first)
	pending_decisions.sort_custom(func(a, b): return a.get("priority", 1) > b.get("priority", 1))

func _cleanup_cache():
	"""Remove old cached decisions if cache is too large"""
	if decision_cache.size() > max_cache_size:
		var oldest_keys = []
		for key in decision_cache.keys():
			oldest_keys.append(key)
		
		# Remove oldest entries (simple FIFO for now)
		var to_remove = decision_cache.size() - max_cache_size
		for i in range(to_remove):
			if oldest_keys.size() > 0:
				decision_cache.erase(oldest_keys.pop_front())

func _hash_context(context: Dictionary) -> String:
	"""Create a hash of the context for caching"""
	# Use normalized context for better cache hit rates
	var normalized_context = AIUtils.normalize_context_for_hash(context)
	return AIUtils.hash_context(normalized_context)

func get_cached_decisions() -> Dictionary:
	"""Get all cached decisions (for debugging)"""
	return decision_cache.duplicate()

func clear_cache():
	"""Clear the decision cache"""
	decision_cache.clear()
	print("[DecisionManager] Decision cache cleared")

func set_ollama_url(url: String):
	"""Set the Ollama server URL"""
	ollama_url = url
	print("[DecisionManager] Ollama URL set to: %s" % url)

func set_decision_cooldown(cooldown: float):
	"""Set the decision cooldown period"""
	decision_cooldown = cooldown
	print("[DecisionManager] Decision cooldown set to: %.1f seconds" % cooldown)
