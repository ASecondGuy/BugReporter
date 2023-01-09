extends PanelContainer

const CFG_PATH := "res://addons/BugReporter/webhook.cfg"

var _cfg : ConfigFile

onready var _screenshot := $VBox/ARC/TextureRect
onready var _screenshot_check = $VBox/CheckBox
onready var _http := $HTTPRequest

func _ready():
	_cfg = ConfigFile.new()
	_cfg.load(CFG_PATH)


func _input(event):
	if event.is_action("screenshot") and event.is_pressed() and !event.is_echo():
		var img := get_viewport().get_texture().get_data()
		img.flip_y()
		var text := ImageTexture.new()
		text.create_from_image(img)
		_screenshot.texture = text
		_screenshot_check.disabled = false



func _on_SendButton_pressed():
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	
	var message := "%"
