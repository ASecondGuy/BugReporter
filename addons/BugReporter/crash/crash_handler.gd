extends Node

func _notification(what):
	if what == NOTIFICATION_CRASH:
		DirAccess.rename_absolute("user://logs/godot.log", "user://logs/godot_crash.log")
		OS.create_process(OS.get_executable_path(), ["-w", "-q",
		"res://addons/BugReporter/crash/crash_reporter.tscn",
		])
