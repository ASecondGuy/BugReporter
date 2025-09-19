class_name BugReporter
extends PanelContainer
## Allows players to send bugreports and feedback to the dev from 
## inside the game using a discord webhook.


## path of the config file that is loaded.
## Will automatically reload
@export var cfg_path := "res://addons/BugReporter/webhook.cfg":
	set(val):
		cfg_path = val
		_reload_cfg()
## If true the Bugreporter will hide after the sending is complete
@export var hide_after_send := true
## If true all input fields will be cleared after sending is complete
@export var clear_after_send := true
## The Text edit containing the player message
@export var _message_text : TextEdit
## The LineEdit for player contact information
@export var _mail_line_edit : LineEdit
## The OptionButton to choose the kind of message
@export var _options : OptionButton
## Screenshot attachment button (if screenshot should be send)
@export var _screenshot_check : Button
## Texture button to display the Screenshot
@export var _screenshot : TextureButton
## Button to attach analytics
@export var _analytics_button : Button 
## Button to send Bugreport
@export var _send_button : Button
## Label to display the charater limit
@export var _text_limit : Label

var _cfg : ConfigFile


@onready var _webhook : WebhookBuilder = $WebhookBuilder


#region virtual functions


func _ready():
	_reload_cfg()
	_webhook.message_send_finished.connect(_send_button.set.bind("disabled", false))
	
	# Test for Screenshotmanager installed and active
	var shmanager : Node = get_node_or_null("/root/ScreenshotManager")
	if is_instance_valid(shmanager):
		_screenshot_check.text = "attach screenshot"
		_screenshot.texture_normal = shmanager.last_screenshot
		_screenshot.texture_normal.changed.connect(_screenshot.queue_redraw)
		_screenshot.texture_normal.changed.connect(
			_screenshot_check.set.bind("disabled", false)
			)
		set_process_input(false) # to disable this nodes screenshot taking
		_screenshot.pressed.connect(_on_screenshot_texture_pressed)


# only for taking screenshots. Disabled when Screenshot manager is installed
func _input(event):
	if event.is_action("screenshot") and event.is_pressed() and !event.is_echo():
		var img := get_viewport().get_texture().get_image()
		var text := ImageTexture.create_from_image(img)
		_screenshot.texture_normal = text
		_screenshot_check.disabled = false


#endregion
#region Reporter public functions


## Compiles all the info into a message with the [WebhookBuilder] and sends it.
func send_report(attach_log_file:=false, attach_analytics_file:=false):
	
	# find player id
	var player_id := "playerid: %s" % _unique_user_id()
	if _cfg.get_value("webhook", "anonymous_players", false):
		player_id = "anonymous"
	
	# message settings
	_webhook.set_username("%s:" % _get_game_name())
	_webhook.set_tts(_cfg.get_value("webhook", "tts", false))
	
	# attach files
	if attach_log_file:
		_webhook.add_file("user://logs/godot.log")
	if attach_analytics_file:
		_webhook.add_file(AnalyticsReport.new(get_tree()))
	
	# embed basics
	_webhook.start_embed()
	_webhook.set_embed_title("%s by %s" % [_options.text, player_id])
	_webhook.set_embed_color(_cfg.get_value("webhook", "color", 15258703))
	
	# add contact
	var contact_info := _mail_line_edit.text
	if !contact_info.is_empty():
		_webhook.add_embed_field("Contact Info:", contact_info)
	
	# add message
	var message = _message_text.text.replace("```", "")
	if !message.is_empty():
		_webhook.add_embed_field("Message:", message)
	
	# add screenshot
	if _screenshot_check.button_pressed:
		_webhook.set_embed_image(_screenshot.texture_normal)
	
	# send message
	_send_button.disabled = true # disable the send button while sending.
	_webhook.send_message(_cfg.get_value("webhook", "url", ""))
	print("BugReporter message send")


## Clears the message field of this Reporter.
func clear():
	_message_text.clear()


#endregion
#region private helper functions


# Returns a user id that depends on the game and device.
# This allows you to connect reports from the same player
# but not connect them across games
func _unique_user_id() -> String:
	if OS.get_name() == "Web":
		return "Webuser"
	return str(hash(str(OS.get_unique_id(), "|", _get_game_name())))


# helper to return the game name from the config
func _get_game_name():
	return _cfg.get_value("webhook", "game_name", "unnamed_game")


func _reload_cfg():
	_cfg = ConfigFile.new()
	var err := _cfg.load(cfg_path)
	if err != OK:
		push_error("Bugreporter couldn't load config. Reason: %s" % error_string(err))
	if is_instance_valid(_analytics_button):
		_analytics_button.visible = _cfg.get_value("webhook", "send_log", false) or _cfg.get_value("webhook", "send_analytics", false)


#endregion
#region called by signals


# does a few checks and then starts the message sending proccess
func _on_SendButton_pressed():
	var analytics := false
	if is_instance_valid(_analytics_button): 
		analytics = _analytics_button.button_pressed
	
	if _webhook.start_message() == OK:
		send_report( 
			bool(_cfg.get_value("webhook", "send_log", false)) and analytics,
			bool(_cfg.get_value("webhook", "send_analytics", false)) and analytics
		)
		if clear_after_send:
			clear()
		if hide_after_send:
			hide()


# unlock the send button and react to possible errors
func _on_webhook_builder_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	_send_button.disabled = false
	if hide_after_send:
		hide()
	if clear_after_send:
		clear()
	if ![200, 204].has(response_code):
		printerr("BugReporter Error sending Report. Result: %s Responsecode: %s Body: %s" % [result, response_code, body.get_string_from_ascii()])


# update the text limit label
func _on_message_text_text_changed():
	if is_instance_valid(_text_limit):
		var len : int = _message_text.text.length()
		_text_limit.add_theme_color_override("font_color", [Color.WHITE, Color.RED][int(len>1024)])
		if len > 800:
			_text_limit.text = "%s/%s" % [len, 1024]
			_text_limit.show()
		else:
			_text_limit.hide()


## Only relevant if ScreenshotManager is installed
## Will open the Screenshot selector
func _on_screenshot_texture_pressed():
	var selector : PackedScene = load(
		"res://addons/screenshotmanager/selector/screenshot_selector.tscn"
		)
	var node := selector.instantiate()
	add_child(node)
	node.selected.connect(func(path:String, image:Image): 
		_screenshot.texture_normal = ImageTexture.create_from_image(image)
		node.queue_free()
		_screenshot_check.disabled = false
		_screenshot_check.button_pressed = true
		)
	node.start_selection()


#endregion
