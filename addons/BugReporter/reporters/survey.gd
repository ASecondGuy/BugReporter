extends WindowDialog

export(String, MULTILINE) var survey := ""
## go to the next page when an answer is given
export var auto_advance := true

onready var _question_label = $Margin/Main/QuestionLabel
onready var _answers = $Margin/Main/Answers
onready var _back_btn = $Margin/Main/NavButtons/BackBtn
onready var _progress_bar = $Margin/Main/NavButtons/ProgressBar
onready var _next_btn = $Margin/Main/NavButtons/NextBtn

var questions := [] # the questions displayed
var options := [] # the answers displayed for each question
var answered := [] # idx of the given answer for each question

var page_idx := -1
var answer_group : ButtonGroup

func _ready():
	get_close_button().connect("pressed", self, "close")
	reset()
	change_page(-1)
	popup_centered()


func reset():
	questions.clear()
	options.clear()
	answered.clear()
	page_idx = -1
	var lines : Array = survey.split("\n")
	# ignore indentation
	for i in range(lines.size()):
		lines[i] = lines[i].strip_edges()
	# ignore empty lines and lines that start with #
	for i in range(lines.size()-1, -1, -1):
		if lines[i].empty() or lines[i].begins_with("#"):
			lines.remove(i)
		
	
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
	_progress_bar.value = clamp(to_idx, 0, questions.size())/questions.size()
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
		close()
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
				btn.connect("pressed", self, "change_page", [to_idx+1])
			_answers.add_child(btn)
		if answered[to_idx] != -1:
			# select the previously used button
			answer_group.get_buttons()[answered[to_idx]].button_pressed = true
	
	page_idx = to_idx


func _clear_anser_buttons():
	for c in _answers.get_children():
		c.queue_free()


func close():
	queue_free()


func _send():
	print("sending survey")


func _on_back_btn_pressed():
	change_page(page_idx-1)


func _on_next_btn_pressed():
	change_page(page_idx+1)


func _on_close_requested():
	close()
