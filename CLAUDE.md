# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Godot 4.7 (Forward+, Jolt Physics), GDScript only, no C#. It's a Mars rover sandbox. There is no main scene set yet, so `godot --headless --quit` refuses to run the project. Run a specific scene or script instead.

- `scenes/terrain_sandbox.tscn` is the playground: terrain, camera, light and a Mars `WorldEnvironment` (tan sky, depth fog tuned to hide the edge of the loaded area).
- `prefabs/` holds reusable scenes: `terrain.tscn` (the generator) and `rover.tscn` (`scripts/rover.gd`: a `CharacterBody3D` with W/S drive and A/D turn, using raw physical keys rather than InputMap. The MER model faces +Z, so it is turned 180° and tilted to the floor normal while the box collider stays upright).
- The rover model is `assets/models/rover_glb/24883_MER_rigged.glb`, split from the static GLB in Blender (`~/3dmodels/rover_rigged.blend`) into `Body > Rocker_L/R > Bogie_L/R`, `Steer_{FL,RL,FR,RR}` and `Wheel_{F,M,R}{L,R}`. Every origin is at its joint and every rotation is identity: `rover.gd` drives them by name, spinning wheels about X, steering about Y and swinging rockers and bogies about X. Keep that contract when re-exporting. The model's +X is the rover's left.
- The sandbox camera is `CameraRig` (`scripts/orbit_camera.gd`): a pivot that follows the rover, with a `SpringArm3D` > `Camera3D`. Holding the left mouse button and dragging orbits it.
- POIs are `Poi` nodes (`scripts/poi.gd`, an `Area3D`). Set `kind` to `LOCATION` to snap to the ground, or to `ROCK` to snap to the nearest boulder from `TerrainGenerator.nearest_rock()`, which computes it from the hash so the chunk needn't be loaded. A rock POI also gets a glowing shell (`assets/shaders/poi_highlight.gdshader`). Each POI places `prefabs/waystone.tscn`, whose beam ignores fog so it shows from far away, and emits `reached` when the rover enters `radius`. It must come after the terrain in the tree. The sandbox has `RockPoi` and `CraterPoi`, the latter on the floor of a real crater for seed 42.
- The event system is `Mission` (`scripts/mission.gd`). It plays its `MissionEvent` children (`scripts/mission_event.gd`) in tree order. Each event waits `delay` seconds after the previous one, and also waits for the rover to be inside its `poi` if it has one. That POI stays hidden until the event is the target and hides again once it's reached. Events with `idle` set are taken out of the sequence and play in turn whenever the rover has stood still for `idle_after` seconds. A transmission shows its lines from the dialog box's JSON (`scenes/UI/dialog_box.tscn` with `assets/mission_1.json`), each kept up for its share of the voice clip, and `event_started` fires for each one.
- `Audio` (`scripts/audio_controller.gd`) is an autoload. Transmissions go through `play_voice()`, which has one channel, so a new transmission cuts off the old one.
- Voice clips are `assets/audio/sy.*.wav`, imported with `edit/normalize=true` because the recordings are very quiet (peaks around -20 dB). The intro is `Prologue_1` then `Prologue_2`, played back to back from an `AudioStreamPlaylist` (`fade_time = 0`) in the sandbox. `Trans_N` is `Transmission 0N` and `Idle_N` is `Idle 0N`. New clips need normalize turned on in their `.import` file.
- `CameraRig` zooms in from `intro_distance` to the spring arm's length on start.
- The sandbox HUD has a compass bar (`scripts/UI/compass.gd`) that follows the camera's heading. North is -Z and east is +X.
- HUD controls need `mouse_filter = 2` (IGNORE). A `Control` defaults to STOP and swallows the clicks `CameraRig` reads in `_unhandled_input`. Headless probes don't show this, because there's no GUI picking without a window.
- Headless, `MultiMesh.get_instance_transform()` reads back zero (the renderer is a dummy). Tests check rocks through their colliders.
- Physics interpolation is on (`project.godot`). Anything that follows a physics body from `_process` must read `get_global_transform_interpolated()` and set `physics_interpolation_mode = OFF` on itself, as `CameraRig` does.
- A new `class_name` is unknown to `-s` scripts until the class cache is refreshed: `timeout -s KILL 120 godot --headless --import < /dev/null`.
- `scenes/mainmenu.tscn` is an empty placeholder.

## Commands

```sh
# Tests are SceneTree scripts using assert(); they print "<name> OK" on success
timeout -s KILL 60 godot --headless -s tests/test_terrain_generator.gd < /dev/null

# Run the sandbox scene
godot scenes/terrain_sandbox.tscn
```

Headless gotchas:
- A failed `assert` drops Godot into the debugger waiting on stdin, so it hangs. Always use `timeout -s KILL` and `< /dev/null`, and read the log for `SCRIPT ERROR`.
- Don't `pkill -f "godot --headless"`: the pattern matches the calling shell's own command line and kills it. The user often has the editor (`godot -e`) open too.
- Reach autoloads with `get_node("/root/Audio")`, not the bare `Audio` name. `-s` scripts and an editor opened before an autoload was added don't declare it, so naming it is a compile error ("Identifier not found: Audio").
- Quitting while a voice clip plays logs a leaked `AudioStreamWAV` and "resources still in use" at exit (the audio server frees playback a mix step later). This is harmless, e.g. in `test_rover`, which quits during the intro.
- Nodes added in a `SceneTree._initialize()` don't get `_ready()` until the main loop starts. `await process_frame` after `add_child` before asserting on them.
- To check visuals, run a temporary `-s` script **without** `--headless` that instantiates the scene, awaits ~20 frames, then saves `root.get_viewport().get_texture().get_image()` as a PNG.

## Terrain generator (`scripts/terrain_generator.gd`)

This is a port of the Unity `TerrainGenerator` from `~/code/walkers-sandbox/WalkersSandbox/Assets/Scripts/TerrainGeneration.cs`, reworked to look like Mars. `TerrainGenerator.instance` is a singleton.

- **Streaming:** infinite chunks, each a `StaticBody3D` named `Chunk_x_z` holding the terrain mesh, a trimesh collider, a `Rocks` MultiMesh and a convex collider per boulder. Chunks load around nodes added with `register_tracker()`. If none are registered, they follow `track_target`, then the active camera. The first load is synchronous; after that, chunk loads are capped per tick. `ensure_loaded_around()` forces ground to exist immediately.
- **Height:** `sample_height(x, z)` is the single source of truth for ground height. It combines Perlin octaves (`FastNoiseLite`, octaves summed by hand to match the Unity formula), a small-scale detail noise layer and one optional crater per `crater_spacing` grid cell. Because everything is sampled in world coordinates, chunk edges line up. Meshes also sample a one-vertex border so normals match across seams. Anything that needs ground height (spawning, rock placement, POIs) must go through `sample_height`.
- **Determinism:** crater placement and rock scatter use `_hash01(x, z, salt)`, which is bit-identical to the Unity C# uint32 hash (emulated by `_mul32` to avoid int64 overflow). Salts 0–3 are for craters and 100+ for rocks; keep new salts distinct. The noise itself does *not* match Unity's `Mathf.PerlinNoise`.
- **Godot-specific details found during the port:**
  - Front faces are clockwise, so Unity's triangle order is reversed.
  - Vertex colors need `vertex_color_is_srgb = true`, or they render washed out.
  - Script members can't be named `scale` or `seed`: one is a `Node3D` property, the other a global function. That's why they're `noise_scale` and `noise_seed`.
  - Colliders can't take non-uniform scale, so boulder convex shapes have their scale baked into the points.
