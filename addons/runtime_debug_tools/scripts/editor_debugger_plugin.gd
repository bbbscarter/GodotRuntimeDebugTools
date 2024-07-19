extends EditorDebuggerPlugin
class_name RuntimeDebugToolsEditorDebuggerPlugin

var found = false
var node_path = ""

func selection_changed():
    var node = EditorInterface.get_inspector().get_edited_object()
    if node == null:
        return 

    if node.get_class() != "EditorDebuggerRemoteObject":
        return

    var node_id = node.get_remote_object_id()

    for session in get_sessions():
        if session.is_active():
            session.send_message("remote_inspector:editor_select", [node_id])
    
func set_debugging(on: bool):
    for session in get_sessions():
        if session.is_active():
            session.send_message("remote_inspector:debug_enable", [on])
    
func set_render_mode(mode):
    for session in get_sessions():
        if session.is_active():
            session.send_message("remote_inspector:render_mode", [mode])

func set_show_collision_shapes(on: bool):
    for session in get_sessions():
        if session.is_active():
            session.send_message("remote_inspector:show_collision_shapes", [on])

func _has_capture(prefix):
    return prefix == "remote_inspector"

func _capture(message, data, session_id):
    if message == "remote_inspector:select_id":
        found = false
        var node_id = data[0]
            
        # Taken from https://github.com/DigitallyTailored/godot-runtime-node-selector/blob/main/RuntimeSelectorAutoload.gd][this]].
        var root_node = EditorInterface.get_edited_scene_root().get_node('/root').find_child("*EditorDebuggerTree*", true, false)
        
        select_object_in_remote_tree(root_node, node_id)
            
        if !found:
            print("Node not found. Please check the remote tab is open")
        return true

            
## TODO - can we do this with object IDs via SceneDebuggerObject and SceneDebuggerTree?
func select_object_in_remote_tree(node: Node, id: int):
    if node == null:
        return
    if node.is_class("Tree"):
        var root = node.get_root()
        select_object_in_tree_items(root,  id)
    for child in node.get_children():
        select_object_in_remote_tree(child, id)

func _uncollapse_up(item: TreeItem):
    item.collapsed = false
    if item.get_parent():
        _uncollapse_up(item.get_parent())
    
func select_object_in_tree_items(item: TreeItem, id: int):
    if item == null:
        return
    if item.get_metadata(0) == id:
        _uncollapse_up(item)
        item.get_tree().scroll_to_item(item)
        item.select(0)
        found = true
    if item.get_children():
        for treeItem in item.get_children():
            select_object_in_tree_items(treeItem, id)
    item = item.get_next()
