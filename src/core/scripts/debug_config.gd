extends Node

# Debug Configuration Manager
# Handles debug settings from environment variables and project settings

# Debug flags
var debug_enabled: bool = false
var debug_perception: bool = false
var debug_perception_visual: bool = false
var debug_ui: bool = false
var debug_ai: bool = false
var debug_spells: bool = false
var debug_environment: bool = false
var debug_verbose: bool = false

# Environment variable names
const ENV_DEBUG = "EMERGENT_DEBUG"
const ENV_DEBUG_PERCEPTION = "EMERGENT_DEBUG_PERCEPTION"
const ENV_DEBUG_PERCEPTION_VISUAL = "EMERGENT_DEBUG_PERCEPTION_VISUAL"
const ENV_DEBUG_UI = "EMERGENT_DEBUG_UI" 
const ENV_DEBUG_AI = "EMERGENT_DEBUG_AI"
const ENV_DEBUG_SPELLS = "EMERGENT_DEBUG_SPELLS"
const ENV_DEBUG_ENVIRONMENT = "EMERGENT_DEBUG_ENVIRONMENT"
const ENV_DEBUG_VERBOSE = "EMERGENT_DEBUG_VERBOSE"

# Project setting keys
const SETTING_DEBUG = "debug/general/enabled"
const SETTING_DEBUG_PERCEPTION = "debug/systems/perception"
const SETTING_DEBUG_PERCEPTION_VISUAL = "debug/systems/perception_visual"
const SETTING_DEBUG_UI = "debug/systems/ui"
const SETTING_DEBUG_AI = "debug/systems/ai"
const SETTING_DEBUG_SPELLS = "debug/systems/spells"
const SETTING_DEBUG_ENVIRONMENT = "debug/systems/environment"
const SETTING_DEBUG_VERBOSE = "debug/general/verbose"

func _ready():
	# Load debug configuration
	_load_debug_settings()
	
	# Print debug status if enabled
	if debug_enabled:
		print("Debug mode enabled")
		print("  Perception: ", debug_perception)
		print("  Perception Visual: ", debug_perception_visual)
		print("  UI: ", debug_ui)
		print("  AI: ", debug_ai)
		print("  Spells: ", debug_spells)
		print("  Environment: ", debug_environment)
		print("  Verbose: ", debug_verbose)

func _load_debug_settings():
	# Load from environment variables first (highest priority)
	debug_enabled = _get_bool_from_env(ENV_DEBUG) or _get_project_setting_bool(SETTING_DEBUG, false)
	debug_perception = _get_bool_from_env(ENV_DEBUG_PERCEPTION) or _get_project_setting_bool(SETTING_DEBUG_PERCEPTION, debug_enabled)
	debug_perception_visual = _get_bool_from_env(ENV_DEBUG_PERCEPTION_VISUAL) or _get_project_setting_bool(SETTING_DEBUG_PERCEPTION_VISUAL, debug_perception)
	debug_ui = _get_bool_from_env(ENV_DEBUG_UI) or _get_project_setting_bool(SETTING_DEBUG_UI, debug_enabled)
	debug_ai = _get_bool_from_env(ENV_DEBUG_AI) or _get_project_setting_bool(SETTING_DEBUG_AI, debug_enabled)
	debug_spells = _get_bool_from_env(ENV_DEBUG_SPELLS) or _get_project_setting_bool(SETTING_DEBUG_SPELLS, debug_enabled)
	debug_environment = _get_bool_from_env(ENV_DEBUG_ENVIRONMENT) or _get_project_setting_bool(SETTING_DEBUG_ENVIRONMENT, debug_enabled)
	debug_verbose = _get_bool_from_env(ENV_DEBUG_VERBOSE) or _get_project_setting_bool(SETTING_DEBUG_VERBOSE, false)

func _get_bool_from_env(env_var: String) -> bool:
	var value = OS.get_environment(env_var)
	if value.is_empty():
		return false
	return value.to_lower() in ["true", "1", "yes", "on", "enabled"]

func _get_project_setting_bool(setting_key: String, default_value: bool = false) -> bool:
	return ProjectSettings.get_setting(setting_key, default_value)

# Convenience methods for checking debug states
func is_debug_enabled() -> bool:
	return debug_enabled

func is_perception_debug() -> bool:
	return debug_perception

func is_perception_visual_debug() -> bool:
	return debug_perception_visual

func is_ui_debug() -> bool:
	return debug_ui

func is_ai_debug() -> bool:
	return debug_ai

func is_spells_debug() -> bool:
	return debug_spells

func is_environment_debug() -> bool:
	return debug_environment

func is_verbose_debug() -> bool:
	return debug_verbose

# Debug print functions
func debug_print(message: String, category: String = "general"):
	if not debug_enabled:
		return
		
	var should_print = false
	match category.to_lower():
		"perception":
			should_print = debug_perception
		"ui":
			should_print = debug_ui
		"ai":
			should_print = debug_ai
		"spells":
			should_print = debug_spells
		"environment":
			should_print = debug_environment
		_:
			should_print = debug_enabled
	
	if should_print:
		print("[DEBUG:%s] %s" % [category.to_upper(), message])

func debug_print_verbose(message: String, category: String = "general"):
	if debug_verbose:
		debug_print(message, category)

# Toggle debug modes at runtime (for development)
func toggle_debug():
	debug_enabled = !debug_enabled
	print("Debug mode: ", "enabled" if debug_enabled else "disabled")

func toggle_category_debug(category: String):
	match category.to_lower():
		"perception":
			debug_perception = !debug_perception
			print("Perception debug: ", "enabled" if debug_perception else "disabled")
		"perception_visual":
			debug_perception_visual = !debug_perception_visual
			print("Perception visual debug: ", "enabled" if debug_perception_visual else "disabled")
		"ui":
			debug_ui = !debug_ui
			print("UI debug: ", "enabled" if debug_ui else "disabled")
		"ai":
			debug_ai = !debug_ai
			print("AI debug: ", "enabled" if debug_ai else "disabled")
		"spells":
			debug_spells = !debug_spells
			print("Spells debug: ", "enabled" if debug_spells else "disabled")
		"environment":
			debug_environment = !debug_environment
			print("Environment debug: ", "enabled" if debug_environment else "disabled")
		"verbose":
			debug_verbose = !debug_verbose
			print("Verbose debug: ", "enabled" if debug_verbose else "disabled")