# AI Utils - Shared utility functions for AI subsystems
# 
# This file contains common functions used across multiple AI systems
# to reduce code duplication and maintain consistency.

class_name AIUtils

# ============================================================================
# CONTEXT AND HASHING UTILITIES
# ============================================================================

static func hash_context(context: Dictionary) -> String:
	"""Create a consistent hash of a context dictionary for caching purposes.
	
	Args:
		context: Dictionary to hash
		
	Returns:
		String: SHA-256 hash of the context
	"""
	var context_string = JSON.stringify(context)
	return context_string.sha256_text()

static func normalize_context_for_hash(context: Dictionary) -> Dictionary:
	"""Normalize a context dictionary before hashing to improve cache hits.
	
	Removes timestamp fields and sorts arrays to ensure consistent hashing
	for contexts that are functionally equivalent.
	
	Args:
		context: Dictionary to normalize
		
	Returns:
		Dictionary: Normalized context suitable for hashing
	"""
	var normalized = context.duplicate(true)
	
	# Remove timestamp fields that change frequently
	normalized.erase("timestamp")
	normalized.erase("time")
	normalized.erase("current_time")
	
	# Sort arrays for consistent ordering
	if normalized.has("available_actions") and normalized.available_actions is Array:
		normalized.available_actions.sort()
	
	if normalized.has("nearby_objects") and normalized.nearby_objects is Array:
		normalized.nearby_objects.sort()
	
	return normalized

# ============================================================================
# TIME AND DATE UTILITIES
# ============================================================================

static func get_game_time_string(hour: int, minute: int) -> String:
	"""Format game time as HH:MM string.
	
	Args:
		hour: Hour (0-23)
		minute: Minute (0-59)
		
	Returns:
		String: Formatted time string
	"""
	return "%02d:%02d" % [hour, minute]

static func get_time_period_name(hour: int) -> String:
	"""Get descriptive name for time period.
	
	Args:
		hour: Hour (0-23)
		
	Returns:
		String: Time period name (morning, afternoon, evening, night)
	"""
	if hour >= 5 and hour < 12:
		return "morning"
	elif hour >= 12 and hour < 17:
		return "afternoon"
	elif hour >= 17 and hour < 21:
		return "evening"
	else:
		return "night"

static func is_daytime(hour: int) -> bool:
	"""Check if given hour is considered daytime.
	
	Args:
		hour: Hour (0-23)
		
	Returns:
		bool: True if daytime (6-17), False otherwise
	"""
	return hour >= 6 and hour < 18

# ============================================================================
# SPATIAL AND MOVEMENT UTILITIES
# ============================================================================

static func estimate_travel_time(from_pos: Vector2, to_pos: Vector2, speed: float) -> float:
	"""Estimate time to travel between two positions.
	
	Args:
		from_pos: Starting position
		to_pos: Destination position
		speed: Movement speed in units per second
		
	Returns:
		float: Estimated travel time in seconds
	"""
	if speed <= 0:
		return 0.0
	var distance = from_pos.distance_to(to_pos)
	return distance / speed

static func get_direction_name(direction: Vector2) -> String:
	"""Get descriptive name for a direction vector.
	
	Args:
		direction: Normalized direction vector
		
	Returns:
		String: Direction name (north, south, east, west, etc.)
	"""
	if direction.length() < 0.1:
		return "none"
	
	var angle = direction.angle()
	var angle_degrees = rad_to_deg(angle)
	
	# Normalize to 0-360 range
	if angle_degrees < 0:
		angle_degrees += 360
	
	if angle_degrees < 22.5 or angle_degrees >= 337.5:
		return "east"
	elif angle_degrees < 67.5:
		return "southeast"
	elif angle_degrees < 112.5:
		return "south"
	elif angle_degrees < 157.5:
		return "southwest"
	elif angle_degrees < 202.5:
		return "west"
	elif angle_degrees < 247.5:
		return "northwest"
	elif angle_degrees < 292.5:
		return "north"
	else:
		return "northeast"

# ============================================================================
# PRIORITY AND QUEUE UTILITIES
# ============================================================================

static func priority_to_string(priority: int) -> String:
	"""Convert priority integer to descriptive string.
	
	Args:
		priority: Priority level (0-4)
		
	Returns:
		String: Priority name (low, normal, high, urgent, critical)
	"""
	match priority:
		0: return "low"
		1: return "normal"
		2: return "high"
		3: return "urgent"
		4: return "critical"
		_: return "unknown"

static func clamp_priority(priority: int) -> int:
	"""Clamp priority to valid range.
	
	Args:
		priority: Raw priority value
		
	Returns:
		int: Priority clamped to 0-4 range
	"""
	return clamp(priority, 0, 4)

# ============================================================================
# DEBUG AND LOGGING UTILITIES
# ============================================================================

static func format_debug_message(system_name: String, entity_name: String, message: String) -> String:
	"""Format a consistent debug message for AI systems.
	
	Args:
		system_name: Name of the AI system (e.g., "PerceptionMCP")
		entity_name: Name of the entity (e.g., "Harry")
		message: The debug message
		
	Returns:
		String: Formatted debug message
	"""
	return "[%s:%s] %s" % [system_name, entity_name, message]

static func safe_get_entity_name(entity: Node) -> String:
	"""Safely get the name of an entity node.
	
	Args:
		entity: Node to get name from (may be null)
		
	Returns:
		String: Entity name or "Unknown" if null
	"""
	return entity.name if entity else "Unknown"

# ============================================================================
# VALIDATION UTILITIES
# ============================================================================

static func validate_position(position: Vector2) -> bool:
	"""Validate that a position is reasonable.
	
	Args:
		position: Position to validate
		
	Returns:
		bool: True if position is finite and reasonable
	"""
	return is_finite(position.x) and is_finite(position.y) and position.length() < 10000

static func validate_dictionary_structure(dict: Dictionary, required_keys: Array[String]) -> bool:
	"""Validate that a dictionary has required keys.
	
	Args:
		dict: Dictionary to validate
		required_keys: Array of required key names
		
	Returns:
		bool: True if all required keys are present
	"""
	for key in required_keys:
		if not dict.has(key):
			return false
	return true