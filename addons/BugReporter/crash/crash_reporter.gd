extends MarginContainer

## path of the config file that is loaded.
## Will automatically reload
@export var cfg_path := "res://addons/BugReporter/webhook.cfg":
	set(val):
		cfg_path = val
		_reload_cfg()

var _cfg : ConfigFile

@onready var _webhook = $WebhookBuilder
@onready var _message_text = $VB/TextEdit
@onready var _text_limit = $VB/LimitLabel


func _ready():
	_reload_cfg()
	_webhook.message_send_finished.connect(get_tree().quit)
	print("CrashReporter started")


func _reload_cfg():
	_cfg = ConfigFile.new()
	var err := _cfg.load(cfg_path)
	if err != OK:
		push_error("CrashReporter couldn't load config. Reason: %s" % error_string(err))


func _get_game_name():
	return _cfg.get_value("webhook", "game_name", "unnamed_game")

func _unique_user_id() -> String:
	if OS.get_name() == "Web":
		return "Webuser"
	return str(hash(str(OS.get_unique_id(), "|", _get_game_name())))

func _send():
	_webhook.start_message()
	# find player id
	var player_id := "playerid: %s" % _unique_user_id()
	if _cfg.get_value("webhook", "anonymous_players", false):
		player_id = "anonymous"
	
	# message settings
	_webhook.set_username("%s:" % _get_game_name())
	_webhook.set_tts(_cfg.get_value("webhook", "tts", false))
	# attach files
	_webhook.add_file("user://logs/godot_crash.log")
	
	# embed basics
	_webhook.start_embed()
	_webhook.set_embed_title("CrashReport by %s" % player_id)
	_webhook.set_embed_color(_cfg.get_value("webhook", "color", 15258703))
	
	# add message
	var message : String = _message_text.text.replace("```", "")
	if !message.is_empty():
		_webhook.set_embed_description("```%s```" % message.left(4000))
	
	_webhook.send_message(_cfg.get_value("webhook", "url", ""))
	print("CrashReporter message send:")
	print(message)

func _restart():
	OS.create_process(OS.get_executable_path(), [])


func _on_message_text_text_changed():
	if is_instance_valid(_text_limit):
		var len : int = _message_text.text.length()
		_text_limit.add_theme_color_override("font_color", [Color.WHITE, Color.RED][int(len>4000)])
		if len > 3000:
			_text_limit.text = "%s/%s" % [len, 4000]
			_text_limit.show()
		else:
			_text_limit.hide()


func _on_quit_pressed():
	get_tree().quit()


func _on_quit_and_send_pressed():
	_send()


func _on_restart_and_send_pressed():
	_restart()
	_send()


func _on_restart_pressed():
	get_tree().quit()
	_restart()

