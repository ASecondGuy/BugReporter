extends Window

@export_multiline var survey := ""
## go to the next page when an answer is given
@export var auto_advance := true
@export var cfg_path := "res://addons/BugReporter/webhook.cfg"

var _cfg : ConfigFile

@onready var _question_label = $Margin/Main/QuestionLabel
@onready var _answers = $Margin/Main/Answers
@onready var _back_btn = $Margin/Main/NavButtons/BackBtn
@onready var _progress_bar = $Margin/Main/NavButtons/ProgressBar
@onready var _next_btn = $Margin/Main/NavButtons/NextBtn
@onready var _webhook : WebhookBuilder = $WebhookBuilder

var questions := [] # the questions displayed
var options := [] # the answers displayed for each question
var answered := [] # idx of the given answer for each question

var page_idx := -1
var answer_group : ButtonGroup

func _ready():
	_reload_cfg()
	reset()
	change_page(-1)
	popup_centered()


func _reload_cfg():
	_cfg = ConfigFile.new()
	var err := _cfg.load(cfg_path)
	if err != OK:
		push_error("Bugreporter couldn't load config. Reason: %s" % error_string(err))



func reset():
	questions.clear()
	options.clear()
	answered.clear()
	page_idx = -1
	var lines : Array = survey.split("\n")
	# ignore indentation
	lines = lines.map(func(s): return s.strip_edges())
	# ignore empty lines and lines that start with #
	lines = lines.filter(
		func(s:String): return !s.is_empty() and !s.begins_with("#")
		)
	
	for line in lines:
		if line.begins_with("?"):
			questions.push_back(line.trim_prefix("?").strip_edges())
			options.push_back([])
		else:
			options[-1].push_back(line)
	
	answered.resize(questions.size())
	answered.fill(-1)



func change_page(to_idx:=0):
	_back_btn.disabled = to_idx < 0
	_next_btn.text = "Next" if to_idx < questions.size() else "Send"
	_progress_bar.value = clampf(to_idx, 0, questions.size())/questions.size()
	if is_instance_valid(answer_group):
		# current page is a question and the answer must be saved.
		if is_instance_valid(answer_group.get_pressed_button()):
			answered[page_idx] = answer_group.get_pressed_button().get_index()
		_clear_anser_buttons()
	answer_group = null
	if to_idx == -1:
		# -1 is the start page not a question
		_question_label.text = "Thank you for playing. \n Please consider taking this survey."
	elif to_idx == questions.size():
		# this is the last page for sending not a question
		_question_label.text = "Thank you for taking this survey. \n You can still change your answers or send them."
	elif to_idx > questions.size():
		# a larger index means a send request
		_send()
		close(true)
		return # in this case we don't want to change the page_idx
	else:
		# this are the question pages
		_question_label.text = questions[to_idx]
		answer_group = ButtonGroup.new()
		# make the answer buttons
		for a in options[to_idx]:
			var btn := Button.new()
			btn.text = a
			btn.button_group = answer_group
			btn.toggle_mode = true
			if auto_advance:
				btn.pressed.connect(change_page.bind(to_idx+1))
			_answers.add_child(btn)
		if answered[to_idx] != -1:
			# select the previously used button
			answer_group.get_buttons()[answered[to_idx]].button_pressed = true
	
	page_idx = to_idx


func _clear_anser_buttons():
	for c in _answers.get_children():
		c.queue_free()


func close(no_free:=false):
	hide()
	if _webhook.get_http_client_status() != 0 and !no_free:
		# don't free if busy
		queue_free()
	else:
		hide()
		# try again after 10s
		get_tree().create_timer(10).timeout.connect(close)


func _send():
	_webhook.start_message()
	# message settings
	_webhook.set_username("%s:" % _cfg.get_value("webhook", "game_name", "unnamed_game"))
	_webhook.set_tts(_cfg.get_value("webhook", "tts", false))
	
	_webhook.start_embed()
	_webhook.set_embed_title("Survey:")
	_webhook.set_embed_color(_cfg.get_value("webhook", "color", 15258703))
	
	var survey_text := '```' + "\n\n".join(
			PackedStringArray(
				range(questions.size()).filter(
					func(i): return answered[i] != -1
				).map(
					func(i): return "%s:\n	%s" % [questions[i], options[i][answered[i]]]
				)
			)
		) + '```'
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

