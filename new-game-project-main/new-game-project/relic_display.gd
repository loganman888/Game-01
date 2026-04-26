extends HBoxContainer

# Inside relic_ui.gd
const RELIC_SCALES = {
	"Budget Permit": 2.2,
	"Overclock": 1.2,
	"Siphoning Shot": .9, 
}


var active_relics = {}
var relic_counts = {}

func _ready():
	add_theme_constant_override("separation", 15)

func add_relic_icon(texture: Texture2D, display_name: String):
	# --- ADD THIS DEBUG ---
	print("[DEBUG] HUD told to add: ", display_name)
	if active_relics.has(display_name):
		print("[DEBUG] HUD says we already have it. Current count was: ", relic_counts[display_name])
	else:
		print("[DEBUG] HUD says this is a brand new relic.")
	# ----------------------

	# 1. HANDLE DUPLICATES
	if active_relics.has(display_name):
		relic_counts[display_name] += 1
		var label = active_relics[display_name]
		label.text = str(relic_counts[display_name]) + "x"
		# Force the label to the front of the visual stack again just in case
		label.move_to_front() 
		print("Updated Stack: ", display_name, " to ", relic_counts[display_name], "x")
		return 

	# 2. HANDLE NEW RELIC
	relic_counts[display_name] = 1
	var visual_scale = RELIC_SCALES.get(display_name, 1.0)
	
	var icon_wrapper = Control.new()
	icon_wrapper.custom_minimum_size = Vector2(128, 128) 
	icon_wrapper.clip_contents = true 
	add_child(icon_wrapper) # Add to HBox first so sizes calculate correctly
	
	# 3. CREATE THE ICON
	var new_icon = TextureRect.new()
	new_icon.texture = texture
	new_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	new_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon_wrapper.add_child(new_icon)
	
	new_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	new_icon.pivot_offset = Vector2(64, 64) 
	new_icon.scale = Vector2(visual_scale, visual_scale)
	new_icon.tooltip_text = display_name
	
	# --- 4. CREATE THE MULTIPLIER LABEL (Updated Logic) ---
	var count_label = Label.new()
	count_label.name = "CountLabel"
	count_label.text = "" 
	
	# Styling: Beefy font and heavy outline to beat the relic art
	count_label.add_theme_font_size_override("font_size", 34)
	count_label.add_theme_color_override("font_outline_color", Color.BLACK)
	count_label.add_theme_constant_override("outline_size", 12)
	
	# Positioning
	icon_wrapper.add_child(count_label)
	
	# Anchor to Bottom-Right
	count_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	
	# NEW: These lines ensure the label grows INWARD from the corner
	# so it never accidentally slides off the screen or moves too high.
	count_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	count_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	
	# Nudge it just a tiny bit so it's not touching the absolute pixel-edge
	# (Positive X/Y = Right/Down | Negative X/Y = Left/Up)
	count_label.position.x -= 2 # Move slightly left from right edge
	count_label.position.y -= 2 # Move slightly up from bottom edge
	
	# Store the reference
	active_relics[display_name] = count_label
