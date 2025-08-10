# NPC Decision Manager Integration

This document explains how the Decision Manager is integrated with NPCs to provide LLM-based decision making capabilities.

## Overview

The Decision Manager allows NPCs to make intelligent decisions using an LLM (Language Model) through the Ollama API. It integrates with the NPC's existing systems to provide context-aware decision making.

## Architecture

```
NPC Scene
├── NPC (CharacterBody2D)
│   ├── DecisionManager (Node)
│   ├── ExecutionSystemMCP
│   ├── PerceptionSystemMCP
│   └── InflectionSystemMCP
└── Other components...
```

## How It Works

1. **Context Gathering**: The NPC collects context from its various systems (perception, needs, goals, etc.)
2. **LLM Request**: The Decision Manager sends this context to Ollama with a structured prompt
3. **Decision Execution**: The LLM response is parsed and executed through the Execution System
4. **Caching**: Decisions are cached to avoid repeated LLM calls for similar situations

## Key Components

### DecisionManager Node
- **Location**: `src/systems/ai/scripts/decision_manager.gd`
- **Purpose**: Handles communication with Ollama and decision caching
- **Features**: 
  - HTTP requests to Ollama
  - Decision caching and cooldown management
  - Structured prompt generation

### NPC Integration
- **Automatic Setup**: Decision Manager is automatically added as a child node
- **Signal Connection**: NPC connects to Decision Manager signals
- **Context Building**: NPC provides rich context for decision making
- **Action Execution**: NPC executes decisions through its Execution System

## Configuration

### Ollama Setup
1. Install Ollama: https://ollama.ai/
2. Run Ollama server (default: http://localhost:11434)
3. Download a model: `ollama pull llama2`

### Decision Timing
- **Default Interval**: 10 seconds between decisions
- **Cooldown**: 5 seconds minimum between LLM calls
- **Configurable**: Use `set_decision_interval(seconds)` to adjust

## Usage Examples

### Basic Usage
```gdscript
# The Decision Manager is automatically initialized
# NPCs will make decisions automatically based on their context

# Manual decision trigger
npc.trigger_decision()

# Check decision statistics
var stats = npc.get_decision_statistics()
print(stats)
```

### Customizing Decision Making
```gdscript
# Set decision interval
npc.set_decision_interval(5.0)  # 5 seconds

# Get decision manager reference
var dm = npc.get_decision_manager()
dm.set_ollama_url("http://localhost:11434")
dm.set_decision_cooldown(3.0)
```

### Monitoring Decisions
```gdscript
# Get debug info
var debug = npc.get_debug_info()
print(debug)

# Get execution status
var exec_status = npc.get_execution_status()
print(exec_status)
```

## Decision Context

The NPC provides rich context for decision making:

- **Available Actions**: What the NPC can currently do
- **Current Needs**: Hunger, rest, social interaction needs
- **Nearby Objects**: Objects the NPC can interact with
- **Current Goals**: Short and long-term objectives
- **Emotional State**: Current mood and emotional context
- **Time of Day**: Morning, afternoon, evening, night

## LLM Prompt Structure

The Decision Manager sends structured prompts to the LLM:

```
You are an AI assistant helping an NPC make decisions in a game world.

NPC Context:
- Name: [NPC Name]
- Personality: [Personality]
- Current Needs: [Needs]
- Relationships: [Relationships]
- Recent Memory: [Memory]

World Context:
- Time: [Time]
- Location: [Location]
- Nearby Objects: [Objects]
- Current Goals: [Goals]

Available Actions: [Actions]

Based on this context, choose the most appropriate action...
```

## Decision Response Format

The LLM responds with structured JSON:

```json
{
  "goal": "satisfy hunger",
  "action": "move_to_kitchen_and_cook_food",
  "narrative": "My stomach is growling and I need sustenance.",
  "priority": 4,
  "duration_estimate": 300
}
```

## Testing

Use the provided test script (`npc_test.gd`) to test decision making:

1. Attach the test script to a scene
2. Set the `test_npc_path` to point to an NPC
3. Run the scene
4. Use keyboard shortcuts for manual testing:
   - **1**: Trigger decision
   - **2**: Show debug info
   - **3**: Show decision statistics
   - **4**: Show execution status

## Troubleshooting

### Common Issues

1. **Ollama Connection Failed**
   - Ensure Ollama is running
   - Check URL in Decision Manager
   - Verify firewall settings

2. **No Decisions Being Made**
   - Check if Decision Manager is initialized
   - Verify signal connections
   - Check decision timer setup

3. **Decisions Not Executing**
   - Verify Execution System is working
   - Check action parsing logic
   - Review decision response format

### Debug Information

Enable debug output by checking the console for:
- `[NPC]` messages from the NPC
- `[DecisionManager]` messages from the Decision Manager
- `[Test]` messages from the test script

## Performance Considerations

- **Caching**: Decisions are cached to reduce LLM calls
- **Cooldown**: Prevents spam requests to Ollama
- **Context Hashing**: Efficient context comparison for caching
- **Priority System**: Important decisions can bypass cooldown

## Future Enhancements

- **Multiple LLM Providers**: Support for different LLM services
- **Advanced Context**: More sophisticated world state analysis
- **Learning**: NPCs learn from decision outcomes
- **Collaborative Decisions**: NPCs can coordinate decisions
- **Emotional Intelligence**: More nuanced emotional decision making

## API Reference

### NPC Methods
- `trigger_decision()`: Manually trigger a decision
- `set_decision_interval(seconds)`: Set decision frequency
- `get_decision_manager()`: Get Decision Manager reference
- `get_decision_statistics()`: Get decision metrics

### Decision Manager Methods
- `request_decision(npc, context, priority)`: Request a decision
- `set_ollama_url(url)`: Set Ollama server URL
- `set_decision_cooldown(seconds)`: Set cooldown period
- `clear_cache()`: Clear decision cache
- `get_cached_decisions()`: Get all cached decisions
