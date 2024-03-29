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
## The Text edit containing the player message
@export var _message_text : TextEdit
## The LineEdit for player contact information
@export var _mail_line_edit : LineEdit
## The OptionButton to choose the kind of message
@export var _options : OptionButton
## Screenshot attachment button
@export var _screenshot_check : Button
## Screenshot viewer
@export var _screenshot : TextureRect
## Button to attach analytics
@export var _analytics_button : Button 
## Button to send Bugreport
@export var _send_button : Button

var _cfg : ConfigFile


@onready var _http : WebhookBuilder = $WebhookBuilder


func _ready():
	_reload_cfg()
	_http.message_send_finished.connect(_send_button.set.bind("disabled", false))

func _reload_cfg():
	_cfg = ConfigFile.new()
	var err := _cfg.load(cfg_path)
	if err != OK:
		push_error("Bugreporter couldn't load config. Reason: %s" % error_string(err))
	if is_instance_valid(_analytics_button):
		_analytics_button.visible = _cfg.get_value("webhook", "send_log", false) or _cfg.get_value("webhook", "send_analytics", false)


func _input(event):
	if event.is_action("screenshot") and event.is_pressed() and !event.is_echo():
		var img := get_viewport().get_texture().get_image()
		var text := ImageTexture.create_from_image(img)
		_screenshot.texture = text
		_screenshot_check.disabled = false


func _on_SendButton_pressed():
	var analytics := false
	if is_instance_valid(_analytics_button): analytics = _analytics_button.button_pressed
	
	if _http.start_message() == OK:
		send_report( 
			bool(_cfg.get_value("webhook", "send_log", false)) and analytics,
			bool(_cfg.get_value("webhook", "send_analytics", false)) and analytics
		)
		if clear_after_send:
			clear()
		if hide_after_send:
			hide()


func send_report(attach_log_file:=false, attach_analytics_file:=false):
	
	# find player id
	var player_id := "playerid: %s" % _unique_user_id()
	if _cfg.get_value("webhook", "anonymous_players", false):
		player_id = "anonymous"
	
	# message settings
	_http.set_username("%s:" % _get_game_name())
	_http.set_tts(_cfg.get_value("webhook", "tts", false))
	
	# attach files
	if attach_log_file:
		_http.add_file("user://logs/godot.log")
	if attach_analytics_file:
		_http.add_file(AnalyticsReport.new(get_tree()))
	
	# embed basics
	_http.start_embed()
	_http.set_embed_title("%s by %s" % [_options.text, player_id])
	_http.set_embed_color(_cfg.get_value("webhook", "color", 15258703))
	
	# add contact
	var contact_info := _mail_line_edit.text
	if !contact_info.is_empty():
		_http.add_field("Contact Info:", contact_info)
	
	# add message
	var message = _message_text.text.replace("```", "")
	if !message.is_empty():
		_http.add_field("Message:", message)
	
	# add screenshot
	if _screenshot_check.button_pressed:
		_http.set_embed_image(_screenshot.texture)
	
	
	
	_send_button.disabled = true
	_http.send_message(_cfg.get_value("webhook", "url", ""))
	print("BugReporter message send")

func clear():
	_message_text.clear()
	


func _on_HTTPRequest_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	_send_button.disabled = false
	if hide_after_send:
		hide()
	if clear_after_send:
		clear()
	if ![200, 204].has(response_code):
		printerr("BugReporter Error sending Report. Result: %s Responsecode: %s Body: %s" % [result, response_code, body.get_string_from_ascii()])


func _unique_user_id() -> String:
	if OS.get_name() == "Web":
		return "Webuser"
	return str(hash(str(OS.get_unique_id(), "|", _get_game_name())))

func _get_game_name():
	return _cfg.get_value("webhook", "game_name", "unnamed_game")


## Converts a texture into the corresponding bytes but limited to a max size
func _texture_to_png_bytes(texture : Texture2D, max_size:=8000)->PackedByteArray:
	var img := texture.get_image()
	var bytes : PackedByteArray = img.save_png_to_buffer()
	
	while bytes.size() > max_size:
		img.resize(img.get_width()/2, img.get_height()/2)
		bytes = img.save_png_to_buffer()
	
	return bytes


## converts an array of [Variant] into the closest multipart form data equivalent. 
func _array_to_form_data(array:Array, boundary:="boundary")->String:
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
		output += "--%s\n" % boundary
		
		if element is Dictionary:
			output += 'Content-Disposition: form-data; name="payload_json"\nContent-Type: application/json\n\n'
			output += JSON.new().stringify(element, "	") + "\n"
			
		elif element is Texture2D:
			output += 'Content-Type: image/png\n'
			output += 'Content-Disposition: attachment; filename="screenshot%s.png"; name="files[%s]";\n' % [file_counter, file_counter]
			output += 'Content-Transfer-Encoding: base64\nX-Attachment-Id: f_ljiz6nfz0\nContent-ID: <f_ljiz6nfz0>'
			output += "\n\n"
			output += Marshalls.raw_to_base64(_texture_to_png_bytes(element)) + "\n"
			file_counter += 1
		elif element is String:
			if element.is_absolute_path():
				var f := FileAccess.open(element, FileAccess.READ)
				if FileAccess.get_open_error() == OK:
					var file := f.get_as_text()
					f.close()
					if !file.is_empty():
						output += 'Content-Type: plain/text"\n'
						output += 'Content-Disposition: attachment; filename="%s"; name="files[%s]";\n' % [element.get_file(), file_counter]
						output += "\n"
						output += file
				else:
					printerr("BugReporter could not attach File %s to Message, Reason: %s" % [element, error_string(FileAccess.get_open_error())])
				file_counter+=1
		elif element is AnalyticsReport:
			output += 'Content-Type: plain/text\n'
			output += 'Content-Disposition: attachment; filename="%s.txt"; name="files[%s]"\n' % [element.get_name(), file_counter]
			output += "\n"
			output += str(element)
			file_counter+=1
	
	output += "--%s--" % boundary
	return output



