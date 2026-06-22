extends Button

signal tile_clicked(tile)

var tile_color = "red"
var grid_position = Vector2i.ZERO

@onready var color_rect = $ColorRect

func _ready():
	custom_minimum_size = Vector2(80, 80)
	pressed.connect(_on_pressed)
	update_color()

func setup(color_name, pos):
	tile_color = color_name
	grid_position = pos
	update_color()

func update_color():
	text = ""
	modulate = Color.WHITE
	self_modulate = Color.WHITE

	match tile_color:
		"red":
			color_rect.color = Color.RED
		"blue":
			color_rect.color = Color.BLUE
		"yellow":
			color_rect.color = Color.YELLOW
		"purple":
			color_rect.color = Color.PURPLE
		"green":
			color_rect.color = Color.GREEN
		"orange":
			color_rect.color = Color.ORANGE
		_:
			color_rect.color = Color.WHITE

func _on_pressed():
	print("Tile clicked: ", tile_color)
	tile_clicked.emit(self)
