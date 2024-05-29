extends PanelContainer


export var cfg_path := "res://addons/BugReporter/webhook.cfg"
export var hide_after_send := true
export var clear_after_send := true


var _cfg : ConfigFile


onready var _screenshot := $VBox/TextureRect
onready var _screenshot_check = $VBox/CheckBox
onready var _mail : LineEdit = $VBox/Mail/LineEdit
onready var _http := $HTTPRequest
onready var _send_button = $VBox/SendButton
onready var _webhook = $WebhookBuilder


func _ready():
	_cfg = ConfigFile.new()
	var err := _cfg.load(cfg_path)
	if err != OK:
		push_error("Bugreporter couldn't load config. Reason: %s" % err)


func _input(event):
	if event.is_action("screenshot") and event.is_pressed() and !event.is_echo():
		var img := get_viewport().get_texture().get_data()
		img.flip_y()
		var text := ImageTexture.new()
		text.create_from_image(img)
		_screenshot.texture = text
		_screenshot_check.disabled = false



func _on_SendButton_pressed():
	if _webhook.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	_webhook.start_message()
	
	var messagetype := tr($VBox/OptionButton.text)
	var message : String = $VBox/Message.text.replace("```", "")
	var player_id := "playerid: %s" % _unique_user_id()
	if _cfg.get_value("webhook", "anonymous_players", false):
		player_id = "anonymous"
	var contact_info := _mail.text.dedent()
	
	var request_body := []# 1st place is reserved for json_payload
	_webhook.set_username("%s:" % _get_game_name())
	_webhook.set_tts(_cfg.get_value("webhook", "tts", false))
	_webhook.start_embed()
	_webhook.set_embed_title("%s by %s" % [messagetype, player_id])
	_webhook.set_embed_color(_cfg.get_value("webhook", "color", 15258703))
	var fields := []
	
	if !contact_info.empty():
		_webhook.add_field("Contact Info:", contact_info)
	
	if !message.empty():
		_webhook.add_field("Message:", "```\n%s\n```" % message)
	
	
	if _screenshot_check.pressed:
		_webhook.set_embed_image(_screenshot.texture)
	
	
	
	_webhook.send_message(_cfg.get_value("webhook", "url", ""))
	_send_button.disabled = true
	print("BugReporter message send")



func _on_HTTPRequest_request_completed(result, response_code, headers, body):
	_send_button.disabled = false
	if hide_after_send:
		hide()
	if clear_after_send:
		_mail.clear()
		$VBox/Message.text = ""
	if ![200, 204].has(response_code):
		printerr("BugReporter Error sending Report. Result: %s Responsecode: %s Body: %s" % [result, response_code, body.get_string_from_ascii()])


func _unique_user_id() -> String:
	if OS.get_name() == "HTML5":
		return "Webuser"
	return str(hash(str(OS.get_unique_id(), "|", _get_game_name())))

func _get_game_name():
	return _cfg.get_value("webhook", "game_name", "unnamed_game")

func _texture_to_png_bytes(texture : Texture, max_size:=8000000)->PoolByteArray:
	var img := texture.get_data()
	var bytes : PoolByteArray = img.save_png_to_buffer()
	
	while bytes.size() > max_size:
		img.resize(img.get_width()/2, img.get_height()/2)
		bytes = img.save_png_to_buffer()
	
	return bytes


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
			output += 'Content-Type: image/png; name="files[%s]"\n' % file_counter
			output += 'Content-Disposition: attachment; filename="screenshot%s.png"\n' % file_counter
			output += 'Content-Transfer-Encoding: base64\nX-Attachment-Id: f_ljiz6nfz0\nContent-ID: <f_ljiz6nfz0>'
			output += "\n\n"
			output += Marshalls.raw_to_base64(_texture_to_png_bytes(element)) + "\n"
			file_counter += 1
	
	output += "--boundary--"
	return output


