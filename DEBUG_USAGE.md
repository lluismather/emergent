# Debug System Usage Guide

The Emergent project includes a comprehensive debug system that can be controlled via environment variables or project settings.

## Quick Start

### Environment Variables (Recommended)

Set environment variables before running the game:

```bash
# Enable all debug features
export EMERGENT_DEBUG=true

# Enable specific systems only
export EMERGENT_DEBUG_UI=true
export EMERGENT_DEBUG_PERCEPTION=true

# Enable verbose logging
export EMERGENT_DEBUG_VERBOSE=true

# Then run the game
godot --path . src/core/scenes/game.tscn
```

### Project Settings Alternative

Edit `project.godot` and modify the `[debug]` section:

```ini
[debug]
general/enabled=true
general/verbose=true
systems/ui=true
systems/perception=true
systems/ai=false
systems/spells=false
systems/environment=false
```

## Available Debug Categories

| Environment Variable | Project Setting | Description |
|---------------------|----------------|-------------|
| `EMERGENT_DEBUG` | `debug/general/enabled` | Master debug toggle |
| `EMERGENT_DEBUG_VERBOSE` | `debug/general/verbose` | Extra detailed logging |
| `EMERGENT_DEBUG_UI` | `debug/systems/ui` | Debug UI sidebar visibility |
| `EMERGENT_DEBUG_PERCEPTION` | `debug/systems/perception` | Perception system logging |
| `EMERGENT_DEBUG_PERCEPTION_VISUAL` | `debug/systems/perception_visual` | Perception circle visualization |
| `EMERGENT_DEBUG_AI` | `debug/systems/ai` | AI system logging |
| `EMERGENT_DEBUG_SPELLS` | `debug/systems/spells` | Spell system logging |
| `EMERGENT_DEBUG_ENVIRONMENT` | `debug/systems/environment` | Environment system logging |

## Debug Features

### Debug UI Sidebar
When `EMERGENT_DEBUG_UI=true`:
- Shows real-time perception data
- Displays nearby objects with details
- Shows environmental conditions
- Provides spatial analysis

### Perception Circle Visualization
When `EMERGENT_DEBUG_PERCEPTION_VISUAL=true`:
- Shows yellow circle around player indicating vision radius
- Displays cross-hairs for reference
- Red center dot shows exact player position

### Debug Logging
When debug categories are enabled:
- Formatted debug messages: `[DEBUG:CATEGORY] message`
- System initialization messages
- Runtime state information

## Runtime Debug Controls

The debug system can be toggled at runtime (useful for development):

```gdscript
# Toggle overall debug mode
DebugConfig.toggle_debug()

# Toggle specific categories
DebugConfig.toggle_category_debug("perception")
DebugConfig.toggle_category_debug("perception_visual")
DebugConfig.toggle_category_debug("ui")
DebugConfig.toggle_category_debug("ai")
```

## Common Debug Scenarios

### Development Workflow
```bash
# Full debug mode for development
export EMERGENT_DEBUG=true
export EMERGENT_DEBUG_VERBOSE=true
```

### Testing Perception System
```bash
# Focus on perception debugging
export EMERGENT_DEBUG_PERCEPTION=true
export EMERGENT_DEBUG_PERCEPTION_VISUAL=true
export EMERGENT_DEBUG_UI=true
```

### Performance Testing
```bash
# Disable all debug features
unset EMERGENT_DEBUG
unset EMERGENT_DEBUG_UI
# (or set them to false)
```

### CI/Build Environment
```bash
# Ensure debug is disabled for builds
export EMERGENT_DEBUG=false
export EMERGENT_DEBUG_UI=false
```

## Priority Order

Debug settings are loaded in this priority order:
1. Environment variables (highest priority)
2. Project settings (fallback)
3. Default values (disabled)

This allows environment variables to override project settings, making it easy to temporarily enable debug features without modifying project files.

## Tips

- Use environment variables for temporary debugging sessions
- Use project settings for persistent debug configurations
- The debug UI can impact performance - disable for final builds
- Verbose logging produces a lot of output - use sparingly
- Individual system debugging allows focused troubleshooting