extends Node2D

# ============================================================
# TILE MERGE MADNESS - GAME MANAGER SCRIPT
# ------------------------------------------------------------
# This script controls the main gameplay flow of the game.
#
# It handles:
# - Level selection
# - Level locking and unlocking
# - Tile spawning
# - Tile merging
# - Score tracking
# - Level objectives
# - Game over and win conditions
# - Level intro and countdown
# - Tile animations
# - Level 3 chaos/ragebait mechanics
# ============================================================


# ============================================================
# 1. BASIC GAME SETTINGS
# ============================================================

# The board is a 4x4 grid.
# This means the game will create 16 tiles in total.
const GRID_SIZE := 4

# This controls the spacing between tiles.
# A bigger value spreads the tiles further apart.
const TILE_SIZE := 90

# The player loses after making this number of wrong moves.
const MAX_INVALID_MOVES := 5


# ============================================================
# 2. TILE SCENE
# ============================================================

# This loads the Tile scene so that the game can create tile
# objects dynamically through code.
var tile_scene = preload("res://scenes/Tile.tscn")


# ============================================================
# 3. GAME STATE VARIABLES
# ============================================================

# Stores the first tile clicked by the player.
# When the player clicks a second tile, the game checks if both
# tiles can merge.
var selected_tile = null

# Stores the special coward tile used in Level 3.
# This tile moves away when the player clicks it.
var coward_tile = null

# Stores all tiles on the board.
# The key is the grid position, for example Vector2i(0, 0).
# The value is the tile object at that position.
var grid_tiles = {}

# Current player score.
var score := 0

# Number of invalid moves made by the player.
var invalid_moves := 0

# Current level being played.
var level := 1

# Score needed to complete the current level.
var target_score := 60

# Becomes true when the player wins the final level.
var game_won := false

# Becomes true when the player loses.
var game_over := false

# Prevents the player from clicking while animations are playing.
# This avoids bugs where the player clicks during tile movement.
var board_animating := false

# Controls which levels are unlocked.
# Level 1 starts unlocked.
# Level 2 unlocks after completing Level 1.
# Level 3 unlocks after completing Level 2.
var max_unlocked_level := 1


# ============================================================
# 4. LEVEL 2 TARGET COUNTERS
# ============================================================

# Level 2 is not completed by score alone.
# The player must create target colours.
# These variables count how many target colours have been created.

var purple_count := 0
var green_count := 0
var orange_count := 0


# ============================================================
# 5. COLOURS AND MERGE RULES
# ============================================================

# These are the basic colours that can spawn naturally.
var colors = ["red", "blue", "yellow"]

# These rules define which tile colours can merge.
#
# Example:
# red + blue = purple
#
# Both orders are included so that red+blue and blue+red
# both work.
var merge_rules = {
	"red+blue": "purple",
	"blue+red": "purple",

	"blue+yellow": "green",
	"yellow+blue": "green",

	"red+yellow": "orange",
	"yellow+red": "orange"
}


# ============================================================
# 6. UI NODE REFERENCES
# ============================================================

# These variables connect this script to UI nodes in Game.tscn.
# @onready means Godot will find the nodes after the scene loads.

@onready var score_label = $ScoreLabel
@onready var level_label = $LevelLabel
@onready var target_label = $TargetLabel
@onready var restart_button = $RestartButton

@onready var win_label = $WinLabel
@onready var game_over_label = $GameOverLabel
@onready var floating_score_label = $FloatingScoreLabel


# ============================================================
# 7. AUDIO NODE REFERENCES
# ============================================================

# These nodes play sound effects during gameplay.

@onready var merge_sound = $MergeSound
@onready var invalid_sound = $InvalidSound
@onready var win_sound = $WinSound
@onready var game_over_sound = $GameOverSound

# This timer is used in Level 3 to trigger random tile movement.
@onready var dance_timer = $DanceTimer


# ============================================================
# 8. LEVEL INTRO UI REFERENCES
# ============================================================

# These nodes control the level introduction popup and countdown.

@onready var level_intro_panel = $LevelIntroPanel
@onready var level_intro_label = $LevelIntroPanel/LevelIntroLabel
@onready var countdown_label = $LevelIntroPanel/CountdownLabel
@onready var start_level_button = $LevelIntroPanel/StartLevelButton


# ============================================================
# 9. LEVEL SELECT UI REFERENCES
# ============================================================

# These nodes control the world map / level select screen.

@onready var level_select_panel = $LevelSelectPanel
@onready var level_1_button = $LevelSelectPanel/Level1Button
@onready var level_2_button = $LevelSelectPanel/Level2Button
@onready var level_3_button = $LevelSelectPanel/Level3Button


# ============================================================
# 10. GAME STARTUP
# ============================================================

func _ready():
	# Makes random choices different each time the game runs.
	randomize()

	# Hide these UI elements at the start.
	win_label.visible = false
	game_over_label.visible = false
	floating_score_label.visible = false
	level_intro_panel.visible = false

	# Show level select first.
	level_select_panel.visible = true

	# Make sure important UI appears above the tiles.
	win_label.z_index = 20
	game_over_label.z_index = 20
	floating_score_label.z_index = 30
	level_select_panel.z_index = 60

	# Stop Level 3 chaos movement until Level 3 starts.
	dance_timer.stop()

	# Create an initial board, but hide it until the player starts.
	create_grid()
	hide_all_tiles()

	# Update all text labels.
	update_ui()
	update_level_select_buttons()

	# Connect button and timer signals to functions.
	# This allows Godot to call these functions when the buttons are pressed.
	restart_button.pressed.connect(_on_restart_pressed)
	dance_timer.timeout.connect(_on_dance_timer_timeout)
	start_level_button.pressed.connect(_on_start_level_pressed)

	level_1_button.pressed.connect(_on_level_1_pressed)
	level_2_button.pressed.connect(_on_level_2_pressed)
	level_3_button.pressed.connect(_on_level_3_pressed)

	# Pause the game while the player is on the level select screen.
	get_tree().paused = true


# ============================================================
# 11. LEVEL SELECT SYSTEM
# ============================================================

func update_level_select_buttons():
	# Level 1 is always available.
	level_1_button.text = "Level 1  ☆☆☆"
	level_1_button.disabled = false

	# Level 2 becomes available only after Level 1 is completed.
	if max_unlocked_level >= 2:
		level_2_button.text = "Level 2  ☆☆☆"
		level_2_button.disabled = false
	else:
		level_2_button.text = "🔒 Level 2"
		level_2_button.disabled = true

	# Level 3 becomes available only after Level 2 is completed.
	if max_unlocked_level >= 3:
		level_3_button.text = "Level 3  ☆☆☆"
		level_3_button.disabled = false
	else:
		level_3_button.text = "🔒 Level 3"
		level_3_button.disabled = true


func unlock_next_level(next_level):
	# Unlocks a new level only if it is higher than the current
	# unlocked level.
	if next_level > max_unlocked_level:
		max_unlocked_level = next_level

	# Refresh the level select buttons so newly unlocked levels appear.
	update_level_select_buttons()


func show_level_select():
	# Shows the player the level select screen.
	level_select_panel.visible = true

	# Hide other gameplay panels.
	level_intro_panel.visible = false
	win_label.visible = false
	game_over_label.visible = false
	floating_score_label.visible = false

	# Hide board tiles while on the menu.
	hide_all_tiles()

	# Refresh locked/unlocked level buttons.
	update_level_select_buttons()

	# Pause gameplay while menu is open.
	get_tree().paused = true


func start_selected_level(selected_level):
	# Unpause temporarily so the level can be prepared.
	get_tree().paused = false

	# Reset common level values.
	level = selected_level
	score = 0
	invalid_moves = 0
	game_won = false
	game_over = false
	board_animating = false
	selected_tile = null
	coward_tile = null

	# Reset Level 2 objective counters.
	purple_count = 0
	green_count = 0
	orange_count = 0

	# Hide messages and menu.
	win_label.visible = false
	game_over_label.visible = false
	floating_score_label.visible = false
	level_select_panel.visible = false

	# Stop chaos timer before preparing any level.
	dance_timer.stop()

	# Prepare the correct level setup.
	if level == 1:
		target_score = 60
		reset_board_normal()

	elif level == 2:
		target_score = 120
		reset_board_for_level_two()

	elif level == 3:
		target_score = 80
		reset_board_for_level_three()

		# Level 3 uses timed random tile movement.
		dance_timer.wait_time = 5
		dance_timer.start()

		# Pick the first coward tile.
		choose_coward_tile()

	# Hide the tiles until the intro countdown finishes.
	hide_all_tiles()

	# Refresh UI text.
	update_ui()

	# Show the level intro popup.
	show_level_intro()


func _on_level_1_pressed():
	start_selected_level(1)


func _on_level_2_pressed():
	# Extra safety check so locked Level 2 cannot start.
	if max_unlocked_level >= 2:
		start_selected_level(2)


func _on_level_3_pressed():
	# Extra safety check so locked Level 3 cannot start.
	if max_unlocked_level >= 3:
		start_selected_level(3)


# ============================================================
# 12. UI UPDATE
# ============================================================

func update_ui():
	# Updates the score and mistakes display.
	score_label.text = "Score: " + str(score) + "/" + str(target_score) + " | Mistakes: " + str(invalid_moves) + "/" + str(MAX_INVALID_MOVES)

	# Updates the current level display.
	level_label.text = "Level: " + str(level)

	# Updates the level objective text.
	if level == 1:
		target_label.text = "Goal:\nReach " + str(target_score) + " points"

	elif level == 2:
		target_label.text = "Targets:\nPurple: " + str(purple_count) + "/3\nGreen: " + str(green_count) + "/2\nOrange: " + str(orange_count) + "/2"

	else:
		target_label.text = "Survive:\nCoward tile + chaos board"


# ============================================================
# 13. BOARD CREATION AND TILE SPAWNING
# ============================================================

func create_grid():
	# Clears any stored board data.
	grid_tiles.clear()

	# Creates a full 4x4 board using random basic colours.
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			spawn_tile(Vector2i(x, y), colors.pick_random(), false)


func hide_all_tiles():
	# Hides all tiles.
	# This is used when showing menus or before the board reveal animation.
	for tile in grid_tiles.values():
		if tile != null and is_instance_valid(tile):
			tile.visible = false


func show_all_tiles_with_animation():
	# Prevent player input while the board reveal animation is playing.
	board_animating = true

	var tile_number := 0

	# Reveal tiles one by one with a small delay.
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var grid_pos = Vector2i(x, y)

			if grid_tiles.has(grid_pos):
				var tile = grid_tiles[grid_pos]

				# Each next tile waits slightly longer before dropping.
				var delay = tile_number * 0.08

				animate_tile_drop(tile, grid_to_world(grid_pos), delay)

				tile_number += 1

	# Wait until all tile animations are likely finished.
	await get_tree().create_timer(1.6).timeout

	# Allow player input again.
	board_animating = false


func spawn_tile(grid_pos, color_name = "", animate := true):
	# Creates a new tile instance from Tile.tscn.
	var tile = tile_scene.instantiate()
	add_child(tile)

	# Convert the tile's grid position to screen position.
	var final_position = grid_to_world(grid_pos)

	# If animation is enabled, the tile starts above the board.
	if animate:
		tile.position = final_position + Vector2(0, -500)
		tile.scale = Vector2(0.85, 0.85)
	else:
		tile.position = final_position
		tile.scale = Vector2.ONE

	# If no colour is provided, choose a colour based on level rules.
	if color_name == "":
		color_name = get_spawn_color_for_level()

	# Set the tile colour and grid position.
	tile.setup(color_name, grid_pos)

	# Connect the tile click signal to the game manager.
	tile.tile_clicked.connect(_on_tile_clicked)

	# Store this tile in the board dictionary.
	grid_tiles[grid_pos] = tile

	# Animate the tile if required.
	if animate:
		animate_tile_drop(tile, final_position, 0.0)

	return tile


func animate_tile_drop(tile, final_position, delay := 0.0):
	# Stop function if the tile no longer exists.
	if tile == null or not is_instance_valid(tile):
		return

	# Prepare tile for drop animation.
	tile.visible = true
	tile.position = final_position + Vector2(0, -500)
	tile.scale = Vector2(0.85, 0.85)

	var tween = create_tween()

	# Allows tween to continue even when the game is paused.
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	# Wait before starting, used for one-by-one tile dropping.
	if delay > 0:
		tween.tween_interval(delay)

	# Move tile down into its final position.
	tween.tween_property(tile, "position", final_position, 0.35)

	# Slight pop animation when the tile lands.
	tween.tween_property(tile, "scale", Vector2(1.12, 1.12), 0.12)
	tween.tween_property(tile, "scale", Vector2.ONE, 0.10)


func grid_to_world(grid_pos):
	# Converts a tile's grid coordinate into an actual screen position.
	#
	# Example:
	# Vector2i(0, 0) becomes the first tile position.
	# Vector2i(1, 0) appears one TILE_SIZE to the right.
	return Vector2(
		200 + grid_pos.x * TILE_SIZE,
		120 + grid_pos.y * TILE_SIZE
	)


# ============================================================
# 14. TILE SPAWNING LOGIC
# ============================================================

func get_spawn_color_for_level():
	# Level 2 needs smart spawning because the player must create
	# specific target colours.
	if level == 2:
		return get_level_two_spawn_color()

	# Level 1 and Level 3 use random basic colours.
	return colors.pick_random()


func get_level_two_spawn_color():
	# This list stores colours that are useful for completing Level 2.
	var needed_ingredients = []

	# To create purple, the player needs red and blue.
	if purple_count < 3:
		needed_ingredients.append("red")
		needed_ingredients.append("blue")

	# To create green, the player needs blue and yellow.
	if green_count < 2:
		needed_ingredients.append("blue")
		needed_ingredients.append("yellow")

	# To create orange, the player needs red and yellow.
	if orange_count < 2:
		needed_ingredients.append("red")
		needed_ingredients.append("yellow")

	# If objectives are still incomplete, spawn a useful colour.
	if needed_ingredients.size() > 0:
		return needed_ingredients.pick_random()

	# If all objectives are complete, spawn randomly.
	return colors.pick_random()


# ============================================================
# 15. TILE CLICKING AND MERGING
# ============================================================

func _on_tile_clicked(tile):
	# Do not allow input if the game is finished or animating.
	if game_won or game_over or board_animating:
		return

	# Level 3 special rule:
	# If the player clicks the coward tile, it moves away and the
	# player receives a mistake.
	if level == 3 and tile == coward_tile:
		move_coward_tile()
		add_invalid_move()
		chaos_punish()
		return

	# If this is the first tile clicked, select it.
	if selected_tile == null:
		selected_tile = tile

		# Enlarge selected tile to show it is active.
		tile.scale = Vector2(1.3, 1.3)
		return

	# If the player clicks the selected tile again, deselect it.
	if selected_tile == tile:
		selected_tile.scale = Vector2.ONE
		selected_tile = null
		return

	# If the second clicked tile is adjacent, try merging.
	if are_tiles_adjacent(selected_tile, tile):
		await try_merge(selected_tile, tile)
	else:
		# Non-adjacent tile selection counts as an invalid move.
		add_invalid_move()

	# Reset selected tile visual size.
	if selected_tile != null and is_instance_valid(selected_tile):
		selected_tile.scale = Vector2.ONE

	selected_tile = null


func are_tiles_adjacent(tile_a, tile_b):
	# Checks if two tiles are beside each other.
	#
	# Valid:
	# left, right, above, below
	#
	# Invalid:
	# diagonal or far apart
	var difference = tile_a.grid_position - tile_b.grid_position

	return abs(difference.x) + abs(difference.y) == 1


func try_merge(tile_a, tile_b):
	# Creates a string key from both selected tile colours.
	# Example: "red+blue"
	var key = tile_a.tile_color + "+" + tile_b.tile_color

	# Check if the selected colours form a valid merge rule.
	if merge_rules.has(key):
		board_animating = true

		# Get the resulting colour from the merge rule.
		var result_color = merge_rules[key]

		# Store tile_b position because a new tile will spawn there.
		var old_position = tile_b.grid_position

		# Used to position the floating +10 text.
		var score_position = (tile_a.position + tile_b.position) / 2

		# Play merge animation before changing the board.
		await animate_merge(tile_a, tile_b)

		# Remove tile_b from the board dictionary.
		grid_tiles.erase(old_position)

		# Change tile_a into the new merged colour.
		tile_a.setup(result_color, tile_a.grid_position)
		tile_a.scale = Vector2.ONE

		# Remove tile_b from the scene.
		tile_b.queue_free()

		# Spawn a new tile in the empty position.
		spawn_tile(old_position)

		# Reward the player.
		score += 10
		merge_sound.play()
		show_floating_score(score_position, 10)

		# Level 2 tracks which target colours have been created.
		if level == 2:
			update_target_progress(result_color)

		# Refresh labels and check if the level is complete.
		update_ui()
		check_level_progress()

		# Level 3 adds chaos after successful merges.
		if level == 3 and not game_won:
			choose_coward_tile()
			chaos_after_merge()

		board_animating = false
	else:
		# If the merge rule does not exist, count it as a mistake.
		add_invalid_move()


func animate_merge(tile_a, tile_b):
	# Save original positions so tile_a can return to its grid cell.
	var original_pos_a = tile_a.position
	var original_pos_b = tile_b.position

	# Find midpoint between the two merging tiles.
	var center_pos = (original_pos_a + original_pos_b) / 2

	var tween = create_tween()
	tween.set_parallel(true)

	# Move both tiles toward the center and shrink them.
	tween.tween_property(tile_a, "position", center_pos, 0.18)
	tween.tween_property(tile_b, "position", center_pos, 0.18)
	tween.tween_property(tile_a, "scale", Vector2(0.75, 0.75), 0.18)
	tween.tween_property(tile_b, "scale", Vector2(0.75, 0.75), 0.18)

	await tween.finished

	# Pop animation to make the merge feel satisfying.
	var pop_tween = create_tween()
	pop_tween.tween_property(tile_a, "scale", Vector2(1.3, 1.3), 0.12)
	pop_tween.tween_property(tile_a, "scale", Vector2.ONE, 0.12)

	await pop_tween.finished

	# Return tile_a to its original cell.
	tile_a.position = original_pos_a


func show_floating_score(start_position, amount):
	# Shows +10 near the merge location.
	floating_score_label.text = "+" + str(amount)
	floating_score_label.position = start_position + Vector2(15, -10)
	floating_score_label.scale = Vector2.ONE
	floating_score_label.modulate.a = 1.0
	floating_score_label.visible = true

	var tween = create_tween()
	tween.set_parallel(true)

	# Move score text upward, fade it out, and slightly enlarge it.
	tween.tween_property(floating_score_label, "position", floating_score_label.position + Vector2(0, -55), 0.7)
	tween.tween_property(floating_score_label, "modulate:a", 0.0, 0.7)
	tween.tween_property(floating_score_label, "scale", Vector2(1.25, 1.25), 0.18)

	await tween.finished

	# Reset label for future use.
	floating_score_label.visible = false
	floating_score_label.modulate.a = 1.0
	floating_score_label.scale = Vector2.ONE


# ============================================================
# 16. LEVEL PROGRESSION AND GAME ENDING
# ============================================================

func update_target_progress(result_color):
	# Level 2 objective tracking.
	#
	# Every time the player creates a required colour,
	# the corresponding counter increases.
	if result_color == "purple":
		purple_count += 1
	elif result_color == "green":
		green_count += 1
	elif result_color == "orange":
		orange_count += 1


func add_invalid_move():
	# Called when the player makes an invalid move.
	invalid_moves += 1

	# Play error feedback.
	invalid_sound.play()

	update_ui()
	check_game_over()

	# Level 3 punishes invalid moves by shuffling tiles.
	if level == 3 and not game_over:
		chaos_punish()


func check_level_progress():
	# Level 1 objective:
	# Reach target score.
	if level == 1 and score >= target_score:
		unlock_next_level(2)
		show_level_select()
		return

	# Level 2 objective:
	# Create the required target colours.
	if level == 2:
		if purple_count >= 3 and green_count >= 2 and orange_count >= 2:
			unlock_next_level(3)
			show_level_select()
			return

	# Level 3 objective:
	# Reach target score and complete all current levels.
	if level == 3 and score >= target_score:
		game_won = true
		win_label.text = "YOU COMPLETED\nALL LEVELS!"
		win_label.visible = true
		win_sound.play()


func check_game_over():
	# If the player reaches the mistake limit, stop the game.
	if invalid_moves >= MAX_INVALID_MOVES and not game_over:
		game_over = true
		game_over_label.text = "GAME OVER!\nTHE TILES WON."
		game_over_label.visible = true
		game_over_sound.play()


# ============================================================
# 17. BOARD RESET FUNCTIONS
# ============================================================

func reset_board_normal():
	# Used for Level 1.
	# Creates a normal random board.
	clear_board()

	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			spawn_tile(Vector2i(x, y), colors.pick_random(), false)


func reset_board_for_level_two():
	# Used for Level 2.
	# Creates a board using useful colours for objectives.
	clear_board()

	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			spawn_tile(Vector2i(x, y), get_level_two_spawn_color(), false)


func reset_board_for_level_three():
	# Used for Level 3.
	# Creates a random board for the chaos level.
	clear_board()

	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			spawn_tile(Vector2i(x, y), colors.pick_random(), false)


func clear_board():
	# Deletes all existing tile objects from the scene.
	for tile in grid_tiles.values():
		if tile != null and is_instance_valid(tile):
			tile.queue_free()

	# Clears the board dictionary.
	grid_tiles.clear()


# ============================================================
# 18. LEVEL INTRO AND COUNTDOWN
# ============================================================

func show_level_intro():
	# Shows the level information popup before gameplay starts.
	level_intro_panel.visible = true
	start_level_button.visible = true
	countdown_label.visible = false

	# Pause the game while the intro is shown.
	get_tree().paused = true

	# Change intro text depending on the current level.
	if level == 1:
		level_intro_label.text = "LEVEL 1\n\nGoal:\nReach 60 points.\n\nMerge adjacent tiles to score."

	elif level == 2:
		level_intro_label.text = "LEVEL 2\n\nGoal:\nCreate target colours.\n\nPurple: 3\nGreen: 2\nOrange: 2"

	else:
		level_intro_label.text = "LEVEL 3\n\nGoal:\nSurvive the ragebait board.\n\nCoward tiles and chaos begin."


func _on_start_level_pressed():
	# Hides the start button and begins countdown.
	start_level_button.visible = false
	start_countdown()


func start_countdown():
	# Countdown prepares the player before the board appears.
	countdown_label.visible = true

	countdown_label.text = "3"
	await get_tree().create_timer(0.7, true, false, true).timeout

	countdown_label.text = "2"
	await get_tree().create_timer(0.7, true, false, true).timeout

	countdown_label.text = "1"
	await get_tree().create_timer(0.7, true, false, true).timeout

	countdown_label.text = "GO!"
	await get_tree().create_timer(0.5, true, false, true).timeout

	# Hide intro UI and start gameplay.
	countdown_label.visible = false
	level_intro_panel.visible = false
	get_tree().paused = false

	# Reveal board with tile drop animation.
	await show_all_tiles_with_animation()


# ============================================================
# 19. LEVEL 3 CHAOS / RAGEBAIT SYSTEM
# ============================================================

func choose_coward_tile():
	# Picks one random tile to become the coward tile.
	# The coward tile runs away when clicked.
	var tiles = get_tree().get_nodes_in_group("tiles")

	if tiles.size() == 0:
		return

	# Reset previous coward tile size.
	if coward_tile != null and is_instance_valid(coward_tile):
		coward_tile.scale = Vector2.ONE

	# Choose a new coward tile.
	coward_tile = tiles.pick_random()

	# Enlarge it slightly so the player notices it.
	coward_tile.scale = Vector2(1.2, 1.2)


func move_coward_tile():
	# Moves the coward tile by swapping it with another random tile.
	if coward_tile == null or not is_instance_valid(coward_tile):
		return

	var possible_positions = []

	# Collect all possible positions except the coward tile's current position.
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var grid_pos = Vector2i(x, y)

			if grid_pos != coward_tile.grid_position and grid_tiles.has(grid_pos):
				possible_positions.append(grid_pos)

	if possible_positions.size() == 0:
		return

	# Pick a random position and swap the coward tile there.
	var new_pos = possible_positions.pick_random()
	swap_tiles_by_position(coward_tile.grid_position, new_pos)


func _on_dance_timer_timeout():
	# In Level 3, the board occasionally swaps tiles on its own.
	if level != 3 or game_won or game_over or board_animating:
		return

	random_tile_swap()


func chaos_after_merge():
	# Adds unpredictable tile movement after successful Level 3 merges.
	var chance = randi_range(1, 100)

	# 60% chance for one swap.
	if chance <= 60:
		random_tile_swap()

	# 35% chance for an additional swap.
	if chance <= 35:
		random_tile_swap()


func chaos_punish():
	# Punishes mistakes in Level 3 by swapping two pairs of tiles.
	random_tile_swap()
	random_tile_swap()


func random_tile_swap():
	# Selects two random tiles and swaps their board positions.
	var tiles = get_tree().get_nodes_in_group("tiles")

	if tiles.size() < 2:
		return

	var tile_a = tiles.pick_random()
	var tile_b = tiles.pick_random()

	# Make sure the same tile is not picked twice.
	while tile_a == tile_b:
		tile_b = tiles.pick_random()

	swap_tiles_by_position(tile_a.grid_position, tile_b.grid_position)


func swap_tiles_by_position(pos_a, pos_b):
	# Makes sure both positions exist.
	if not grid_tiles.has(pos_a) or not grid_tiles.has(pos_b):
		return

	var tile_a = grid_tiles[pos_a]
	var tile_b = grid_tiles[pos_b]

	# Safety checks.
	if tile_a == null or tile_b == null:
		return

	if not is_instance_valid(tile_a) or not is_instance_valid(tile_b):
		return

	# Swap the tiles in the dictionary.
	grid_tiles[pos_a] = tile_b
	grid_tiles[pos_b] = tile_a

	# Update each tile's stored grid position.
	tile_a.grid_position = pos_b
	tile_b.grid_position = pos_a

	# Move each tile visually to its new location.
	tile_a.position = grid_to_world(pos_b)
	tile_b.position = grid_to_world(pos_a)


# ============================================================
# 20. RESTART BUTTON
# ============================================================

func _on_restart_pressed():
	# Restart does not reset progress.
	# It simply returns the player to the level select screen.
	show_level_select()
