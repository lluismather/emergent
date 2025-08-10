# Perception System - MCP Server for NPC Environmental Awareness
extends MCPServerBase
class_name PerceptionSystemMCP

# Core perception configuration
var vision_radius: float = 80.0
var detection_layers: int = 0xFFFFFFFF # All collision layers
var update_frequency: float = 0.1 # Update every 100ms
var last_update_time: float = 0.0

# Perception data
var nearby_objects: Array[Dictionary] = []
var environmental_data: Dictionary = {}
var temporal_data: Dictionary = {}
var spatial_grid: Dictionary = {}

# Reference to the perceiving NPC
var owner_npc: CharacterBody2D
var world_reference: Node2D

# MCP Server state  
var last_query_hash: String = ""
var cached_response: Dictionary = {}

# Day-night cycle integration
var current_day_night_state: String = "day"
var game_time_hour: int = 6
var game_time_minute: int = 0

func _init():
	super._init("perception")

func initialize(entity: Node, world: Node2D = null) -> bool:
	# Initialize MCP server base
	var success = super.initialize(entity)
	
	# Cast to CharacterBody2D for perception system
	if entity is CharacterBody2D:
		owner_npc = entity as CharacterBody2D
		world_reference = world if world else entity.get_tree().current_scene
		
		# Connect to the day-night cycle for time updates
		if world_reference and world_reference.has_method("get_node"):
			var day_night_cycle = world_reference.get_node_or_null("DayNightCycle")
			if day_night_cycle:
				day_night_cycle.time_tick.connect(_on_time_tick)
		
		if DebugConfig and DebugConfig.is_perception_debug():
			var msg = AIUtils.format_debug_message("PerceptionMCP", entity.name, "System initialized successfully")
			DebugConfig.debug_print(msg, "perception")
		elif not DebugConfig:
			print("[PerceptionMCP] Initialized for NPC: %s" % entity.name)
		return true
	else:
		if DebugConfig and DebugConfig.is_perception_debug():
			var msg = AIUtils.format_debug_message("PerceptionMCP", AIUtils.safe_get_entity_name(entity), "Requires CharacterBody2D, got " + entity.get_class())
			DebugConfig.debug_print(msg, "perception")
		return false

# ============================================================================
# MCP SERVER INTERFACE IMPLEMENTATION
# ============================================================================

func _register_tools():
	"""Register available tools for AI to discover and use"""
	register_tool("get_nearby_objects", "Get objects within perception range", {
		"filter_type": {"type": "string", "description": "Filter by object type"},
		"max_distance": {"type": "number", "description": "Maximum distance to search"}
	})
	
	register_tool("find_object", "Find specific object by ID or type", {
		"object_id": {"type": "string", "description": "Specific object ID to find"},
		"object_type": {"type": "string", "description": "Type of object to find"}
	})
	
	register_tool("get_spatial_analysis", "Get spatial relationships of nearby objects")
	
	register_tool("scan_area", "Perform targeted scan of specific area", {
		"center": {"type": "vector2", "description": "Center point for scan"},
		"radius": {"type": "number", "description": "Scan radius"}
	}, ["center"])

func _register_resources():
	"""Register available resources for AI to access"""
	register_resource("perception_snapshot", "Current complete perception state")
	register_resource("environment", "Current environmental conditions")
	register_resource("temporal_data", "Time and day/night cycle information")
	register_resource("nearby_objects", "List of currently perceived objects")
	register_resource("spatial_grid", "Spatial organization of perceived objects")

func _execute_tool_internal(tool_name: String, args: Dictionary) -> Dictionary:
	"""Execute perception tools"""
	match tool_name:
		"get_nearby_objects":
			return mcp_tool_get_nearby_objects(
				args.get("filter_type", ""),
				args.get("max_distance", -1.0)
			)
		"find_object":
			return mcp_tool_find_object(
				args.get("object_id", ""),
				args.get("object_type", "")
			)
		"get_spatial_analysis":
			return mcp_tool_get_spatial_analysis()
		"scan_area":
			return mcp_tool_scan_area(
				args.get("center", Vector2.ZERO),
				args.get("radius", vision_radius)
			)
		_:
			return {"error": "Unknown tool", "tool": tool_name}

func _get_resource_internal(resource_name: String) -> Dictionary:
	"""Get perception resources"""
	match resource_name:
		"perception_snapshot":
			return mcp_resource_perception_snapshot()
		"environment":
			return mcp_resource_environment()
		"temporal_data":
			return mcp_resource_temporal_data()
		"nearby_objects":
			return mcp_resource_nearby_objects()
		"spatial_grid":
			return mcp_resource_spatial_grid()
		_:
			return {"error": "Unknown resource", "resource": resource_name}

func update(delta: float):
	if not active or not owner_npc:
		return
	
	last_update_time += delta
	
	# Update perception data at configured frequency
	if last_update_time >= update_frequency:
		_scan_environment()
		_update_temporal_data()
		_update_environmental_conditions()
		last_update_time = 0.0

# ============================================================================
# CORE PERCEPTION DETECTION
# ============================================================================

func _scan_environment():
	nearby_objects.clear()
	spatial_grid.clear()
	
	if not owner_npc:
		return
	
	var space_state = owner_npc.get_world_2d().direct_space_state
	var center_position = owner_npc.global_position
	
	# Create circular query for nearby objects
	var query = PhysicsShapeQueryParameters2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = vision_radius
	query.shape = circle_shape
	query.transform.origin = center_position
	query.collision_mask = detection_layers
	
	# Get all objects in perception radius
	var detected_bodies = space_state.intersect_shape(query, 32) # Max 32 objects
	
	for detection in detected_bodies:
		var body = detection.collider
		if body == owner_npc:
			continue # Skip self
		
		# Skip tilemap layers and other non-perceivable objects
		if body is TileMapLayer: # or body.name.to_lower().contains("layer"):
			continue
		
		# If this is a collision body (StaticBody2D, etc.), check its parent for groups/identity
		var target_node = body
		if body is StaticBody2D or body is RigidBody2D or body is CharacterBody2D:
			if body.get_parent() and body.get_parent() != body.get_tree().current_scene:
				target_node = body.get_parent()
		
		var obj_data = _analyze_object(target_node, center_position)
		nearby_objects.append(obj_data)
		
		# Objects are now properly detected and will appear in the debug UI sidebar
		
		# Add to spatial grid for quick lookups
		var grid_key = _get_grid_key(obj_data.relative_position)
		if not spatial_grid.has(grid_key):
			spatial_grid[grid_key] = []
		spatial_grid[grid_key].append(obj_data)

func _analyze_object(body: Node2D, center_pos: Vector2) -> Dictionary:
	var relative_pos = body.global_position - center_pos
	var distance = relative_pos.length()
	var direction = relative_pos.normalized()
	
	# Determine object velocity if it has CharacterBody2D
	var velocity = Vector2.ZERO
	var is_moving = false
	if body is CharacterBody2D:
		velocity = body.velocity
		is_moving = velocity.length() > 1.0
	
	# Classify object type
	var object_type = _classify_object(body)
	var object_id = _get_object_id(body)
	
	return {
		"id": object_id,
		"type": object_type,
		"position": body.global_position,
		"relative_position": relative_pos,
		"distance": distance,
		"direction": direction,
		"velocity": velocity,
		"is_moving": is_moving,
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"properties": _extract_object_properties(body)
	}

func _classify_object(body: Node2D) -> String:
	# Classify based on groups first (most reliable)
	if body.is_in_group("npcs"):
		return "npc"
	elif body.is_in_group("players"):
		return "player"
	elif body.is_in_group("light_sources"):
		return "light_source"
	elif body.is_in_group("animals"):
		return "animal"
	elif body.is_in_group("spell_targets"):
		return "interactive_object"
	elif body.is_in_group("items"):
		return "item"
	
	# Enhanced name-based classification
	var name_lower = body.name.to_lower()
	
	# Light sources
	if name_lower.contains("lamp") or name_lower.contains("torch"):
		return "light_source"
	
	# Vegetation
	elif name_lower.contains("tree") or name_lower.contains("bush") or name_lower.contains("flower"):
		return "vegetation"
	
	# Structures
	elif name_lower.contains("house") or name_lower.contains("building") or name_lower.contains("barn") or name_lower.contains("coop"):
		return "structure"
	
	# Furniture/objects
	elif name_lower.contains("fence") or name_lower.contains("well") or name_lower.contains("sign"):
		return "furniture"
	
	# Animals
	elif name_lower.contains("horse") or name_lower.contains("cow") or name_lower.contains("chicken"):
		return "animal"
	
	# Level transitions
	elif name_lower.contains("exit") or name_lower.contains("door") or name_lower.contains("portal"):
		return "portal"
	
	else:
		return "unknown"

func _get_object_id(body: Node2D) -> String:
	# Generate consistent ID for objects
	if body.has_method("get_npc_id"):
		return body.get_npc_id()
	elif body.name:
		return body.name.to_lower().replace(" ", "_")
	else:
		return "obj_%d" % body.get_instance_id()

func _extract_object_properties(body: Node2D) -> Dictionary:
	var properties = {}
	
	# Extract NPC-specific properties
	if body.has_method("get_debug_info"):
		var debug_info = body.get_debug_info()
		properties["name"] = debug_info.get("name", "Unknown")
		properties["role"] = debug_info.get("role", "Unknown")
	else:
		# Use node name as display name, cleaned up
		var display_name = body.name
		# Convert names like "PathLamp1" to "Path Lamp 1"
		display_name = display_name.replace("PathLamp", "Path Lamp ")
		display_name = display_name.replace("ForestLamp", "Forest Lamp ")
		display_name = display_name.replace("Torch", "Torch ")
		display_name = display_name.replace("LevelExit", "Level Exit ")
		display_name = display_name.replace("Horse", "Horse")
		properties["name"] = display_name
	
	# Extract size information
	if body.has_method("get_rect"):
		var rect = body.get_rect()
		properties["size"] = {"width": rect.size.x, "height": rect.size.y}
	
	# Add description based on object type
	var obj_type = _classify_object(body)
	properties["description"] = _get_object_description(obj_type, body.name)
	
	return properties

func _get_grid_key(relative_pos: Vector2) -> String:
	# Create spatial grid key for quick lookups (50x50 unit cells)
	var grid_size = 50.0
	var x = int(relative_pos.x / grid_size)
	var y = int(relative_pos.y / grid_size)
	return "%d,%d" % [x, y]

func _update_temporal_data():
	# Use game time from day-night cycle instead of system time
	temporal_data = {
		"hour": game_time_hour,
		"minute": game_time_minute,
		"is_day": current_day_night_state == "day",
		"is_night": current_day_night_state == "night",
		"day_night_state": current_day_night_state,
		"time_of_day": _get_time_period(game_time_hour),
		"game_time": AIUtils.get_game_time_string(game_time_hour, game_time_minute)
	}

func _get_time_period(hour: int) -> String:
	return AIUtils.get_time_period_name(hour)

func _update_environmental_conditions():
	# Get environmental data from game systems with day-night cycle integration
	var lighting_level = "bright" if current_day_night_state == "day" else "dim"
	if current_day_night_state == "night":
		# Check for artificial lighting sources nearby
		var light_sources = _count_nearby_light_sources()
		if light_sources > 0:
			lighting_level = "artificial"
	
	environmental_data = {
		"weather": "clear", # Would connect to weather system
		"temperature": _get_temperature_by_time(),
		"lighting": lighting_level,
		"noise_level": _calculate_noise_level(),
		"crowd_density": _calculate_crowd_density(),
		"time_atmosphere": _get_atmospheric_description()
	}

func _calculate_noise_level() -> String:
	var moving_objects = nearby_objects.filter(func(obj): return obj.is_moving)
	if moving_objects.size() > 3:
		return "noisy"
	elif moving_objects.size() > 1:
		return "moderate"
	else:
		return "quiet"

func _calculate_crowd_density() -> String:
	var npc_count = nearby_objects.filter(func(obj): return obj.type == "npc").size()
	if npc_count > 4:
		return "crowded"
	elif npc_count > 2:
		return "busy"
	elif npc_count > 0:
		return "populated"
	else:
		return "empty"

# ============================================================================
# MCP SERVER INTERFACE - TOOLS
# ============================================================================

# Tool: Get all nearby objects
func mcp_tool_get_nearby_objects(filter_type: String = "", max_distance: float = -1.0) -> Dictionary:
	var filtered_objects = nearby_objects.duplicate()
	
	# Apply type filter
	if filter_type != "":
		filtered_objects = filtered_objects.filter(func(obj): return obj.type == filter_type)
	
	# Apply distance filter
	if max_distance > 0:
		filtered_objects = filtered_objects.filter(func(obj): return obj.distance <= max_distance)
	
	# Sort by distance (closest first)
	filtered_objects.sort_custom(func(a, b): return a.distance < b.distance)
	
	# Generate comprehensive summary
	var by_type = {}
	var moving_count = 0
	var closest_distance = 999999.0
	var furthest_distance = 0.0
	
	for obj in filtered_objects:
		# Count by type
		if not by_type.has(obj.type):
			by_type[obj.type] = 0
		by_type[obj.type] += 1
		
		# Count moving objects
		if obj.is_moving:
			moving_count += 1
			
		# Track distance range
		if obj.distance < closest_distance:
			closest_distance = obj.distance
		if obj.distance > furthest_distance:
			furthest_distance = obj.distance
	
	return {
		"objects": filtered_objects,
		"total_count": filtered_objects.size(),
		"scan_radius": vision_radius,
		"center_position": owner_npc.global_position if owner_npc else Vector2.ZERO,
		"summary": {
			"objects_by_type": by_type,
			"moving_objects": moving_count,
			"stationary_objects": filtered_objects.size() - moving_count,
			"closest_distance": closest_distance if filtered_objects.size() > 0 else 0.0,
			"furthest_distance": furthest_distance if filtered_objects.size() > 0 else 0.0,
			"distance_range": "%.1f to %.1f units" % [closest_distance, furthest_distance] if filtered_objects.size() > 0 else "No objects detected"
		}
	}

# Tool: Get environmental conditions (comprehensive data by default)
func mcp_tool_get_environment() -> Dictionary:
	return {
		"temporal": temporal_data,
		"environmental": environmental_data,
		"perception_config": {
			"vision_radius": vision_radius,
			"update_frequency": update_frequency,
			"detection_layers": detection_layers,
			"owner": owner_npc.name if owner_npc else "unknown"
		},
		"detailed_summary": {
			"current_time": temporal_data.get("game_time", "unknown"),
			"time_period": temporal_data.get("time_of_day", "unknown"),
			"day_night_cycle": temporal_data.get("day_night_state", "unknown"),
			"lighting_conditions": environmental_data.get("lighting", "unknown"),
			"temperature": environmental_data.get("temperature", "unknown"),
			"atmospheric_feel": environmental_data.get("time_atmosphere", "unknown"),
			"weather_status": environmental_data.get("weather", "unknown"),
			"noise_level": environmental_data.get("noise_level", "unknown"),
			"crowd_density": environmental_data.get("crowd_density", "unknown"),
			"total_nearby_objects": nearby_objects.size(),
			"active_light_sources": _count_nearby_light_sources()
		}
	}

# Tool: Find specific object by ID or type
func mcp_tool_find_object(object_id: String = "", object_type: String = "") -> Dictionary:
	var matches = []
	
	for obj in nearby_objects:
		var id_match = object_id == "" or obj.id == object_id
		var type_match = object_type == "" or obj.type == object_type
		
		if id_match and type_match:
			matches.append(obj)
	
	return {
		"matches": matches,
		"found": matches.size() > 0,
		"query": {"id": object_id, "type": object_type}
	}

# Tool: Get objects in specific direction
func mcp_tool_get_objects_in_direction(direction: Vector2, angle_tolerance: float = 45.0) -> Dictionary:
	if not owner_npc:
		return {"objects": [], "error": "No owner NPC reference"}
	
	var target_direction = direction.normalized()
	var tolerance_radians = deg_to_rad(angle_tolerance)
	var matching_objects = []
	
	for obj in nearby_objects:
		var obj_direction = obj.direction
		var angle_diff = abs(target_direction.angle_to(obj_direction))
		
		if angle_diff <= tolerance_radians:
			obj["angle_difference"] = rad_to_deg(angle_diff)
			matching_objects.append(obj)
	
	# Sort by distance
	matching_objects.sort_custom(func(a, b): return a.distance < b.distance)
	
	return {
		"objects": matching_objects,
		"search_direction": direction,
		"tolerance_degrees": angle_tolerance
	}

# Tool: Get spatial analysis
func mcp_tool_get_spatial_analysis() -> Dictionary:
	var analysis = {
		"total_objects": nearby_objects.size(),
		"by_type": {},
		"by_distance": {"close": 0, "medium": 0, "far": 0},
		"by_movement": {"stationary": 0, "moving": 0},
		"clusters": _analyze_spatial_clusters()
	}
	
	# Count by type
	for obj in nearby_objects:
		var type = obj.type
		analysis.by_type[type] = analysis.by_type.get(type, 0) + 1
		
		# Count by distance
		if obj.distance < vision_radius * 0.3:
			analysis.by_distance.close += 1
		elif obj.distance < vision_radius * 0.7:
			analysis.by_distance.medium += 1
		else:
			analysis.by_distance.far += 1
		
		# Count by movement
		if obj.is_moving:
			analysis.by_movement.moving += 1
		else:
			analysis.by_movement.stationary += 1
	
	return analysis

func mcp_tool_scan_area(center: Vector2, radius: float) -> Dictionary:
	"""Perform targeted scan of specific area"""
	if not owner_npc:
		return {"error": "No NPC reference for area scan"}
	
	var scan_results = []
	var world = world_reference if world_reference else owner_npc.get_tree().current_scene
	
	# Perform physics query in the specified area
	var space_state = world.get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = radius
	query.shape = circle_shape
	query.transform = Transform2D(0, center)
	query.collision_mask = detection_layers
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var collider = result.collider
		if collider == owner_npc:
			continue # Skip self
		
		var distance = center.distance_to(collider.global_position)
		var scan_object = {
			"id": str(collider.get_instance_id()),
			"name": collider.name,
			"type": _determine_object_type(collider),
			"position": collider.global_position,
			"distance_from_scan_center": distance,
			"distance_from_npc": owner_npc.global_position.distance_to(collider.global_position),
			"is_moving": _is_object_moving(collider),
			"metadata": _get_object_metadata(collider)
		}
		scan_results.append(scan_object)
	
	return {
		"scan_center": center,
		"scan_radius": radius,
		"objects_found": scan_results,
		"total_count": scan_results.size(),
		"scan_timestamp": Time.get_unix_time_from_system()
	}

func _analyze_spatial_clusters() -> Array:
	var clusters = []
	var cluster_distance = 80.0 # Objects within 80 units are considered clustered
	
	# Simple clustering algorithm
	var processed = {}
	for i in range(nearby_objects.size()):
		if processed.has(i):
			continue
		
		var cluster = [nearby_objects[i]]
		processed[i] = true
		
		# Find nearby objects for this cluster
		for j in range(i + 1, nearby_objects.size()):
			if processed.has(j):
				continue
			
			var distance = nearby_objects[i].position.distance_to(nearby_objects[j].position)
			if distance <= cluster_distance:
				cluster.append(nearby_objects[j])
				processed[j] = true
		
		if cluster.size() > 1:
			clusters.append({
				"objects": cluster,
				"center": _calculate_cluster_center(cluster),
				"size": cluster.size()
			})
	
	return clusters

func _calculate_cluster_center(cluster: Array) -> Vector2:
	var center = Vector2.ZERO
	for obj in cluster:
		center += obj.position
	return center / cluster.size()

# ============================================================================
# MCP SERVER INTERFACE - RESOURCES
# ============================================================================

# Resource: Current perception snapshot
func mcp_resource_perception_snapshot() -> Dictionary:
	return {
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"owner": owner_npc.name if owner_npc else "Unknown",
		"perception_data": {
			"nearby_objects": nearby_objects,
			"environmental": environmental_data,
			"temporal": temporal_data,
			"spatial_grid": spatial_grid
		},
		"metadata": {
			"vision_radius": vision_radius,
			"object_count": nearby_objects.size(),
			"last_update": last_update_time
		}
	}

func mcp_resource_environment() -> Dictionary:
	"""Resource: Current environmental conditions"""
	return {
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"environmental": environmental_data,
		"temporal": temporal_data,
		"lighting_analysis": {
			"current_state": current_day_night_state,
			"time_period": _get_time_period(game_time_hour),
			"light_sources_nearby": _count_nearby_light_sources()
		}
	}

func mcp_resource_temporal_data() -> Dictionary:
	"""Resource: Time and day/night cycle information"""
	return {
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"game_time": temporal_data,
		"day_night_state": current_day_night_state,
		"hour": game_time_hour,
		"minute": game_time_minute
	}

func mcp_resource_nearby_objects() -> Dictionary:
	"""Resource: List of currently perceived objects"""
	return {
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"objects": nearby_objects,
		"count": nearby_objects.size(),
		"scan_radius": vision_radius,
		"center_position": owner_npc.global_position if owner_npc else Vector2.ZERO
	}

func mcp_resource_spatial_grid() -> Dictionary:
	"""Resource: Spatial organization of perceived objects"""
	return {
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"spatial_grid": spatial_grid,
		"grid_size": 50.0,
		"total_cells": spatial_grid.size(),
		"objects_by_cell": _summarize_spatial_grid()
	}

# Resource: Perception capabilities
func mcp_resource_capabilities() -> Dictionary:
	return {
		"tools": [
			{
				"name": "get_nearby_objects",
				"description": "Get all objects within perception radius, with optional filtering",
				"parameters": {
					"filter_type": "Filter by object type (npc, player, item, etc.)",
					"max_distance": "Maximum distance from NPC (default: full vision radius)"
				}
			},
			{
				"name": "get_environment",
				"description": "Get current environmental and temporal conditions"
			},
			{
				"name": "find_object",
				"description": "Find specific objects by ID or type",
				"parameters": {
					"object_id": "Specific object identifier",
					"object_type": "Object type to search for"
				}
			},
			{
				"name": "get_objects_in_direction",
				"description": "Get objects in a specific direction from the NPC",
				"parameters": {
					"direction": "Direction vector to search",
					"angle_tolerance": "Angle tolerance in degrees (default: 45)"
				}
			},
			{
				"name": "get_spatial_analysis",
				"description": "Get comprehensive spatial analysis of the environment"
			}
		],
		"resources": [
			{
				"name": "perception_snapshot",
				"description": "Complete current perception state"
			},
			{
				"name": "capabilities",
				"description": "Available perception tools and resources"
			}
		]
	}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func is_active() -> bool:
	return active

func get_vision_radius() -> float:
	return vision_radius

func set_vision_radius(radius: float):
	vision_radius = max(50.0, radius) # Minimum 50 units
	print("[PerceptionMCP] Vision radius updated to: %.1f" % vision_radius)

func get_object_count() -> int:
	return nearby_objects.size()

# ============================================================================
# HELPER METHODS
# ============================================================================

func _determine_object_type(collider: Node) -> String:
	"""Determine the type of an object based on its class and properties"""
	if collider is CharacterBody2D:
		if collider.has_method("is_player"):
			return "player"
		else:
			return "npc"
	elif collider is StaticBody2D:
		if collider.name.to_lower().contains("tree"):
			return "vegetation"
		elif collider.name.to_lower().contains("lamp") or collider.name.to_lower().contains("torch"):
			return "light_source"
		elif collider.name.to_lower().contains("exit") or collider.name.to_lower().contains("portal"):
			return "portal"
		else:
			return "structure"
	elif collider is RigidBody2D:
		if collider.name.to_lower().contains("horse"):
			return "animal"
		else:
			return "object"
	else:
		return "unknown"

func _is_object_moving(collider: Node) -> bool:
	"""Check if an object is currently moving"""
	if collider is CharacterBody2D:
		var velocity = collider.velocity
		return velocity.length() > 0.1 # Threshold for movement
	elif collider is RigidBody2D:
		var velocity = collider.linear_velocity
		return velocity.length() > 0.1
	else:
		return false

func _get_object_metadata(collider: Node) -> Dictionary:
	"""Get additional metadata about an object"""
	var metadata = {}
	
	if collider is CharacterBody2D:
		metadata["health"] = collider.get("health") if collider.has("health") else 100
		metadata["max_health"] = collider.get("max_health") if collider.has("max_health") else 100
		if collider.has_method("get_current_state"):
			metadata["state"] = collider.get_current_state()
	
	elif collider is StaticBody2D:
		if collider.name.to_lower().contains("lamp") or collider.name.to_lower().contains("torch"):
			metadata["is_lit"] = collider.get("is_lit") if collider.has("is_lit") else false
			metadata["light_intensity"] = collider.get("light_intensity") if collider.has("light_intensity") else 1.0
	
	elif collider is RigidBody2D:
		metadata["mass"] = collider.mass
	
	return metadata

func has_line_of_sight(target_position: Vector2) -> bool:
	if not owner_npc:
		return false
	
	var space_state = owner_npc.get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		owner_npc.global_position,
		target_position
	)
	query.collision_mask = 1 # Check only solid obstacles
	
	var result = space_state.intersect_ray(query)
	return result.is_empty() # No obstacles = clear line of sight

# ============================================================================
# DAY-NIGHT CYCLE INTEGRATION
# ============================================================================

# Day-night cycle integration methods
func on_time_change(state: String):
	current_day_night_state = state
	# Time changes are now reflected in environmental data responses

func _on_time_tick(_day: int, hour: int, minute: int):
	game_time_hour = hour
	game_time_minute = minute

func _count_nearby_light_sources() -> int:
	# Count lamps, torches, and other light sources
	var light_count = 0
	for obj in nearby_objects:
		if obj.type in ["lamp", "torch", "light_source"]:
			light_count += 1
	return light_count

func _get_temperature_by_time() -> String:
	# Temperature varies by time of day
	if current_day_night_state == "night":
		return "cool"
	elif game_time_hour >= 11 and game_time_hour <= 15:
		return "warm"
	else:
		return "mild"

func _get_atmospheric_description() -> String:
	var time_period = _get_time_period(game_time_hour)
	if current_day_night_state == "night":
		return "quiet and dark"
	elif time_period == "morning":
		return "fresh and awakening"
	elif time_period == "afternoon":
		return "active and bright"
	else:
		return "settling and peaceful"

func _get_object_description(obj_type: String, obj_name: String) -> String:
	match obj_type:
		"light_source":
			if obj_name.to_lower().contains("lamp"):
				return "A decorative lamp that lights up at night"
			elif obj_name.to_lower().contains("torch"):
				return "A flaming torch providing warm light"
			else:
				return "A light source"
		"vegetation":
			return "Natural vegetation in the environment"
		"structure":
			return "A building or constructed structure"
		"furniture":
			return "Environmental furniture or decoration"
		"animal":
			if obj_name.to_lower().contains("horse"):
				return "A horse wandering the area"
			else:
				return "An animal in the environment"
		"portal":
			return "A way to travel to another area"
		"npc":
			return "A non-player character"
		"player":
			return "Another player character"
		_:
			return "An object in the environment"

func _summarize_spatial_grid() -> Dictionary:
	"""Summarize spatial grid for resource access"""
	var summary = {}
	for grid_key in spatial_grid.keys():
		var cell_objects = spatial_grid[grid_key]
		summary[grid_key] = {
			"object_count": cell_objects.size(),
			"object_types": []
		}
		var type_counts = {}
		for obj in cell_objects:
			var obj_type = obj.get("type", "unknown")
			type_counts[obj_type] = type_counts.get(obj_type, 0) + 1
		summary[grid_key]["object_types"] = type_counts
	return summary
