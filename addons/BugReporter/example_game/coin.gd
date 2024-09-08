extends Node2D

@onready var player := get_node("/root/Example/Player")


func _process(_delta):
	if player is Node2D:
		if visible and (player.position - position).length() < 40:
			print("Collect Coin %s" % name)
			hide()
