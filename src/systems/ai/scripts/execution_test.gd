extends Node2D

# Simple test script to demonstrate ExecutionSystem functionality
# Add this to a scene with an NPC to test the execution system

@onready var npc: CharacterBody2D = null
var test_running: bool = false
var test_step: int = 0

func _ready():
	# Find the NPC in the scene
	_find_npc()
	
	# Start the test after a short delay
	await get_tree().create_timer(2.0).timeout
	if npc:
		_start_execution_test()

func _find_npc():
	var npcs = get_tree().get_nodes_in_group("npcs")
	if npcs.size() > 0:
		npc = npcs[0]
		print("ExecutionTest: Found NPC: %s" % npc.npc_name)
		
		# Connect to ExecutionSystem signals if available
		if npc.execution_system:
			npc.execution_system.action_started.connect(_on_action_started)
			npc.execution_system.action_completed.connect(_on_action_completed)
			npc.execution_system.execution_status_changed.connect(_on_status_changed)
	else:
		print("ExecutionTest: No NPCs found in scene")

func _start_execution_test():
	if not npc or test_running:
		return
	
	test_running = true
	test_step = 1
	
	print("=== ExecutionSystem Test Started ===")
	print("NPC: %s at position: %s" % [npc.npc_name, npc.global_position])
	
	# Test 1: Basic movement
	print("Test 1: Queuing movement actions")
	var start_pos = npc.global_position
	
	# Queue several movement actions
	npc.move_to(start_pos + Vector2(100, 0))  # Move right
	npc.move_to(start_pos + Vector2(100, 100))  # Move down
	npc.move_to(start_pos + Vector2(0, 100))  # Move left
	npc.move_to(start_pos)  # Return to start
	
	# Add a wait and high priority interrupt
	npc.wait_for(3.0)
	
	# Queue a high priority action after 5 seconds
	await get_tree().create_timer(5.0).timeout
	if test_running:
		print("Test 2: High priority interrupt")
		npc.move_to(start_pos + Vector2(200, 0), ExecutionSystem.Priority.HIGH)

func _on_action_started(action_type: String, action_data: Dictionary):
	print("✓ Action started: %s" % action_type)

func _on_action_completed(action_type: String, success: bool, result: Dictionary):
	print("✓ Action completed: %s (success: %s)" % [action_type, success])
	
	# Check if we should run next test
	if test_running and action_type == "move":
		test_step += 1
		
		if test_step == 5:  # After returning to start
			print("Test 3: Interaction test")
			npc.interact_with("test_object", 2.0)
		elif test_step == 6:  # After interaction
			print("Test 4: Clear queue test")
			npc.move_to(npc.global_position + Vector2(300, 0))
			npc.move_to(npc.global_position + Vector2(300, 300))
			
			# Clear queue after 1 second
			await get_tree().create_timer(1.0).timeout
			if test_running:
				print("Clearing action queue...")
				npc.clear_all_actions()
				
				# Add final test
				await get_tree().create_timer(1.0).timeout
				print("Test 5: Interrupt test")
				npc.move_to(npc.global_position + Vector2(-500, 0))
				
				# Interrupt after 0.5 seconds
				await get_tree().create_timer(0.5).timeout
				if test_running:
					npc.interrupt_current_action("Test interrupt")
					_end_test()

func _on_status_changed(status: String, current_action: Dictionary, queue_size: int):
	print("Status: %s | Queue: %d actions | Current: %s" % [
		status, 
		queue_size, 
		current_action.get("type", "none")
	])

func _end_test():
	test_running = false
	print("=== ExecutionSystem Test Completed ===")
	
	# Print final status
	if npc:
		var status = npc.get_execution_status()
		print("Final Status: %s" % status.get("status", "unknown"))
		print("Interruptions: %d" % status.get("interruptions", []).size())
		print("Recent completions: %d" % status.get("recent_completions", []).size())

# Manual test controls (call from debugger or other scripts)
func test_basic_movement():
	if npc:
		var start_pos = npc.global_position
		npc.move_to(start_pos + Vector2(50, 50))

func test_priority_queue():
	if npc:
		var start_pos = npc.global_position
		npc.move_to(start_pos + Vector2(100, 0), ExecutionSystem.Priority.LOW)
		npc.move_to(start_pos + Vector2(0, 100), ExecutionSystem.Priority.HIGH)  # Should go first
		npc.move_to(start_pos + Vector2(-100, 0), ExecutionSystem.Priority.NORMAL)

func test_interruption():
	if npc:
		npc.move_to(npc.global_position + Vector2(200, 200))
		await get_tree().create_timer(1.0).timeout
		npc.interrupt_current_action("Manual test interrupt")