# MCPServerBase.gd - Base interface for Model Context Protocol servers
# 
# This is the foundation class that all AI subsystems extend to become MCP-compatible.
# MCP (Model Context Protocol) allows LLM systems to discover and interact with 
# AI capabilities through standardized tools and resources.
#
# Key Concepts:
# - Tools: Actions the LLM can execute (e.g., "move_to_position", "get_nearby_objects")
# - Resources: Data the LLM can read (e.g., "current_state", "perception_data")
# - Server: An AI subsystem that exposes tools/resources via this interface
#
# Usage:
# 1. Extend this class in your AI subsystem (e.g., PerceptionSystemMCP)
# 2. Override _register_tools() and _register_resources() to define capabilities
# 3. Implement _execute_tool_internal() and _get_resource_internal() for functionality
# 4. The NPC can then discover and use your system via get_available_mcp_servers()
#
# Architecture:
# NPC -> DecisionManager -> LLM -> MCP Servers (Perception, Execution, etc.)

class_name MCPServerBase
extends Node

signal tool_executed(tool_name: String, args: Dictionary, result: Dictionary)
signal resource_accessed(resource_name: String, result: Dictionary)
signal server_error(error: String, context: Dictionary)

var server_name: String
var server_version: String = "1.0.0"
var entity_ref: Node
var active: bool = false

# Server metadata
var _tools: Dictionary = {}
var _resources: Dictionary = {}

func _init(name: String = ""):
	server_name = name

# Core MCP Server Interface
func initialize(entity: Node) -> bool:
	"""Initialize the MCP server for the given entity.
	
	This method should be called by wrapper classes or directly by NPCs
	to set up the MCP server. It registers tools/resources and activates
	the server for LLM discovery.
	
	Args:
		entity: The Node (typically CharacterBody2D) that owns this system
	
	Returns:
		bool: True if initialization succeeded, False otherwise
	"""
	entity_ref = entity
	_register_tools()
	_register_resources()
	active = true
	return true

func get_server_info() -> Dictionary:
	"""Get server metadata for capability negotiation"""
	return {
		"name": server_name,
		"version": server_version,
		"active": active,
		"entity_id": entity_ref.get_instance_id() if entity_ref else 0
	}

# Tool Management
func _register_tools():
	"""Override in subclasses to register available tools"""
	pass

func _register_resources():
	"""Override in subclasses to register available resources"""
	pass

func register_tool(name: String, description: String, parameters: Dictionary = {}, required: Array[String] = []):
	"""Register a tool that the AI can call"""
	_tools[name] = {
		"name": name,
		"description": description,
		"parameters": parameters,
		"required": required
	}

func register_resource(name: String, description: String, schema: Dictionary = {}):
	"""Register a resource that the AI can read"""
	_resources[name] = {
		"name": name,
		"description": description,
		"schema": schema
	}

func get_available_tools() -> Array[Dictionary]:
	"""Get list of all available tools for AI discovery"""
	var tools: Array[Dictionary] = []
	for tool_name in _tools.keys():
		tools.append(_tools[tool_name])
	return tools

func get_available_resources() -> Array[Dictionary]:
	"""Get list of all available resources for AI discovery"""
	var resources: Array[Dictionary] = []
	for resource_name in _resources.keys():
		resources.append(_resources[resource_name])
	return resources

# Tool Execution
func execute_tool(tool_name: String, args: Dictionary = {}) -> Dictionary:
	"""Execute a tool by name with given arguments.
	
	This is the main entry point for LLMs to execute actions on this system.
	It validates the tool exists, checks required parameters, and delegates
	to the concrete implementation via _execute_tool_internal().
	
	Args:
		tool_name: Name of the tool to execute (must be registered)
		args: Dictionary of arguments for the tool
	
	Returns:
		Dictionary: Result of tool execution or error information
	"""
	if not active:
		var error = {"error": "Server not active", "server": server_name}
		server_error.emit("server_inactive", {"tool": tool_name, "args": args})
		return error
	
	if not _tools.has(tool_name):
		var error = {"error": "Tool not found", "tool": tool_name, "server": server_name}
		server_error.emit("tool_not_found", {"tool": tool_name, "args": args})
		return error
	
	# Validate required parameters
	var tool_def = _tools[tool_name]
	if tool_def.has("required"):
		for param in tool_def.required:
			if not args.has(param):
				var error = {"error": "Missing required parameter", "parameter": param, "tool": tool_name}
				server_error.emit("missing_parameter", {"tool": tool_name, "args": args, "missing": param})
				return error
	
	# Execute the tool
	var result = _execute_tool_internal(tool_name, args)
	tool_executed.emit(tool_name, args, result)
	return result

func _execute_tool_internal(tool_name: String, args: Dictionary) -> Dictionary:
	"""Override in subclasses to implement actual tool execution"""
	return {"error": "Tool execution not implemented", "tool": tool_name}

# Resource Access
func get_resource(resource_name: String) -> Dictionary:
	"""Get a resource by name.
	
	This allows LLMs to access data from this system for context building.
	Unlike tools, resources are read-only and provide current state information.
	
	Args:
		resource_name: Name of the resource to retrieve (must be registered)
	
	Returns:
		Dictionary: Resource data or error information
	"""
	if not active:
		var error = {"error": "Server not active", "server": server_name}
		server_error.emit("server_inactive", {"resource": resource_name})
		return error
	
	if not _resources.has(resource_name):
		var error = {"error": "Resource not found", "resource": resource_name, "server": server_name}
		server_error.emit("resource_not_found", {"resource": resource_name})
		return error
	
	var result = _get_resource_internal(resource_name)
	resource_accessed.emit(resource_name, result)
	return result

func _get_resource_internal(resource_name: String) -> Dictionary:
	"""Override in subclasses to implement actual resource access"""
	return {"error": "Resource access not implemented", "resource": resource_name}

# Context for AI Decision Making
func get_context_summary() -> Dictionary:
	"""Get a summary of current state for AI context building"""
	return {
		"server": server_name,
		"active": active,
		"tools_count": _tools.size(),
		"resources_count": _resources.size(),
		"last_updated": Time.get_unix_time_from_system()
	}

# Server Management
func is_active() -> bool:
	return active

func set_active(is_active: bool):
	active = is_active

func shutdown():
	"""Cleanup server resources"""
	active = false
	_tools.clear()
	_resources.clear()
	entity_ref = null
