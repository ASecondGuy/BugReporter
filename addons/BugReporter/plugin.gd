tool
extends EditorPlugin


#func _enter_tree():
#	if !InputMap.has_action("screenshot"):
#		InputMap.add_action("screenshot")
#		var event := InputEventKey.new()
#		event.pressed = true
#		event.scancode = KEY_F2
#		InputMap.action_add_event("screenshot", event)


func _exit_tree():
	pass
