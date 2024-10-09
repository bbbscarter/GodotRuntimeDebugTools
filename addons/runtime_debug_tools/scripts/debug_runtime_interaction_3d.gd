extends Node
class_name DebugRuntimeInteraction3D

@onready var _debug_camera := $DebugCamera3D as Camera3D
@onready var _gizmo := $Gizmo3D as Node3D
signal on_object_picked(node) 

var _selected_node : Node
var _is_active = false
var _previous_camera : Camera3D
var _previous_mouse_mode : Input.MouseMode
var _restore_previous_mouse_mode : bool
var _use_only_physics_for_picking = false
var _click_queued := false

var _picker_ignore_nodes := {}
var _camera_pos_set := false
var _gizmo_dist = 3

enum MouseMode { ROTATE, PAN, NONE }
var _mouse_mode := MouseMode.NONE
var _mouse_zoom := 0

@export_range(0, 10, 0.01) var sensitivity : float = 3
@export_range(0, 1000, 0.1) var default_velocity : float = 5
@export_range(0, 10, 0.01) var speed_scale : float = 1.17
@export_range(0.1, 0.9) var slow_down_multiplier : float = 0.3
@export_range(1, 100, 0.1) var boost_speed_multiplier : float = 3.0
@export var max_speed : float = 1000
@export var min_speed : float = 0.2
@onready var _velocity = default_velocity

#---------------------------------------------------------------------------
# API
#----------------------------------------------------------------------------
func select_node(node):
    if node == _selected_node:
        return
    
    _selected_node = node
    if node == null:
        _gizmo.visible = false
        return
    _gizmo.visible = true
    _update_gizmo_pos()

func set_active(on):
    var active_cam := get_viewport().get_camera_3d()

    if on:
        add_child(_debug_camera)
        _debug_camera.visible = on 
    
        if not _is_active:
            _previous_camera = active_cam

        if not _camera_pos_set:
            if _previous_camera:
                _debug_camera.global_position = _previous_camera.global_position
                _debug_camera.global_rotation = _previous_camera.global_rotation
            _camera_pos_set = true
        
        _debug_camera.make_current()

        _previous_mouse_mode = Input.get_mouse_mode()
    else:
        if _previous_camera:
            _previous_camera.make_current()
            _previous_camera = null
        remove_child(_debug_camera)

        _restore_previous_mouse_mode = true;

    _is_active = on
    _update_gizmo_pos()

#---------------------------------------------------------------------------
# lifecycle
#----------------------------------------------------------------------------
func _ready():
    _ignore_nodes(get_parent())
    _debug_camera.current = false
    remove_child(_debug_camera)

func _input(event):
    if not _is_active:
        return
    
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        get_viewport().set_input_as_handled()
        _click_queued = true

func _physics_process(_delta: float) -> void:
    if _click_queued:
        _click_queued = false
        _pick_object()

func _process(delta: float) -> void:

    if get_window().has_focus() and _restore_previous_mouse_mode:
        Input.mouse_mode = _previous_mouse_mode
        _restore_previous_mouse_mode = false;

    if not _is_active:
        return

    var direction = Vector3(
        float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
        float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q)), 
        float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
        ).normalized()

    var step = delta
    if Input.is_physical_key_pressed(KEY_ALT): # slow movement
        step = delta * slow_down_multiplier

    if Input.is_physical_key_pressed(KEY_SHIFT): # boost
        step = delta * boost_speed_multiplier

    if abs(_mouse_zoom) > 0:
        _debug_camera.translate(Vector3.FORWARD*_mouse_zoom * delta)
        _mouse_zoom = 0

    _debug_camera.translate(direction * _velocity * step)
    _update_gizmo_pos()

func _unhandled_input(event: InputEvent) -> void:
    if not _is_active:
        return

    if event is InputEventMouseMotion:
        if _mouse_mode == MouseMode.ROTATE:
            var rotx = (event.relative.x / 1000.0) * sensitivity 
            var roty = (event.relative.y / 1000.0) * sensitivity
            _debug_camera.rotation.y -= rotx
            _debug_camera.rotation.x -= roty
            _debug_camera.rotation.x = clamp(_debug_camera.rotation.x, PI/-2, PI/2)
        elif _mouse_mode == MouseMode.PAN:
            var move_x = _debug_camera.global_basis.x * event.relative.x/1000*sensitivity
            var move_y = _debug_camera.global_basis.y * event.relative.y/1000*sensitivity
            _debug_camera.global_position += move_y - move_x

    if event is InputEventMouseButton:
        match event.button_index:
            MOUSE_BUTTON_RIGHT:
                if event.pressed:
                    _mouse_mode = MouseMode.ROTATE
                else:
                    _mouse_mode = MouseMode.NONE

            MOUSE_BUTTON_MIDDLE:
                if event.pressed:
                    _mouse_mode = MouseMode.PAN
                else:
                    _mouse_mode = MouseMode.NONE
            MOUSE_BUTTON_WHEEL_UP:
                _mouse_zoom += 10
            MOUSE_BUTTON_WHEEL_DOWN:
                _mouse_zoom -= 10
                
    if _mouse_mode != MouseMode.NONE:
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    else: 
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


#---------------------------------------------------------------------------
# internals
#----------------------------------------------------------------------------
func _update_gizmo_pos():
    if _is_active and _selected_node is Node3D:
        _gizmo.visible = true
        # Place the gizmo at a constant distance from the camera, so scaling remains constant.
        var gizmo_pos = _selected_node.global_position
        var gizmo_rot = _selected_node.global_rotation

        var dir = (gizmo_pos - _debug_camera.global_position).normalized()
        var pos = _debug_camera.global_position + (dir * _gizmo_dist)
        _gizmo.global_position = pos
        _gizmo.global_rotation = gizmo_rot
    else:
        _gizmo.visible = false

func _ignore_nodes(parent : Node):
    var node_stack : Array[Node] = []
    node_stack.append(parent)
    while not node_stack.is_empty():
        var node: Node = node_stack.pop_front()
        if not is_instance_valid(node):
            continue
        node_stack.append_array(node.get_children())
        _picker_ignore_nodes[node] = true

#---------------------------------------------------------
# Object picking
#---------------------------------------------------------
var _full_mesh_check_count := 0

func _pick_object():
    # Object picking
    var camera := get_viewport().get_camera_3d()

    var space_state := camera.get_world_3d().direct_space_state
    var mouse_vector2 = get_viewport().get_mouse_position()
    var raycast_origin = camera.project_ray_origin(mouse_vector2)
    var raycast_end = camera.project_position(mouse_vector2, 1000)
    var picked_node = null
    if _use_only_physics_for_picking:
        var query = PhysicsRayQueryParameters3D.create(raycast_origin, raycast_end)
        var intersect = space_state.intersect_ray(query) 

        if intersect and intersect.collider:
            picked_node = intersect.collider

    else:
        var hit_node = _find_nearest_node_instersecting_ray(raycast_origin, raycast_end)
        if hit_node:
            picked_node = hit_node

    on_object_picked.emit(picked_node)


func _find_nearest_node_instersecting_ray(ray_start: Vector3, ray_end: Vector3) -> Node3D:
    var nearest_node : Node3D = null
    var nearest_intersection : Vector3 = ray_end
    _full_mesh_check_count = false

    # First of all, try physics
    var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
    var space_state = _debug_camera.get_world_3d().direct_space_state
    var intersect = space_state.intersect_ray(query) 
    
    if intersect and intersect.collider:
        nearest_node = intersect.collider
        nearest_intersection = intersect.position

    # Then 3D meshes
    var mesh_nodes := get_tree().root.find_children("*", "MeshInstance3D", true, false)
    for mesh_node : MeshInstance3D in mesh_nodes:
        if not mesh_node.visible or mesh_node.mesh == null or mesh_node in _picker_ignore_nodes:
            continue
        var intersection = _get_mesh_ray_intersection(ray_start, ray_end, mesh_node.mesh, mesh_node.global_transform, nearest_intersection)
        if intersection:
            nearest_intersection = intersection
            nearest_node = mesh_node

    # Then grid nodes
    var grid_map_nodes := get_tree().root.find_children("*", "GridMap", true, false)
    for grid_map_node : GridMap in grid_map_nodes:
        if not grid_map_node.visible:
            continue

        var grid_meshes = grid_map_node.get_meshes()
        for grid_map_idx in range(0, grid_meshes.size(), 2):
            var mesh := grid_meshes[grid_map_idx+1] as Mesh
            var transform := grid_meshes[grid_map_idx] as Transform3D
            var mesh_transform = grid_map_node.global_transform * transform

            var intersection = _get_mesh_ray_intersection(ray_start, ray_end, mesh, mesh_transform, nearest_intersection)
            if intersection:
                nearest_intersection = intersection
                nearest_node = grid_map_node
                break

    #print("Tri intersections done: %d" %_full_mesh_check_count)
    return nearest_node
            
func _get_mesh_ray_intersection(
        ray_start: Vector3, ray_end: Vector3, mesh: Mesh, transform: Transform3D, current_best_intersection: Vector3):
    var inverse_transform := transform.affine_inverse()
    var local_ray_start := inverse_transform * ray_start
    var local_ray_end := inverse_transform * ray_end
    var local_best_intersection := inverse_transform * current_best_intersection
    var local_ray_dir = local_ray_end - local_ray_start

    var aabb := mesh.get_aabb()
    var aabb_intersect = aabb.intersects_ray(local_ray_start, local_ray_dir)
    if aabb_intersect == null:
        return null
 
    var best_dist = (local_best_intersection - local_ray_start).length_squared()

    var aabb_intersect_dist = (aabb_intersect - local_ray_start).length_squared()

    if aabb_intersect_dist > best_dist:
        return null

    var faces := mesh.get_faces()
    var num_faces := faces.size()
    var found_best_intersection = null

    _full_mesh_check_count += 1
    for idx in range(0, num_faces, 3):
        var tri_intersect = Geometry3D.ray_intersects_triangle(
            local_ray_start, local_ray_dir, faces[idx], faces[idx+1], faces[idx+2])
        if tri_intersect:
            var tri_intersect_dist: float = (tri_intersect - local_ray_start).length_squared()
            # early out if it's near the bounding box dist?
            if tri_intersect_dist < best_dist:
                best_dist = tri_intersect_dist
                found_best_intersection = tri_intersect

    if found_best_intersection != null:
        return transform * found_best_intersection
                
    return null
