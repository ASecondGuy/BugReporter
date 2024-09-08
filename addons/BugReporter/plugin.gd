@tool
extends EditorPlugin

const CRASHHANDLER_NAME := "CrashHandler"

func _enter_tree():
#	if !InputMap.has_action("screenshot"):
#		InputMap.add_action("screenshot")
#		var event := InputEventKey.new()
#		event.pressed = true
#		event.scancode = KEY_F2
#		InputMap.action_add_event("screenshot", event)
	add_autoload_singleton(CRASHHANDLER_NAME, "res://addons/BugReporter/crash/crash_handler.gd")


func _exit_tree():
	remove_autoload_singleton(CRASHHANDLER_NAME)
