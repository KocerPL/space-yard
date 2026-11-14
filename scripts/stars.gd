extends Control
var stars = []
var star_count = 50

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for i in range(star_count):
		stars.append({
			"pos":Vector2(
				randf()*size.x,
				randf()*size.y
			),
			"phase": randf()*TAU,
			"speed": randf_range(1.0,3.0),
			"radius":randf_range(1.0,2.5)
		})


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	for star in stars:
		star.phase+= delta*star.speed;
	queue_redraw()

func _draw() -> void:
	for star in stars:
		var alpha = 0.4 +0.5*sin(star.phase)
		var color = Color(1,1,1,alpha)
		draw_circle(star.pos,star.radius,color)	
