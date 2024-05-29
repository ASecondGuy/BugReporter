class_name AnalyticsReport


var timestamp:int
var os_name:String
var nodes := {}

func _init(tree:SceneTree):
	timestamp = Time.get_unix_time_from_system()
	os_name = "%s" % OS.get_name()
	for node in tree.get_nodes_in_group("analize"):
		var val := ""
		if node.has_method("analize"):
			val = str(node.analize())
		else:
			val = str(node)
		nodes[node.get_path().get_concatenated_names()] = val

func get_name()->String:
	return ("Report-%s-%s" % [timestamp, os_name]).replace(".", "-")


func _to_string():
	var out := get_name()+ "\n"
	for key in nodes.keys():
		out+= "\n%s\n%s\n" % [key, nodes[key]]
	return out
