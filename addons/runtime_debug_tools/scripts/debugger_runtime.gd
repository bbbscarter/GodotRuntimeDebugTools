extends Node3D
#class_name RuntimeDebugToolsRuntime

var _is_active := false
var _use_only_physics_for_picking = false
@onready var _camera := $DebugCamera3D as Camera3D
@onready var _active_label := $DebugLabel as Node
@onready var _gizmo := $Gizmo as Node3D

@export_range(0, 10, 0.01) var sensitivity : float = 3
@export_range(0, 1000, 0.1) var default_velocity : float = 5
@export_range(0, 10, 0.01) var speed_scale : float = 1.17
@export_range(1, 100, 0.1) var boost_speed_multiplier : float = 3.0
@export var max_speed : float = 1000
@export var min_speed : float = 0.2

@onready var _velocity = default_velocity

var _gizmo_dist = 3
var _selected_node : Node = null
var _showing_collision_shapes := false
var _picker_ignore_nodes := {}
var _previous_camera : Camera3D
var _camera_pos_set := false

enum MouseMode { ROTATE, PAN, NONE }
var _mouse_mode := MouseMode.NONE
var _mouse_zoom := 0


func _ready():
    _set_active(false)
    EngineDebugger.register_message_capture("remote_inspector", _on_editor_select)

    # Don't let the picker pick the gizmo.
    for n in _gizmo.get_children():
        _picker_ignore_nodes[n] = true

    # Apparently this doesn't do anything at the moment.
    # RenderingServer.set_debug_generate_wireframes(true)


func _on_editor_select(msg, args):
    if msg == "editor_select":
        var node_to_select = instance_from_id(args[0]) as Node3D
        # print("Asked to select node: %s" %args[0])
        _select_node(node_to_select)
        # print("Selected node: %s" %_selected_node)
    elif msg == "debug_enable":
        var enabled = args[0]
        _set_active(enabled)
    elif msg == "render_mode":
        var mode = args[0]
        get_viewport().debug_draw = mode
    elif msg == "show_collision_shapes":
        var mode = args[0]
        _show_collision_shapes(mode)
    
    return true

func _show_collision_shapes(on: bool):
    # taken from https://github.com/godotengine/godot-proposals/issues/2072
    _showing_collision_shapes = on

    var tree := get_tree()
    if tree.debug_collisions_hint == on:
        return

    tree.debug_collisions_hint = on

    # Traverse tree to call queue_redraw on instances of
    # CollisionShape2D and CollisionPolygon2D.
    var node_stack: Array[Node] = [tree.get_root()]
    while not node_stack.is_empty():
        var node: Node = node_stack.pop_back()
        if is_instance_valid(node):

            if node is CollisionShape2D or node is CollisionPolygon2D:
                node.queue_redraw()
            elif node is RayCast3D \
                or node is GridMap \
                or node is CollisionShape3D \
                or node is CollisionPolygon3D \
                or node is CollisionObject3D \
                or node is GPUParticlesCollision3D \
                or node is GPUParticlesCollisionBox3D \
                or node is GPUParticlesCollisionHeightField3D \
                or node is GPUParticlesCollisionSDF3D \
                or node is GPUParticlesCollisionSphere3D:
                # remove and re-add the node to the tree to force a redraw
                # https://github.com/godotengine/godot/blob/26b1fd0d842fa3c2f090ead47e8ea7cd2d6515e1/scene/3d/collision_object_3d.cpp#L39
                var parent: Node = node.get_parent()
                if parent:
                    var was_blocking = parent.is_blocking_signals()
                    parent.set_block_signals(true)
                    parent.remove_child(node)
                    parent.add_child(node)
                    parent.set_block_signals(was_blocking)

            node_stack.append_array(node.get_children()) 

func _select_node(node):
    _selected_node = node
    if node == null:
        _gizmo.visible = false
        return
    _gizmo.visible = true
    _update_gizmo_pos()
        
func _update_gizmo_pos():
    # Place the gizmo at a constant distance from the camera, so scaling remains constant.
    if _selected_node == null:
        return
    var gizmo_pos = _selected_node.global_position
    var gizmo_rot = _selected_node.global_rotation


    var dir = (gizmo_pos - _camera.global_position).normalized()
    var pos = _camera.global_position + (dir * _gizmo_dist)
    _gizmo.global_position = pos
    _gizmo.global_rotation = gizmo_rot
    
func _input(event):
    var key_event = event as InputEventKey

    if key_event and key_event.pressed and key_event.keycode == KEY_F12:
        _set_active(not _is_active)
        
    if not _is_active:
        return
    
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        # Object picking
        get_viewport().set_input_as_handled()
        var camera = get_viewport().get_camera_3d()

        var space_state = get_world_3d().direct_space_state
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

        if picked_node:
            var picked_id = picked_node.get_instance_id()
            _select_node(picked_node)
            EngineDebugger.send_message("remote_inspector:select_id", [picked_id])
        else:
            _select_node(null)

            

func _process(delta: float) -> void:
    var direction = Vector3(
        float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
        float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q)), 
        float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
    ).normalized()
    
    var step = delta
    if Input.is_physical_key_pressed(KEY_SHIFT): # boost
        step = delta * boost_speed_multiplier

    if abs(_mouse_zoom) > 0:
        _camera.translate(Vector3.FORWARD*_mouse_zoom * delta)
        _mouse_zoom = 0
        
    _camera.translate(direction * _velocity * step)
    
    if _mouse_mode != MouseMode.NONE:
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    else: 
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

    _update_gizmo_pos()


func _unhandled_input(event: InputEvent) -> void:
    
    if event is InputEventMouseMotion:
        if _mouse_mode == MouseMode.ROTATE:
            _camera.rotation.y -= event.relative.x / 1000 * sensitivity
            _camera.rotation.x -= event.relative.y / 1000 * sensitivity
            _camera.rotation.x = clamp(_camera.rotation.x, PI/-2, PI/2)
        elif _mouse_mode == MouseMode.PAN:
            var move_x = _camera.global_basis.x * event.relative.x/1000*sensitivity
            var move_y = _camera.global_basis.y * event.relative.y/1000*sensitivity
            _camera.global_position += move_y - move_x
    
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
 

func _set_active(on):
    _gizmo.visible = on
    _active_label.visible = on
    _camera.visible = on

    if on:
        if not _is_active:
            _previous_camera = get_viewport().get_camera_3d()

        if _previous_camera:
            _previous_camera.current = false
            if not _camera_pos_set:
                _camera.global_position = _previous_camera.global_position
                _camera.global_rotation = _previous_camera.global_rotation
                _camera_pos_set = true
    else:
        if _previous_camera:
            _previous_camera.current = true
            _previous_camera = null

        _camera.current = false
        
    _is_active = on

var _full_mesh_check_count := 0

func _find_nearest_node_instersecting_ray(ray_start: Vector3, ray_end: Vector3) -> Node3D:
    var nearest_node : Node3D = null
    var nearest_intersection : Vector3 = ray_end
    _full_mesh_check_count = false

    # First of all, try physics
    var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
    var space_state = get_world_3d().direct_space_state
    var intersect = space_state.intersect_ray(query) 
    
    if intersect and intersect.collider:
        nearest_node = intersect.collider
        nearest_intersection = intersect.position

    # Then 3D meshes
    var mesh_nodes := get_tree().root.find_children("*", "MeshInstance3D", true, false)
    for mesh_node : MeshInstance3D in mesh_nodes:
        if not mesh_node.visible  or mesh_node in _picker_ignore_nodes:
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
    var aabb_intersect := aabb.intersects_ray(local_ray_start, local_ray_dir)
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
        var tri_intersect := Geometry3D.ray_intersects_triangle(
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

    
        

    # var local_ray_start = mesh_node _transform * ray_start
    
     
    

    
