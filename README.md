# Runtime Debug Tools for Godot
A proof-of-concept Godot addon that attempts to extend and improve the runtime
debugging experience.

# Features
- Works with both 2D and 3D scenes.
- Debug camera. A simple in-game debug camera for navigating around the live
  scene. This somewhat mimics the in-editor camera experience.
- In-game object picker. While using the debug camera, clicking the mouse will
  select the object under the mouse, highlighting it with a visible gizmo in the
  runtime and selecting the object in the Godot Editor remote tree inspector.
- Editor object picker synchronised with the running application. Selecting a node in the
  Godot Editor, will visually select it in the runtime debug view with a visible gizmo.
- Optionally, turning on 2D or 3D Debug mode pauses the running game. This makes
  debugging easier, and also prevents running game code from interfering with
  debug controls.
- Runtime toggling of debug features. The remote inspector popup menu exposes
  various debug visualisation options. Including:
  - Wireframe mode.
  - Collision shapes.

# Videos
- [Debug Camera](https://github.com/user-attachments/assets/977d41cb-2934-45e6-8e3d-afe25f7bd268)
- [In-game object picker](https://github.com/user-attachments/assets/037759d3-13fe-4212-a2d9-45193eec0e13)
- [Editor selections synced with game](https://github.com/user-attachments/assets/c86a7406-1e82-49b5-980d-631db51d4eb2)
- [Runtime debug visualisations](https://github.com/user-attachments/assets/05ecf725-8006-4ee6-b63c-71511c40c4dc)

# Installation and Usage
- Download from the Godot Asset Library.
- Import the plugin into your Godot project.
- Enable the plugin in your project settings.
- When the game is running click on the RDT button in the toolbar and select '2D' or '3D' debugging.
 
# Notes
- 3D object picking uses physics meshes, as well as rendered MeshInstances. This
  has the benefit of being accurate and working with all rendered assets without
  requiring any scene modifications; however triangle picking may be slow in
  large/complex scenes.
- 2D object picking is currently limited to sprites and canvas items.
- Some features, such as selecting nodes in the editor scene tree, and toggling
  collision meshes, rely on undocumented Godot features.
- This is just a proof of concept. The hope is that some of these features might
  eventually appear in core Godot as first class features.
 
