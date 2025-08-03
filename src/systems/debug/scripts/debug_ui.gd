extends CanvasLayer

var debug_label: Label = null
var player_ref: CharacterBody2D = null
var update_timer = 0.0
var update_frequency = 0.2  # Update 5 times per second

func _ready():
	# Get the debug label safely
	debug_label = $Control/VBoxContainer/ScrollContainer/DebugLabel
	if not debug_label:
		print("Debug UI: Failed to find debug label")
		return
		
	debug_label.text = "Initializing..."
	
	# Find the player in the scene
	await get_tree().process_frame  # Wait for scene to be ready
	_find_player()

func _find_player():
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		player_ref = players[0]
		print("Debug UI connected to player: %s" % player_ref.name)
	else:
		print("Debug UI: No players found, retrying...")
		# Retry after a short delay
		await get_tree().create_timer(0.5).timeout
		_find_player()

func _process(delta):
	update_timer += delta
	if update_timer >= update_frequency:
		_update_debug_info()
		update_timer = 0.0

func _update_debug_info():
	if not debug_label:
		return
		
	if not player_ref:
		debug_label.text = "Searching for player..."
		return
		
	if not player_ref.perception_system:
		debug_label.text = "Player found but no perception system available"
		return
	
	var debug_text = ""
	debug_text += "=== PLAYER PERCEPTION DEBUG ===\n\n"
	
	# Use the player's configured vision radius (no override)
	
	debug_text += "Vision Radius: %.1f units\n" % player_ref.perception_system.get_vision_radius()
	debug_text += "Player Position: %.1f, %.1f\n\n" % [player_ref.global_position.x, player_ref.global_position.y]
	
	# Get all nearby objects from player's perspective
	var all_nearby = player_ref.perception_system.mcp_tool_get_nearby_objects("", -1.0)
	debug_text += "NEARBY OBJECTS (%d total):\n" % all_nearby.get("total_count", 0)
	debug_text += "------------------------\n"
	
	var objects = all_nearby.get("objects", [])
	if objects.size() == 0:
		debug_text += "No objects detected\n\n"
	else:
		# Sort by distance
		objects.sort_custom(func(a, b): return a.distance < b.distance)
		
		for obj in objects:
			var obj_name = obj.properties.get("name", obj.id)
			var type = obj.type
			var distance = obj.distance
			var rel_pos = obj.relative_position
			var moving = "🏃" if obj.is_moving else "🚶"
			var description = obj.properties.get("description", "No description")
			
			debug_text += "%s %s (%s)\n" % [moving, obj_name, type]
			debug_text += "  %s\n" % description
			debug_text += "  Distance: %.1f units\n" % distance
			debug_text += "  Relative: (%.1f, %.1f)\n" % [rel_pos.x, rel_pos.y]
			debug_text += "  World Pos: (%.1f, %.1f)\n" % [obj.position.x, obj.position.y]
			if obj.is_moving:
				debug_text += "  Velocity: (%.1f, %.1f)\n" % [obj.velocity.x, obj.velocity.y]
			
			# Show additional properties if available
			var properties = obj.properties
			if properties.has("role"):
				debug_text += "  Role: %s\n" % properties.role
			if properties.has("size"):
				var size = properties.size
				debug_text += "  Size: %.1fx%.1f\n" % [size.width, size.height]
			
			debug_text += "\n"
	
	# Get environmental conditions from player
	var env = player_ref.perception_system.mcp_tool_get_environment()
	var temporal = env.get("temporal", {})
	var environmental = env.get("environmental", {})
	
	debug_text += "ENVIRONMENT:\n"
	debug_text += "------------\n"
	debug_text += "Game Time: %s\n" % temporal.get("game_time", "unknown")
	debug_text += "Time of Day: %s\n" % temporal.get("time_of_day", "unknown")
	debug_text += "Day/Night: %s\n" % temporal.get("day_night_state", "unknown")
	debug_text += "Lighting: %s\n" % environmental.get("lighting", "unknown")
	debug_text += "Temperature: %s\n" % environmental.get("temperature", "unknown")
	debug_text += "Atmosphere: %s\n" % environmental.get("time_atmosphere", "unknown")
	debug_text += "Weather: %s\n" % environmental.get("weather", "unknown")
	debug_text += "Noise Level: %s\n" % environmental.get("noise_level", "unknown")
	debug_text += "Crowd Density: %s\n\n" % environmental.get("crowd_density", "unknown")
	
	# Get spatial analysis from player
	var analysis = player_ref.perception_system.mcp_tool_get_spatial_analysis()
	debug_text += "SPATIAL ANALYSIS:\n"
	debug_text += "-----------------\n"
	
	var by_type = analysis.get("by_type", {})
	if by_type.size() > 0:
		debug_text += "Objects by Type:\n"
		for type_name in by_type.keys():
			debug_text += "  %s: %d\n" % [type_name, by_type[type_name]]
	
	var by_distance = analysis.get("by_distance", {})
	debug_text += "\nDistance Distribution:\n"
	debug_text += "  Close: %d\n" % by_distance.get("close", 0)
	debug_text += "  Medium: %d\n" % by_distance.get("medium", 0)
	debug_text += "  Far: %d\n" % by_distance.get("far", 0)
	
	var by_movement = analysis.get("by_movement", {})
	debug_text += "\nMovement Status:\n"
	debug_text += "  Moving: %d\n" % by_movement.get("moving", 0)
	debug_text += "  Stationary: %d\n" % by_movement.get("stationary", 0)
	
	var clusters = analysis.get("clusters", [])
	debug_text += "\nClusters: %d found\n" % clusters.size()
	for i in range(clusters.size()):
		var cluster = clusters[i]
		debug_text += "  Cluster %d: %d objects\n" % [i + 1, cluster.size]
	
	debug_text += "\n--- End Debug Info ---"
	
	debug_label.text = debug_text