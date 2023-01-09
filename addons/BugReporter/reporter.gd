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
	var message : String = $VBox/Message.text.replace("```", "")
	var player_id := "playerid: %s" % _unique_user_id()
	
	var data := {
		"username" : "%s:" % _get_game_name(),
		"tts" : _cfg.get_value("webhook", "tts", false),
		"content" : "test content",
		"embeds" : [{
			"title": "%s by %s" % [messagetype, player_id],
			"color": 15258703,
			"fields": [],
		}]
	}
	if !message.empty():
		data["embeds"][0]["fields"].push_back({
				"name" : "Message:",
				"value" : "```\n%s\n```" % message,
			}
	)
	
	var request_body := [data]
	
	if _screenshot_check.pressed:
		data["embeds"][0]["fields"].push_back({
				"name" : "Screenshot:",
				"image" : {
					"url" : "file0.png",
				}
			})
		request_body.push_back(_screenshot.texture)
	
	
	var payload := _array_to_form_data(request_body)
	print(payload)
	
	_http.request(_cfg.get_value("webhook", "url", ""), 
			PoolStringArray(["connection: keep-alive", "Content-Type: multipart/form-data", "Content-Length: %s" % payload.length(), 'boundary="boundary123']), 
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

func _texture_to_png_bytes(texture : Texture, max_size:=1000):
	var img := texture.get_data()
	var bytes : PoolByteArray = img.save_png_to_buffer()
	
	while bytes.size() > max_size:
		img.resize(img.get_width()/2, img.get_height()/2)
		bytes = img.save_png_to_buffer()
	
	return Marshalls.raw_to_base64(bytes)

func _array_to_form_data(array:Array)->String:
	var file_counter := 0
	
	var output = ""
#	output += "--boundary\n"
#	output += 'Content-Disposition: form-data; name="content"\n'
#	output += "message"
	
	for element in array:
		output += "--boundary123\n"
		
		if element is Dictionary:
			output += 'Content-Disposition: form-data; name="payload_json"\nContent-Type: application/json\n'
			output += to_json(element) + "\n"
			
		elif element is Texture:
			output += 'Content-Disposition: form-data; name="files[%s]", filename="file%s.png"' % [file_counter, file_counter]
			output += "\nContent-Type: image/png\n\n"
			output += _texture_to_data_uri(element) + "\n"
			file_counter += 1
	
	output += "--boundary123--"
	
	return output


