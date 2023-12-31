extends HTTPRequest

var _request_body := []
var _form_data_array := []
var _json_payload := {}
var _is_embedding := false
var _last_embed := {}
var _last_embed_fields := []

func start_message():
	if get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return ERR_BUSY
	_request_body.clear()
	_json_payload.clear()
	_last_embed.clear()
	_last_embed_fields.clear()
	_form_data_array.clear()
	_form_data_array.push_back(_json_payload)
	_json_payload["attachments"] = []
	return OK


## sets the message username
func set_username(username:String):
	_json_payload["username"] = username

## sets message text to speach
func set_tts(tts:bool):
	_json_payload["tts"] = tts

## sets the message content. The standard discord message text
func set_content(content:String):
	_json_payload["content"]

func start_embed():
	if _is_embedding:
		finish_embed()
	_is_embedding = true

func finish_embed():
	_last_embed["fields"] = _last_embed_fields
	_json_payload["embeds"]
	_is_embedding = false

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
