extends Node

func _notification(what):
	if what == NOTIFICATION_CRASH:
		DirAccess.rename_absolute("user://logs/godot.log", "user://logs/godot_crash.log")
		var restart_comand := OS.get_executable_path()+" -w -q res://addons/BugReporter/crash/crash_reporter.tscn"
		
		match OS.get_name():
			"Windows":
				OS.create_process("cmd", ["/c", "timeout /t 5 >nul && start " + restart_comand])
			"Linux":
				OS.create_process("sh", ["-c", "sleep 1 && "+restart_comand])
			"macOS":
				OS.create_process("sh", ["-c", "sleep 1 && open "+restart_comand])
