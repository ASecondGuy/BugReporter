extends Node2D

@onready var _player = $Player
@onready var _pausemenu = $Pausemenu



func _process(_delta):
	_player.position += Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")


func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if !event.is_echo():
			_pausemenu.visible = !_pausemenu.visible
			set_process(!_pausemenu.visible)


