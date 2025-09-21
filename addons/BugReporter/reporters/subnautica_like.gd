class_name BugReporterSub
extends PanelContainer
## Bugreporter styled after Subnautica.

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
## Screenshot attachment button (if screenshot should be send)
@onready var _screenshot_check : Button = $VBox/ScreenshotButton
## Texture button to display the Screenshot
@onready var _screenshot : TextureButton = $VBox/ScreenshotTexture
## Button to attach analytics
@onready var _analytics_button : Button = $VBox/AnalyticsButton
## Label to display the charater limit
@onready var _text_limit : Label = $VBox/TextLimit
## The Text edit containing the player message
@onready var _text_edit : TextEdit = $VBox/TextEdit


var _cfg : ConfigFile


@onready var _http : WebhookBuilder = $WebhookBuilder


#region virtual functions


func _ready():
	_reload_cfg()
	for b in $VBox/SendBtns.get_children():
		if b is Button:
			b.pressed.connect(_send.bind(b.text))
	if is_instance_valid(_analytics_button):
		_analytics_button.visible = _cfg.get_value("webhook", "send_log", false) or _cfg.get_value("webhook", "send_analytics", false)
	
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

## Clears the message field of this Reporter.
func clear():
	$VBox/TextEdit.text = ""


#endregion
#region Private functions

func _reload_cfg():
	_cfg = ConfigFile.new()
	var err := _cfg.load(cfg_path)
	if err != OK:
		push_error("Bugreporter couldn't load config. Reason: %s" % error_string(err))


# Compiles all the info into a message with the [WebhookBuilder] and sends it.
func _send(mood:String):
	if _http.start_message() != OK:
		return
	
	_http.set_username("%s:" % _cfg.get_value("webhook", "game_name", "unnamed_game"))
	_http.set_tts(_cfg.get_value("webhook", "tts", false))
	
	_http.start_embed()
	_http.set_embed_title("Feedback:")
	# set color according to player mood
	var moods := $VBox/SendBtns.get_children().map(func(c): return c.text)
	_http.set_embed_color([Color.GREEN, Color.GREEN_YELLOW, Color.YELLOW, Color.RED][
		moods.find(mood)
	])
	
	# use the description for the feedback text
	_http.set_embed_description(_text_edit.text)
	
	# footer and timestamp because it is pretty. You can add other info here if you want.
	_http.set_embed_timestamp()
	_http.set_embed_footer_text("Subnautica like Reporter")
	
	# make space for the players feelings (label of the button)
	_http.add_embed_field("Mood:", mood)
	
	# add screenshot
	if _screenshot_check.button_pressed and _screenshot.texture_normal != null:
		_http.set_embed_image(_screenshot.texture_normal)
	
	# make a list of all the categories the player marked
	var categories := ""
	for b in $VBox/Toggls.get_children():
		if b is CheckBox:
			categories += "%s %s\n" % [["☐", "☒"][int(b.button_pressed)], b.text]
	_http.add_embed_field("Categories:", categories)
	
	# put the icon as thumbnail for good measure
	# could also be a players avatar or something
	_http.set_embed_thumbnail(load(
		ProjectSettings.get_setting_with_override("application/config/icon")
	))
	
	# subnautica icon because it inspired me to make this addon and especially this reporter
	_http.set_embed_footer_icon_url("https://static.wikia.nocookie.net/subnautica/images/e/e6/Site-logo.png")
	
	# analytics
	var log := _cfg.get_value("webhook", "send_log", false)
	var rep := _cfg.get_value("webhook", "send_analytics", false)
	if (log or rep) and _analytics_button.button_pressed:
		if log:
			_http.add_file("user://logs/godot.log")
		if rep:
			_http.add_file(AnalyticsReport.new(get_tree()))
	
	
	_http.send_message(_cfg.get_value("webhook", "url"))
	if hide_after_send:
		hide()
	if clear_after_send:
		clear()


#endregion
#region called by signals


# react to possible errors
func _on_HTTPRequest_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if hide_after_send:
		hide()
	if clear_after_send:
		clear()
	if ![200, 204].has(response_code):
		printerr("BugReporter Error sending Report. Result: %s Responsecode: %s Body: %s" % [result, response_code, body.get_string_from_ascii()])


# update the text limit label
func _on_text_edit_text_changed():
	var len : int = _text_edit.text.length()
	_text_limit.add_theme_color_override("font_color", [Color.WHITE, Color.RED][int(len>2000)])
	if len > 1800:
		_text_limit.text = "%s/%s" % [len, 2000]
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
