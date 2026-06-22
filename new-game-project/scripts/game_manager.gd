extends Node2D

const GRID_SIZE := 4
const TILE_SIZE := 90

var tile_scene = preload("res://scenes/Tile.tscn")
var selected_tile = null
var score := 0

var colors = ["red", "blue", "yellow"]

var merge_rules = {
	"red+blue": "purple",
	"blue+red": "purple",
	"blue+yellow": "green",
	"yellow+blue": "green",
	"red+yellow": "orange",
	"yellow+red": "orange"
}

func _ready():
	create_grid()

func create_grid():
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var tile = tile_scene.instantiate()
			add_child(tile)
			tile.position = Vector2(200 + x * TILE_SIZE, 120 + y * TILE_SIZE)
			tile.setup(colors.pick_random(), Vector2i(x, y))
			tile.tile_clicked.connect(_on_tile_clicked)

func _on_tile_clicked(tile):
	print("Selected: ", tile.tile_color)

	if selected_tile == null:
		selected_tile = tile
		tile.scale = Vector2(1.15, 1.15)
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
		tile_a.setup(merge_rules[key], tile_a.grid_position)
		tile_b.queue_free()
		score += 10
		print("Merged! Score: ", score)
	else:
		print("Invalid merge")
