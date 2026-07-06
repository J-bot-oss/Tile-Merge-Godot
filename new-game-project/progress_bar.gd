extends ProgressBar

static var next_scene_path: String = "res://scenes/Game.tscn"
var progress: Array[float] = []

func _ready():
	if next_scene_path == "":
		push_error("No next_scene_path set")
		return

	var err = ResourceLoader.load_threaded_request(next_scene_path)
	print("LOADER: request returned err = ", err, " (OK = ", OK, ")")
	if err != OK:
		push_error("Failed to start loading: %s (error %s)" % [next_scene_path, err])

func _process(delta):
	var status = ResourceLoader.load_threaded_get_status(next_scene_path, progress)
	print("LOADER: status = ", status, " progress = ", progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			value = progress[0] * 100
		ResourceLoader.THREAD_LOAD_LOADED:
			var scene = ResourceLoader.load_threaded_get(next_scene_path)
			set_process(false)
			get_tree().change_scene_to_packed(scene)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Failed to load scene: %s" % next_scene_path)
			set_process(false)
