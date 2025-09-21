class_name BugReporterExportPlugin
extends EditorExportPlugin

const LOG_ERROR_1 := """
BugReporter configs use log files but flush on print is off.
This will cause the last part of the log file to be missing.
Enable application/run/flush_stdout_on_print in the Project Settings.
"""
const LOG_ERROR_2 := """
BugReporter configs use log files but logging is off.
This will cause empty or no log files to be send.
Enable debug/file_logging/enable_file_logging in the ProjectSettings.
"""


var included_count : int = 0
var log_used := false


func _get_name():
	return "BugReporterExportPlugin"


func _export_begin(features, is_debug, _path, _flags):
	included_count = 0
	log_used = false
	var todo := ["res://"]
	while todo.size() > 0:
		var dir : String = todo.pop_back()
		todo.append_array(
			Array(DirAccess.get_directories_at(dir)).filter(
				filter_visible
			).map(
				func(p): return dir + p + "/"
			)
			)
		for config in Array(DirAccess.get_files_at(dir)).filter(filter_cfg):
			handle_cfg(dir+config, is_debug)
	
	if included_count == 0:
		push_error("There was no valid BugReporter config found.")
	if log_used:
		if not get_setting("application/run/flush_stdout_on_print", features):
			push_error(LOG_ERROR_1.replace("\n", " ").strip_edges())
		if not get_setting("debug/file_logging/enable_file_logging", features):
			push_error(LOG_ERROR_2.replace("\n", " ").strip_edges())


func filter_visible(string:String) -> bool:
	return not string.begins_with(".")


func filter_cfg(string:String) -> bool:
	return not string.begins_with(".") and string.to_lower().ends_with(".cfg")


func handle_cfg(path:String, is_debug:bool):
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return# Can't open. Don't include.
	if not cfg.get_sections().has("webhook"):
		return# No webhook section -> not relevant
	
	var url = cfg.get_value("webhook", "url", "")
	if not url is String:
		push_error("cfg file %s has an invalid url" % path)
		return 
	if url.contains("<webhook.id>") or url.contains("<webhook.token>"):
		return# Example cfg should not be included
	
	add_file(path, FileAccess.get_file_as_bytes(path), false)
	included_count += 1
	
	if not (url.begins_with("https://") or url.begins_with("http://")):
		push_error("cfg file %s has an invalid url" % path)
		return# invalid url
	if url.contains("discord.com"):
		if is_debug:
			push_warning("cfg file %s uses discord api directly. Consider using a proxy." % path)
		else:
			push_error("cfg file %s uses discord api directly. This is not recomended for release. Consider using a proxy." % path)
	if cfg.get_value("webhook", "send_log", false):
		log_used = true


func get_setting(setting:String, features:PackedStringArray):
	# I hope this is equivalent to get_setting_with_override_and_custom_features
	# because I want to support 4.x and that is only available from 4.5
	for over in features:
		if ProjectSettings.has_setting(setting + "." + over):
			return ProjectSettings.get_setting(setting + "." + over)
	return ProjectSettings.get_setting(setting)
