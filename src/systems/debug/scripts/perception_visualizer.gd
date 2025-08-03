extends Node2D

var target_character: CharacterBody2D = null
var circle_color = Color.YELLOW
var circle_width = 2.0
var circle_alpha = 0.3

func _ready():
	# Check if perception visualization should be enabled
	if not DebugConfig.is_perception_visual_debug():
		visible = false
		set_process(false)
		return
	
	# Find the player to follow
	await get_tree().process_frame
	_find_target()

func _find_target():
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		target_character = players[0]  # Follow the player
		DebugConfig.debug_print("Perception visualizer following player: %s" % target_character.name, "perception")
	else:
		DebugConfig.debug_print("No players found for perception visualizer", "perception")
		# Don't retry, just stay inactive

func _process(_delta):
	if target_character:
		global_position = target_character.global_position
		queue_redraw()  # Request a redraw

func _draw():
	if not target_character or not target_character.perception_system:
		return
	
	var radius = target_character.perception_system.get_vision_radius()
	
	# Draw filled circle with transparency
	draw_circle(Vector2.ZERO, radius, Color(circle_color.r, circle_color.g, circle_color.b, circle_alpha))
	
	# Draw circle outline
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, circle_color, circle_width)
	
	# Draw radius lines (cross pattern)
	var line_color = Color(circle_color.r, circle_color.g, circle_color.b, 0.5)
	draw_line(Vector2(-radius, 0), Vector2(radius, 0), line_color, 1.0)
	draw_line(Vector2(0, -radius), Vector2(0, radius), line_color, 1.0)
	
	# Draw center dot
	draw_circle(Vector2.ZERO, 3.0, Color.RED)