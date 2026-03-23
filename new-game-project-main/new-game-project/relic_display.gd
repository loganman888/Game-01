extends HBoxContainer


func add_relic_icon(texture: Texture2D, display_name: String):
	# 1. Create a Control node to act as a "Fixed Box"
	# This prevents the giant image from pushing the UI boundaries
	var icon_wrapper = Control.new()
	icon_wrapper.custom_minimum_size = Vector2(64, 64) # Set your desired size here
	
	# 2. Create the actual icon
	var new_icon = TextureRect.new()
	new_icon.texture = texture
	
	# 3. CRITICAL: Force it to ignore the 1536x1024 size
	new_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	
	# 4. Keep it from stretching/looking weird
	new_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# 5. Make the icon fill the 40x40 wrapper
	new_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	new_icon.tooltip_text = display_name
	
	# 6. Assemble: HBox -> Wrapper -> Icon
	icon_wrapper.add_child(new_icon)
	add_child(icon_wrapper)
