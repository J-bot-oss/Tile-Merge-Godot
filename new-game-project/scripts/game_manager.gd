extends Node2D

const GRID_SIZE := 4
const TILE_SIZE := 90
const WIN_SCORE := 100
const MAX_INVALID_MOVES := 5

var tile_scene = preload("res://scenes/Tile.tscn")
var selected_tile = null
var coward_tile = null

var score := 0
var invalid_moves := 0
var game_won := false
var game_over := false

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
@onready var restart_button = $RestartButton
@onready var win_label = $WinLabel
@onready var game_over_label = $GameOverLabel

@onready var merge_sound = $MergeSound
@onready var invalid_sound = $InvalidSound
@onready var win_sound = $WinSound
@onready var game_over_sound = $GameOverSound

func _ready():
	win_label.visible = false
	game_over_label.visible = false
	win_label.z_index = 10
	game_over_label.z_index = 10

	create_grid()
	update_score()
	choose_coward_tile()

	restart_button.pressed.connect(_on_restart_pressed)

func update_score():
	score_label.text = "Score: " + str(score) + " | Mistakes: " + str(invalid_moves) + "/" + str(MAX_INVALID_MOVES)

func create_grid():
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			spawn_tile(Vector2i(x, y))

func spawn_tile(grid_pos):
	var tile = tile_scene.instantiate()
	add_child(tile)

	tile.position = grid_to_world(grid_pos)
	tile.setup(colors.pick_random(), grid_pos)
	tile.tile_clicked.connect(_on_tile_clicked)

	return tile

func grid_to_world(grid_pos):
	return Vector2(
		200 + grid_pos.x * TILE_SIZE,
		120 + grid_pos.y * TILE_SIZE
	)

func _on_tile_clicked(tile):
	if game_won or game_over:
		return

	if tile == coward_tile:
		move_coward_tile()
		return

	if selected_tile == null:
		selected_tile = tile
		tile.scale = Vector2(1.3, 1.3)
		return

	if selected_tile == tile:
		selected_tile.scale = Vector2.ONE
		selected_tile = null
		return

	try_merge(selected_tile, tile)

	selected_tile.scale = Vector2.ONE
	selected_tile = null

func try_merge(tile_a, tile_b):
	var key = tile_a.tile_color + "+" + tile_b.tile_color

	if merge_rules.has(key):
		var old_position = tile_b.grid_position

		tile_a.setup(merge_rules[key], tile_a.grid_position)
		tile_b.queue_free()
		spawn_tile(old_position)

		score += 10
		merge_sound.play()

		update_score()
		check_win()
		choose_coward_tile()
	else:
		invalid_moves += 1
		invalid_sound.play()

		update_score()
		check_game_over()

func choose_coward_tile():
	var tiles = get_tree().get_nodes_in_group("tiles")

	if tiles.size() == 0:
		return

	coward_tile = tiles.pick_random()
	coward_tile.scale = Vector2(1.15, 1.15)

func move_coward_tile():
	if coward_tile == null:
		return

	var new_pos = Vector2i(
		randi_range(0, GRID_SIZE - 1),
		randi_range(0, GRID_SIZE - 1)
	)

	coward_tile.grid_position = new_pos
	coward_tile.position = grid_to_world(new_pos)

	print("Coward tile ran away!")

func check_win():
	if score >= WIN_SCORE and not game_won:
		game_won = true
		win_label.visible = true
		win_sound.play()

func check_game_over():
	if invalid_moves >= MAX_INVALID_MOVES and not game_over:
		game_over = true
		game_over_label.visible = true
		game_over_sound.play()

func _on_restart_pressed():
	get_tree().reload_current_scene()
