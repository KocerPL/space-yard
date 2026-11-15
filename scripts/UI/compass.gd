extends Control
## Compass bar: N/E/S/W and 15° ticks slide past as the camera turns. North is -Z, east is +X.

## Degrees of heading the bar spans, edge to edge.
@export var span := 120.0
@export var font: Font
@export var font_size := 22

@onready var targetRock: Poi = get_node("../../RockPoi")
@onready var targetCrater: Poi = get_node("../../CraterPoi")
@export var target_color := Color.CYAN

const CARDINALS := {0: "N", 90: "E", 180: "S", 270: "W"}


## Compass bearing of a direction, 0..360, clockwise from north.
static func heading(forward: Vector3) -> float:
	return fposmod(rad_to_deg(atan2(forward.x, -forward.z)), 360.0)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var h := heading(-cam.global_basis.z)
	var f := font if font else get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
	for deg in range(0, 360, 15):
		var x := size.x * 0.5 + wrapf(deg - h, -180.0, 180.0) * size.x / span
		if x < 0.0 or x > size.x:
			continue
		if CARDINALS.has(deg):
			draw_string(f, Vector2(x - 20.0, size.y * 0.5 + font_size * 0.35), CARDINALS[deg], HORIZONTAL_ALIGNMENT_CENTER, 40.0, font_size)
		else:
			draw_line(Vector2(x, size.y * 0.65), Vector2(x, size.y), Color(1, 1, 1, 0.5), 2.0)
	draw_line(Vector2(size.x * 0.5, 0.0), Vector2(size.x * 0.5, size.y * 0.25), Color(1, 0.6, 0.3), 3.0) # where the camera faces
	draw_target_indicator(cam, targetRock)
	draw_target_indicator(cam, targetCrater)

#Function showing location to poi on compass	
func draw_target_indicator(cam: Camera3D, target: Poi) -> void:
	if target == null or !target.is_visible_in_tree():
		return

	var target_pos := target.global_position

	if not cam.is_position_in_frustum(target_pos):
		return

	var direction := target_pos - cam.global_position
	var target_heading := heading(direction)
	var camera_heading := heading(-cam.global_basis.z)
	var difference := wrapf(target_heading - camera_heading, -180.0, 180.0)
	var x := size.x * 0.5 + difference * size.x / span

	if x < 0.0 or x > size.x:
		return
	
	draw_line(
		Vector2(x, size.y * 0.25),
		Vector2(x, size.y),
		target_color,
		4.0
	)
