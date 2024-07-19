# Runtime Debug Tools for Godot
A proof-of-concept Godot addon that attempts to improve the runtime debugging
experience.

# Features
- Debug Camera. A simple in game debug camera for navigating around the live
  scene. This somewhat mimics the in-editor camera experience.
- In-game object picker. While using the debug camera, clicking the mouse will
  select the object under the mouse. This will also select the object in the
  Godot editor remote tree inspector.
- In-game object selection. Selecting a node in the Godot Editor, or using the
  in-game object picker, will visually select it in the Debug Camera view, with
  a visible widget.
- Runtime toggling of debug features. The remote inspector popup menu exposes
  various debug visualisation options. Including:
  - Wireframe mode.
  - Collision shapes.
  
 
# Notes
- In-game object uses physics meshes and rendered MeshInstances. This has the
  benefit of being accurate and not requiring any changes to assets - but
  triangle picking may be slow in large/complex scenes.
- Currently only supports 3D scenes, but should be easily extended to 2D scenes.
- Some features, such as selecting nodes in the editor scene tree, and toggling
  collision meshes, rely on undocumented Godot features.
- This is just a proof of concept. The hope is that some of these features might
  eventually appear in core Godot as first class features.
 
