extends ProgressBar

@export var next_scene_path: String

var progress: Array[float] = []

func _ready():
	ResourceLoader.load_threaded_request(next_scene_path)

func _process(delta):
	var status = ResourceLoader.load_threaded_get_status(next_scene_path, progress)

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
