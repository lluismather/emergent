# Emergent

**A Simulation Exploring Autonomous Decision-Making**

*Emergent* is an experimental project focused on creating autonomous NPCs with complex decision-making systems. The goal is to explore how sophisticated behaviors and social dynamics can emerge from the interaction of simple AI subsystems, creating a living simulation where agents make independent choices based on their perceptions, needs, and social context.

## 🧠 Project Vision

Rather than scripted behaviors, NPCs in Emergent operate through interconnected psychological systems that drive authentic decision-making:

- **Autonomous Agents**: NPCs make independent decisions based on their internal state and environment
- **Emergent Behavior**: Complex social dynamics arise naturally from simple system interactions  
- **Psychological Realism**: Agents have needs, emotions, memories, and personalities that influence their choices
- **Observable Systems**: Every decision and internal state can be observed and analyzed in real-time

## 🏗️ Architecture Overview

### Core Philosophy
Emergent uses a **signal-based, modular architecture** where independent AI subsystems communicate through Godot signals. This creates a decoupled system where complex behaviors emerge from the interaction of simple, focused components.

### NPC Subsystems

Each NPC contains a comprehensive set of AI subsystems:

#### **🎯 ExecutionSystem** *(Implemented)*
- **Purpose**: Handles all NPC actions and movement
- **Features**: Priority-based action queue, interruption handling, signal-based status updates
- **Actions**: Move, Wait, Face Direction, Interact
- **Reusable**: Can be attached to any entity requiring autonomous behavior

#### **👁️ PerceptionSystem** *(Implemented)*
- **Purpose**: Environmental awareness and object detection
- **Features**: Vision radius, object classification, spatial analysis, temporal awareness
- **Integration**: MCP-compatible for AI model integration
- **Real-time**: Continuous environmental scanning and updates

#### **🏃 NeedsSystem** *(Shell - Ready for Implementation)*
- **Purpose**: Drives NPC motivation through biological and psychological needs
- **Planned Needs**: Hunger, Energy, Social Connection, Purpose/Meaning
- **Mechanics**: Needs decay over time, creating urgency for action
- **Influence**: Directly impacts goal formation and decision priority

#### **😊 EmotionSystem** *(Shell - Ready for Implementation)*
- **Purpose**: Emotional state management affecting decision-making
- **Features**: Mood tracking, emotional modifiers, social emotional responses
- **Integration**: Emotions influence action selection and social interactions

#### **🎭 PersonalitySystem** *(Shell - Ready for Implementation)*
- **Purpose**: Individual character traits that shape behavior patterns
- **Traits**: Introversion/Extraversion, Risk-taking, Empathy levels
- **Persistence**: Stable characteristics that consistently influence decisions

#### **🧠 MemorySystem** *(Shell - Ready for Implementation)*
- **Purpose**: Learning and experience retention
- **Types**: Short-term working memory, long-term experience storage
- **Applications**: Remember locations, people, successful strategies

#### **🎯 GoalsSystem** *(Shell - Ready for Implementation)*
- **Purpose**: Objective formation based on needs and circumstances
- **Hierarchy**: Long-term, mid-term, and immediate goals
- **Dynamic**: Goals emerge from need states and environmental opportunities

#### **📋 PlanningSystem** *(Shell - Ready for Implementation)*
- **Purpose**: Break down goals into executable action sequences
- **Features**: Goal decomposition, action sequencing, plan adaptation
- **Integration**: Feeds action sequences to ExecutionSystem

#### **👥 SocialSystem** *(Shell - Ready for Implementation)*
- **Purpose**: Relationship management and social behavior
- **Features**: Relationship tracking, social norm awareness, group dynamics
- **Emergence**: Social structures arise from individual interactions

#### **🎭 IdentitySystem** *(Shell - Ready for Implementation)*
- **Purpose**: Sense of self, role, and place in the community
- **Components**: Personal role, family connections, social status, skills
- **Influence**: Identity shapes goal selection and social behavior

#### **⚖️ ReputationSystem** *(Shell - Ready for Implementation)*
- **Purpose**: Social standing and community expectation tracking
- **Mechanics**: Actions affect reputation, reputation influences social interactions
- **Dynamics**: Creates social pressure and behavioral conformity

#### **📦 ResourceSystem** *(Shell - Ready for Implementation)*
- **Purpose**: Physical and abstract resource management
- **Resources**: Items, energy, time, social capital
- **Constraints**: Resource limitations drive decision-making

#### **⚡ InflectionSystem** *(Shell - Ready for Implementation)*
- **Purpose**: Determines when NPCs should make new decisions
- **Triggers**: Need thresholds, environmental changes, social events
- **Optimization**: Prevents constant decision-making, focuses on meaningful moments

#### **🤔 TheoryOfMindSystem** *(Shell - Ready for Implementation)*
- **Purpose**: Understanding and predicting other agents' mental states
- **Applications**: Empathy, manipulation, cooperation, competition
- **Emergence**: Enables complex social dynamics and relationships

## 🎮 Technology Stack

- **Engine**: Godot 4.4
- **Language**: GDScript
- **Architecture**: Signal-based component system
- **Debug**: Environment variable configuration with real-time UI
- **Integration**: MCP (Model Context Protocol) compatible for AI model integration

## 🔍 Debug System

Comprehensive debugging system with environment variable control:

```bash
# Enable all debug features
export EMERGENT_DEBUG=true

# Enable specific systems
export EMERGENT_DEBUG_UI=true              # Debug UI sidebar
export EMERGENT_DEBUG_PERCEPTION=true      # Perception logging
export EMERGENT_DEBUG_AI=true              # AI system logging
export EMERGENT_DEBUG_PERCEPTION_VISUAL=true  # Visual perception circle
```

## 🎯 Research Goals

### Primary Questions
- How do complex social behaviors emerge from simple AI system interactions?
- What minimal set of psychological systems can produce believable autonomous agents?
- How do group dynamics form when individual agents follow their own needs and goals?

