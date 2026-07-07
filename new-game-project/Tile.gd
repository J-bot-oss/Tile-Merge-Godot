extends Node2D

# ============================================================
# TILE.GD - Visual + interaction script for a single tile
# ============================================================
# Expected scene structure (Tile.tscn):
#   Tile (Node2D)          <- this script goes here
#    └─ ColorRect          <- untouched, keep its existing size/position
#
# This script does NOT change the ColorRect's size or position in
# the scene - it only adds a shader material + a small overlay
# Label, both created at runtime. Nothing in Tile.tscn needs to
# be edited by hand.
#
# What it adds:
# - A shader on the ColorRect for rounded corners + gradient fill
#   + soft glossy highlight (instead of a flat color square)
# - A gentle pulsing glow on rare tiles (tier 3) and the ultimate
#   "prism" tile (tier 4), so rarity is visually obvious
# - A tiny tier icon (✦ / ✧✧ / ★) overlaid on the tile
# - Same public interface as before: tile_color, grid_position,
#   setup(color_name, grid_pos), and the tile_clicked(tile) signal
# ============================================================

signal tile_clicked(tile)

var tile_color: String = ""
var grid_position: Vector2i = Vector2i.ZERO

@onready var color_rect: ColorRect = $ColorRect

var tier_icon_label: Label = null
var glow_tween: Tween = null

const TILE_SHADER_CODE := """
shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 accent_color : source_color = vec4(1.0);
uniform float glow_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV;

	// Rounded corner mask
	vec2 centered = abs(uv - 0.5) * 2.0;
	float corner_radius = 0.22;
	vec2 corner_dist = max(centered - (1.0 - corner_radius), 0.0);
	float rounded_mask = 1.0 - smoothstep(corner_radius * 0.85, corner_radius, length(corner_dist));

	// Diagonal gradient from base color to accent color
	float gradient_t = clamp((uv.x + uv.y) * 0.5, 0.0, 1.0);
	vec3 body_color = mix(base_color.rgb, accent_color.rgb, gradient_t * 0.55);

	// Soft glossy highlight near the top
	float shine = smoothstep(0.55, 0.0, uv.y) * 0.35;
	body_color += vec3(shine);

	// Subtle outer glow pulse for rare tiles
	float edge_glow = smoothstep(0.85, 1.0, length(centered)) * glow_strength;
	body_color += accent_color.rgb * edge_glow * 0.6;

	COLOR = vec4(body_color, rounded_mask);
}
"""


func _ready():
	if not (color_rect.material is ShaderMaterial):
		var shader = Shader.new()
		shader.code = TILE_SHADER_CODE

		var shader_mat = ShaderMaterial.new()
		shader_mat.shader = shader

		color_rect.material = shader_mat

	if not color_rect.gui_input.is_connected(_on_color_rect_gui_input):
		color_rect.gui_input.connect(_on_color_rect_gui_input)

	_ensure_tier_icon_label()


func setup(color_name: String, new_grid_position: Vector2i):
	tile_color = color_name
	grid_position = new_grid_position

	var base_color := Color(0.6, 0.6, 0.6)
	var accent_color := Color(0.8, 0.8, 0.8)
	var tier := 1

	var game_manager = _find_game_manager()

	if game_manager != null:
		base_color = game_manager.get_color_value(color_name)
		accent_color = game_manager.get_color_accent(color_name)
		tier = game_manager.get_color_tier(color_name)

	if color_rect.material is ShaderMaterial:
		color_rect.material.set_shader_parameter("base_color", base_color)
		color_rect.material.set_shader_parameter("accent_color", accent_color)

	_update_tier_icon(tier)
	_update_glow_animation(tier)


# Walks up the tree looking for the node that owns get_color_value(),
# instead of assuming a fixed node name/path. Works no matter what
# your game manager's root node is called.
func _find_game_manager():
	var node = get_parent()

	while node != null:
		if node.has_method("get_color_value"):
			return node
		node = node.get_parent()

	return null


func _ensure_tier_icon_label():
	if tier_icon_label != null and is_instance_valid(tier_icon_label):
		return

	tier_icon_label = Label.new()
	tier_icon_label.name = "TierIconLabel"
	tier_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tier_icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tier_icon_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	tier_icon_label.add_theme_font_size_override("font_size", 20)
	tier_icon_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	tier_icon_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	tier_icon_label.add_theme_constant_override("shadow_offset_x", 1)
	tier_icon_label.add_theme_constant_override("shadow_offset_y", 1)

	color_rect.add_child(tier_icon_label)


func _update_tier_icon(tier: int):
	if tier_icon_label == null:
		return

	if tier == 2:
		tier_icon_label.text = "✦"
	elif tier == 3:
		tier_icon_label.text = "✧✧"
	elif tier == 4:
		tier_icon_label.text = "★"
	else:
		tier_icon_label.text = ""


func _update_glow_animation(tier: int):
	if glow_tween != null and glow_tween.is_valid():
		glow_tween.kill()

	if not (color_rect.material is ShaderMaterial):
		return

	if tier < 3:
		color_rect.material.set_shader_parameter("glow_strength", 0.0)
		return

	var target_strength = 0.55 if tier == 3 else 0.9

	glow_tween = create_tween()
	glow_tween.set_loops()
	glow_tween.tween_method(_set_glow_strength, 0.15, target_strength, 0.9)
	glow_tween.tween_method(_set_glow_strength, target_strength, 0.15, 0.9)


func _set_glow_strength(value: float):
	if color_rect.material is ShaderMaterial:
		color_rect.material.set_shader_parameter("glow_strength", value)


func _on_color_rect_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tile_clicked.emit(self)
