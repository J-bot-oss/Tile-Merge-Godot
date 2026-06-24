extends Node2D

const GRID_SIZE := 4
const TILE_SIZE := 90
const MAX_INVALID_MOVES := 5

var tile_scene = preload("res://scenes/Tile.tscn")

var selected_tile = null
var coward_tile = null
var grid_tiles = {}

var score := 0
var invalid_moves := 0
var level := 1
var target_score := 60
var game_won := false
var game_over := false

var purple_count := 0
var green_count := 0
var orange_count := 0

var colors = ["red", "blue", "yellow"]

var merge_rules = {
	"red+blue": "purple",
	"blue+red": "purple",
	"blue+yellow": "green",
	"yellow+blue": "green",
	"red+yellow": "orange",
	"yellow+red": "orange"
}

@onready var score_label = $ScoreLabel
@onready var level_label = $LevelLabel
@onready var target_label = $TargetLabel
@onready var restart_button = $RestartButton
@onready var win_label = $WinLabel
@onready var game_over_label = $GameOverLabel

@onready var merge_sound = $MergeSound
@onready var invalid_sound = $InvalidSound
@onready var win_sound = $WinSound
@onready var game_over_sound = $GameOverSound
@onready var dance_timer = $DanceTimer

func _ready():
	randomize()

	win_label.visible = false
	game_over_label.visible = false
	win_label.z_index = 20
	game_over_label.z_index = 20

	dance_timer.stop()

	create_grid()
	update_ui()

	restart_button.pressed.connect(_on_restart_pressed)
	dance_timer.timeout.connect(_on_dance_timer_timeout)

func update_ui():
	score_label.text = "Score: " + str(score) + "/" + str(target_score) + " | Mistakes: " + str(invalid_moves) + "/" + str(MAX_INVALID_MOVES)
	level_label.text = "Level: " + str(level)

	if level == 1:
		target_label.text = "Goal:\nReach " + str(target_score) + " points"
	elif level == 2:
		target_label.text = "Targets:\nPurple: " + str(purple_count) + "/3\nGreen: " + str(green_count) + "/2\nOrange: " + str(orange_count) + "/2"
	else:
		target_label.text = "Survive:\nCoward tile + chaos board"

func create_grid():
	grid_tiles.clear()

	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			spawn_tile(Vector2i(x, y), colors.pick_random())

func spawn_tile(grid_pos, color_name = ""):
	var tile = tile_scene.instantiate()
	add_child(tile)

	tile.position = grid_to_world(grid_pos)

	if color_name == "":
		color_name = get_spawn_color_for_level()

	tile.setup(color_name, grid_pos)
	tile.tile_clicked.connect(_on_tile_clicked)

	grid_tiles[grid_pos] = tile
	return tile

func get_spawn_color_for_level():
	if level == 2:
		return get_level_two_spawn_color()

	return colors.pick_random()

func get_level_two_spawn_color():
	var needed_ingredients = []

	if purple_count < 3:
		needed_ingredients.append("red")
		needed_ingredients.append("blue")

	if green_count < 2:
		needed_ingredients.append("blue")
		needed_ingredients.append("yellow")

	if orange_count < 2:
		needed_ingredients.append("red")
		needed_ingredients.append("yellow")

	if needed_ingredients.size() > 0:
		return needed_ingredients.pick_random()

	return colors.pick_random()

func grid_to_world(grid_pos):
	return Vector2(
		200 + grid_pos.x * TILE_SIZE,
		120 + grid_pos.y * TILE_SIZE
	)

func _on_tile_clicked(tile):
	if game_won or game_over:
		return

	if level == 3 and tile == coward_tile:
		move_coward_tile()
		add_invalid_move()
		chaos_punish()
		return

	if selected_tile == null:
		selected_tile = tile
		tile.scale = Vector2(1.3, 1.3)
		return

	if selected_tile == tile:
		selected_tile.scale = Vector2.ONE
		selected_tile = null
		return

	if are_tiles_adjacent(selected_tile, tile):
		try_merge(selected_tile, tile)
	else:
		add_invalid_move()

	selected_tile.scale = Vector2.ONE
	selected_tile = null

func are_tiles_adjacent(tile_a, tile_b):
	var difference = tile_a.grid_position - tile_b.grid_position
	return abs(difference.x) + abs(difference.y) == 1

func try_merge(tile_a, tile_b):
	var key = tile_a.tile_color + "+" + tile_b.tile_color

	if merge_rules.has(key):
		var result_color = merge_rules[key]
		var old_position = tile_b.grid_position

		grid_tiles.erase(old_position)

		tile_a.setup(result_color, tile_a.grid_position)
		tile_b.queue_free()

		spawn_tile(old_position)

		score += 10
		merge_sound.play()

		if level == 2:
			update_target_progress(result_color)

		update_ui()
		check_level_progress()

		if level == 3 and not game_won:
			choose_coward_tile()
			chaos_after_merge()
	else:
		add_invalid_move()

func update_target_progress(result_color):
	if result_color == "purple":
		purple_count += 1
	elif result_color == "green":
		green_count += 1
	elif result_color == "orange":
		orange_count += 1

func add_invalid_move():
	invalid_moves += 1
	invalid_sound.play()

	update_ui()
	check_game_over()

	if level == 3 and not game_over:
		chaos_punish()

func check_level_progress():
	if level == 1 and score >= target_score:
		level = 2
		target_score = 120
		score = 0
		invalid_moves = 0

		purple_count = 0
		green_count = 0
		orange_count = 0

		reset_board_for_level_two()
		show_level_message("LEVEL 2:\nCREATE TARGET COLOURS")
		update_ui()
		return

	if level == 2:
		if purple_count >= 3 and green_count >= 2 and orange_count >= 2:
			level = 3
			target_score = 80
			score = 0
			invalid_moves = 0

			reset_board_for_level_three()

			dance_timer.wait_time = 5
			dance_timer.start()

			choose_coward_tile()
			show_level_message("LEVEL 3:\nTHE BOARD CHEATS")
			update_ui()
			return

	if level == 3 and score >= target_score:
		game_won = true
		win_label.text = "YOU SURVIVED\nTHE TILES!"
		win_label.visible = true
		win_sound.play()

func reset_board_for_level_two():
	for tile in grid_tiles.values():
		if tile != null and is_instance_valid(tile):
			tile.queue_free()

	grid_tiles.clear()

	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var grid_pos = Vector2i(x, y)
			spawn_tile(grid_pos, get_level_two_spawn_color())

func reset_board_for_level_three():
	for tile in grid_tiles.values():
		if tile != null and is_instance_valid(tile):
			tile.queue_free()

	grid_tiles.clear()

	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var grid_pos = Vector2i(x, y)
			spawn_tile(grid_pos, colors.pick_random())

func show_level_message(message):
	win_label.text = message
	win_label.visible = true
	await get_tree().create_timer(1.8).timeout

	if not game_won:
		win_label.visible = false

func choose_coward_tile():
	var tiles = get_tree().get_nodes_in_group("tiles")

	if tiles.size() == 0:
		return

	if coward_tile != null and is_instance_valid(coward_tile):
		coward_tile.scale = Vector2.ONE

	coward_tile = tiles.pick_random()
	coward_tile.scale = Vector2(1.2, 1.2)

func move_coward_tile():
	if coward_tile == null or not is_instance_valid(coward_tile):
		return

	var possible_positions = []

	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var grid_pos = Vector2i(x, y)

			if grid_pos != coward_tile.grid_position and grid_tiles.has(grid_pos):
				possible_positions.append(grid_pos)

	if possible_positions.size() == 0:
		return

	var new_pos = possible_positions.pick_random()
	swap_tiles_by_position(coward_tile.grid_position, new_pos)

func _on_dance_timer_timeout():
	if level != 3 or game_won or game_over:
		return

	random_tile_swap()

func chaos_after_merge():
	var chance = randi_range(1, 100)

	if chance <= 60:
		random_tile_swap()

	if chance <= 35:
		random_tile_swap()

func chaos_punish():
	random_tile_swap()
	random_tile_swap()

func random_tile_swap():
	var tiles = get_tree().get_nodes_in_group("tiles")

	if tiles.size() < 2:
		return

	var tile_a = tiles.pick_random()
	var tile_b = tiles.pick_random()

	while tile_a == tile_b:
		tile_b = tiles.pick_random()

	swap_tiles_by_position(tile_a.grid_position, tile_b.grid_position)

func swap_tiles_by_position(pos_a, pos_b):
	if not grid_tiles.has(pos_a) or not grid_tiles.has(pos_b):
		return

	var tile_a = grid_tiles[pos_a]
	var tile_b = grid_tiles[pos_b]

	if tile_a == null or tile_b == null:
		return

	if not is_instance_valid(tile_a) or not is_instance_valid(tile_b):
		return

	grid_tiles[pos_a] = tile_b
	grid_tiles[pos_b] = tile_a

	tile_a.grid_position = pos_b
	tile_b.grid_position = pos_a

	tile_a.position = grid_to_world(pos_b)
	tile_b.position = grid_to_world(pos_a)

func check_game_over():
	if invalid_moves >= MAX_INVALID_MOVES and not game_over:
		game_over = true
		game_over_label.text = "GAME OVER!\nTHE TILES WON."
		game_over_label.visible = true
		game_over_sound.play()

func _on_restart_pressed():
	get_tree().reload_current_scene()
