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

var _cfg : ConfigFile


@onready var _http : WebhookBuilder = $WebhookBuilder

func _ready():
	_reload_cfg()
	for b in $VBox/SendBtns.get_children():
		if b is Button:
			b.pressed.connect(_send.bind(b.text))


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
	
	_http.start_embed()
	_http.set_username("%s:" % _cfg.get_value("webhook", "game_name", "unnamed_game"))
	_http.set_embed_description($VBox/TextEdit.text)
	_http.set_embed_timestamp()
	_http.set_embed_footer_text("Subnautica like Reporter")
	_http.add_embed_field("Mood:", mood)
	if _screenshot_check.pressed and _screenshot.texture != null:
		_http.set_embed_image(_screenshot.texture)
	var categories := ""
	for b in $VBox/Toggls.get_children():
		if b is CheckBox:
			categories += "%s %s\n" % [["☐", "☒"][int(b.button_pressed)], b.text]
	_http.add_embed_field("Categories:", categories)
	_http.set_embed_thumbnail(preload("res://icon.png"))
	_http.set_embed_footer_icon_url("https://static.wikia.nocookie.net/subnautica/images/e/e6/Site-logo.png")
	_http.send_message(_cfg.get_value("webhook", "url"))

func clear():
	$VBox/TextEdit.text = ""

func _on_HTTPRequest_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if hide_after_send:
		hide()
	if clear_after_send:
		clear()
	if ![200, 204].has(response_code):
		printerr("BugReporter Error sending Report. Result: %s Responsecode: %s Body: %s" % [result, response_code, body.get_string_from_ascii()])
