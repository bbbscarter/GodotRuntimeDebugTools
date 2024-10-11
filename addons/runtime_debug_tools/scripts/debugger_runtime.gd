extends Node
#class_name RuntimeDebugToolsRuntime

var _is_active := false
var _is_paused := false
var _was_paused := false

@onready var _interaction_3d := $Interaction3D as DebugRuntimeInteraction3D
@onready var _interaction_2d := $Interaction2D as DebugRuntimeInteraction2D
var _interaction = null

@onready var _debug_ui := $DebugUI as Node
@onready var _debug_label := $DebugUI/DebugLabel as Label
var _showing_collision_shapes := false
var _pause_on_debug := false
var _debug_key_3d := KEY_F12
var _debug_key_2d := KEY_F11

func _ready():
    _interaction_2d.on_object_picked.connect(_on_object_picked)
    _interaction_3d.on_object_picked.connect(_on_object_picked)

    _debug_ui.visible = false
    _interaction = null
    _is_active = false

    _deactivate_debug_mode()
    EngineDebugger.register_message_capture("remote_inspector", _on_editor_message)
    EngineDebugger.send_message("remote_inspector:connected", [])

    var key_2d = ProjectSettings.get_setting("addons/RuntimeDebugTools/DebugToggle2D")
    if key_2d and OS.find_keycode_from_string(key_2d):
        print("Binding 2D debug to: " + key_2d)
        _debug_key_2d = OS.find_keycode_from_string(key_2d)

    var key_3d = ProjectSettings.get_setting("addons/RuntimeDebugTools/DebugToggle3D")
    if key_3d and OS.find_keycode_from_string(key_3d):
        print("Binding 3D debug to: " + key_3d)
        _debug_key_3d = OS.find_keycode_from_string(key_3d)

    # Apparently this doesn't do anything at the moment.
    # RenderingServer.set_debug_generate_wireframes(true)

func _on_editor_message(msg, args):
    if msg == "editor_select":
        if _is_active:
            var node_to_select = instance_from_id(args[0]) as Node
            # print("Asked to select node: %s" %args[0])
            _select_node(node_to_select)
            # print("Selected node: %s" %_selected_node)
    elif msg == "debug_activate":
        if _is_active:
            _deactivate_debug_mode()
        var debug_3d = args[0]
        _activate_debug_mode(debug_3d)

    elif msg == "debug_deactivate":
        if _is_active:
            _deactivate_debug_mode()
    elif msg == "render_mode":
        var mode = args[0]
        get_viewport().debug_draw = mode
    elif msg == "show_collision_shapes":
        var mode = args[0]
        _show_collision_shapes(mode)
    elif msg == "pause_on_debug":
        _pause_on_debug = args[0]
    elif msg == "pause":
        _set_paused(args[0])
    return true

func _show_collision_shapes(on: bool):
    # taken from https://github.com/godotengine/godot-proposals/issues/2072
    _showing_collision_shapes = on

    var tree := get_tree()
    if tree.debug_collisions_hint == on:
        return

    tree.debug_collisions_hint = on

    # Traverse tree to call queue_redraw on instances of CollisionShape2D and CollisionPolygon2D.
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
    _interaction.select_node(node)
    
func _on_object_picked(picked_node):
    if picked_node:
        var picked_id = picked_node.get_instance_id()
        _select_node(picked_node)
        EngineDebugger.send_message("remote_inspector:select_id", [picked_id])
    else:
        _select_node(null)
    
func _input(event):
    var key_event := event as InputEventKey

    # Toggle debugging if a key is pressed
    if key_event and key_event.pressed:
        if key_event.keycode == _debug_key_3d or key_event.keycode == _debug_key_2d:
            get_viewport().set_input_as_handled()
            # If debugging is active, turn it off regardless of the key pressed.
            if _is_active:
                _deactivate_debug_mode()
                return

            var is_3d := key_event.keycode == _debug_key_3d
            # if is_3d:
            #     is_3d = get_viewport().get_camera_3d() != null

            _activate_debug_mode(is_3d)

func _activate_debug_mode(debug_3d: bool):
    _debug_ui.visible = true

    if _interaction:
        _interaction.set_active(false)
        _interaction = null
    
    if debug_3d:
        _interaction = _interaction_3d
        _debug_label.text = "Debug 3D"
    else:
        _interaction = _interaction_2d
        _debug_label.text = "Debug 2D"

    _interaction.set_active(true)
    if _pause_on_debug:
        _set_paused(true)

    EngineDebugger.send_message("remote_inspector:debug_activated", [debug_3d])
        
    _is_active = true

func _deactivate_debug_mode():
    _debug_ui.visible = false

    if _interaction:
        _interaction.set_active(false)
        _interaction = null
    
    if _is_paused:
        _set_paused(false)

    EngineDebugger.send_message("remote_inspector:debug_deactivated", [])
        
    _is_active = false

func _set_paused(on: bool):
    if _is_paused == on:
        return

    _is_paused = on

    if on:
        _was_paused = get_tree().paused
        get_tree().paused = true
    else:
        get_tree().paused = _was_paused

    EngineDebugger.send_message("remote_inspector:paused", [on])
