extends Control

func _on_play_button_pressed():
  get_tree().change_scene_to_file("res://scenes/game/Game.tscn")

func _on_instructions_button_pressed():
  $InstructionsPanel.visible = true

func _on_close_button_pressed():
  $InstructionsPanel.visible = false
