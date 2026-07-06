extends Node

# ============================================================
# TILE MERGE MADNESS - SAVE MANAGER
# ============================================================
# PURPOSE
# -------
# This script is responsible for saving and loading player
# progress.
#
# RESPONSIBILITIES
# ----------------
# - Save the highest unlocked level.
# - Save the player's coin total.
# - Save the best star rating for each level.
# - Load saved data when the game starts.
#
# WHY THIS MANAGER EXISTS
# -----------------------
# Saving is not gameplay logic, so it should not stay inside
# GameManager forever.
#
# Moving saving and loading here makes the project cleaner,
# easier to maintain, and easier to expand when we later add
# energy, gems, shop items, achievements, or settings.
# ============================================================


# ============================================================
# 1. SAVE FILE SETTINGS
# ============================================================

# Godot's user:// path stores data safely on the player's device.
#
# This file will contain the player's progress in JSON format.
# Example saved data:
#
# {
#   "max_unlocked_level": 2,
#   "coins": 150,
#   "level_stars": {
#     "1": 3,
#     "2": 1,
#     "3": 0
#   }
# }
const SAVE_PATH := "user://tile_merge_save.json"


# ============================================================
# 2. DEFAULT SAVE DATA
# ============================================================

# This function returns the default progress used when:
# - the player opens the game for the first time,
# - the save file does not exist,
# - or the save file cannot be read properly.
func get_default_save_data() -> Dictionary:
	return {
		"max_unlocked_level": 1,
		"coins": 0,
		"level_stars": {
			1: 0,
			2: 0,
			3: 0
		}
	}


# ============================================================
# 3. SAVE PLAYER PROGRESS
# ============================================================

# Saves the player's progress to disk.
#
# PARAMETERS
# ----------
# max_unlocked_level:
#     The highest level the player has unlocked.
#
# coins:
#     The player's current coin total.
#
# level_stars:
#     A dictionary storing the best star rating for each level.
func save_progress(max_unlocked_level: int, coins: int, level_stars: Dictionary) -> void:
	var save_data = {
		"max_unlocked_level": max_unlocked_level,
		"coins": coins,
		"level_stars": {
			"1": level_stars[1],
			"2": level_stars[2],
			"3": level_stars[3]
		}
	}

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file == null:
		print("SaveManager: Failed to open save file for writing.")
		return

	file.store_string(JSON.stringify(save_data))
	file.close()


# ============================================================
# 4. LOAD PLAYER PROGRESS
# ============================================================

# Loads saved player progress from disk.
#
# RETURNS
# -------
# Dictionary:
#     The loaded progress if a save file exists.
#     Default progress if no valid save file is found.
func load_progress() -> Dictionary:
	var save_data = get_default_save_data()

	if not FileAccess.file_exists(SAVE_PATH):
		return save_data

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)

	if file == null:
		print("SaveManager: Failed to open save file for reading.")
		return save_data

	var content = file.get_as_text()
	file.close()

	var parsed_data = JSON.parse_string(content)

	if parsed_data == null:
		print("SaveManager: Save file exists but could not be parsed.")
		return save_data

	if parsed_data.has("max_unlocked_level"):
		save_data["max_unlocked_level"] = int(parsed_data["max_unlocked_level"])

	if parsed_data.has("coins"):
		save_data["coins"] = int(parsed_data["coins"])

	if parsed_data.has("level_stars"):
		var saved_stars = parsed_data["level_stars"]

		if saved_stars.has("1"):
			save_data["level_stars"][1] = int(saved_stars["1"])

		if saved_stars.has("2"):
			save_data["level_stars"][2] = int(saved_stars["2"])

		if saved_stars.has("3"):
			save_data["level_stars"][3] = int(saved_stars["3"])

	return save_data


# ============================================================
# 5. RESET SAVE DATA
# ============================================================

# Deletes the save file and resets progress.
#
# This is useful during testing when you want to return the game
# to a fresh first-time-player state.
func reset_save_data() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

	print("SaveManager: Save data reset.")


# ============================================================
# DEVELOPER NOTES
# ============================================================
# This manager is intentionally simple for now.
#
# Future improvements:
# - Save player energy.
# - Save unlocked worlds.
# - Save power-ups.
# - Save achievements.
# - Add save versioning for future updates.
# ============================================================
