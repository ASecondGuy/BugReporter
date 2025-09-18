class_name WebhookBuilder
extends HTTPRequest
## Manages the convoluded stuff about building a webhook request.
##
## This class provides set_* and add_* functions you can use to build your Report.[br]
## set_* functions set a value. So they overwrite the last value.[br]
## add_* functions will add something. 
## If you call them multiple times it will add more.
## Something added by this can't be undone.[br]
## Some set_* functions might use add_* functions internally. 
## Calling them multiple times can lead to unexpected behavour.[br]
## *_embed_* functions work the same but in the scope of one embed.[br][br]
## For example usage see [BugReporter].
## Minimal Example:
## [codeblock]
## if start_message() == OK:
##     set_username("Example User")
##     set_content("This is the example message.")
##     send_message("https://discord.com/api/webhooks/<webhook.id>/<webhook.token>")
## [/codeblock][br]
## Also note, Discord has a few limits that are not all checked by this node.[br]
## - A file limit per message of 8MB. 
##(Images are compressed to at least 6MB each but nothing else. 
## This is usually not a problem with jpgs)[br]
## - Many seperate character limits. (All checked and mentioned where relevant)[br]
## - A shared character limit for all embeds of 6000. (Not checked)[br]
## Especially with many embeds/field it is easy to accidentally 
## get over the shared character limit.


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


#region Whole Message Settings


## Call this before using any other functions. 
## It prepares the node for composing a new message.
## Returns either [constant ERR_BUSY] or [constant OK].
## Wait for [signal message_send_finished] if it returns busy and try again.
func start_message()-> Error:
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
	_file_counter = 0
	return OK


## Sets the message username.[br]
## Character limit is 256.
## This is optional
func set_username(username:String):
	_json_payload["username"] = username.left(256)

## Sets message text to speech.[br]
## This needs to be enabled in discord.
## I don't know why you would want this but I put it here anyway.
func set_tts(tts:bool):
	_json_payload["tts"] = tts

## sets the message content. The standard discord message text.
## content character limit is 2000
func set_content(content:String):
	_json_payload["content"] = content.left(2000)


## Sends the constructed message.
func send_message(url:String):
	finish_embed()
	var boundary := "b%s" % hash(str(Time.get_unix_time_from_system(), _json_payload))
	var payload := _array_to_form_data(_request_body, boundary)
	
	request(url, 
			PackedStringArray(["connection: keep-alive", 
			"Content-type: multipart/form-data; boundary=%s" % boundary
			]), 
			HTTPClient.METHOD_POST,
			payload
	)


## Adds a file attached to the message.[br]
## Returns the file id to be used for refernences.
## The file argument will later be converted by _array_to_form_data()
## this supports loading at paths, converting a texture and a few more.
## Textures will have the path "attachment://screenshot<id>.jpg"
## Files loaded from a path will keep their filename and be treated as plain text
## payload_inject will be added to the file object in the json payload
## this isn't required but can be used 
func add_file(file, payload_inject:={}) -> int:
	var id := _file_counter
	_request_body.push_back(file)
	var json_attach = {"id":id}
	json_attach.merge(payload_inject)
	_json_payload["attachments"].push_back(json_attach)
	_file_counter+=1
	return id


#endregion
#region Embeds


## from this point you can use *_embed_* functions
## there can be up to 8 embeds per message
func start_embed():
	if _is_embedding:
		finish_embed()
	_is_embedding = true


## this will finish up the embed data.[br]
## calling this is optional because both [method start_embed] and [method send_message]
## will call this automatically if an embed is still active.
func finish_embed():
	if _is_embedding:
		if !_last_embed_fields.is_empty():
			_last_embed["fields"] = _last_embed_fields
		_last_embed_fields = []
		if _json_payload.get("embeds") is Array:
			_json_payload["embeds"].push_back(_last_embed)
		else:
			_json_payload["embeds"] = [_last_embed]
		_last_embed = {}
		_is_embedding = false


## Adds a field to the embed. Fields are a small section of header and text in the embed.[br]
## They appear after the embed description and title but above the embed image.[br]
## Character limit for [param field_name] is 256 and 1024 for [param field_value].[br]
## [param field_inline] will display the field to the right of the last field.[br]
## There can only be up to 25 fields per embed.
func add_embed_field(field_name:String, field_value:String, field_inline:=false):
	_last_embed_fields.push_back({
		"name":field_name.left(256),
		"value":field_value.left(1024),
		"inline":field_inline,
	})


## Sets the embed image to [param image]. The image appears large at the bottom of the embed.[br]
## This will also add it as a file!
## If you want to use a link, use [method set_embed_image_url] instead.
func set_embed_image(image:Texture2D):
	if is_instance_valid(image):
		set_embed_image_url("attachment://screenshot%s.jpg" % add_file(image))
	else:
		push_warning("Embed image invalid")


## Sets the embed image with a url.
## The image appears large at the bottom of the embed.[br]
## This can be any url. Including [code]"attachment://screenshot1.jpg"[/code].[br]
## If you want to use a texture use [method set_embed_image] instead.
func set_embed_image_url(image_url:String):
	_last_embed["image"] = {
				"url" : image_url,
		}


## Sets the embed's thumbnail with a texture.
## The image appears large in the top right corner of the embed.[br]
## If you want to use a link, use [method set_embed_thumbnail_url] instead.
func set_embed_thumbnail(image:Texture2D):
	if is_instance_valid(image):
		set_embed_thumbnail_url("attachment://screenshot%s.jpg" % add_file(image))
	else:
		push_warning("Embed thumbnail image invalid")


## Sets the embed's thumbnail with a url.
## The image appears large in the top right corner of the embed.[br]
## This can be any url. Including [code]"attachment://screenshot1.jpg"[/code].[br]
## If you want to use a texture, use [method set_embed_thumbnail] instead.
func set_embed_thumbnail_url(image_url:String):
	_last_embed["thumbnail"] = {
				"url" : image_url,
		}


## The Footer is the bottom most element of the embed.
## This text appears between the footer icon and the timestamp.
## Footer text character limit is 2048.
## See also: [method set_embed_footer_icon]
## [method set_embed_footer_icon] [method set_embed_timestamp]
func set_embed_footer_text(text:String):
	if _last_embed.get("footer") is Dictionary:
		_last_embed["footer"]["text"] = text.left(2048)
	else:
		_last_embed["footer"] = {
			"text" : text.left(2048)
		}


## The Footer is the bottom most element of the embed.
## This icon appears at the footers left side.[br]
## This function sets the icon using a Texture.
## If you want to use a link, use [method set_embed_footer_icon_url] instead.
## See also: [method set_embed_footer_text] [method set_embed_footer_icon_url]
## [method set_embed_timestamp]
func set_embed_footer_icon(image:Texture2D):
	if is_instance_valid(image):
		set_embed_footer_icon_url("attachment://screenshot%s.jpg" % add_file(image))
	else:
		push_warning("Embed footer image invalid")


## The Footer is the bottom most element of the embed.
## This icon appears at the footers left side.[br]
## This function sets the icon using a url.
## If you want to use a Texture, use [method set_embed_footer_icon_url] instead.
## See also: [method set_embed_footer_text] [method set_embed_footer_icon]
## [method set_embed_timestamp]
func set_embed_footer_icon_url(image_url:String):
	if _last_embed.get("footer") is Dictionary:
		_last_embed["footer"]["icon_url"] = image_url
	else:
		_last_embed["footer"] = {
			"icon_url" : image_url
		}


## Sets the color of the embed.[br]
## This only affects the border of the left side.
## The function supports Discords own 24bit integer encoding, 
## color names from Godot, and any [Color] Object.
func set_embed_color(color):
	if color is int:
		_last_embed["color"] = color
	else:
		if color is String:
			color = Color(color)
		if color is Color:
			_last_embed["color"] = color.b8 + (color.g8 << 8) + (color.r8 << 16)

## Sets the embed's title. The title is at the very top
## and a little bigger than the headers of fields.
## Character limit is 256.
func set_embed_title(title:String):
	_last_embed["title"] = title.left(256)


## The Timestamp appears in the footer to the right of 
## the footer icon and footer text.[br]
## Use -1 to set it to current system time. This function only supports Unix timestamp.
## Discord itself only supports ISO8601 timestamp. This function converts it automatically.[br]
## See also: [method set_embed_footer_text] [method set_embed_footer_icon]
## [method set_embed_footer_icon] [method set_embed_timestamp]
func set_embed_timestamp(stamp:int=-1):
	if stamp == -1:
		stamp = floori(Time.get_unix_time_from_system())
	_last_embed["timestamp"] = Time.get_datetime_string_from_unix_time(stamp)


## Embed description character limit is 4096.
## (That is more than the standart messages 2000 characters)[br]
## The description is right below the embeding title. 
func set_embed_description(description:String):
	_last_embed["description"] = description.left(4096)


#endregion
#region Helper functions

# Converts a texture into the corresponding bytes but limited to a max size.[br]
# This is important because uncompressed images will easily exceed the discord size limit.[br]
# This function will downsize the file until it fits.
func _texture_to_png_bytes(texture : Texture2D, max_size:=600000)->PackedByteArray:
	var img := texture.get_image()
	var bytes : PackedByteArray = img.save_png_to_buffer()
	
	while bytes.size() > max_size:
		img.resize(img.get_width()/2, img.get_height()/2)
		bytes = img.save_png_to_buffer()
	
	return bytes


# Converts a texture into the corresponding bytes but limited to a max size.[br]
# This is important because uncompressed images will easily exceed the discord size limit.[br]
# This function will downsize the file until it fits.
func _texture_to_jpg_bytes(texture : Texture2D, max_size:=600000)->PackedByteArray:
	var img := texture.get_image()
	var bytes : PackedByteArray = img.save_jpg_to_buffer()
	
	while bytes.size() > max_size:
		img.resize(img.get_width()/2, img.get_height()/2)
		bytes = img.save_jpg_to_buffer()
	
	return bytes


# Converts an [Array] of [Variant] into the closest multipart form data equivalent. 
# This is not a general converter to formdata but a very specific implementation for this usecase.
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
	# this is the function internal counter how many files have already been parsed
	# Don't confuse with _file_counter that counts how many files were already added to the message
	var file_counter := 0 
	var output = ""
	
	for element in array:
		output += "--%s\n" % boundary
		
		if element is Dictionary:
			output += 'Content-Disposition: form-data; name="payload_json"\nContent-Type: application/json\n\n'
			output += JSON.new().stringify(element, "	") + "\n"
			
		elif element is Texture2D:
			output += 'Content-Type: image/jpg\n'
			output += 'Content-Disposition: attachment; filename="screenshot%s.jpg"; name="files[%s]";\n' % [file_counter, file_counter]
			output += 'Content-Transfer-Encoding: base64\nX-Attachment-Id: f_ljiz6nfz0\nContent-ID: <f_ljiz6nfz0>'
			output += "\n\n"
			output += Marshalls.raw_to_base64(_texture_to_jpg_bytes(element)) + "\n"
			file_counter += 1
		elif element is String:
			if element.is_absolute_path():
				var f := FileAccess.open(element, FileAccess.READ)
				if FileAccess.get_open_error() == OK:
					var file := f.get_as_text()
					f.close()
					output += 'Content-Type: plain/text"\n'
					output += 'Content-Disposition: attachment; filename="%s"; name="files[%s]";\n' % [element.get_file(), file_counter]
					output += "\n"
					output += file + "\n"
				else:
					output += "File %s could not be attached" % element
					printerr("BugReporter could not attach File %s to Message, Reason: %s" % [element, error_string(FileAccess.get_open_error())])
				file_counter+=1
		elif element is AnalyticsReport:
			output += 'Content-Type: plain/text\n'
			output += 'Content-Disposition: attachment; filename="%s.txt"; name="files[%s]"\n' % [element.get_name(), file_counter]
			output += "\n"
			output += str(element) + "\n"
			file_counter+=1
		else:
			output += "Element %s could not be attached" % element
			printerr("BugReporter can not attach Element %s" % element)
	
	output += "--%s--" % boundary
	return output


#endregion


func _on_request_completed(result, response_code, _headers, _body):
	if result == RESULT_SUCCESS:
		message_send_success.emit()
	else:
		message_send_failed.emit()
	message_send_finished.emit()
