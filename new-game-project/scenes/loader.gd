extends Node2D

@onready var progress_bar = $ProgressBar
@export var next_scene_path: String = "res://scenes/Game.tscn"
var progress: Array[float] = []

const MIN_DISPLAY_TIME := 3.0  # seconds — adjust to taste

var elapsed_time := 0.0
var load_finished := false
var scene_ready_to_switch: PackedScene = null

func _ready():
	if next_scene_path == "":
		push_error("No next_scene_path set")
		return

	var err = ResourceLoader.load_threaded_request(next_scene_path)
	if err != OK:
		push_error("Failed to start loading: %s (error %s)" % [next_scene_path, err])

func _process(delta):
	elapsed_time += delta

	# Smoothly animate the bar based purely on elapsed time, capped at 99%
	# until the real load is confirmed done.
	var time_based_pct = min(99.0, (elapsed_time / MIN_DISPLAY_TIME) * 100.0)
	progress_bar.value = time_based_pct

	if not load_finished:
		var status = ResourceLoader.load_threaded_get_status(next_scene_path, progress)
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				scene_ready_to_switch = ResourceLoader.load_threaded_get(next_scene_path)
				load_finished = true
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				push_error("Failed to load scene: %s" % next_scene_path)
				set_process(false)
				return

	if load_finished and elapsed_time >= MIN_DISPLAY_TIME:
		progress_bar.value = 100.0
		set_process(false)
		get_tree().change_scene_to_packed(scene_ready_to_switch)
		
