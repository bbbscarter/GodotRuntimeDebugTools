@tool
extends MenuButton

#var _scene_running := false
var _inspector : RuntimeDebugToolsEditorDebuggerPlugin

# Some checkbox items need to persistent and be accessible in the editor
var _persistent_items : Dictionary = {}

enum PopupItems {
    Debug2D=1,
    Debug3D,
    PauseOnDebug,
    Paused,
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
    popup.add_separator("Pause")
    popup.add_check_item("Pause On Debug", PopupItems.PauseOnDebug)
    popup.add_check_item("Paused", PopupItems.Paused)
    
    popup.add_separator("Options")
    popup.add_check_item("Show Collisions", PopupItems.ShowCollisions)
    popup.add_separator("Rendering")
    popup.add_radio_check_item("RenderNormal", PopupItems.RenderNormal)
    popup.add_radio_check_item("RenderWireframe", PopupItems.RenderWireframe)

    popup.set_item_checked(popup.get_item_index(PopupItems.PauseOnDebug), true)
    _persistent_items[popup.get_item_index(PopupItems.PauseOnDebug)] = true

    _reset_ui(false)

func _on_popup_item_pressed(id):
    var idx := get_popup().get_item_index(id)
    var popup := get_popup()

    match id:
        PopupItems.Debug2D:
            var on = not popup.is_item_checked(idx)
            var mode = RuntimeDebugToolsEditorDebuggerPlugin.DebugMode.None
            if on:
                mode = RuntimeDebugToolsEditorDebuggerPlugin.DebugMode.Debug2D
            _inspector.set_debugging(mode)
            
        PopupItems.Debug3D:
            var on = not popup.is_item_checked(idx)
            var mode = RuntimeDebugToolsEditorDebuggerPlugin.DebugMode.None
            if on:
                mode = RuntimeDebugToolsEditorDebuggerPlugin.DebugMode.Debug3D
            _inspector.set_debugging(mode)

        PopupItems.PauseOnDebug:
            var on = not popup.is_item_checked(idx)
            popup.set_item_checked(idx, on)
            _inspector.set_pause_on_debug(on)

        PopupItems.Paused:
            var on = not popup.is_item_checked(idx)
            popup.set_item_checked(idx, on)
            _inspector.set_pause(on)

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
    _inspector.on_client_connected.connect(_client_connected)
    _inspector.on_client_disconnected.connect(_client_disconnected)
    _inspector.on_client_paused.connect(_client_paused)
    _inspector.on_client_debug_activate.connect(_client_debug_activate)
    _inspector.on_client_debug_deactivate.connect(_client_debug_deactivate)
    
func _client_connected():
    _reset_ui(true)

    var popup := get_popup()
    var pause_on_debug := popup.is_item_checked(popup.get_item_index(PopupItems.PauseOnDebug))
    _inspector.set_pause_on_debug(pause_on_debug)

func _client_disconnected():
    _reset_ui(false)

func _client_paused(on: bool):
    var popup := get_popup()
    popup.set_item_checked(popup.get_item_index(PopupItems.Paused), on)
    
func _client_debug_activate(is_3d: bool):
    var popup := get_popup()

    popup.set_item_disabled(popup.get_item_index(PopupItems.Paused), false)

    popup.set_item_checked(popup.get_item_index(PopupItems.Debug2D), !is_3d)
    popup.set_item_checked(popup.get_item_index(PopupItems.Debug3D), is_3d)
        
func _client_debug_deactivate():
    var popup := get_popup()
    popup.set_item_checked(popup.get_item_index(PopupItems.Debug2D), false)
    popup.set_item_checked(popup.get_item_index(PopupItems.Debug3D), false)
    popup.set_item_disabled(popup.get_item_index(PopupItems.Paused), true)

func _reset_ui(client_running: bool):
    var popup := get_popup()
    for idx in range(0, popup.item_count):
        if _persistent_items.has(idx):
            continue
        popup.set_item_checked(idx, false)
        popup.set_item_disabled(idx, not client_running)
    
    popup.set_item_checked(popup.get_item_index(PopupItems.RenderNormal), true)
    popup.set_item_disabled(popup.get_item_index(PopupItems.Paused), true)
        
