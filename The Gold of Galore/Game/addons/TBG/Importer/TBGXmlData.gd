class_name TBGXmlData

var export_version: int
var tgs_file_path: String
var sprite_sheets: Array[SpriteSheetSettings]
var skeletons: Array[SkeletonSettings]
var drawing_animations: Dictionary
var animations: Dictionary
var skeleton_to_stages: Dictionary

func _init(asset_path: String):
	var zip_file = Utils.read_zip_file(asset_path)
	
	if not zip_file or zip_file.is_empty():
		push_error("Failed to load ZipArchive: %s" % asset_path)
		return
	
	# Sprite Sheets
	var sprite_sheets_tag: bool = false
	var sprite_sheets_file
	if zip_file.has("spriteSheets.xml"):
		sprite_sheets_file = zip_file["spriteSheets.xml"]
	var sprite_sheets_xml = XMLParser.new()
	
	if sprite_sheets_file:
		sprite_sheets_xml.open_buffer(sprite_sheets_file)
		
		# Parse the XML until we find the <spritesheets> tag
		while sprite_sheets_xml.read() == OK:
			if sprite_sheets_xml.get_node_type() == XMLParser.NODE_ELEMENT and sprite_sheets_xml.get_node_name() == "spritesheets":
				sprite_sheets_tag = true
				break
	
	if sprite_sheets_tag:
		var current_sprite_sheet = {}
		var sprites = []
		
		while sprite_sheets_xml.read() == OK:
			if sprite_sheets_xml.get_node_type() == XMLParser.NODE_ELEMENT:
				var node_name = sprite_sheets_xml.get_node_name()
				
				if node_name == "spritesheet":
					current_sprite_sheet = {}
					sprites = []
					current_sprite_sheet["name"] = sprite_sheets_xml.get_named_attribute_value("name")
					current_sprite_sheet["filename"] = sprite_sheets_xml.get_named_attribute_value("filename")
					current_sprite_sheet["resolution"] = sprite_sheets_xml.get_named_attribute_value("resolution")
					current_sprite_sheet["width"] = int(sprite_sheets_xml.get_named_attribute_value("width"))
					current_sprite_sheet["height"] = int(sprite_sheets_xml.get_named_attribute_value("height"))
				
				elif node_name == "sprite":
					# Parse the sprite attributes
					var rect_str = sprite_sheets_xml.get_named_attribute_value("rect").split(",")
					var rect = []
					for value in rect_str:
						rect.append(int(value))
					
					sprites.append(SpriteSettings.new(
						rect,
						float(sprite_sheets_xml.get_named_attribute_value("scaleX")),
						float(sprite_sheets_xml.get_named_attribute_value("scaleY")),
						float(sprite_sheets_xml.get_named_attribute_value("offsetX")),
						float(sprite_sheets_xml.get_named_attribute_value("offsetY")),
						sprite_sheets_xml.get_named_attribute_value("name")
					))
			
			# If we reach the end of a spritesheet tag, save the spritesheet data
			if sprite_sheets_xml.get_node_type() == XMLParser.NODE_ELEMENT_END and sprite_sheets_xml.get_node_name() == "spritesheet":
				sprites.sort_custom(Callable(self, "_sort_sprites_by_name"))
				sprite_sheets.append(SpriteSheetSettings.new(
					current_sprite_sheet["name"],
					current_sprite_sheet["filename"],
					current_sprite_sheet["resolution"],
					current_sprite_sheet["width"],
					current_sprite_sheet["height"],
					sprites
				))
	
	else:
		# Alternative way to load sprite data if "spriteSheets.xml" is not present
		var sprite_data = {}
		for entry in zip_file.keys():
			if entry.get_extension() == "sprite":
				var sprite_xml = XMLParser.new()
				sprite_xml.open_buffer(zip_file[entry])
				
				# Parse the XML until we find the <crop> tag
				while sprite_xml.read() == OK:
					if sprite_xml.get_node_type() == XMLParser.NODE_ELEMENT and sprite_xml.get_node_name() == "crop":
						var path_splits = entry.split("/")
						var resolution = path_splits[1]
						var sprite_sheet_name = path_splits[0]
						
						if not sprite_data.has(resolution):
							sprite_data[resolution] = {
								"sprite_sheet_name": sprite_sheet_name,
								"sprites": []
							}
						var split_names = entry.get_basename().split("/")
						var name = split_names[split_names.size()-1]
						var ss = SpriteSettings.new(
							[],  # rect is not available in this case
							float(sprite_xml.get_named_attribute_value("scaleX")),
							float(sprite_xml.get_named_attribute_value("scaleY")),
							float(sprite_xml.get_named_attribute_value("pivotX")),
							float(sprite_xml.get_named_attribute_value("pivotY")),
							name
						)
						var temp_arr = entry.split(".sprite")
						ss.filename = temp_arr[0]
						sprite_data[resolution]["sprites"].append(ss)
						break  # Exit the loop when crop is found
		
		for resolution in sprite_data:
			var data = sprite_data[resolution]
			sprite_sheets.append(SpriteSheetSettings.new(
				data["sprite_sheet_name"],
				"",  # filename is not available in this case
				resolution,
				0,  # width is not available in this case
				0,  # height is not available in this case
				data["sprites"]
			))
	
	#Load skeleton xml
	var skeleton_xml = XMLParser.new()
	skeleton_xml.open_buffer(zip_file["skeleton.xml"])
	
	var skeletons_tag: bool = false
	var export_version: int = -1
	var expected_version: int = 3
	var current_skeleton = {}
	var current_nodes = []
	var current_links = []

	while skeleton_xml.read() == OK:
		# Check if the node is an element
		if skeleton_xml.get_node_type() == XMLParser.NODE_ELEMENT:
			var node_name = skeleton_xml.get_node_name()
			
			if node_name == "skeletons":
				skeletons_tag = true
				# Get export version attribute
				export_version = int(skeleton_xml.get_named_attribute_value("version"))
				if export_version != expected_version:
					push_error("Unsupported TBG version (v%d) - Please try re-exporting your project with the latest version of TBG (v%d)" % [export_version, expected_version])
					return
				# Get tgspath attribute
				if skeleton_xml.has_attribute("tgspath"):
					tgs_file_path = skeleton_xml.get_named_attribute_value("tgspath")
			
			elif skeletons_tag and node_name == "skeleton":
				# Start reading a new skeleton
				current_skeleton = {}
				current_nodes = []
				current_links = []
				current_skeleton["name"] = skeleton_xml.get_named_attribute_value("name")
			
			elif skeletons_tag and node_name == "nodes":
				# Reading nodes inside the skeleton
				while skeleton_xml.read() == OK and skeleton_xml.get_node_type() != XMLParser.NODE_ELEMENT_END:
					if skeleton_xml.get_node_type() == XMLParser.NODE_ELEMENT:# and skeleton_xml.get_node_name() == "node":
						# Parse node attributes
						current_nodes.append(NodeSettings.new(
							skeleton_xml.get_node_name(),
							int(skeleton_xml.get_named_attribute_value("id")),
							skeleton_xml.get_named_attribute_value("name"),
							skeleton_xml.get_named_attribute_value_safe("visible") == "true" if skeleton_xml.has_attribute("visible") else null
						))
			
			elif skeletons_tag and node_name == "links":
				# Reading links inside the skeleton
				while skeleton_xml.read() == OK and skeleton_xml.get_node_type() != XMLParser.NODE_ELEMENT_END:
					if skeleton_xml.get_node_type() == XMLParser.NODE_ELEMENT and skeleton_xml.get_node_name() == "link":
						var node_in = -1 if skeleton_xml.get_named_attribute_value("in") == "Top" else int(skeleton_xml.get_named_attribute_value("in"))
						current_links.append(LinkSettings.new(
							node_in,
							int(skeleton_xml.get_named_attribute_value("out")),
							int(skeleton_xml.get_named_attribute_value("port")) if skeleton_xml.has_attribute("port") else null
						))
		
		# If we encounter the end of a skeleton tag, save the parsed skeleton data
		if skeleton_xml.get_node_type() == XMLParser.NODE_ELEMENT_END and skeleton_xml.get_node_name() == "skeleton":
			skeletons.append(SkeletonSettings.new(
				current_skeleton["name"],
				current_nodes,
				current_links
			))
	
	# Drawing Animations
	var drawing_animations_xml = XMLParser.new()
	drawing_animations_xml.open_buffer(zip_file["drawingAnimation.xml"])
	var in_drawing_animations_tag = false
	var in_drawing_animation_tag = false
	var current_animation = {}
	var current_drawings = {}
	var current_drw_list = []
	var drawing_node_name = ""

	while drawing_animations_xml.read() == OK:
		if drawing_animations_xml.get_node_type() == XMLParser.NODE_ELEMENT:
			var node_name = drawing_animations_xml.get_node_name()
			
			# Detect the opening of the drawingAnimations tag
			if node_name == "drawingAnimations":
				in_drawing_animations_tag = true
			
			# Detect the drawingAnimation tag and start parsing its attributes
			elif in_drawing_animations_tag and node_name == "drawingAnimation":
				in_drawing_animation_tag = true
				current_animation = {}
				current_drawings = {}
				current_animation["name"] = drawing_animations_xml.get_named_attribute_value("name")
				current_animation["spritesheet"] = drawing_animations_xml.get_named_attribute_value("spritesheet")
			
			# Parse each drawing inside drawingAnimation
			elif in_drawing_animation_tag and node_name == "drawing":
				current_drw_list = []
				drawing_node_name = drawing_animations_xml.get_named_attribute_value("node")
			
			# Parse each drw inside drawing
			elif in_drawing_animation_tag and node_name == "drw":
				var skin_id = int(drawing_animations_xml.get_named_attribute_value("skinId")) if drawing_animations_xml.has_attribute("skinId") else 0
				var name = drawing_animations_xml.get_named_attribute_value("name")
				var frame = int(drawing_animations_xml.get_named_attribute_value("frame"))
				var repeat = int(drawing_animations_xml.get_named_attribute_value("repeat")) if drawing_animations_xml.has_attribute("repeat") else 1
				
				current_drw_list.append(DrwSettings.new(skin_id, name, frame, repeat))
			
		# If we reach the end of a drawing tag, store its parsed data
		if drawing_animations_xml.get_node_type() == XMLParser.NODE_ELEMENT_END and drawing_animations_xml.get_node_name() == "drawing":
			current_drawings[drawing_node_name] = current_drw_list
		
		# If we reach the end of a drawingAnimation tag, save the parsed animation data
		if drawing_animations_xml.get_node_type() == XMLParser.NODE_ELEMENT_END and drawing_animations_xml.get_node_name() == "drawingAnimation":
			drawing_animations[current_animation["name"]] = DrawingAnimationSettings.new(
				current_animation["name"],
				current_animation["spritesheet"],
				current_drawings
			)
			in_drawing_animation_tag = false

	## Stages
	var stage_xml = XMLParser.new()
	stage_xml.open_buffer(zip_file["stage.xml"])

	var in_stages_tag = false
	var in_stage_tag = false
	var current_stage_settings: StageSettings = null
	var current_play_settings: PlaySettings = null

	while stage_xml.read() == OK:
		if stage_xml.get_node_type() == XMLParser.NODE_ELEMENT:
			var node_name = stage_xml.get_node_name()
			
			# Handle <stages> tag
			if node_name == "stages":
				in_stages_tag = true
			
			# Handle <stage> tag
			elif in_stages_tag and node_name == "stage":
				in_stage_tag = true
				current_stage_settings = StageSettings.new()
				current_stage_settings.name = stage_xml.get_named_attribute_value("name")
				current_stage_settings.skins = []
				current_stage_settings.groups = []
				current_stage_settings.metadata = []
				current_stage_settings.nodes = []

			# Handle <node> tag inside <stage>
			elif in_stage_tag and node_name == "node":
				var skin_ids = []
				for value in stage_xml.get_named_attribute_value("skinId").split(","):
					if value.length() > 0:
						skin_ids.append(int(value))
				
				current_stage_settings.nodes.append(StageNodeSettings.new(
					int(stage_xml.get_named_attribute_value("drwId")),
					stage_xml.get_named_attribute_value("name"),
					int(stage_xml.get_named_attribute_value("groupId")),
					skin_ids
				))
			
			# Handle <play> tag inside <stage>
			elif in_stage_tag and node_name == "play":
				current_play_settings = PlaySettings.new(
					stage_xml.get_named_attribute_value("name"),
					stage_xml.get_named_attribute_value("animation"),
					stage_xml.get_named_attribute_value("drawingAnimation"),
					stage_xml.get_named_attribute_value("skeleton"),
					int(stage_xml.get_named_attribute_value("framerate")) if stage_xml.has_attribute("framerate") else 30,
					int(stage_xml.get_named_attribute_value("markerLength")) if stage_xml.has_attribute("markerLength") else 1,
					(stage_xml.get_named_attribute_value("loop") == "true") if stage_xml.has_attribute("loop") else false,
					stage_xml.get_named_attribute_value("facing") if stage_xml.has_attribute("facing") else "None",
					stage_xml.get_named_attribute_value("mode") if stage_xml.has_attribute("mode") else "None"
				)
				current_stage_settings.play = current_play_settings
			
			# Handle elements like <skin>, <group>, <meta>, and <sound> inside <stage>
			elif in_stage_tag:
				match node_name:
					"skin":
						current_stage_settings.skins.append(SkinSettings.new(
							int(stage_xml.get_named_attribute_value("skinId")),
							stage_xml.get_named_attribute_value("name")
						))
					"group":
						current_stage_settings.groups.append(GroupSettings.new(
							int(stage_xml.get_named_attribute_value("groupId")),
							stage_xml.get_named_attribute_value("name")
						))
					"meta":
						current_stage_settings.metadata.append(Metadata.new(
							stage_xml.get_named_attribute_value("node"),
							stage_xml.get_named_attribute_value("name"),
							stage_xml.get_named_attribute_value("value")
						))
					"sound":
						var sound_name = stage_xml.get_named_attribute_value("name")
						var sound_time = int(stage_xml.get_named_attribute_value("time")) if stage_xml.has_attribute("time") else 0
						current_stage_settings.sound = SoundSettings.new(sound_name, sound_time)
		
		# Closing <stage> tag
		if stage_xml.get_node_type() == XMLParser.NODE_ELEMENT_END and stage_xml.get_node_name() == "stage":
			if not skeleton_to_stages.has(current_stage_settings.play.skeleton):
				skeleton_to_stages[current_stage_settings.play.skeleton] = []
			skeleton_to_stages[current_stage_settings.play.skeleton].append(current_stage_settings)
			in_stage_tag = false  # Reset flag for next <stage>

	## Animations
	var xml = XMLParser.new()
	xml.open_buffer(zip_file["animation.xml"])

	while xml.read() == OK:
		if xml.get_node_type() == XMLParser.NODE_ELEMENT and xml.get_node_name() == "animations":
			# Start reading animations
			while xml.read() == OK:
				# Detect animation element
				if xml.get_node_type() == XMLParser.NODE_ELEMENT and xml.get_node_name() == "animation":
					var attr_links = []
					var timed_values = {}

					# Get the animation name
					var animation_name = xml.get_named_attribute_value("name")

					# Read attrlinks and timedvalues within each animation
					while xml.read() == OK and xml.get_node_type() != XMLParser.NODE_ELEMENT_END:
						if xml.get_node_type() == XMLParser.NODE_ELEMENT and xml.get_node_name() == "attrlinks":
							# Parsing attrlinks
							while xml.read() == OK and xml.get_node_type() != XMLParser.NODE_ELEMENT_END:
								if xml.get_node_type() == XMLParser.NODE_ELEMENT and xml.get_node_name() == "attrlink":
									# Create instance of AttrLinkSettings
									var attrlink_settings = AttrLinkSettings.new(
										xml.get_named_attribute_value("node"),
										xml.get_named_attribute_value("attr"),
										xml.get_named_attribute_value_safe("timedvalue") if xml.has_attribute("timedvalue") else "",
										float(xml.get_named_attribute_value_safe("value")) if xml.has_attribute("value") else 0.0,
										xml.get_named_attribute_value_safe("iskeyed") == "true" if xml.has_attribute("iskeyed") else false
									)
									attr_links.append(attrlink_settings)

						elif xml.get_node_type() == XMLParser.NODE_ELEMENT and xml.get_node_name() == "timedvalues":
							# Parsing timedvalues
							while xml.read() == OK and xml.get_node_type() != XMLParser.NODE_ELEMENT_END:
								if xml.get_node_type() == XMLParser.NODE_ELEMENT:
									var points = []
									var timed_value_name = xml.get_named_attribute_value("name")  # Get "name" attribute
									
									# Read points
									while xml.read() == OK and xml.get_node_type() != XMLParser.NODE_ELEMENT_END:
										if xml.get_node_type() == XMLParser.NODE_ELEMENT and xml.get_node_name() == "pt":
											var point_settings = {
												"x": float(xml.get_named_attribute_value("x")),
												"y": float(xml.get_named_attribute_value("y")),
												"z": float(xml.get_named_attribute_value_safe("z")) if xml.has_attribute("z") else 0.0,
												"lx": float(xml.get_named_attribute_value_safe("lx")) if xml.has_attribute("lx") else 0.0,
												"ly": float(xml.get_named_attribute_value_safe("ly")) if xml.has_attribute("ly") else 0.0,
												"rx": float(xml.get_named_attribute_value_safe("rx")) if xml.has_attribute("rx") else 0.0,
												"ry": float(xml.get_named_attribute_value_safe("ry")) if xml.has_attribute("ry") else 0.0,
												"locked_in_time": float(xml.get_named_attribute_value_safe("lockedInTime")) if xml.has_attribute("lockedInTime") else null,
												"const_seg": xml.get_named_attribute_value("constSeg") == "true" if xml.has_attribute("constSeg") else false,
												"start": int(xml.get_named_attribute_value_safe("start")) if xml.has_attribute("start") else 0
											}
											points.append(point_settings)

									# Create instance of TimedValueSettings and add to dictionary
									var timed_settings = TimedValueSettings.new(
										xml.get_node_name(),  # Using the node name as the tag
										timed_value_name,  # Using the "name" attribute
										points
									)
									timed_values[timed_settings.name] = timed_settings

					# Create and add AnimationSettings instance to animations dictionary
					var animation_settings = AnimationSettings.new(animation_name, attr_links, timed_values)
					animations[animation_settings.name] = animation_settings

				# Exit if we reach the end of animations node
				elif xml.get_node_type() == XMLParser.NODE_ELEMENT_END and xml.get_node_name() == "animations":
					break  # Exit outer animations loop once fully parsed


func _sort_sprites_by_name(a: SpriteSettings, b: SpriteSettings) -> bool:
	return a.name < b.name
