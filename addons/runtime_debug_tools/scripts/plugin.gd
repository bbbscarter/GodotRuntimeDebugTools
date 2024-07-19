@tool
extends EditorPlugin

var _editor_plugin = preload("res://addons/runtime_debug_tools/scripts/editor_debugger_plugin.gd").new()
var _runtime_scene = "res://addons/runtime_debug_tools/scenes/remote_inspector.tscn"
var _editor_ui_scene = preload("res://addons/runtime_debug_tools/scripts/editor_menu.gd").new()

func _enter_tree():
    add_debugger_plugin(_editor_plugin)
    EditorInterface.get_inspector().edited_object_changed.connect(_editor_plugin.selection_changed)

    if not ProjectSettings.has_setting("autoload/RuntimeDebugTools"):
        add_autoload_singleton("RuntimeDebugTools", _runtime_scene)

    _editor_ui_scene.set_remote_inspector(_editor_plugin)
    add_control_to_container(CONTAINER_TOOLBAR, _editor_ui_scene)

func _exit_tree():
    if _editor_plugin != null:
        EditorInterface.get_inspector().edited_object_changed.disconnect(_editor_plugin.selection_changed)
        remove_debugger_plugin(_editor_plugin)
    if ProjectSettings.has_setting("autoload/RuntimeDebugTools"):
        remove_autoload_singleton("RuntimeDebugTools")

    remove_control_from_container(CONTAINER_TOOLBAR, _editor_ui_scene)
