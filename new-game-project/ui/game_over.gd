extends Control

func set_score(score: int):
  $FinalScoreLabel.text = "Final Score: " + str(score)

func _on_play_again_pressed():
  get_tree().reload_current_scene()

func _on_main_menu_pressed():
  get_tree().change_scene_to_file("res://ui/main_menu.tscn")
