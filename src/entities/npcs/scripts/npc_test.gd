# NPC Test Script - Demonstrates Decision Manager Integration
extends Node

# This script shows how to test the NPC's decision making capabilities
# You can attach this to a test scene or run it from the editor

@export var test_npc_path: NodePath
var test_npc: Node

func _ready():
	# Wait a frame for everything to initialize
	await get_tree().process_frame
	
	# Find the test NPC
	if test_npc_path:
		test_npc = get_node(test_npc_path)
	else:
		# Try to find any NPC in the scene
		var npcs = get_tree().get_nodes_in_group("npcs")
		if npcs.size() > 0:
			test_npc = npcs[0]
	
	if not test_npc:
		print("[Test] No NPC found to test")
		return
	
	print("[Test] Testing NPC: %s" % test_npc.npc_name)
	
	# Set up test
	_setup_test()

func _setup_test():
	"""Set up the decision making test"""
	if not test_npc:
		return
	
	# Set a shorter decision interval for testing
	test_npc.set_decision_interval(5.0)
	
	# Print initial state
	print("[Test] Initial NPC state:")
	print(test_npc.get_debug_info())
	
	# Start testing after a delay
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(_run_tests)
	add_child(timer)
	timer.start()

func _run_tests():
	"""Run various tests on the NPC"""
	if not test_npc:
		return
	
	print("\n[Test] Running decision manager tests...")
	
	# Test 1: Manual decision trigger
	print("\n[Test 1] Manually triggering decision...")
	test_npc.trigger_decision()
	
	# Test 2: Check decision statistics after a delay
	var stats_timer = Timer.new()
	stats_timer.wait_time = 3.0
	stats_timer.one_shot = true
	stats_timer.timeout.connect(_check_decision_stats)
	add_child(stats_timer)
	stats_timer.start()
	
	# Test 3: Check execution status
	var exec_timer = Timer.new()
	exec_timer.wait_time = 1.0
	exec_timer.one_shot = true
	exec_timer.timeout.connect(_check_execution_status)
	add_child(exec_timer)
	exec_timer.start()

func _check_decision_stats():
	"""Check decision statistics"""
	if not test_npc:
		return
	
	print("\n[Test 2] Decision statistics:")
	var stats = test_npc.get_decision_statistics()
	for key in stats:
		if key == "recent_decisions" and stats[key] is Array:
			print("  %s:" % key)
			for decision in stats[key]:
				print("    - %s (Goal: %s, Priority: %d)" % [
					decision.get("action", "Unknown"),
					decision.get("goal", "Unknown"),
					decision.get("priority", 1)
				])
		else:
			print("  %s: %s" % [key, stats[key]])

func _check_execution_status():
	"""Check execution system status"""
	if not test_npc:
		return
	
	print("\n[Test 3] Execution system status:")
	var exec_status = test_npc.get_execution_status()
	for key in exec_status:
		print("  %s: %s" % [key, exec_status[key]])

func _input(event):
	"""Handle input for manual testing"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				# Trigger decision manually
				if test_npc:
					print("\n[Manual Test] Triggering decision...")
					test_npc.trigger_decision()
			KEY_2:
				# Show debug info
				if test_npc:
					print("\n[Manual Test] Debug info:")
					print(test_npc.get_debug_info())
			KEY_3:
				# Show decision statistics
				if test_npc:
					print("\n[Manual Test] Decision statistics:")
					var stats = test_npc.get_decision_statistics()
					for key in stats:
						print("  %s: %s" % [key, stats[key]])
			KEY_4:
				# Show execution status
				if test_npc:
					print("\n[Manual Test] Execution status:")
					var exec_status = test_npc.get_execution_status()
					for key in exec_status:
						print("  %s: %s" % [key, exec_status[key]])
			KEY_5:
				# Test perception system
				if test_npc:
					print("\n[Manual Test] Testing perception system...")
					var perception_debug = test_npc.test_perception_system()
					for key in perception_debug:
						if key == "perception_methods" and perception_debug[key] is Array:
							print("  %s:" % key)
							for method in perception_debug[key]:
								print("    - %s" % method)
						else:
							print("  %s: %s" % [key, perception_debug[key]])
			KEY_6:
				# Force perception update
				if test_npc:
					print("\n[Manual Test] Forcing perception update...")
					test_npc.force_perception_update()
			KEY_7:
				# Test nearby objects specifically
				if test_npc:
					print("\n[Manual Test] Testing nearby objects...")
					var nearby_result = test_npc.test_nearby_objects()
					print("[Manual Test] Final nearby objects result: %s" % nearby_result)

func _on_test_complete():
	"""Called when all tests are completed"""
	print("\n[Test] All tests completed!")
	print("Press keys 1-7 for manual testing:")
	print("  1: Trigger decision")
	print("  2: Show debug info")
	print("  3: Show decision statistics")
	print("  4: Show execution status")
	print("  5: Test perception system")
	print("  6: Force perception update")
	print("  7: Test nearby objects")
