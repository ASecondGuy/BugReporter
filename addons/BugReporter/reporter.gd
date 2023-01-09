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
	
	var messagetype := tr($VBox/OptionButton.text)
	var message := "playerid: %s\n```\n%s\n```" % [_unique_user_id(), $VBox/Message.text.replace("```", "")]
	
	var data := {
		"content" : message,
		"username" : "%s:" % _get_game_name(),
		"tts" : _cfg.get_value("webhook", "tts", false),
#		"embeds": 
#			[{"image": {"url": "attachment://screenshot.png"}}],
		
	}
	
	
	print(_http.request(_cfg.get_value("webhook", "url", ""), 
			PoolStringArray(["connection: keep-alive", "Content-Type: application/json"]), 
			true, 
			HTTPClient.METHOD_POST,
			to_json(data)
	))


func _on_HTTPRequest_request_completed(result, response_code, headers, body):
	print(result, response_code, headers, body.get_string_from_ascii())


func _unique_user_id() -> String:
	return str(hash(str(OS.get_unique_id(), "|", _get_game_name())))

func _get_game_name():
	return _cfg.get_value("webhook", "game_name", "unnamed_game")
