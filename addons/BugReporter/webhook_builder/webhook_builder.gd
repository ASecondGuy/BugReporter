class_name WebhookBuilder
extends HTTPRequest

signal message_send_finished
signal message_send_failed
signal message_send_success


var _request_body := []
var _form_data_array := []
var _json_payload := {}
var _is_embedding := false
var _last_embed := {}
var _last_embed_fields := []
var _file_counter := 0

func start_message():
	if get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return ERR_BUSY
	_request_body.clear()
	_json_payload.clear()
	_request_body.push_back(_json_payload)
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


## adds a file attached to the message
## returns the file id to be used for refernences
## the file argument will later be converted by _array_to_form_data()
## this supports loading at paths, converting a texture and a few more.
func add_file(file, payload_inject:={}) -> int:
	var id := _file_counter
	_request_body.push_back(file)
	var json_attach = {"id":id}
	json_attach.merge(payload_inject)
	_json_payload["attachments"].push_back(json_attach)
	_file_counter+=1
	return id

func start_embed():
	if _is_embedding:
		finish_embed()
	_is_embedding = true

func finish_embed():
	if _is_embedding:
		_last_embed["fields"] = _last_embed_fields
		if _json_payload.get("embeds") is Array:
			_json_payload["embeds"].push_back(_last_embed)
		else:
			_json_payload["embeds"] = [_last_embed]
		_is_embedding = false

func add_field(field_name:String, field_value:String, field_inline:=false):
	_last_embed_fields.push_back({"name":field_name, "value":field_value, "inline":field_inline})

func set_embed_image(image:Texture):
	_last_embed["image"] = {
				"url" : "attachment://screenshot%s.png" % add_file(image),
		}

func set_embed_thumbnail(image:Texture):
	_last_embed["thumbnail"] = {
				"url" : "attachment://screenshot%s.png" % add_file(image),
		}


func set_embed_color(color:int):
	_last_embed["color"] = color

func set_embed_title(title:String):
	_last_embed["title"] = title


## Converts a texture into the corresponding bytes but limited to a max size
func _texture_to_png_bytes(texture : Texture, max_size:=8000)->PoolByteArray:
	var img := texture.get_data()
	var bytes : PoolByteArray = img.save_png_to_buffer()
	
	while bytes.size() > max_size:
		img.resize(img.get_width()/2, img.get_height()/2)
		bytes = img.save_png_to_buffer()
	
	return bytes

## Converts a texture into the corresponding bytes but limited to a max size
func _texture_to_jpg_bytes(texture : Texture, max_size:=8000)->PoolByteArray:
	var img := texture.get_data()
	var bytes : PoolByteArray = img.save_jpg_to_buffer()
	
	while bytes.size() > max_size:
		img.resize(img.get_width()/2, img.get_height()/2)
		bytes = img.save_jpg_to_buffer()
	
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
			output += to_json(element) + "\n"
			
		elif element is Texture:
			output += 'Content-Type: image/png\n'
			output += 'Content-Disposition: attachment; filename="screenshot%s.png"; name="files[%s]";\n' % [file_counter, file_counter]
			output += 'Content-Transfer-Encoding: base64\nX-Attachment-Id: f_ljiz6nfz0\nContent-ID: <f_ljiz6nfz0>'
			output += "\n\n"
			output += Marshalls.raw_to_base64(_texture_to_png_bytes(element)) + "\n"
			file_counter += 1
		elif element is String:
			if element.is_absolute_path():
				var f := File.new()
				f.open(element, File.READ)
				var err = f.get_error()
				if err == OK:
					var file := f.get_as_text()
					f.close()
					if !file.empty():
						output += 'Content-Type: plain/text"\n'
						output += 'Content-Disposition: attachment; filename="%s"; name="files[%s]";\n' % [element.get_file(), file_counter]
						output += "\n"
						output += file
				else:
					printerr("BugReporter could not attach File %s to Message, Reason: %s" % [element, err])
				file_counter+=1
		elif element is AnalyticsReport:
			output += 'Content-Type: plain/text\n'
			output += 'Content-Disposition: attachment; filename="%s.txt"; name="files[%s]"\n' % [element.get_name(), file_counter]
			output += "\n"
			output += str(element)
			file_counter+=1
	
	output += "--%s--" % boundary
	return output

## Sends the constructed message
func send_message(url:String):
	finish_embed()
	var boundary := "b%s" % hash(str(Time.get_unix_time_from_system(), _json_payload))
	var payload := _array_to_form_data(_request_body, boundary)
	
	request(url, 
			PoolStringArray(["connection: keep-alive", "Content-type: multipart/form-data; boundary=%s" % boundary]), 
			true,
			HTTPClient.METHOD_POST,
			payload
	)

func _on_request_completed(result, response_code, _headers, _body):
	if result == RESULT_SUCCESS:
		emit_signal("message_send_success")
	else:
		emit_signal("message_send_failed")
	emit_signal("message_send_finished")
