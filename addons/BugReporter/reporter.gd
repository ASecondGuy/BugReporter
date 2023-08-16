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
## If true the log file will be attached
@export var attach_log_file := false
## If true an analytics file will be attached.  
## It will call analize() on every node in the group analize and append the node path and result to the file.
## If the function doesn't exist _to_string() will be used instead.
@export var attach_analytics_file := false

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
		"attachments": []
	}
	
	if attach_log_file:
		request_body.push_back("user://logs/godot.log")
#		json_payload["attachments"].push_back({"id":0})
	if attach_analytics_file:
		request_body.push_back(AnalyticsReport.new(get_tree()))
#		json_payload["attachments"].push_back({"id":int(attach_log_file)})
	
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
					"url" : "attachment://screenshot%s.png" % request_body.size(),
				}
		
		request_body.push_back(_screenshot.texture)
	
	embed["fields"] = fields
	json_payload["embeds"] = [embed]
	
	
	request_body.push_front(json_payload)
	var boundary := "b%s" % floori(Time.get_unix_time_from_system())
	var payload := _array_to_form_data(request_body, boundary)
	
	if fields.is_empty():
		return
	print(payload)
	_http.request(_cfg.get_value("webhook", "url", ""), 
			PackedStringArray(["connection: keep-alive", "Content-type: multipart/form-data; boundary=%s" % boundary]), 
			HTTPClient.METHOD_POST,
			payload
	)
	
	_send_button.disabled = true
	print("BugReporter message send")



func _on_HTTPRequest_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	_send_button.disabled = false
	if hide_after_send:
		hide()
	if clear_after_send:
		_mail.clear()
		$VBox/Message.text = ""
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
			output += JSON.new().stringify(element) + "\n"
			
		elif element is Texture2D:
			output += 'Content-Type: image/png; name="files[%s]"\n' % file_counter
			output += 'Content-Disposition: attachment; filename="screenshot%s.png; "\n' % file_counter
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
						output += 'Content-Type: plain/text; name="files[%s]"\n' % file_counter
						output += 'Content-Disposition: attachment; filename="%s"\n' % element.get_file()
						output += "\n"
						output += file
						file_counter+=1
				else:
					printerr("BugReporter could not attach File to Message, Reason: %s" % error_string(FileAccess.get_open_error()))
		elif element is AnalyticsReport:
			output += 'Content-Type: plain/text; name="files[%s]"\n' % file_counter
			output += 'Content-Disposition: attachment; filename="%s.txt"\n' % element.get_name()
			output += "\n"
			output += str(element)
			file_counter+=1
	
	output += "--%s--" % boundary
	return output


class AnalyticsReport:
	var timestamp:int
	var os_name:String
	var nodes := {}
	
	func _init(tree:SceneTree):
		timestamp = Time.get_unix_time_from_system()
		os_name = "%s-%s" % [OS.get_name(), OS.get_version()]
		for node in tree.get_nodes_in_group("analize"):
			var val := ""
			if node.has_method("analize"):
				val = str(node.analize())
			else:
				val = str(node)
			nodes[node.get_path().get_concatenated_names()] = val
		nodes.make_read_only()
	
	func get_name()->String:
		return ("Report:%s:%s" % [timestamp, os_name]).replace(".", "-")
	
	
	func _to_string():
		var out := get_name()+ "\n"
		for key in nodes.keys():
			out+= "\n%s\n%s\n" % [key, nodes[key]]
		return out

