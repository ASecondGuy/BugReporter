extends WindowDialog

## The text on the first page
export(String, MULTILINE) var greeting := "Thank you for playing.\nPlease consider taking this survey."
## The Text on the last page
export(String, MULTILINE) var goodbye := "Thank you for taking part in this survey.\nYou can still change your answers now or send them."
## The survey data. Put your questions and answers here. Can also be a translation key
export(String, MULTILINE) var survey := ""
## go to the next page when an answer is given
export var auto_advance := true
export var cfg_path := "res://addons/BugReporter/webhook.cfg"

var _cfg : ConfigFile

onready var _question_label = $Margin/Main/QuestionLabel
onready var _answers = $Margin/Main/Answers
onready var _back_btn = $Margin/Main/NavButtons/BackBtn
onready var _progress_bar = $Margin/Main/NavButtons/ProgressBar
onready var _next_btn = $Margin/Main/NavButtons/NextBtn
onready var _skip_btn = $Margin/Main/SkipBtn
onready var _webhook : WebhookBuilder = $WebhookBuilder

## the questions that get displayed
var questions := []
## indexes of the questions that can't be skipped
var required := []
## the answers displayed for each question
var options := []
## idx of the given answer for each question (-1 for skipped)
var answered := []

## pages are -1 for the start page. 0-x for the questions (one each) and x+1 for the send page.
var page_idx := -1
var _answer_group : ButtonGroup

func _ready():
	get_close_button().connect("pressed", self, "_on_close_requested")
	_reload_cfg()
	reset()
	change_page(-1)
	call_deferred("popup_centered")


func _reload_cfg():
	_cfg = ConfigFile.new()
	var err := _cfg.load(cfg_path)
	if err != OK:
		push_error("Bugreporter couldn't load config. Reason: %s" % err)


## reload the survey string
func reset():
	questions.clear()
	required.clear()
	options.clear()
	answered.clear()
	page_idx = -1
	var lines : Array = tr(survey).split("\n")
	# ignore indentation
	for i in range(lines.size()):
		lines[i] = lines[i].strip_edges()
	# ignore empty lines and lines that start with #
	for i in range(lines.size()-1, -1, -1):
		if lines[i].empty() or lines[i].begins_with("#"):
			lines.remove(i)
		
	
	for line in lines:
		if line.begins_with("?") or line.begins_with("!"):
			if line.begins_with("!"):
				required.push_back(options.size()) # save index of required question
			questions.push_back(line.trim_prefix("?").trim_prefix("!").strip_edges())
			options.push_back([])
		else:
			if options.size() > 0:
				options[-1].push_back(line)
	
	answered.resize(questions.size())
	answered.fill(-1)


## handles everything so the right stuff is displayed
func change_page(to_idx:=0):
	_back_btn.disabled = to_idx < 0
	_next_btn.text = "Next" if to_idx < questions.size() else "Send"
	_skip_btn.visible = to_idx > -1 and to_idx < questions.size() and !to_idx in required
	_progress_bar.value = clamp(to_idx, 0, questions.size())/float(questions.size())
	if to_idx in required:
		_next_btn.disabled = answered[to_idx] == -1
	else:
		_next_btn.disabled = false
	
	if is_instance_valid(_answer_group):
		# current page is a question and the answer must be saved.
		if is_instance_valid(_answer_group.get_pressed_button()):
			answered[page_idx] = _answer_group.get_pressed_button().get_index()
		else:
			answered[page_idx] = -1 # clear when skip
		_clear_anser_buttons()
	_answer_group = null
	if to_idx == -1:
		# -1 is the start page not a question
		_question_label.text = greeting
	elif to_idx == questions.size():
		# this is the last page for sending not a question
		_question_label.text = goodbye
	elif to_idx > questions.size():
		# a larger index means a send request
		_send()
		close(true)
		return # in this case we don't want to change the page_idx
	else:
		# this are the question pages
		_question_label.text = questions[to_idx]
		_answer_group = ButtonGroup.new()
		# make the answer buttons
		var buttons := []
		for a in options[to_idx]:
			var btn := Button.new()
			btn.text = a
			btn.group = _answer_group
			btn.toggle_mode = true
			# connect auto advance
			if auto_advance:
				btn.connect("pressed", self, "change_page", [to_idx+1])
			else:
				# if required unlock next button. Only needed without auto advance
				if to_idx in required:
					btn.connect("pressed", _next_btn, "set", ["disabled", false])
			_answers.add_child(btn)
			buttons.push_back(btn)
		if answered[to_idx] != -1:
			# select the previously used button
			buttons[answered[to_idx]].pressed = true
	
	page_idx = to_idx


func _clear_anser_buttons():
	for c in _answers.get_children():
		c.queue_free()


## hides and removes the scene. Removal is only when webhook is not busy.
## Removal is retried every 10s should succeed at first retry.
func close(no_free:=false):
	hide()
	if _webhook.get_http_client_status() != 0 and !no_free:
		# don't free if busy
		queue_free()
	else:
		hide()
		# try again after 10s
		get_tree().create_timer(10).connect("timeout", self, "close")


func _send():
	_webhook.start_message()
	# message settings
	_webhook.set_username("%s:" % _cfg.get_value("webhook", "game_name", "unnamed_game"))
	_webhook.set_tts(_cfg.get_value("webhook", "tts", false))
	
	_webhook.start_embed()
	_webhook.set_embed_title("Survey:")
	_webhook.set_embed_color(_cfg.get_value("webhook", "color", 15258703))
	
	
	var text_parts := []
	for i in range(questions.size()):
		if answered[i] != -1:
			text_parts.push_back(
				"%s:\n	%s" % [questions[i], options[i][answered[i]]]
			)
	var survey_text := '```' + "\n\n".join(text_parts) + '```'
	_webhook.set_embed_description(survey_text)
	_webhook.add_embed_field("Answer idx as csv:", "```%s```" % ",".join(answered))
	_webhook.send_message(_cfg.get_value("webhook", "url", ""))
	print("BugReporter survey send")


func _on_back_btn_pressed():
	change_page(page_idx-1)


func _on_next_btn_pressed():
	change_page(page_idx+1)


func _on_close_requested():
	close()


func _on_webhook_builder_request_completed(result, response_code, headers, body):
	if ![200, 204].has(response_code):
		printerr("BugReporter Error sending Report. Result: %s Responsecode: %s Body: %s" % [result, response_code, body.get_string_from_ascii()])


func _on_webhook_builder_message_send_success():
	print("Bugreporter survey send success")


func _on_skip_btn_pressed():
	if is_instance_valid(_answer_group):
		if is_instance_valid(_answer_group.get_pressed_button()):
			_answer_group.get_pressed_button().pressed = false
	change_page(page_idx+1)
