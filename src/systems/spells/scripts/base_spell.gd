extends Area2D

@export var effect_name: String
@export var duration: float = 1.0

func _ready():
   # Configure and add a one-shot timer for effect removal
   if not has_node("Timer"):
       var t = Timer.new()
       add_child(t)
       t.name = "Timer"
   $Timer.wait_time = duration
   $Timer.one_shot = true
   $Timer.connect("timeout", Callable(self, "_on_timer_timeout"))
   connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body: Node) -> void:
   # Apply the spell effect to the first valid target and start removal timer
   if body.is_in_group("spell_targets") and body.has_method("apply_spell_effect"):
       body.apply_spell_effect(effect_name, duration)
       # Prevent re-triggering on the same or other bodies
       set_monitoring(false)
       $Timer.start()

func _on_timer_timeout() -> void:
   # Remove the spell effect when duration elapses
   # If overlapping multiple bodies, remove from any that support it
   for body in get_overlapping_bodies():
       if body.is_in_group("spell_targets") and body.has_method("remove_spell_effect"):
           body.remove_spell_effect(effect_name)
   queue_free()