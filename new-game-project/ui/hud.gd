extends CanvasLayer

func update_score(new_score: int):
  $ScoreLabel.text = "Score: " + str(new_score)

func _on_restart_button_pressed():
  get_tree().reload_current_scene()
