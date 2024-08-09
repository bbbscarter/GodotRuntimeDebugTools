@tool
extends MenuButton

var _scene_running := false
@onready var _inspector 

enum PopupItems {
    Debug2D=1,
    Debug3D,
    ShowCollisions,
    RenderNormal,
    RenderWireframe,
    RenderEnd
    }
    
func _enter_tree():
    text = "RDT"
    var popup := get_popup()
    popup.clear()
    popup.id_pressed.connect(_on_popup_item_pressed)
    popup.add_check_item("2D Debugging", PopupItems.Debug2D)
    popup.add_check_item("3D Debugging", PopupItems.Debug3D)
    
    popup.add_separator("Options")
    popup.add_check_item("Show Collisions", PopupItems.ShowCollisions)
    popup.add_separator("Rendering")
    popup.add_radio_check_item("RenderNormal", PopupItems.RenderNormal)
    popup.add_radio_check_item("RenderWireframe", PopupItems.RenderWireframe)

    _reset_ui()

func _on_popup_item_pressed(id):
    var idx := get_popup().get_item_index(id)
    var popup := get_popup()

    match id:
        PopupItems.Debug2D:
            var on = not popup.is_item_checked(idx)
            popup.set_item_checked(popup.get_item_index(PopupItems.Debug3D), false)
            popup.set_item_checked(idx, on)
            var mode = RuntimeDebugToolsEditorDebuggerPlugin.DebugMode.None
            
            if on:
                mode = RuntimeDebugToolsEditorDebuggerPlugin.DebugMode.Debug2D
            _inspector.set_debugging(mode)
            
        PopupItems.Debug3D:
            print("Debug 3D")
            var on = not popup.is_item_checked(idx)
            popup.set_item_checked(popup.get_item_index(PopupItems.Debug2D), false)
            popup.set_item_checked(idx, on)
            var mode = RuntimeDebugToolsEditorDebuggerPlugin.DebugMode.None
            
            if on:
                mode = RuntimeDebugToolsEditorDebuggerPlugin.DebugMode.Debug3D
            _inspector.set_debugging(mode)

        PopupItems.ShowCollisions:
            var on = not popup.is_item_checked(idx)
            popup.set_item_checked(idx, on)
            _inspector.set_show_collision_shapes(on)

        PopupItems.RenderNormal:
            _clear_checked_range(PopupItems.RenderNormal, PopupItems.RenderEnd)
            popup.set_item_checked(idx, true)
            _inspector.set_render_mode(Viewport.DEBUG_DRAW_DISABLED)

        PopupItems.RenderWireframe:
            _clear_checked_range(PopupItems.RenderNormal, PopupItems.RenderEnd)
            popup.set_item_checked(idx, true)
            _inspector.set_render_mode(Viewport.DEBUG_DRAW_WIREFRAME)

            
func _clear_checked_range(s, e):
    var popup := get_popup()
    for id in range(s, e):
        var idx = popup.get_item_index(id)
        popup.set_item_checked(idx, false)
        
    
func set_remote_inspector(inspector):
    _inspector = inspector
    
func _process(_delta):
    if not Engine.is_editor_hint():
        return
        
    var running = EditorInterface.is_playing_scene()

    if running != _scene_running:
        _scene_running = running
        _reset_ui()

    if not _scene_running:
        return

func _reset_ui():
    var popup := get_popup()
    for idx in range(0, popup.item_count):
        popup.set_item_checked(idx, false)
        popup.set_item_disabled(idx, not _scene_running)
    
    popup.set_item_checked(popup.get_item_index(PopupItems.RenderNormal), true)
    
    

