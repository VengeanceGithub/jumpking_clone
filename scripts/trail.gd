extends Line2D
class_name Trails
@onready var player: CharacterBody2D = $".."
 
var queue : Array
@export var MAX_LENGTH : int
 
func _process(_delta):
	add_point(get_parent().global_position)
	if points.size() > 30:
		remove_point(0)
