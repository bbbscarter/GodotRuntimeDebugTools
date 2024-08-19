extends Node3D
@export var degrees_per_sec := 90.0
@export var axis := Vector3.FORWARD


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    rotate_object_local(axis, deg_to_rad(degrees_per_sec) * delta)
