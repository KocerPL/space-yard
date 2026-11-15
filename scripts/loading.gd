extends CanvasLayer

@onready var container: Control = $Container
@onready var progressBar:ProgressBar =$Container/ProgressBar
var duration = 2;
var target_scene_path: String = ""
var is_loading: bool = false
var progress: Array = []

func _ready() -> void:
	container.visible = false
	container.modulate.a = 0.0

func load_scene(path: String) -> void:

	if is_loading:
		return
		
	target_scene_path = path
	progressBar.value = 0.0
	container.visible = true

	var fade_in = create_tween()
	fade_in.tween_property(container, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await fade_in.finished
	
	ResourceLoader.load_threaded_request(target_scene_path)
	is_loading = true

func _process(delta: float) -> void:
	if not is_loading:
		return
	
	var status = ResourceLoader.load_threaded_get_status(target_scene_path, progress)
	
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			# Smoothly glide the progress bar toward the current percentage
			var target_percent = progress[0] * 100.0
			progressBar.value = lerp(progressBar.value, target_percent, delta * 10.0)
		ResourceLoader.THREAD_LOAD_LOADED:
			is_loading = false
			_finish_transition()
			
		ResourceLoader.THREAD_LOAD_FAILED:
			is_loading = false
			push_error("Failed to load scene: " + target_scene_path)

func _finish_transition() -> void:

	progressBar.value =100.0
	await get_tree().create_timer(0.2).timeout

	var packed_scene = ResourceLoader.load_threaded_get(target_scene_path)
	get_tree().change_scene_to_packed(packed_scene)
	
	await get_tree().process_frame
	

	var fade_out = create_tween()
	fade_out.tween_property(container, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await fade_out.finished

	container.visible = false
