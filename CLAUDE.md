# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Godot 4.4 game project called "Wizarding" - a 2D top-down adventure game with spell mechanics, day/night cycles, and character movement. The game features a Harry Potter-themed wizarding world with spells, environmental interactions, and atmospheric lighting.

## Development Commands

### Running the Game
- Open the project in Godot Editor and press F5 to run
- Main scene: `res://scenes/game.tscn`

### Building/Exporting
The project is configured for multi-platform export:
- **macOS**: Exports to `builds/Wizarding.dmg` 
- **iOS**: Configured but no export path set
- Use Godot's Project -> Export menu to build releases

### Project Configuration
- Resolution: 1920x1080 with viewport stretching
- Rendering: 2D pixel-perfect with integer scaling
- Input: WASD/Arrow keys for movement, Shift for walk/sprint

## Code Architecture

### Core Systems

**Game Manager (`scripts/game.gd`)**
- Main game controller extending Node2D
- Manages day/night cycle integration
- Broadcasts day/night state changes to all responders via `day_night_responders` group

**Player System (`scripts/player.gd`)**
- CharacterBody2D with 8-directional movement
- Multi-speed movement: walk (0.5x), normal (1x), sprint (1.5x)
- Animation state machine for directional movement and idle states
- Base speed: 150 units/second

**Day/Night Cycle (`scripts/day_night_cycle.gd`)**
- CanvasModulate-based lighting system
- Configurable time progression (default 20x speed)
- Day hours: 6-17, Night: 18-5
- Uses gradient textures for smooth lighting transitions
- Emits signals for time ticks and day/night state changes

**Spell System (`scripts/spells/`)**
- `base_spell.gd`: Area2D-based spell effects with duration timers
- Targets objects in `spell_targets` group
- Spells auto-remove after duration expires
- `growing_spell.gd`: Specific implementation for growth effects

### Scene Structure
- `scenes/game.tscn`: Main game scene
- `scenes/player.tscn`: Player character prefab
- `scenes/spells/`: Spell effect prefabs
- Environmental objects: `horse.tscn`, `lamp.tscn`, `torch.tscn`, `level_exit.tscn`

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

- Uses Godot's group system for spell targeting and day/night responses
- Pixel-perfect rendering with integer scaling for crisp visuals
- Modular spell system allows for easy expansion of magical effects
- Day/night cycle affects all registered responder objects simultaneously