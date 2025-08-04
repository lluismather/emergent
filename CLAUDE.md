# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Godot 4.4 game project called "Emergent" - a psychological simulation focused on autonomous NPCs with complex decision-making systems. The project explores emergent behaviors arising from AI agents with perception, needs, execution, and social systems interacting in a 2D environment.

## Development Commands

### Running the Game
- Open the project in Godot Editor and press F5 to run
- Main scene: `res://src/core/scenes/game.tscn`

### Building/Exporting
The project is configured for multi-platform export:
- **macOS**: Exports to `builds/Emergent.dmg` 
- **iOS**: Configured but no export path set
- Use Godot's Project -> Export menu to build releases

### Project Configuration
- Resolution: 1920x1080 with viewport stretching
- Rendering: 2D pixel-perfect with integer scaling
- Input: WASD/Arrow keys for movement, Shift for walk/sprint

## Code Architecture

### Core Systems

**Game Manager (`src/core/scripts/game.gd`)**
- Main game controller extending Node2D
- Manages day/night cycle integration
- Broadcasts day/night state changes to all responders via `day_night_responders` group

**Player System (`src/entities/player/scripts/player.gd`)**
- CharacterBody2D with 8-directional movement
- Multi-speed movement: walk (0.5x), normal (1x), sprint (1.5x)
- Animation state machine for directional movement and idle states
- Includes perception system for environmental awareness
- Base speed: 150 units/second

**NPC System (`src/entities/npcs/scripts/npc.gd`)**
- Autonomous agents with comprehensive AI subsystems
- **ExecutionSystem**: Priority-based action queue with movement, waiting, interaction
- **PerceptionSystem**: Environmental awareness and object detection
- **NeedsSystem**: Hunger, energy, social, purpose drives (shell)
- **EmotionSystem**: Mood and emotional state management (shell)
- **PlanningSystem**: Goal decomposition and decision making (shell)
- Signal-based communication between all subsystems

**Perception System (`src/systems/ai/scripts/perception_system.gd`)**
- MCP-compatible environmental awareness
- Object detection within configurable vision radius
- Temporal and environmental data integration
- Spatial analysis and clustering
- Real-time updates with debug visualization

**Execution System (`src/systems/ai/scripts/execution_system.gd`)**
- Reusable component for action execution
- Priority-based action queue (LOW, NORMAL, HIGH, URGENT, CRITICAL)
- Action types: move, wait, face, interact
- Signal emissions for action lifecycle events
- Interruption and completion tracking

**Day/Night Cycle (`src/core/scripts/day_night_cycle.gd`)**
- CanvasModulate-based lighting system
- Configurable time progression (default 20x speed)
- Day hours: 6-17, Night: 18-5
- Uses gradient textures for smooth lighting transitions
- Emits signals for time ticks and day/night state changes

**Debug System (`src/core/scripts/debug_config.gd`)**
- Environment variable and project setting configuration
- Category-specific debug flags (perception, ui, ai, environment)
- Real-time debug UI with perception data visualization
- Signal-based debug logging with priorities

### Scene Structure
- `src/core/scenes/game.tscn`: Main game scene
- `src/entities/player/scenes/player.tscn`: Player character with perception
- `src/entities/npcs/scenes/npc.tscn`: Autonomous NPC with full AI stack
- `src/systems/debug/scenes/`: Debug UI and visualization tools
- Environmental objects: `src/entities/environment/scenes/`

### Asset Organization
- `assets/`: Extensive pixel art assets including characters, buildings, tiles, UI
- `audio/`: Game music (hedwig theme)
- `tilesets/`: Universal tileset resource
- Multi-themed asset packs: base, characters, dungeons, halloween, ui

### Input Mapping
- Movement: WASD + Arrow keys
- Walk: Shift key (reduces speed)
- Sprint: Ctrl key (increases speed)

## Development Notes

### Environment Variables for Debug
- `EMERGENT_DEBUG=true`: Enable all debug features
- `EMERGENT_DEBUG_UI=true`: Show debug UI sidebar with real-time data
- `EMERGENT_DEBUG_PERCEPTION=true`: Enable perception system logging
- `EMERGENT_DEBUG_PERCEPTION_VISUAL=true`: Show perception circle visualization  
- `EMERGENT_DEBUG_AI=true`: Enable AI execution system logging
- `EMERGENT_DEBUG_ENVIRONMENT=true`: Enable environment system logging

### Key Features
- **Emergent Behavior**: Complex decisions arise from simple AI system interactions
- **Signal-Based Architecture**: All systems communicate via Godot signals
- **Reusable Components**: ExecutionSystem can be attached to any entity
- **Priority Systems**: Actions, needs, and decisions use priority queues
- **MCP Integration**: Perception system compatible with Model Context Protocol
- **Real-time Debug**: Comprehensive debug UI shows all system states
- **Modular Design**: Each AI subsystem is independent and replaceable

### Development Workflow
1. **NPCs**: Start with ExecutionSystem for visible behavior
2. **Needs**: Add drives that motivate NPC actions
3. **Goals**: Create objectives based on needs
4. **Planning**: Break goals into executable actions
5. **Social**: Add inter-NPC interactions and relationships