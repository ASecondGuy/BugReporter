@tool
extends EditorPlugin

var export_plugin := BugReporterExportPlugin.new()


func _enter_tree():
	add_export_plugin(export_plugin)
#	if !InputMap.has_action("screenshot"):
#		InputMap.add_action("screenshot")
#		var event := InputEventKey.new()
#		event.pressed = true
#		event.scancode = KEY_F2
#		InputMap.action_add_event("screenshot", event)


func _exit_tree():
	remove_export_plugin(export_plugin)
