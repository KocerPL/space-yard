class_name RoverArm
extends Node
## The rover's instrument arm. The model has no arm joints: it is all one surface (tex_arm) of Model/Body, folded under
## the front. On ready this cuts it into the shoulder mount (stays on the body), the upper arm and the instrument turret,
## and adds a forearm tube, which the model folds out of sight. reach() unfolds it towards a point with two-bone IK;
## stow() folds it back. E (interact) reaches for the ground ahead, holds, and folds back.

## Body space, measured on the GLB: the shoulder ring, the elbow end of the upper arm, where the turret meets the
## forearm, and the tip of the instrument that touches the target.
const SHOULDER := Vector3(0.082, 0.432, 0.478)
const ELBOW := Vector3(-0.186, 0.432, 0.302)
const WRIST := Vector3(0.09, 0.405, 0.365)
const TIP := Vector3(0.25, 0.41, 0.42)

@export var unfold_time := 1.4
## After E, seconds the arm stays out before folding back.
@export var hold_time := 1.5

var _joints: Array[Node3D] = [] # shoulder, elbow, wrist
var _e_was_down := false
var _tween: Tween
var _root := PackedInt32Array() # union-find over the arm's vertices


func _ready() -> void:
	var body: MeshInstance3D = get_parent().get_node("Model/Body")
	var mesh: ArrayMesh = body.mesh.duplicate()
	var surface := 0
	while mesh.surface_get_name(surface) != "tex_arm":
		surface += 1
	var arrays := mesh.surface_get_arrays(surface)
	var mat := mesh.surface_get_material(surface)
	mesh.surface_remove(surface)
	body.mesh = mesh
	var piece := _pieces(arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_INDEX])

	body.add_child(_cut(arrays, piece, 0, Vector3.ZERO, mat))
	_joints.append(_joint(body, SHOULDER))
	_joints[0].add_child(_cut(arrays, piece, 1, SHOULDER, mat))
	_joints.append(_joint(_joints[0], ELBOW - SHOULDER))
	_joints.append(_joint(_joints[1], WRIST - ELBOW))
	_joints[2].add_child(_cut(arrays, piece, 2, WRIST, mat))

	var tube := CylinderMesh.new()
	tube.top_radius = 0.014
	tube.bottom_radius = 0.014
	tube.height = ELBOW.distance_to(WRIST)
	tube.radial_segments = 12
	tube.rings = 1
	# texture it with the upper arm's colour: squeeze the UVs onto the texel under the middle of that tube
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var mid := (SHOULDER + ELBOW) / 2.0
	var nearest := 0
	for i in verts.size():
		if piece[i] == 1 and verts[i].distance_squared_to(mid) < verts[nearest].distance_squared_to(mid):
			nearest = i
	tube.material = mat.duplicate()
	tube.material.uv1_offset = Vector3(arrays[Mesh.ARRAY_TEX_UV][nearest].x, arrays[Mesh.ARRAY_TEX_UV][nearest].y, 0.0)
	tube.material.uv1_scale = Vector3(0.01, 0.01, 1.0)
	var forearm := MeshInstance3D.new()
	forearm.mesh = tube
	forearm.transform = Transform3D(Basis(Quaternion(Vector3.UP, (WRIST - ELBOW).normalized())), (WRIST - ELBOW) / 2.0)
	_joints[1].add_child(forearm)


func _physics_process(_delta: float) -> void:
	# shortcut: raw physical key like rover.gd's drive keys, move to an InputMap action along with them
	var e := Input.is_physical_key_pressed(KEY_E)
	if e and not _e_was_down:
		var ground := (_joints[0].get_parent() as Node3D).to_global(Vector3(0, 0, 1.0)) # 1 m ahead, at the wheels' feet
		if TerrainGenerator.instance:
			ground.y = TerrainGenerator.instance.sample_height(ground.x, ground.z)
		reach(ground)
		_tween.tween_interval(hold_time)
		_tween.tween_callback(stow)
	_e_was_down = e


## Unfolds the arm so the instrument tip reaches for a world point, or towards it as far as the arm goes.
func reach(target: Vector3) -> void:
	var p := (_joints[0].get_parent() as Node3D).to_local(target)
	var dir := p - SHOULDER
	dir.z = maxf(dir.z, 0.3 * dir.length()) # the model faces +Z: reach ahead or aside, never back through the body
	dir = dir.normalized()
	var l1 := SHOULDER.distance_to(ELBOW)
	var l2 := ELBOW.distance_to(WRIST)
	var d := clampf(SHOULDER.distance_to(p) - WRIST.distance_to(TIP), absf(l1 - l2) + 0.05, (l1 + l2) * 0.97)
	var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d) # law of cosines: how far along the shoulder-wrist line the elbow sits
	var up := (Vector3.UP - dir * dir.y).normalized() # elbow up
	var elbow := SHOULDER + dir * a + up * sqrt(maxf(l1 * l1 - a * a, 0.0))
	var wrist := SHOULDER + dir * d
	var upper := Quaternion((ELBOW - SHOULDER).normalized(), (elbow - SHOULDER).normalized())
	var fore := Quaternion((WRIST - ELBOW).normalized(), (wrist - elbow).normalized())
	var turret := Quaternion((TIP - WRIST).normalized(), dir)
	_move([upper, upper.inverse() * fore, fore.inverse() * turret], true)


func stow() -> void:
	_move([Quaternion.IDENTITY, Quaternion.IDENTITY, Quaternion.IDENTITY], false)


## World position of the instrument tip.
func tip() -> Vector3:
	return _joints[2].to_global(TIP - WRIST)


## Turns the joints from where they are to `to`, one after another: shoulder first when unfolding, wrist first when folding.
func _move(to: Array[Quaternion], unfolding: bool) -> void:
	var from: Array[Quaternion] = []
	for j in _joints:
		from.append(j.quaternion)
	if _tween:
		_tween.kill()
	_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS) # physics ticks, so interpolation smooths it
	_tween.tween_method(func(t: float) -> void:
		for i in 3:
			var k := clampf(t * 1.6 - (i if unfolding else 2 - i) * 0.3, 0.0, 1.0)
			_joints[i].quaternion = from[i].slerp(to[i], smoothstep(0.0, 1.0, k)), 0.0, 1.0, unfold_time)


func _joint(parent: Node3D, at: Vector3) -> Node3D:
	var j := Node3D.new()
	j.position = at
	parent.add_child(j)
	return j


## A mesh of the triangles of one piece, moved so `origin` (its joint) is at zero.
func _cut(arrays: Array, piece: PackedByteArray, which: int, origin: Vector3, mat: Material) -> MeshInstance3D:
	var a := arrays.duplicate()
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX].duplicate() # packed arrays are shared, keep the caller's intact
	for i in v.size():
		v[i] -= origin
	a[Mesh.ARRAY_VERTEX] = v
	var src: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var idx := PackedInt32Array()
	for t in range(0, src.size(), 3):
		if piece[src[t]] == which:
			idx.append(src[t])
			idx.append(src[t + 1])
			idx.append(src[t + 2])
	a[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi


## Which piece each vertex goes with: 0 the mount, 1 the upper arm, 2 the turret. Decided per connected part of the
## mesh by its centroid: the mount's parts sit above or ahead of the shoulder, the upper arm's on its axis plane.
func _pieces(v: PackedVector3Array, idx: PackedInt32Array) -> PackedByteArray:
	_root = PackedInt32Array(range(v.size()))
	var at := {} # vertices are split along UV seams, so join them by position too
	for i in v.size():
		var key := Vector3i((v[i] * 10000.0).round())
		if at.has(key):
			_root[_find(i)] = _find(at[key])
		else:
			at[key] = i
	for t in range(0, idx.size(), 3):
		_root[_find(idx[t + 1])] = _find(idx[t])
		_root[_find(idx[t + 2])] = _find(idx[t])
	var sum := {}
	var count := {}
	for i in v.size():
		var r := _find(i)
		sum[r] = sum.get(r, Vector3.ZERO) + v[i]
		count[r] = count.get(r, 0) + 1
	var piece := PackedByteArray()
	piece.resize(v.size())
	for i in v.size():
		var r := _find(i)
		var c: Vector3 = sum[r] / count[r]
		if c.y > 0.445 or (c.z > 0.42 and c.x > 0.09):
			piece[i] = 0
		elif absf(c.y - SHOULDER.y) < 0.002:
			piece[i] = 1
		else:
			piece[i] = 2
	return piece


func _find(i: int) -> int:
	while _root[i] != i:
		_root[i] = _root[_root[i]]
		i = _root[i]
	return i
