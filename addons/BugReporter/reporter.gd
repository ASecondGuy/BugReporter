extends PanelContainer
## Allows players to send bugreports and feedback to the dev from inside the game using a discord webhook
class_name BugReporter

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


var _cfg : ConfigFile


@onready var _screenshot := $VBox/TextureRect
@onready var _screenshot_check = $VBox/CheckBox
@onready var _mail : LineEdit = $VBox/Mail/LineEdit
@onready var _http := $HTTPRequest
@onready var _send_button = $VBox/SendButton


func _ready():
	_reload_cfg()

func _reload_cfg():
	_cfg = ConfigFile.new()
	var err := _cfg.load(cfg_path)
	if err != OK:
		push_error("Bugreporter couldn't load config. Reason: %s" % error_string(err))


func _input(event):
	if event.is_action("screenshot") and event.is_pressed() and !event.is_echo():
		var img := get_viewport().get_texture().get_image()
		var text := ImageTexture.create_from_image(img)
		_screenshot.texture = text
		_screenshot_check.disabled = false



func _on_SendButton_pressed():
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	
	var messagetype := tr($VBox/OptionButton.text)
	var message : String = $VBox/Message.text.replace("```", "")
	var player_id := "playerid: %s" % _unique_user_id()
	if _cfg.get_value("webhook", "anonymous_players", false):
		player_id = "anonymous"
	var contact_info := _mail.text.dedent()
	
	var request_body := []# 1st place is reserved for json_payload
	
	
	var json_payload := {
		"username" : "%s:" % _get_game_name(),
		"tts" : _cfg.get_value("webhook", "tts", false),
	}
	var embed = {
			"title": "%s by %s" % [messagetype, player_id],
			"color": _cfg.get_value("webhook", "color", 15258703),
		}
	var fields := []
	
	if !contact_info.is_empty():
		fields.push_back({
				"name" : "Contact Info:",
				"value" : contact_info
		})
	
	if !message.is_empty():
		fields.push_back({
				"name" : "Message:",
				"value" : "```\n%s\n```" % message,
			}
	)
	
	
	if _screenshot_check.button_pressed:
		embed["image"] = {
					"url" : "attachment://screenshot0.png",
				}
		
		request_body.push_back(_screenshot.texture)
	
	embed["fields"] = fields
	json_payload["embeds"] = [embed]
	
	request_body.push_back("user://logs/godot.log")
	
	request_body.push_front(json_payload)
	var payload := _array_to_form_data(request_body)
	
	if fields.is_empty():
		return
	
	_http.request(_cfg.get_value("webhook", "url", ""), 
			PackedStringArray(["connection: keep-alive", "Content-type: multipart/form-data; boundary=boundary"]), 
			HTTPClient.METHOD_POST,
			payload
	)
	
	_send_button.disabled = true
	print("BugReporter message send")



func _on_HTTPRequest_request_completed(result, response_code, headers, body):
	_send_button.disabled = false
	if hide_after_send:
		hide()
	if clear_after_send:
		_mail.clear()
		$VBox/Message.text = ""


func _unique_user_id() -> String:
	if OS.get_name() == "Web":
		return "Webuser"
	return str(hash(str(OS.get_unique_id(), "|", _get_game_name())))

func _get_game_name():
	return _cfg.get_value("webhook", "game_name", "unnamed_game")


## Converts a texture into the corresponding bytes but limited to a max size
func _texture_to_png_bytes(texture : Texture2D, max_size:=8000000)->PackedByteArray:
	var img := texture.get_image()
	var bytes : PackedByteArray = img.save_png_to_buffer()
	
	while bytes.size() > max_size:
		img.resize(img.get_width()/2, img.get_height()/2)
		bytes = img.save_png_to_buffer()
	
	return bytes


## converts an array of [Variant] into the closest multipart form data equivalent. 
func _array_to_form_data(array:Array)->String:
	# Discord example request
#	-boundary
#	Content-Disposition: form-data; name="content"
#
#	Hello, World!
#	--boundary
#	Content-Disposition: form-data; name="tts"
#
#	true
#	--boundary--
#	
	var file_counter := 0
	var output = ""
	
	for element in array:
		output += "--boundary\n"
		
		if element is Dictionary:
			output += 'Content-Disposition: form-data; name="payload_json"\nContent-Type: application/json\n\n'
			output += JSON.new().stringify(element) + "\n"
			
		elif element is Texture2D:
			output += 'Content-Type: image/png; name="files[%s]"\n' % file_counter
			output += 'Content-Disposition: attachment; filename="screenshot%s.png"\n' % file_counter
			output += 'Content-Transfer-Encoding: base64\nX-Attachment-Id: f_ljiz6nfz0\nContent-ID: <f_ljiz6nfz0>'
			output += "\n\n"
			output += Marshalls.raw_to_base64(_texture_to_png_bytes(element)) + "\n"
			file_counter += 1
		elif element is String:
			if element.is_absolute_path():
				var f := FileAccess.open(element, FileAccess.READ)
				if FileAccess.get_open_error() == OK:
					output += 'Content-Type: plain/text; name="files[%s]"\n' % file_counter
					output += 'Content-Disposition: attachment; filename="%s"\n' % element.get_file()
					output += "\n\n"
					output += f.get_as_text()
					file_counter+=1
				else:
					printerr("BugReporter could not attach File to Message, Reason: %s" % error_string(FileAccess.get_open_error()))
	
	output += "--boundary--"
	return output


