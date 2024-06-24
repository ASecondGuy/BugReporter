extends PanelContainer

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

@onready var _screenshot_check = $VBox/ScreenshotButton
@onready var _screenshot = $VBox/ScreenshotTexture
@onready var _analytics_button = $VBox/AnalyticsButton

var _cfg : ConfigFile


@onready var _http : WebhookBuilder = $WebhookBuilder

func _ready():
	_reload_cfg()
	for b in $VBox/SendBtns.get_children():
		if b is Button:
			b.pressed.connect(_send.bind(b.text))
	if is_instance_valid(_analytics_button):
		_analytics_button.visible = _cfg.get_value("webhook", "send_log", false) or _cfg.get_value("webhook", "send_analytics", false)


func _input(event):
	if event.is_action("screenshot") and event.is_pressed() and !event.is_echo():
		var img := get_viewport().get_texture().get_image()
		var text := ImageTexture.create_from_image(img)
		_screenshot.texture = text
		_screenshot_check.disabled = false


func _reload_cfg():
	_cfg = ConfigFile.new()
	var err := _cfg.load(cfg_path)
	if err != OK:
		push_error("Bugreporter couldn't load config. Reason: %s" % error_string(err))


func _send(mood:String):
	if _http.start_message() != OK:
		return
	
	_http.set_username("%s:" % _cfg.get_value("webhook", "game_name", "unnamed_game"))
	_http.set_tts(_cfg.get_value("webhook", "tts", false))
	
	_http.start_embed()
	_http.set_embed_title("Feedback:")
	_http.set_embed_color(_cfg.get_value("webhook", "color", 15258703))
	
	# use the description for the feedback text
	_http.set_embed_description($VBox/TextEdit.text)
	
	# footer and timestamp because it is pretty. You can add other info here if you want.
	_http.set_embed_timestamp()
	_http.set_embed_footer_text("Subnautica like Reporter")
	
	# make space for the players feelings (label of the button)
	_http.add_embed_field("Mood:", mood)
	
	# add screenshot
	if _screenshot_check.button_pressed and _screenshot.texture != null:
		_http.set_embed_image(_screenshot.texture)
	
	# make a list of all the categories the player marked
	var categories := ""
	for b in $VBox/Toggls.get_children():
		if b is CheckBox:
			categories += "%s %s\n" % [["☐", "☒"][int(b.button_pressed)], b.text]
	_http.add_embed_field("Categories:", categories)
	
	# put the icon as thumbnail for good measure
	# could also be a players avatar or something
	_http.set_embed_thumbnail(preload("res://icon.png"))
	
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

func clear():
	$VBox/TextEdit.text = ""

func _on_HTTPRequest_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if hide_after_send:
		hide()
	if clear_after_send:
		clear()
	if ![200, 204].has(response_code):
		printerr("BugReporter Error sending Report. Result: %s Responsecode: %s Body: %s" % [result, response_code, body.get_string_from_ascii()])
