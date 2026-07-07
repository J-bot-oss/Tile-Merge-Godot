extends Node2D

# ============================================================
# TILE MERGE MADNESS - GAME MANAGER SCRIPT
# ============================================================
# This script controls the main game scene.
#
# It handles:
# - Level selection
# - Level locking and unlocking
# - Saving and loading progress
# - Tile spawning
# - Tile clicking and merging (now with recursive color tiers)
# - Scoring
# - Star ratings
# - Level objectives
# - Level complete screen
# - Game over and win conditions
# - Level intro and countdown
# - Tile animations
# - Level 3 chaos/ragebait mechanics
# ============================================================


# ============================================================
# 1. BASIC GAME SETTINGS
# ============================================================

const GRID_SIZE := 4
const TILE_SIZE := 90
const MAX_INVALID_MOVES := 5

const SAVE_PATH := "user://tile_merge_save.json"


# ============================================================
# 2. TILE SCENE
# ============================================================

var tile_scene = preload("res://scenes/Tile.tscn")


# ============================================================
# 3. GAME STATE VARIABLES
# ============================================================

var selected_tile = null
var coward_tile = null
var grid_tiles = {}

var score := 0
var invalid_moves := 0
var level := 1
var target_score := 60

var game_won := false
var game_over := false
var board_animating := false

var max_unlocked_level := 1

var level_stars = {
	1: 0,
	2: 0,
	3: 0
}


# ============================================================
# 4. LEVEL 2 OBJECTIVE COUNTERS
# ============================================================
# NOTE: these only track the FIRST-TIER creation of each secondary
# color (i.e. a primary+primary merge). If the player later merges
# that secondary tile again into a tertiary tile, these counts stay
# exactly as they were — the objective was already satisfied.

var purple_count := 0
var green_count := 0
var orange_count := 0


# ============================================================
# 5. TILE COLOURS AND MERGE RULES (a real color-wheel tree)
# ============================================================

# Only the base spawnable colors. Everything above Tier 1 is only
# ever created by merging - never spawned directly on the board.
var colors = ["red", "blue", "yellow"]

# color_data holds everything needed to describe and render every
# color in the game: which tier it belongs to, and the actual
# colors to use for its visuals. Tier drives bonus scoring too.
#
# This follows a real artist's color wheel:
#   Tier 1 Primary:    Red, Yellow, Blue
#   Tier 2 Secondary:  Orange, Green, Purple (primary + primary)
#   Tier 3 Tertiary:   Vermilion, Amber, Chartreuse, Teal, Violet,
#                       Magenta (a primary + its NEIGHBORING secondary)
#   Tier 4 Prism:      merging two COMPLEMENTARY (opposite-on-the-
#                       wheel) tertiary colors neutralizes them into
#                       the ultimate Prism tile - same principle as
#                       complementary colors mixing to white/gray.
#
# To extend further later: add new entries here + new pair(s) in
# merge_rules below. Nothing else in the game needs to change.
var color_data = {
	# ---- Tier 1 : Primary (spawnable) ----
	"red":         { "tier": 1, "value": Color(0.90, 0.16, 0.16), "accent": Color(1.00, 0.55, 0.50) },
	"yellow":      { "tier": 1, "value": Color(0.98, 0.85, 0.20), "accent": Color(1.00, 0.95, 0.60) },
	"blue":        { "tier": 1, "value": Color(0.15, 0.35, 0.85), "accent": Color(0.55, 0.70, 1.00) },

	# ---- Tier 2 : Secondary ----
	"orange":      { "tier": 2, "value": Color(0.95, 0.55, 0.10), "accent": Color(1.00, 0.75, 0.40) },
	"green":       { "tier": 2, "value": Color(0.20, 0.65, 0.35), "accent": Color(0.55, 0.90, 0.60) },
	"purple":      { "tier": 2, "value": Color(0.50, 0.20, 0.70), "accent": Color(0.75, 0.55, 0.90) },

	# ---- Tier 3 : Tertiary (primary + neighboring secondary) ----
	"vermilion":   { "tier": 3, "value": Color(0.90, 0.35, 0.15), "accent": Color(1.00, 0.60, 0.40) },
	"amber":       { "tier": 3, "value": Color(0.92, 0.68, 0.15), "accent": Color(1.00, 0.85, 0.50) },
	"chartreuse":  { "tier": 3, "value": Color(0.60, 0.80, 0.20), "accent": Color(0.80, 0.95, 0.50) },
	"teal":        { "tier": 3, "value": Color(0.15, 0.60, 0.55), "accent": Color(0.50, 0.85, 0.80) },
	"violet":      { "tier": 3, "value": Color(0.38, 0.25, 0.75), "accent": Color(0.65, 0.55, 0.95) },
	"magenta":     { "tier": 3, "value": Color(0.80, 0.20, 0.55), "accent": Color(0.95, 0.55, 0.80) },

	# ---- Tier 4 : Prism (the ultimate tile - endgame) ----
	"prism":       { "tier": 4, "value": Color(1.00, 0.92, 0.50), "accent": Color(1.00, 1.00, 1.00) },
}

# Bonus points awarded per tier of the RESULT color of a merge.
# Tier 2 stays at 10 on purpose, so Level 1 (target 60) and
# Level 3 (target 80) balance is completely unchanged from before.
var tier_score_bonus = {
	2: 10,
	3: 25,
	4: 100
}

# merge_rules is keyed by an order-independent "colorA+colorB" key
# (built via get_merge_key so "red+blue" and "blue+red" both work).
var merge_rules = {
	# Tier 1 + Tier 1 -> Tier 2
	"blue+red": "purple",
	"blue+yellow": "green",
	"red+yellow": "orange",

	# Tier 1 + Tier 2 -> Tier 3 (primary + its neighboring secondary)
	"orange+red": "vermilion",
	"purple+red": "magenta",
	"orange+yellow": "amber",
	"green+yellow": "chartreuse",
	"blue+green": "teal",
	"blue+purple": "violet",

	# Tier 3 + Tier 3 -> Tier 4 (complementary pairs neutralize into Prism)
	"teal+vermilion": "prism",
	"amber+violet": "prism",
	"chartreuse+magenta": "prism",
}


# ============================================================
# 6. UI REFERENCES
# ============================================================

@onready var hud_layer = $HUDLayer
@onready var menu_layer = $MenuLayer

@onready var score_label = $HUDLayer/ScoreLabel
@onready var level_label = $HUDLayer/LevelLabel
@onready var target_label = $TargetLabel
@onready var restart_button = $HUDLayer/RestartButton
@onready var win_label = $HUDLayer/WinLabel
@onready var game_over_label = $GameOverLabel
@onready var floating_score_label = $EffectsLayer/FloatingScoreLabel

@onready var merge_sound = $AudioLayer/MergeSound
@onready var invalid_sound = $AudioLayer/InvalidSound
@onready var win_sound = $AudioLayer/WinSound
@onready var game_over_sound = $AudioLayer/GameOverSound
@onready var dance_timer = $DanceTimer

@onready var level_intro_panel = $PopupLayer/LevelIntroPanel
@onready var level_intro_label = $PopupLayer/LevelIntroPanel/LevelIntroLabel
@onready var countdown_label = $PopupLayer/LevelIntroPanel/CountdownLabel
@onready var start_level_button = $PopupLayer/LevelIntroPanel/StartLevelButton

@onready var level_select_panel = $MenuLayer/LevelSelectPanel
@onready var level_1_button = $MenuLayer/LevelSelectPanel/Level1Button
@onready var level_2_button = $MenuLayer/LevelSelectPanel/Level2Button
@onready var level_3_button = $MenuLayer/LevelSelectPanel/Level3Button

# Level complete popup UI.
# This appears after the player successfully finishes a level.
@onready var level_complete_panel = $PopupLayer/LevelCompletePanel
@onready var level_complete_title = $PopupLayer/LevelCompletePanel/LevelCompleteTitle
@onready var level_complete_stars = $PopupLayer/LevelCompletePanel/LevelCompleteStars
@onready var level_complete_stats = $PopupLayer/LevelCompletePanel/LevelCompleteStats
@onready var continue_button = $PopupLayer/LevelCompletePanel/ContinueButton


# ============================================================
# 7. GAME STARTUP
# ============================================================

func _ready():
	randomize()

	hud_layer.visible = false
	menu_layer.visible = true

	win_label.visible = true
	game_over_label.visible = false
	floating_score_label.visible = false
	level_intro_panel.visible = false
	level_complete_panel.visible = false

	level_select_panel.visible = true

	win_label.z_index = 20
	game_over_label.z_index = 20
	floating_score_label.z_index = 30
	level_select_panel.z_index = 60
	level_complete_panel.z_index = 70

	dance_timer.stop()

	load_progress()

	create_grid()
	hide_all_tiles()

	update_ui()
	update_level_select_buttons()

	restart_button.pressed.connect(_on_restart_pressed)
	dance_timer.timeout.connect(_on_dance_timer_timeout)
	start_level_button.pressed.connect(_on_start_level_pressed)
	continue_button.pressed.connect(_on_continue_pressed)

	level_1_button.pressed.connect(_on_level_1_pressed)
	level_2_button.pressed.connect(_on_level_2_pressed)
	level_3_button.pressed.connect(_on_level_3_pressed)

	get_tree().paused = true


# ============================================================
# 8. LEVEL SELECT SYSTEM
# ============================================================

func get_star_text(level_number):
	var stars = level_stars[level_number]

	if stars == 3:
		return "★★★"
	elif stars == 2:
		return "★★☆"
	elif stars == 1:
		return "★☆☆"
	else:
		return "☆☆☆"


func update_level_select_buttons():
	level_1_button.text = "Level 1  " + get_star_text(1)
	level_1_button.disabled = false

	if max_unlocked_level >= 2:
		level_2_button.text = "Level 2  " + get_star_text(2)
		level_2_button.disabled = false
	else:
		level_2_button.text = "🔒 Level 2"
		level_2_button.disabled = true

	if max_unlocked_level >= 3:
		level_3_button.text = "Level 3  " + get_star_text(3)
		level_3_button.disabled = false
	else:
		level_3_button.text = "🔒 Level 3"
		level_3_button.disabled = true


func unlock_next_level(next_level):
	if next_level > max_unlocked_level:
		max_unlocked_level = next_level
		save_progress()

	update_level_select_buttons()


func show_level_select():
	hud_layer.visible = false
	menu_layer.visible = true

	level_select_panel.visible = true
	level_intro_panel.visible = false
	level_complete_panel.visible = false
	win_label.visible = false
	game_over_label.visible = false
	floating_score_label.visible = false

	hide_all_tiles()
	update_level_select_buttons()

	get_tree().paused = true


func start_selected_level(selected_level):
	get_tree().paused = false

	hud_layer.visible = true
	menu_layer.visible = false

	level = selected_level
	score = 0
	invalid_moves = 0
	game_won = false
	game_over = false
	board_animating = false
	selected_tile = null
	coward_tile = null

	purple_count = 0
	green_count = 0
	orange_count = 0

	win_label.visible = false
	game_over_label.visible = false
	floating_score_label.visible = false
	level_select_panel.visible = false
	level_complete_panel.visible = false

	dance_timer.stop()

	if level == 1:
		target_score = 60
		reset_board_normal()

	elif level == 2:
		target_score = 120
		reset_board_for_level_two()

	elif level == 3:
		target_score = 80
		reset_board_for_level_three()

		dance_timer.wait_time = 5
		dance_timer.start()

		choose_coward_tile()

	hide_all_tiles()

	update_ui()
	show_level_intro()


func _on_level_1_pressed():
	start_selected_level(1)


func _on_level_2_pressed():
	if max_unlocked_level >= 2:
		start_selected_level(2)


func _on_level_3_pressed():
	if max_unlocked_level >= 3:
		start_selected_level(3)


# ============================================================
# 9. UI UPDATE
# ============================================================

func update_ui():
	score_label.text = "Score: " + str(score) + "/" + str(target_score) + " | Mistakes: " + str(invalid_moves) + "/" + str(MAX_INVALID_MOVES)
	level_label.text = "Level: " + str(level)

	if level == 1:
		target_label.text = "Goal:\nReach " + str(target_score) + " points"

	elif level == 2:
		target_label.text = "Targets:\nPurple: " + str(purple_count) + "/3\nGreen: " + str(green_count) + "/2\nOrange: " + str(orange_count) + "/2"

	else:
		target_label.text = "Survive:\nCoward tile + chaos board"


# ============================================================
# 10. BOARD CREATION AND TILE SPAWNING
# ============================================================

func create_grid():
	grid_tiles.clear()

	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			spawn_tile(Vector2i(x, y), colors.pick_random(), false)


func hide_all_tiles():
	for tile in grid_tiles.values():
		if tile != null and is_instance_valid(tile):
			tile.visible = false


func show_all_tiles_with_animation():
	board_animating = true

	var tile_number := 0

	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var grid_pos = Vector2i(x, y)

			if grid_tiles.has(grid_pos):
				var tile = grid_tiles[grid_pos]
				var delay = tile_number * 0.08

				animate_tile_drop(tile, grid_to_world(grid_pos), delay)
				tile_number += 1

	await get_tree().create_timer(1.6).timeout
	board_animating = false


func spawn_tile(grid_pos, color_name = "", animate := true):
	var tile = tile_scene.instantiate()
	add_child(tile)

	var final_position = grid_to_world(grid_pos)

	if animate:
		tile.position = final_position + Vector2(0, -500)
		tile.scale = Vector2(0.85, 0.85)
	else:
		tile.position = final_position
		tile.scale = Vector2.ONE

	if color_name == "":
		color_name = get_spawn_color_for_level()

	tile.setup(color_name, grid_pos)
	tile.tile_clicked.connect(_on_tile_clicked)

	grid_tiles[grid_pos] = tile

	if animate:
		animate_tile_drop(tile, final_position, 0.0)

	return tile


func animate_tile_drop(tile, final_position, delay := 0.0):
	if tile == null or not is_instance_valid(tile):
		return

	tile.visible = true
	tile.position = final_position + Vector2(0, -500)
	tile.scale = Vector2(0.85, 0.85)

	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	if delay > 0:
		tween.tween_interval(delay)

	tween.tween_property(tile, "position", final_position, 0.35)
	tween.tween_property(tile, "scale", Vector2(1.12, 1.12), 0.12)
	tween.tween_property(tile, "scale", Vector2.ONE, 0.10)


func grid_to_world(grid_pos):
	return Vector2(
		200 + grid_pos.x * TILE_SIZE,
		120 + grid_pos.y * TILE_SIZE
	)


# ============================================================
# 11. TILE SPAWNING LOGIC
# ============================================================
# NOTE: the board only ever SPAWNS Tier 1 (primary) colors.
# Every higher tier only ever appears as the result of a merge.

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


# ============================================================
# 12. TILE CLICKING AND MERGING
# ============================================================

func _on_tile_clicked(tile):
	if game_won or game_over or board_animating:
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
		await try_merge(selected_tile, tile)
	else:
		add_invalid_move()

	if selected_tile != null and is_instance_valid(selected_tile):
		selected_tile.scale = Vector2.ONE

	selected_tile = null


func are_tiles_adjacent(tile_a, tile_b):
	var difference = tile_a.grid_position - tile_b.grid_position
	return abs(difference.x) + abs(difference.y) == 1


# Builds an order-independent key so "red+blue" and "blue+red" are
# treated as the same merge, without needing duplicate dictionary
# entries for every reversed pair.
func get_merge_key(color_a, color_b):
	var pair = [color_a, color_b]
	pair.sort()
	return pair[0] + "+" + pair[1]


func try_merge(tile_a, tile_b):
	var key = get_merge_key(tile_a.tile_color, tile_b.tile_color)

	if merge_rules.has(key):
		board_animating = true

		var result_color = merge_rules[key]
		var old_position = tile_b.grid_position
		var score_position = (tile_a.position + tile_b.position) / 2

		await animate_merge(tile_a, tile_b)

		grid_tiles.erase(old_position)

		tile_a.setup(result_color, tile_a.grid_position)
		tile_a.scale = Vector2.ONE

		tile_b.queue_free()

		spawn_tile(old_position)

		var result_tier = 1
		if color_data.has(result_color):
			result_tier = color_data[result_color]["tier"]

		var points_earned = tier_score_bonus.get(result_tier, 10)

		score += points_earned
		merge_sound.play()
		show_floating_score(score_position, points_earned)

		if level == 2:
			update_target_progress(result_color)

		update_ui()
		check_level_progress()

		if level == 3 and not game_won:
			choose_coward_tile()
			chaos_after_merge()

		board_animating = false
	else:
		add_invalid_move()


func animate_merge(tile_a, tile_b):
	var original_pos_a = tile_a.position
	var original_pos_b = tile_b.position
	var center_pos = (original_pos_a + original_pos_b) / 2

	var tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(tile_a, "position", center_pos, 0.18)
	tween.tween_property(tile_b, "position", center_pos, 0.18)
	tween.tween_property(tile_a, "scale", Vector2(0.75, 0.75), 0.18)
	tween.tween_property(tile_b, "scale", Vector2(0.75, 0.75), 0.18)

	await tween.finished

	var pop_tween = create_tween()
	pop_tween.tween_property(tile_a, "scale", Vector2(1.3, 1.3), 0.12)
	pop_tween.tween_property(tile_a, "scale", Vector2.ONE, 0.12)

	await pop_tween.finished

	tile_a.position = original_pos_a


func show_floating_score(start_position, amount):
	floating_score_label.text = "+" + str(amount)
	floating_score_label.position = start_position + Vector2(15, -10)
	floating_score_label.scale = Vector2.ONE
	floating_score_label.modulate.a = 1.0
	floating_score_label.visible = true

	var tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(floating_score_label, "position", floating_score_label.position + Vector2(0, -55), 0.7)
	tween.tween_property(floating_score_label, "modulate:a", 0.0, 0.7)
	tween.tween_property(floating_score_label, "scale", Vector2(1.25, 1.25), 0.18)

	await tween.finished

	floating_score_label.visible = false
	floating_score_label.modulate.a = 1.0
	floating_score_label.scale = Vector2.ONE


# ============================================================
# 13. LEVEL PROGRESSION, STARS, AND COMPLETE SCREEN
# ============================================================

func calculate_stars():
	if invalid_moves == 0:
		return 3
	elif invalid_moves <= 2:
		return 2
	else:
		return 1


func get_star_display(stars):
	if stars == 3:
		return "★★★"
	elif stars == 2:
		return "★★☆"
	elif stars == 1:
		return "★☆☆"

	return "☆☆☆"


func save_level_stars(completed_level):
	var stars_earned = calculate_stars()

	if stars_earned > level_stars[completed_level]:
		level_stars[completed_level] = stars_earned
		save_progress()


func show_level_complete(completed_level):
	# Calculate how many stars the player earned based on mistakes.
	var stars_earned = calculate_stars()

	# Save the player's best star rating for this level.
	save_level_stars(completed_level)

	# Unlock the next level if the completed level is not the final level.
	if completed_level < 3:
		unlock_next_level(completed_level + 1)

	# Prepare the level complete panel text.
	level_complete_title.text = "LEVEL " + str(completed_level) + " COMPLETE!"
	level_complete_stats.text = "Score: " + str(score) + "\nMistakes: " + str(invalid_moves)

	# Start with empty stars before revealing them.
	level_complete_stars.text = "☆☆☆"

	# Disable Continue while the star animation is playing.
	continue_button.disabled = true

	# Show the panel and pause gameplay.
	level_complete_panel.visible = true
	get_tree().paused = true

	# Reveal stars one by one.
	await animate_star_reveal(stars_earned)

	# Allow the player to continue after the reward animation finishes.
	continue_button.disabled = false

func animate_star_reveal(stars_earned):
	# This function reveals the earned stars one by one.
	# It makes level completion feel more rewarding than showing all stars instantly.
	#
	# Example:
	# 0. Start: ☆☆☆
	# 1. First reveal: ★☆☆
	# 2. Second reveal: ★★☆
	# 3. Third reveal: ★★★

	var current_display := "☆☆☆"

	for i in range(stars_earned):
		await get_tree().create_timer(0.35, true).timeout

		if i == 0:
			current_display = "★☆☆"
		elif i == 1:
			current_display = "★★☆"
		elif i == 2:
			current_display = "★★★"

		level_complete_stars.text = current_display

		# Small pop animation for the star label.
		level_complete_stars.scale = Vector2(1.35, 1.35)

		var tween = create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(level_complete_stars, "scale", Vector2.ONE, 0.18)

		await tween.finished


func _on_continue_pressed():
	level_complete_panel.visible = false
	show_level_select()


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
		show_level_complete(1)
		return

	if level == 2:
		if purple_count >= 3 and green_count >= 2 and orange_count >= 2:
			show_level_complete(2)
			return

	if level == 3 and score >= target_score:
		show_level_complete(3)
		return


func check_game_over():
	if invalid_moves >= MAX_INVALID_MOVES and not game_over:
		game_over = true
		game_over_label.text = "GAME OVER!\nTHE TILES WON."
		game_over_label.visible = true
		game_over_sound.play()


# ============================================================
# 14. BOARD RESET FUNCTIONS
# ============================================================

func reset_board_normal():
	clear_board()

	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			spawn_tile(Vector2i(x, y), colors.pick_random(), false)


func reset_board_for_level_two():
	clear_board()

	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			spawn_tile(Vector2i(x, y), get_level_two_spawn_color(), false)


func reset_board_for_level_three():
	clear_board()

	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			spawn_tile(Vector2i(x, y), colors.pick_random(), false)


func clear_board():
	for tile in grid_tiles.values():
		if tile != null and is_instance_valid(tile):
			tile.queue_free()

	grid_tiles.clear()


# ============================================================
# 15. LEVEL INTRO AND COUNTDOWN
# ============================================================

func show_level_intro():
	level_intro_panel.visible = true
	start_level_button.visible = true
	countdown_label.visible = false

	get_tree().paused = true

	if level == 1:
		level_intro_label.text = "LEVEL 1\n\nGoal:\nReach 60 points.\n\nMerge adjacent tiles to score.\nChain secondary colors into rarer ones for big bonus points!"

	elif level == 2:
		level_intro_label.text = "LEVEL 2\n\nGoal:\nCreate target colours.\n\nPurple: 3\nGreen: 2\nOrange: 2"

	else:
		level_intro_label.text = "LEVEL 3\n\nGoal:\nSurvive the ragebait board.\n\nCoward tiles and chaos begin."


func _on_start_level_pressed():
	start_level_button.visible = false
	start_countdown()


func start_countdown():
	countdown_label.visible = true

	countdown_label.text = "3"
	await get_tree().create_timer(0.7, true, false, true).timeout

	countdown_label.text = "2"
	await get_tree().create_timer(0.7, true, false, true).timeout

	countdown_label.text = "1"
	await get_tree().create_timer(0.7, true, false, true).timeout

	countdown_label.text = "GO!"
	await get_tree().create_timer(0.5, true, false, true).timeout

	countdown_label.visible = false
	level_intro_panel.visible = false
	get_tree().paused = false

	await show_all_tiles_with_animation()


# ============================================================
# 16. LEVEL 3 CHAOS SYSTEM
# ============================================================

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
	if level != 3 or game_won or game_over or board_animating:
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


# ============================================================
# 17. COLOR DATA ACCESSORS (for Tile.gd visuals to use)
# ============================================================
# Once you send me Tile.gd, these are what its polished visuals
# will call into - e.g. get_node("/root/Game").get_color_value("indigo")
# depending on your scene root node name.

func get_color_value(color_name: String) -> Color:
	if color_data.has(color_name):
		return color_data[color_name]["value"]
	return Color.WHITE


func get_color_accent(color_name: String) -> Color:
	if color_data.has(color_name):
		return color_data[color_name]["accent"]
	return Color.WHITE


func get_color_tier(color_name: String) -> int:
	if color_data.has(color_name):
		return color_data[color_name]["tier"]
	return 1


# ============================================================
# 18. SAVE SYSTEM
# ============================================================

func save_progress():
	var save_data = {
		"max_unlocked_level": max_unlocked_level,
		"level_stars": {
			"1": level_stars[1],
			"2": level_stars[2],
			"3": level_stars[3]
		}
	}

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file != null:
		file.store_string(JSON.stringify(save_data))
		file.close()


func load_progress():
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)

	if file != null:
		var content = file.get_as_text()
		file.close()

		var data = JSON.parse_string(content)

		if data != null:
			if data.has("max_unlocked_level"):
				max_unlocked_level = int(data["max_unlocked_level"])

			if data.has("level_stars"):
				var saved_stars = data["level_stars"]

				if saved_stars.has("1"):
					level_stars[1] = int(saved_stars["1"])

				if saved_stars.has("2"):
					level_stars[2] = int(saved_stars["2"])

				if saved_stars.has("3"):
					level_stars[3] = int(saved_stars["3"])


# ============================================================
# 19. RESTART BUTTON
# ============================================================

func _on_restart_pressed():
	show_level_select()
