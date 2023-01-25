extends PanelContainer

const CFG_PATH := "res://addons/BugReporter/webhook.cfg"

var _cfg : ConfigFile

onready var _screenshot := $VBox/TextureRect
onready var _screenshot_check = $VBox/CheckBox
onready var _mail : LineEdit = $VBox/Mail/LineEdit
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
	var message : String = $VBox/Message.text.replace("```", "")
	var player_id := "playerid: %s" % _unique_user_id()
	var contact_info := _mail.text.dedent()
	
	var request_body := []# 1st place is reserved for json_payload
	var json_payload := {
		"username" : "%s:" % _get_game_name(),
		"tts" : _cfg.get_value("webhook", "tts", false),
	}
	var embed = {
			"title": "%s by %s" % [messagetype, player_id],
			"color": 15258703,
		}
	var fields := []
	
	if !contact_info.empty():
		fields.push_back({
				"name" : "Contact Info:",
				"value" : contact_info
		})
	
	if !message.empty():
		fields.push_back({
				"name" : "Message:",
				"value" : "```\n%s\n```" % message,
			}
	)
	
	
	if _screenshot_check.pressed:
		embed["image"] = {
					"url" : "attachment://file0.png",
				}
		
		request_body.push_back(_screenshot.texture)
	
	embed["fields"] = fields
	json_payload["embeds"] = [embed]
	
	request_body.push_back(json_payload)
	var payload := _array_to_form_data(request_body)
	
	if fields.empty():
		return
	
	_http.request(_cfg.get_value("webhook", "url", ""), 
			PoolStringArray(["connection: keep-alive", "Content-type: multipart/form-data; boundary=boundary"]), 
			true, 
			HTTPClient.METHOD_POST,
			payload
	)



func _on_HTTPRequest_request_completed(result, response_code, headers, body):
	prints(result, response_code, "headers", body.get_string_from_ascii())



func _unique_user_id() -> String:
	return str(hash(str(OS.get_unique_id(), "|", _get_game_name())))


func _get_game_name():
	return _cfg.get_value("webhook", "game_name", "unnamed_game")


func _texture_to_data_uri(texture : Texture):
	return "data:image/png;base64,%s" % _texture_to_png_bytes(texture)


func _texture_to_png_bytes(texture : Texture, max_size:=8000000):
	var img := texture.get_data()
	var bytes : PoolByteArray = img.save_png_to_buffer()
	
	while bytes.size() > max_size:
		img.resize(img.get_width()/2, img.get_height()/2)
		bytes = img.save_png_to_buffer()
	
	return Marshalls.raw_to_base64(bytes)


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
			output += to_json(element) + "\n"
			
		elif element is Texture:
			output += 'Content-Disposition: form-data; name="files[%s]", filename="file%s.png"' % [file_counter, file_counter]
			output += "\nContent-Type: image/png\n\n"
			output += _texture_to_data_uri(element) + "\n"
			file_counter += 1
	
	output += "--boundary--"
	
	return output


