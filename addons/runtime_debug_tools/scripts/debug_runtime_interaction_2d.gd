extends Node
class_name DebugRuntimeInteraction2D

signal on_object_picked(node) 

@onready var _debug_camera := $DebugCamera2D as Camera2D
@onready var _gizmo := $Gizmo2D as Node
#@onready var _label := $"../DebugLabel" as Node

var _is_active = false
var _previous_camera : Camera2D
var _previous_mouse_mode : Input.MouseMode
var _restore_previous_mouse_mode : bool
var _use_only_physics_for_picking = false

var _picker_ignore_nodes := {}
var _camera_pos_set := false
enum MouseMode { NONE, PAN }
var _mouse_mode := MouseMode.NONE
var _selected_node : Node

#---------------------------------------------------------------------------
# API
#----------------------------------------------------------------------------
func set_active(on):
    if _is_active == on:
        return
        
    _debug_camera.visible = on 

    if on:
        var active_cam := get_viewport().get_camera_2d()
        _previous_camera = active_cam

        if not _camera_pos_set:
            if _previous_camera:
                _debug_camera.global_position = _previous_camera.global_position
                _debug_camera.global_rotation = _previous_camera.global_rotation
                _debug_camera.anchor_mode = _previous_camera.anchor_mode
            _camera_pos_set = true
        
        _debug_camera.enabled = true
        _debug_camera.make_current()

        _previous_mouse_mode = Input.get_mouse_mode()
    else:
        if _previous_camera:
            _debug_camera.enabled = false
            _previous_camera.make_current()
            _previous_camera = null

        _restore_previous_mouse_mode = true

    _is_active = on
    _update_gizmo()

func select_node(node):
    if node == _selected_node:
        return
    
    _selected_node = node
    if node == null:
        _gizmo.visible = false
        return
    _gizmo.visible = true
    _update_gizmo()

#---------------------------------------------------------------------------
# lifecycle
#----------------------------------------------------------------------------
func _ready():
    _debug_camera.enabled = false
    _ignore_nodes(get_parent())
    
func _process(_delta: float) -> void:
    
    if get_window().has_focus() and _restore_previous_mouse_mode:
        Input.mouse_mode = _previous_mouse_mode
        _restore_previous_mouse_mode = false;

    if not _is_active:
        return
        
    _update_gizmo()

func _do_mouse_movement(event: InputEvent):
    if event is InputEventMouseMotion:
        if _mouse_mode == MouseMode.PAN:
            get_viewport().set_input_as_handled()
            var move_x = event.relative.x
            var move_y = event.relative.y
            _debug_camera.position += Vector2(-move_x, -move_y) / _debug_camera.zoom

    var new_mouse_mode := _mouse_mode
    var mouse_zoom = _debug_camera.zoom
    if event is InputEventMouseButton:
        get_viewport().set_input_as_handled()
        match event.button_index:
            MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
                if event.pressed:
                    new_mouse_mode = MouseMode.PAN
                else:
                    new_mouse_mode = MouseMode.NONE
            MOUSE_BUTTON_WHEEL_UP:
                mouse_zoom *= 1.1
            MOUSE_BUTTON_WHEEL_DOWN:
                mouse_zoom *= 0.9
                
    if mouse_zoom != _debug_camera.zoom:
        _debug_camera.zoom = mouse_zoom
        
    if _mouse_mode != new_mouse_mode:    
        _mouse_mode = new_mouse_mode  
        if _mouse_mode != MouseMode.NONE:
            Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)

        else: 
            Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
        
func _input(event):
    if not _is_active:
        return

    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _pick_object()
    _do_mouse_movement(event)

#---------------------------------------------------------------------------
# internals
#----------------------------------------------------------------------------
func _update_gizmo():
    if _is_active and _selected_node and (_selected_node is Node2D or _selected_node is Control):
        _gizmo.visible = true
        _gizmo.global_position = _selected_node.global_position
        _gizmo.rotation = _selected_node.rotation

        var gizmo_zoom = Vector2(5, 5) / _debug_camera.zoom
        _gizmo.scale = gizmo_zoom
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
# Find the 2D node intersecting the mouse position.
func _pick_object():
    var picked_node : Node = null
    var mouse_pos = _debug_camera.get_global_mouse_position()

    if _use_only_physics_for_picking:
        var camera := get_viewport().get_camera_2d()
        var space_state = camera.get_world_2d().direct_space_state
        var query = PhysicsPointQueryParameters2D.new()
        query.position = mouse_pos
        var intersect = space_state.intersect_point(query) 

        if intersect and intersect.collider:
            picked_node = intersect.collider
    else:
        var hit_node = _find_nearest_node_instersecting_point_2d(mouse_pos)
        if hit_node:
            picked_node = hit_node

    on_object_picked.emit(picked_node)

# Find the topmost node intersecting point.
func _find_nearest_node_instersecting_point_2d(point: Vector2) -> Node2D:
    var nearest_node : Node = null
    var tree := get_tree()
    var node_stack: Array[Node] = [tree.get_root()]
    var best_z_index := RenderingServer.CANVAS_ITEM_Z_MIN

    # Run through all the nodes in the scene in render order finding nodes intersecting 'point'.
    # The last node overlapping will usually be the last node rendered, and hence the one 'on top'.
    # Controls are additionally prioritised by z-index.
    while not node_stack.is_empty():
        var node: Node = node_stack.pop_front()
        if not is_instance_valid(node):
            continue

        # Rendering order is normally depth first, preorder. 
        # Get the child nodes and put them to at the front of the stack.
        var child_nodes := node.get_children()
        child_nodes.append_array(node_stack)
        node_stack = child_nodes

        if node in _picker_ignore_nodes:
            continue

        elif node is Sprite2D:
            var sprite_node := node as Sprite2D
            if sprite_node.visible:
                if sprite_node.get_rect().has_point(sprite_node.to_local(point)):
                    nearest_node = node
        elif node is MeshInstance2D:
            # TODO
            pass
        elif node is Control:
            # This is naive, and doesn't take into account things like 'Y Sort Enabled'
            # or CanvasLayers
            var control_node := node as Control
            if control_node.visible and control_node.z_index >= best_z_index:
                if control_node.get_global_rect().has_point(point):
                    best_z_index = control_node.z_index
                    nearest_node = node
        else:
            pass


    return nearest_node
    

    
