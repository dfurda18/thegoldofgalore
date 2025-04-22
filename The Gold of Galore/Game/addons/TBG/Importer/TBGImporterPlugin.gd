@tool
extends EditorImportPlugin

# This script is a translation of TBGImporterPlugin.cs from C# to GDScript for Godot 4.
# It imports Toon Boom Harmony animation files (.tbg) into Godot scenes.

var plugin
var root_node

func _get_importer_name():
	return "ToonBoom.TBG"

func _get_visible_name():
	return "TBG"

func _get_recognized_extensions():
	return ["tbg"]

func _get_save_extension():
	return "scn"

func _get_resource_type():
	return "PackedScene"

func _get_preset_count():
	return 1

func _get_preset_name(preset):
	return "Default"

func _get_import_options(path, preset):
	return [
		{
			"name": "Motions/ImportAsMotionCharacter",
			"description": "Opt-in to Toon Boom Motion rigging workflow, provides mapping between 'motion'/'direction' and 'Animations'",
			"default_value": true
		},
		{
			"name": "Rendering/UseCanvasLayer",
			"description": "Compose all sprites into a single layer to allow for full-character transparency",
			"default_value": false
		},
		{
			"name": "Optimization/CompressAnimationTracks",
			"description": "Combine position/scale/rotation/skew tracks into a single transform track for better performance. May affect animation blending.",
			"default_value": true
		},
		{
			"name": "Optimization/RemoveEmptyTracks",
			"description": "Remove transform tracks that don't have any keyframes in their timeline in the asset editor",
			"default_value": false
		},
		{
			"name": "Optimization/GeneratePolygons",
			"description": "Generate Polygons for each texture during the import process to allow for complex polygon shapes.",
			"default_value": true
		},
	]

func _get_option_visibility(path, option, options):
	return true

func _get_import_order():
	return 90

func _get_priority():
	return 1.0

const RuntimeScriptsFolder = "res://addons/TBG/Runtime"

class TextureImportResult:
	var texture
	var width
	var height
	var image
	
	func _init(texture, image):
		self.texture = texture
		self.width = image.get_width()
		self.height = image.get_height()
		self.image = image

func _import_texture(entry: PackedByteArray, compress: bool) -> TextureImportResult:
	var image = Image.new()
	image.load_png_from_buffer(entry)  # Directly load from PackedByteArray
	image.generate_mipmaps()
	var texture: Texture2D
	
	if not compress:
		texture = ImageTexture.create_from_image(image)
	else:
		var compressed_texture = PortableCompressedTexture2D.new()
		compressed_texture.keep_compressed_buffer = true
		compressed_texture.create_from_image(image, PortableCompressedTexture2D.COMPRESSION_MODE_BASIS_UNIVERSAL)
		texture = compressed_texture
	
	return TextureImportResult.new(texture, image)


class HarmonySpriteInfo:
	var texture
	var offset
	var scale
	var polygons
	
	func _init(texture, offset, scale, polygons):
		self.texture = texture
		self.offset = offset
		self.scale = scale
		self.polygons = polygons

func SpriteSheetToSpriteInfos(data, global_path, compress, options):
	var textures = []
	var result = {}
	var archive = Utils.read_zip_file(global_path)
	
	for sprite_sheet in data.sprite_sheets:
		var sprite_infos = {}
		
		# Individual Sprites
		if sprite_sheet.filename == null or sprite_sheet.filename.is_empty():
			for sprite_settings in sprite_sheet.sprites:
				var texture_import_result = _import_texture(archive[sprite_settings.filename], compress)
				texture_import_result.texture.resource_name = "%s-%s" % [sprite_sheet.resolution, sprite_settings.name]
				textures.append(texture_import_result.texture)
				sprite_infos[sprite_settings.name] = HarmonySpriteInfo.new(
					texture_import_result.texture,
					Vector2(-sprite_settings.offset_x, sprite_settings.offset_y),
					Vector2(sprite_settings.scale_x, sprite_settings.scale_y),
					null
				)
		# Sprite sheets
		else:
			var texture_import_result
			texture_import_result = _import_texture(archive[sprite_sheet.filename], compress)
			texture_import_result.texture.resource_name = sprite_sheet.resolution
			textures.append(texture_import_result.texture)
			
			for sprite_settings in sprite_sheet.sprites:
				var region = Rect2(
					sprite_settings.rect[0],
					sprite_settings.rect[1],
					min(sprite_settings.rect[2], texture_import_result.width - sprite_settings.rect[0]),
					min(sprite_settings.rect[3], texture_import_result.height - sprite_settings.rect[1])
				)
				var atlas_texture = AtlasTexture.new()
				atlas_texture.resource_name = "%s-%s" % [sprite_sheet.resolution, sprite_settings.name]
				atlas_texture.atlas = texture_import_result.texture
				atlas_texture.region = region
				sprite_infos[sprite_settings.name] = HarmonySpriteInfo.new(
					atlas_texture,
					Vector2(sprite_settings.offset_x, -sprite_settings.offset_y),
					Vector2(sprite_settings.scale_x, sprite_settings.scale_y),
					get_polygons(texture_import_result.image.get_region(region), options)
				)
		
		result[sprite_sheet.resolution] = sprite_infos
	
	var texture_assets = textures.duplicate()
	return {"result":result, "textures":texture_assets}


enum CutterPort {
	CUTTEE = 0,
	MATTE = 1
}

enum WeightAgainst
{
	None,
	Parent,
	Child,
}
class VertexBoneCalc:
	var distance
	var flatDistance
	var weightAgainst

class ClosestBone:
	var index
	var distance


func _import(source_file, save_path, options, platform_variants, gen_files):
	var start_time = Time.get_ticks_msec()

	save_path = save_path if save_path else source_file + ".imported"
	var scene = PackedScene.new()

	# Get absolute path from res:// sourceFile path.
	var global_path = ProjectSettings.globalize_path(source_file)
	var xml_data = TBGXmlData.new(global_path)

	# For now just import first skeleton TODO support multiple skeletons.
	var skeleton = xml_data.skeletons[0]
	var stages = xml_data.skeleton_to_stages[skeleton.name]

	# Generating a bunch of useful lookups.
	var node_id_to_file_node = {}
	for x in skeleton.nodes:
		node_id_to_file_node[x.id] = x
	
	var name_to_parent_node = {}
	for entry in skeleton.nodes:
		var links = []
		for link in skeleton.links:
			if link.node_out == entry.id:
				links.append(link)
		if not links:
			continue
		var link = links[0]
		if link.node_in == -1:
			continue
		name_to_parent_node[entry.name] = node_id_to_file_node[link.node_in]
	
	var name_to_first_non_bone_parent_node = {}
	for entry in skeleton.nodes:
		var non_bone_parent = name_to_parent_node.get(entry.name)
		while non_bone_parent != null and non_bone_parent.tag == "bone":
			non_bone_parent = name_to_parent_node.get(non_bone_parent.name)
		if non_bone_parent == null:
			continue
		name_to_first_non_bone_parent_node[entry.name] = non_bone_parent

	var name_to_child_nodes = {}
	for entry in skeleton.nodes:
		var links = []
		for link in skeleton.links:
			if link.node_in == entry.id:
				links.append(node_id_to_file_node[link.node_out])
		name_to_child_nodes[entry.name] = links
	
	var id_to_visibility = {}
	
	# Godot node generation --- composes lookups as well to be used later in-scope.
	var created_drawing_nodes = []
	for stage_node_info in stages[0].nodes:
		for skin_id in stage_node_info.skin_ids:
			if xml_data.drawing_animations.values().any(
			func(animation):
				return animation.drawings.has(stage_node_info.name) and animation.drawings[stage_node_info.name].any(
					func(drw): return drw.skin_id == skin_id
				)
			):
				var node_info = null
				for node in skeleton.nodes:
					if node.name == stage_node_info.name:
						node_info = node
						break
				
				var name = node_info.name if stage_node_info.skin_ids.size() <= 1 else "%s (%s)" % [node_info.name, stages[0].skins.filter(func(skin): return skin.skin_id == skin_id)[0].name]
				var node
				if name_to_parent_node.get(node_info.name) and name_to_parent_node[node_info.name].tag == "bone":
					node = Polygon2D.new()
					node.name = name
					node.visible = node_info.visible if node_info.visible != null else true
				else:
					node = Sprite2D.new()
					node.name = name
					node.visible = node_info.visible if node_info.visible != null else true
				
				var skin_name = "none"
				var group_name = ""
				
				for skin in stages[0].skins:
					if skin.skin_id == skin_id:
						skin_name = skin.name
				
				for group in stages[0].groups:
					if group.group_id == stage_node_info.group_id:
						group_name = group.name
				
				created_drawing_nodes.append({
					"node_info": node_info,
					"skin_id": skin_id,
					"skin_name": skin_name,
					"group_name": group_name,
					"group_id": stage_node_info.group_id,
					"node": node
				})

	# created_drawing_nodes.reverse() # Reverse so that the first sprite is the last child of the canvas group to respect Godot's draw order.

	var created_sprite_nodes = []
	for entry in created_drawing_nodes:
		if entry.node is Sprite2D:
			created_sprite_nodes.append({"node_info": entry.node_info, "node": entry.node})

	var created_polygon_nodes = []
	for entry in created_drawing_nodes:
		if entry.node is Polygon2D:
			created_polygon_nodes.append({"node_info": entry.node_info, "node": entry.node})

	var created_remote_nodes = []
	for entry in created_sprite_nodes:
		created_remote_nodes.append({
			"node_info": entry.node_info,
			"remote_node": entry.node,
			"node": Node2D.new()
		})
		created_remote_nodes[-1].node.name = entry.node.name + " (Remote)"

	var created_kinematic_nodes = []
	for node_info in skeleton.nodes:
		if node_info.tag == "kinematic":
			var bone2d = Bone2D.new()
			bone2d.name = node_info.name
			created_kinematic_nodes.append({
				"node_info": node_info,
				"node": bone2d
			})

	var created_peg_nodes = []
	for i in range(skeleton.nodes.size()):
		var node_info = skeleton.nodes[i]
		if node_info.tag == "peg":
			var bone2d = Bone2D.new()
			bone2d.name = node_info.name
			created_peg_nodes.append({
				"node_info": node_info,
				"node": bone2d
			})

	var created_bone_nodes = []
	for node_info in skeleton.nodes:
		if node_info.tag == "bone":
			var bone2d = Bone2D.new()
			bone2d.name = node_info.name
			created_bone_nodes.append({
				"node_info": node_info,
				"node": bone2d
			})

	# Post process any Godot node that is a Bone2D - if the children of this node are NOT Bone2D, then we need to disable auto-calculation of rotation/length.
	for entry in created_kinematic_nodes + created_peg_nodes + created_bone_nodes:
		var children = name_to_child_nodes.get(entry.node_info.name)
		if not children:
			entry.node.set_autocalculate_length_and_angle(false)
			continue
		var all_not_bone = true
		for child in children:
			if child.tag == "kinematic" or child.tag == "peg" or child.tag == "bone":
				all_not_bone = false
				break
		if all_not_bone:
			entry.node.set_autocalculate_length_and_angle(false)

	# Cache some useful lookups.
	var created_hierarchy_nodes = []
	for x in created_peg_nodes:
		created_hierarchy_nodes.append({"node_info": x.node_info, "node": x.node})
	for x in created_kinematic_nodes:
		created_hierarchy_nodes.append({"node_info": x.node_info, "node": x.node})
	for x in created_bone_nodes:
		created_hierarchy_nodes.append({"node_info": x.node_info, "node": x.node})
	for x in created_remote_nodes:
		created_hierarchy_nodes.append({"node_info": x.node_info, "node": x.node})
	
	var all_created_nodes = created_hierarchy_nodes.duplicate()
	for x in created_drawing_nodes:
		all_created_nodes.append({"node_info": x.node_info, "node": x.node})

	var name_to_hierarchy_node = {}
	for x in created_hierarchy_nodes:
		name_to_hierarchy_node[x.node_info.name] = x.node

	var name_to_deform_bone_node = {}
	for x in created_bone_nodes:
		name_to_deform_bone_node[x.node_info.name] = x.node

	var name_to_kinematic_node = {}
	for x in created_kinematic_nodes:
		name_to_kinematic_node[x.node_info.name] = x.node

	var name_to_drawing_node = {}
	for x in created_drawing_nodes:
		name_to_drawing_node[x.node_info.name] = x.node

	# Load runtime scripts
	var cutter_script = load("%s/Cutter.gd" % RuntimeScriptsFolder)
	var drawing_script = load("%s/Drawing.gd" % RuntimeScriptsFolder)
	var composite_script = load("%s/Composite.gd" % RuntimeScriptsFolder)
	var composite_config_script = load("%s/CompositeConfig.gd" % RuntimeScriptsFolder)
	var polygon_config_script = load("%s/PolygonConfig.gd" % RuntimeScriptsFolder)
	var remote_drawing_transform_script = load("%s/RemoteDrawingTransform.gd" % RuntimeScriptsFolder)

	var name_to_skeleton_order = {}
	for entry in created_drawing_nodes:
		for node in skeleton.nodes:
			if node.name == entry.node_info.name:
				name_to_skeleton_order[entry.node_info.name] = node.id
				break

	# Load textures.
	var sstsi = SpriteSheetToSpriteInfos(xml_data, global_path, true, options)
	var sprite_sheet_to_sprite_infos: Dictionary = sstsi.result
	
	var texture_assets =  sstsi.textures
	if sprite_sheet_to_sprite_infos.is_empty():
		push_error("No sprite sheets found in TBG file.")
		return FAILED

	# Make the root --- name is file name
	var root_name = source_file.get_basename().get_file()
	if options["Motions/ImportAsMotionCharacter"]:
		var motion_character_script = load("%s/MotionCharacter.gd" % RuntimeScriptsFolder)
		root_node = motion_character_script.new() as Node
		root_node.set("frame_rate", stages[0].play.framerate)
	
		var character_config = Resource.new()
		var character_config_script = load("%s/MotionCharacterConfig.gd" % RuntimeScriptsFolder)
		character_config.set_script(character_config_script)
		root_node.set("config", character_config)
	
		var motion_configs = [];
		character_config.set("motions", motion_configs);

		for stage in stages:
			var mode = stage.play.mode;
			var facing = stage.play.facing;
		
			var motion_config = Resource.new();
			motion_configs.append(motion_config);
			
			var motion_config_script = load("%s/MotionConfig.gd" % RuntimeScriptsFolder);
			motion_config.set_script(motion_config_script);
			motion_config.set("loop", stage.play.loop);
			motion_config.set("animation_name", stage.play.name);
			motion_config.set("mode", stage.play.mode);
			var facing_map = {
				"None": TBG.Direction.None,
				"Left": TBG.Direction.Left,
				"Up Left": TBG.Direction.Up | TBG.Direction.Left,
				"Up": TBG.Direction.Up,
				"Up Right": TBG.Direction.Up | TBG.Direction.Right,
				"Right": TBG.Direction.Right,
				"Down Right": TBG.Direction.Down | TBG.Direction.Right,
				"Down": TBG.Direction.Down,
				"Down Left": TBG.Direction.Down | TBG.Direction.Left
			}
			var split_facing = facing_map.get(stage.play.facing, TBG.Direction.None)
			motion_config.set("facing", split_facing);
	else:
		root_node = Node2D.new()
	root_node.name = root_name
	root_node.set_meta("TBG", source_file)
	root_node.set_meta("tgsPath", xml_data.tgs_file_path)

	# Make all sprites the child of root under a single new canvas group.
	var composite_node
	if options["Rendering/UseCanvasLayer"]:
		composite_node = CanvasGroup.new()
		composite_node.name = "Composite"
	else:
		composite_node = Node2D.new()
		composite_node.name = "Composite"
	root_node.add_child(composite_node)
	composite_node.owner = root_node
	composite_node.set_script(composite_script)
	composite_node.set("perform_sort", true)
	composite_node.set("texture_assets", texture_assets)
	for entry in created_drawing_nodes:
		composite_node.add_child(entry.node)
		entry.node.owner = root_node
		entry.node.set_script(drawing_script)
		entry.node.set("skin_id", entry.skin_id)
		var node_order = name_to_skeleton_order.get(entry.node_info.name)
		if node_order != null:
			entry.node.set("node_order", node_order)
	
	# Add Cutter scripts to nodes getting cut, referencing their mattes.
	var name_to_sprite = {}
	for x in created_drawing_nodes:
		name_to_sprite[x.node_info.name] = x.node
	for cutter_node in skeleton.nodes:
		if cutter_node.tag == "cutter" or cutter_node.tag == "inverseCutter":
			var cutter_parents = []
			for link in skeleton.links:
				if link.node_out == cutter_node.id:
					var node = null
					for n in skeleton.nodes:
						if n.id == link.node_in:
							node = n
							break
					cutter_parents.append({"port": link.port, "node": node})
			
			var matte_node = null
			for entry in cutter_parents:
				if entry.port == CutterPort.MATTE:
					matte_node = entry.node
					break
			var cuttee_node = null
			for entry in cutter_parents:
				if entry.port == CutterPort.CUTTEE:
					cuttee_node = entry.node
					break
			
			var matte_sprite = name_to_sprite.get(matte_node.name)
			var cuttee_sprite = name_to_sprite.get(cuttee_node.name)
			if matte_sprite != null and cuttee_sprite != null:
				cuttee_sprite.set_script(cutter_script)
				cuttee_sprite.node_order = name_to_skeleton_order.get(cuttee_node.name)
				cuttee_sprite.matte_path = "../%s" % matte_sprite.name
				cuttee_sprite.inverse = cutter_node.tag == "inverseCutter"
				cuttee_sprite.connect("local_transform_changed", Callable(cuttee_sprite, "set_dirty"), CONNECT_PERSIST)
				matte_sprite.connect("local_transform_changed", Callable(cuttee_sprite, "set_dirty"), CONNECT_PERSIST)

				id_to_visibility[matte_sprite.name] = matte_sprite.visible
	
	# Setup node hierarchy.
	var created_skeleton_node = Skeleton2D.new()
	created_skeleton_node.name = "Skeleton"
	root_node.add_child(created_skeleton_node)
	created_skeleton_node.owner = root_node
	var node_id_to_node = {}
	
	for x in created_hierarchy_nodes:
		if not node_id_to_node.has(x.node_info.id):
			node_id_to_node[x.node_info.id] = []
		node_id_to_node[x.node_info.id].append(x.node)
	
	for link in skeleton.links:
		var nodes_out = node_id_to_node.get(link.node_out)
		if link.node_in == -1:
			if nodes_out:
				for node_out in nodes_out:
					created_skeleton_node.add_child(node_out)
			continue
		var nodes_in = node_id_to_node.get(link.node_in)
		if nodes_in == null or nodes_in.is_empty():
			continue
		var node_in = nodes_in[0]
		if node_in and nodes_out:
			for node_out in nodes_out:
				node_in.add_child(node_out)
	
	# Map read node's remote transform remote path to corresponding sprite nodes using relative path.
	for remote_transform in created_remote_nodes:
		remote_transform.node.set_script(remote_drawing_transform_script)
		var path = remote_transform.node.get_path_to(remote_transform.remote_node)
		remote_transform.node.set("remote_sprite_path", path)
	
	 #Set all nodes owners to root.
	for entry in all_created_nodes:
		entry.node.owner = root_node
	
	var composite_config = Resource.new()
	composite_config.set_script(composite_config_script)
	composite_node.config = composite_config
	
	composite_config.id_to_visibility = id_to_visibility
	
	# Generate ID to Texture lookup for Composite Config (Texture path to Texture resource)
	var id_to_texture = {}
	for sprite_name in sprite_sheet_to_sprite_infos:
		var sprite_info = sprite_sheet_to_sprite_infos[sprite_name]
		for drawing_name in sprite_sheet_to_sprite_infos[sprite_name]:
			id_to_texture[drawing_name] = {
				"texture": sprite_info[drawing_name].texture,
				"scale": sprite_info[drawing_name].scale,
				"offset": sprite_info[drawing_name].offset
			}
	composite_config.id_to_texture = id_to_texture

	# Generate skin id / group id from stage
	var group_to_skin_to_nodes = {}
	for created_drawing in created_drawing_nodes:
		if created_drawing.group_name == "":
			continue
		var skin_to_nodes = group_to_skin_to_nodes.get(created_drawing.group_name, {})
		var nodes = skin_to_nodes.get(created_drawing.skin_name, [])
		nodes.append(NodePath("./%s" % created_drawing.node.name))
		skin_to_nodes[created_drawing.skin_name] = nodes
		group_to_skin_to_nodes[created_drawing.group_name] = skin_to_nodes
	composite_config.group_to_skin_to_nodes = group_to_skin_to_nodes
	
	# Get polygon data. will be null if not imported as motion config
	var polygons_dict = {}
	for data in xml_data.sprite_sheets:
		var current_sprite_info = sprite_sheet_to_sprite_infos[data.resolution]
		for resource in current_sprite_info:
			var sprite_info = current_sprite_info[resource]
			polygons_dict["p-%s" % sprite_info.texture.resource_name] = sprite_info.polygons
	composite_config.polygons = polygons_dict
	
	# Add AnimationPlayer under root.
	var animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	animation_player.root_node = ".."
	root_node.add_child(animation_player)
	root_node.move_child(animation_player, 0)
	animation_player.owner = root_node

	# Assign the identity matrix to all bones as their rest pose instead!
	for bone in created_peg_nodes + created_bone_nodes:
		bone.node.rest = Transform2D.IDENTITY

	# Tesselate Polygon2Ds
	var rest_attributes = []
	
	for attr_link in xml_data.animations[stages[0].name].attr_links:
		if attr_link.attr.begins_with("rest."):
			rest_attributes.append(attr_link)
	
	var grid_size = 16
	var grid_size_plus_1 = grid_size + 1
	
	# Troll through the xml drawinganimations to find all textures used by polygons.
	var node_to_sprite_infos = {}
	for node in created_polygon_nodes:
		var texture_names = []
		for drawing_animations in xml_data.drawing_animations.values():
			if drawing_animations.drawings.has(node.node_info.name):
				for drw in drawing_animations.drawings[node.node_info.name]:
					texture_names.append(drw.name)
		texture_names = Utils.remove_duplicates_from_arr(texture_names)
		
		var sprite_infos = []
		for texture_name in texture_names:
			for sheet_sprite_infos in sprite_sheet_to_sprite_infos.values():
				var info = sheet_sprite_infos.get(texture_name)
				if info:
					sprite_infos.append(info)
		node_to_sprite_infos[node.node_info.name] = sprite_infos
	
	var node_to_texture_to_polygon_data = {}
	for node_entry in created_polygon_nodes:
		var texture_to_polygon_data = {}
		node_to_texture_to_polygon_data[node_entry.node.name] = texture_to_polygon_data
		for sprite_info in node_to_sprite_infos[node_entry.node_info.name]:
			var polygon_data = Resource.new()
			polygon_data.set_script(polygon_config_script)

			var polygon2d = node_entry.node
			var uv = PackedVector2Array()
			var atlas_size = sprite_info.texture.get_size()
			var region
			if sprite_info.texture is AtlasTexture:
				atlas_size = sprite_info.texture.atlas.get_size()
				region = sprite_info.texture.region
			else:
				region = Rect2(0, 0, atlas_size.x, atlas_size.y)

			# Create internal vertices
			var vertex_count = 0
			for i in range(grid_size_plus_1):
				for j in range(grid_size_plus_1):
					uv.append(Vector2(j, i) * region.size / grid_size + region.position)
					# HACK - Polygon transforms this pixel-friendly UV space from the 'AtlasTexture' (abstraction) size, not the Atlas (actual sampler) size, so we have to re-scale to make Polygon2D happy.
					uv[vertex_count] = uv[vertex_count] / atlas_size * region.size
					vertex_count += 1
			var positions = PackedVector2Array()
			vertex_count = 0
			for i in range(grid_size_plus_1):
				for j in range(grid_size_plus_1):
					positions.append((Vector2(j, i) * region.size / grid_size - region.size / 2.0 + sprite_info.offset) * sprite_info.scale)
					vertex_count += 1
			
			polygon_data.set("positions", positions)
			polygon_data.set("uv", uv)

			var polygons = []
			for i in range(grid_size):
				for j in range(grid_size):
					polygons.append([
						0 + 0 + j + i * grid_size_plus_1,
						1 + 0 + j + i * grid_size_plus_1,
						1 + grid_size_plus_1 + j + i * grid_size_plus_1,
						0 + grid_size_plus_1 + j + i * grid_size_plus_1
					])

			polygon2d.polygons = polygons
			polygon2d.skeleton = polygon2d.get_path_to(created_skeleton_node)
			polygon2d.internal_vertex_count = 0

			var bone_stats = []
			# Go through parents in xml skeleton to get all bones
			var bone_entries = []
			var parents = []
			
			parents.append(name_to_parent_node[node_entry.node_info.name])
			while not parents.is_empty():
				var parent = parents.pop_front()
				if parent.tag == "bone":
					var grandparent = name_to_parent_node.get(parent.name)
					var grandparent_name = grandparent.name if grandparent else ""
					bone_entries.append({"name" : parent.name, "parent" : grandparent_name, "bone" : name_to_deform_bone_node.get(parent.name)})
					parents.append(grandparent)
			bone_entries.reverse() # Start from the root bone
			
			for index in bone_entries.size():
				var bone_entry = bone_entries[index]
				
				# Determine if this bone is a deformation root
				var is_deformation_root = true
				if name_to_parent_node.has(bone_entry.name):
					if name_to_parent_node[bone_entry.name].tag == "bone":
						is_deformation_root = false
				
				# Gather rest attributes for the bone and its parent
				var rest = {}
				for attr_link in rest_attributes:
					if attr_link.node == bone_entry.name:
						if !rest.has(attr_link.attr):
							rest[attr_link.attr] = []
						rest[attr_link.attr].append(attr_link.value if attr_link.value != null else 0)
				
				var parent_rest = {}
				for attr_link in rest_attributes:
					if attr_link.node == bone_entry.parent:
						if !parent_rest.has(attr_link.attr):
							parent_rest[attr_link.attr] = []
						parent_rest[attr_link.attr].append(attr_link.value if attr_link.value != null else 0)
				
				# Set default values if no values found
				var radius = 0.0 if index == 0 else float(rest.get("rest.radius", [0])[0])
				var length = float(rest.get("rest.length", [0])[0])
				
				var rest_transform = deform_transform(
					is_deformation_root,
					Vector2(rest.get("rest.offset.x", [0.0])[0], -rest.get("rest.offset.y", [0.0])[0]), # TODO: Account for parent pivot again?
					parent_rest.get("rest.length", [0.0])[0],
					rest.get("rest.rotation.z", [0.0])[0],
					radius,
					radius
				)
				
				bone_stats.append([index, bone_entry.name, bone_entry.parent, bone_entry.bone, radius, length, rest_transform])
			
			# Go through all bones and set the rest pose.
			for stat in bone_stats:
				if stat[3] != null:
					stat[3].rest = stat[6]
			
			var bone_index_to_vertex_to_weight = []
			bone_index_to_vertex_to_weight.resize(bone_stats.size())
			for i in range(bone_stats.size()):
				var arr = []
				arr.resize(grid_size_plus_1 * grid_size_plus_1)
				for j in arr.size():
					arr[j] = 0.0
				bone_index_to_vertex_to_weight[i] = arr
			
			if bone_stats.size() > 0:
				var bone_index_to_children = {}
				for entry in bone_stats:
					var children = []
					for other_entry in bone_stats:
						if other_entry[2] == entry[1]:
							children.append(other_entry[0])
					bone_index_to_children[entry[0]] = children
				
				var bone_index_to_parent = {}
				for entry in bone_stats:
					var parent_index = -1
					for other_entry in bone_stats:
						if other_entry[1] == entry[2]:
							parent_index = other_entry[0]
							break
					bone_index_to_parent[entry[0]] = parent_index
				
				var sprite_transforms = []
				sprite_transforms.resize(bone_stats.size())
				for i in range(bone_stats.size()):
					var parent_index = -1
					var idx = 0
					for bone in bone_stats:
						if bone[1] == bone_stats[i][2]:
							parent_index = idx
						idx += 1
					var parent_transform = Transform2D.IDENTITY if parent_index == -1 else sprite_transforms[parent_index]
					sprite_transforms[i] = parent_transform * bone_stats[i][6]
				
				var bone_calcs = []
				bone_calcs.resize(bone_stats.size())
				for weights_index in range(uv.size()):
					var world_position = positions[weights_index]
					for index in range(bone_stats.size()):
						var bone = bone_stats[index]
						var child_index = bone_index_to_children[index][0] if bone_index_to_children.has(index) and bone_index_to_children[index].size() > 0 else -1
						var parent_index = bone_index_to_parent[index]
						var child_radius = 0.0 if child_index < 0 else bone_stats[child_index][4]
						var place_on_shrunken_bone = world_position * sprite_transforms[index] - Vector2.RIGHT * bone[4]
						var shrunken_length = bone[5] - bone[4] - child_radius
						if place_on_shrunken_bone.x < 0:
							bone_calcs[index] = {
								"distance": place_on_shrunken_bone.length(),
								"flat_distance": -place_on_shrunken_bone.x,
								"weight_against": WeightAgainst.Parent
							}
						elif place_on_shrunken_bone.x < shrunken_length:
							bone_calcs[index] = {
								"distance": abs(place_on_shrunken_bone.y),
								"flat_distance": 0.0,
								"weight_against": WeightAgainst.None
							}
						else:
							bone_calcs[index] = {
								"distance": (place_on_shrunken_bone - Vector2.RIGHT * shrunken_length).length(),
								"flat_distance": place_on_shrunken_bone.x - shrunken_length,
								"weight_against": WeightAgainst.Child
							}
					
					var closest_bone = {"index": -1, "distance": INF}
					for calcs_index in range(bone_calcs.size()):
						if bone_calcs[calcs_index].distance < closest_bone.distance:
							closest_bone = {"index": calcs_index, "distance": bone_calcs[calcs_index].distance}
					
					var closest_child_bone = {"index": -1, "distance": INF}
					if bone_index_to_children.has(closest_bone.index):
						for child_bone_index in bone_index_to_children[closest_bone.index]:
							if bone_calcs[child_bone_index].distance < closest_child_bone.distance:
								closest_child_bone = {"index": child_bone_index, "distance": bone_calcs[child_bone_index].distance}

					if bone_calcs[closest_bone.index].weight_against == WeightAgainst.None:
						bone_index_to_vertex_to_weight[closest_bone.index][weights_index] = 1
						continue
					
					var other_bone_index = bone_index_to_parent[closest_bone.index] if bone_calcs[closest_bone.index].weight_against == WeightAgainst.Parent else closest_child_bone.index
					if other_bone_index < 0:
						bone_index_to_vertex_to_weight[closest_bone.index][weights_index] = 1
						continue
					
					var weight0:float = pow(bone_calcs[closest_bone.index].flat_distance, 2.0)
					var weight1:float = pow(bone_calcs[other_bone_index].flat_distance, 2.0)
					var combined_distance = weight0 + weight1
					bone_index_to_vertex_to_weight[closest_bone.index][weights_index] = weight1 / combined_distance
					bone_index_to_vertex_to_weight[other_bone_index][weights_index] = weight0 / combined_distance

			var bone_path_to_vertex_to_weight = {}
			for bone_index in range(bone_stats.size()):
				var bone = bone_stats[bone_index]
				var vertex_to_weight = bone_index_to_vertex_to_weight[bone_index]
				var path = created_skeleton_node.get_path_to(bone[3])
				bone_path_to_vertex_to_weight[str(path)] = vertex_to_weight
			
			polygon_data.bones = bone_path_to_vertex_to_weight
			texture_to_polygon_data[sprite_info.texture.resource_name] = polygon_data
	
	composite_config.node_to_texture_to_polygon_data = node_to_texture_to_polygon_data
	
	var name_to_kinematic_transform = {}
	for entry in created_kinematic_nodes:
		var parent = name_to_parent_node.get(entry.node_info.name)
		if not parent:
			continue
		var parent_length = 0
		for attr_link in rest_attributes:
			if attr_link.node == parent.name and attr_link.attr == "rest.length":
				parent_length = attr_link.value if attr_link.value != null else 0
				break
		
		var transform = Transform2D.IDENTITY
		while parent and parent.tag == "bone":
			var rest = name_to_deform_bone_node.get(parent.name).rest
			if rest:
				transform = rest * transform
			parent = name_to_parent_node.get(parent.name)

		# Set the rest pose of the kinematic node to the inverse of the transform (important for child deformations)
		entry.node.rest = transform.affine_inverse()

		name_to_kinematic_transform[entry.node_info.name] = transform * Transform2D(0, Vector2.ONE, 0, Vector2(parent_length, 0))

	# Create animation library and attach to AnimationPlayer.
	var animation_library = AnimationLibrary.new()
	animation_library.resource_name = "AnimationLibrary"
	animation_player.add_animation_library("", animation_library)

	var name_to_remote_node = {}
	for x in created_remote_nodes:
		name_to_remote_node[x.node_info.name] = x.node

	for stage in stages:
		var animation = Animation.new()
		animation_library.add_animation(stage.name, animation)
		# Preliminary animation setup.
		var framerate = stage.play.framerate
		animation.length = stage.play.length / float(framerate)
		animation.step = 1.0 / float(framerate)
		animation.loop_mode = stage.play.loop

		# Convert all animated attrs to easily evaluatable curves.
		var animation_info = xml_data.animations.get(stage.name)
		
		if not animation_info:
			continue
		
		var node_to_attr_to_curve = {}
		for attr_link in animation_info.attr_links:
			var curves = node_to_attr_to_curve.get(attr_link.node, {})
			curves[attr_link.attr] = animation_attr_link_to_curve(animation_info, attr_link)
			node_to_attr_to_curve[attr_link.node] = curves
		
		# Gather pivot curves for animations.
		var node_to_pivot_curves = {}
		for node_to_attrs_entry in node_to_attr_to_curve:
			var pivot_attrs = []
			for attr_link in animation_info.attr_links:
				if attr_link.node == node_to_attrs_entry and attr_link.attr == "pivot":
					pivot_attrs.append(attr_link)
			if not pivot_attrs:
				continue
			var timed_values = animation_info.timed_values.get(pivot_attrs[0].timed_value)
			if not timed_values:
				continue
			var x_points = []
			var y_points = []
			for point in timed_values.points:
				x_points.append(Point.new(point.start, point.x))
				y_points.append(Point.new(point.start, point.y))
			node_to_pivot_curves[node_to_attrs_entry] = {"X": ConstCurve.new(x_points), "Y": ConstCurve.new(y_points)}
		
		# Special pivots calculated for Kinematic output. Takes the first non-bone ancestor as the starting point, adds in the bone chain's rest transforms, this is the kO pivot.
		for entry in name_to_kinematic_transform:
			var pivot = name_to_kinematic_transform[entry] * Vector2.ZERO
			node_to_pivot_curves[entry] = {"X": ConstCurve.from_value(pivot.x), "Y": ConstCurve.from_value(-pivot.y)}
		
		# Gather info relevant to animations from sprite sheets and sprite data.
		var default_sprite_sheet = sprite_sheet_to_sprite_infos.keys()[0]
		var sprite_sheet = sprite_sheet_to_sprite_infos[default_sprite_sheet]
		
		var node_to_attr_to_frames := {}
		if options["Optimization/RemoveEmptyTracks"]:
			for attr_link in animation_info.attr_links:
				if not node_to_attr_to_frames.has(attr_link.node):
					node_to_attr_to_frames[attr_link.node] = {}
				node_to_attr_to_frames[attr_link.node][attr_link.attr] = attr_link.iskeyed
		
		for node_entry in created_hierarchy_nodes:
			var node = node_entry.node
			var node_name = node_entry.node_info.name
			var drawing_node = name_to_drawing_node.get(node_name)
			var attr_to_curve = node_to_attr_to_curve.get(node_name, {})
			var node_is_deform_bone = name_to_deform_bone_node.has(node_entry.node_info.name) or name_to_kinematic_node.has(node_entry.node_info.name)
			var pivot_curves = node_to_pivot_curves.get(node_name, {"X": ConstCurve.from_value(0), "Y": ConstCurve.from_value(0)})
			var parent_pivot_curves = {"X": ConstCurve.from_value(0), "Y": ConstCurve.from_value(0)}
			
			if name_to_parent_node.has(node_name) and name_to_parent_node.size() > 0:
				parent_pivot_curves = node_to_pivot_curves.get(name_to_parent_node[node_name].name, {"X": ConstCurve.from_value(0), "Y": ConstCurve.from_value(0)})
			
			if not node_is_deform_bone:
				var curves = {
					"rotation": attr_to_curve.get("rotation.anglez", ConstCurve.from_value(0)),
					"skew": attr_to_curve.get("skew", ConstCurve.from_value(0)),
					"scale_x": attr_to_curve.get("scale.x", ConstCurve.from_value(1)),
					"scale_y": attr_to_curve.get("scale.y", ConstCurve.from_value(1)),
					"position_x": attr_to_curve.get("position.x", attr_to_curve.get("offset.x", ConstCurve.from_value(0))),
					"position_y": attr_to_curve.get("position.y", attr_to_curve.get("offset.y", ConstCurve.from_value(0))),
				}
				
				build_animation_tracks(animation, framerate, node, Animation.UPDATE_CONTINUOUS, func(frame):
					if options["Optimization/RemoveEmptyTracks"] and node_to_attr_to_frames.has(node_name):
						var result = {}
						if node_to_attr_to_frames[node_name].get("rotation.anglez", false):
							result["rotation"] = -curves.rotation.get_value(frame)
						if node_to_attr_to_frames[node_name].get("skew", false):
							result["skew"] = curves.skew.get_value(frame) * PI / 180
						if node_to_attr_to_frames[node_name].get("scale.x", false) or node_to_attr_to_frames[node_name].get("scale.y", false):
							result["scale"] = Vector2(curves.scale_x.get_value(frame), curves.scale_y.get_value(frame))
						if node_to_attr_to_frames[node_name].get("position.x", false) or node_to_attr_to_frames[node_name].get("position.y", false):
							result["position"] = Vector2(
								curves.position_x.get_value(frame) - parent_pivot_curves.X.get_value(frame) + pivot_curves.X.get_value(frame),
								-(curves.position_y.get_value(frame) - parent_pivot_curves.Y.get_value(frame) + pivot_curves.Y.get_value(frame))
							)
						if not options["Optimization/CompressAnimationTracks"] or not result:
							return result
					return {
						"rotation": -curves.rotation.get_value(frame),
						"skew": curves.skew.get_value(frame) * PI / 180,
						"scale": Vector2(curves.scale_x.get_value(frame), curves.scale_y.get_value(frame)),
						"position": Vector2(
							curves.position_x.get_value(frame) - parent_pivot_curves.X.get_value(frame) + pivot_curves.X.get_value(frame),
							-(curves.position_y.get_value(frame) - parent_pivot_curves.Y.get_value(frame) + pivot_curves.Y.get_value(frame))
						)
					})
			else:
				var parent_attr_to_curve = {}
				var parent_attr_to_frames = {}
				if name_to_parent_node.has(node_name) and name_to_parent_node.size() > 0:
					parent_attr_to_curve = node_to_attr_to_curve.get(name_to_parent_node[node_name].name, {})
					if options["Optimization/RemoveEmptyTracks"]:
						parent_attr_to_frames = node_to_attr_to_frames.get(name_to_parent_node[node_name].name, {})
				var child_attr_to_curve = {}
				var child_attr_to_frames = {}
				if name_to_child_nodes.has(node_name) and name_to_child_nodes.size() > 0 and name_to_child_nodes[node_name].size() > 0:
					child_attr_to_curve = node_to_attr_to_curve.get(name_to_child_nodes[node_name][0].name, {})
					if options["Optimization/RemoveEmptyTracks"]:
						child_attr_to_frames = node_to_attr_to_frames.get(name_to_child_nodes[node_name][0].name, {})
				
				var deform_curves = {
					"offset_x": attr_to_curve.get("deform.offset.x"),
					"offset_y": attr_to_curve.get("deform.offset.y"),
					"length": attr_to_curve.get("deform.length"),
					"rest_length": attr_to_curve.get("rest.length"),
					"parent_length": parent_attr_to_curve.get("deform.length"),
					"parent_rest_length": parent_attr_to_curve.get("rest.length"),
					"radius": attr_to_curve.get("deform.radius"),
					"rest_radius": attr_to_curve.get("rest.radius"),
					"parent_radius": parent_attr_to_curve.get("deform.radius"),
					"parent_rest_radius": parent_attr_to_curve.get("rest.radius"),
					"child_radius": child_attr_to_curve.get("deform.radius"),
					"rest_child_radius": child_attr_to_curve.get("rest.radius"),
					"rotation": attr_to_curve.get("deform.rotation.z")
				}
				var is_deformation_root = true
				if name_to_parent_node[node_name].tag == "bone":
					is_deformation_root = false
				var kinematic_rotation = 0.0
				if name_to_kinematic_transform.has(node_name):
					kinematic_rotation = name_to_kinematic_transform[node_name].get_rotation()

				build_animation_tracks(animation, framerate, node, Animation.UPDATE_CONTINUOUS, func(frame):
					var length_scale = 1.0 / DeformTransformScale(
						deform_curves.parent_length.get_value(frame) if deform_curves.parent_length else 1.0,
						deform_curves.parent_rest_length.get_value(frame) if deform_curves.parent_rest_length else 1.0,
						deform_curves.parent_radius.get_value(frame) if deform_curves.parent_radius else 1.0,
						deform_curves.parent_rest_radius.get_value(frame) if deform_curves.parent_rest_radius else 1.0,
						deform_curves.radius.get_value(frame) if deform_curves.radius else 1.0,
						deform_curves.rest_radius.get_value(frame) if deform_curves.rest_radius else 1.0
					)
					var offset = Vector2(
						deform_curves.offset_x.get_value(frame) if deform_curves.offset_x else 0.0,
						-(deform_curves.offset_y.get_value(frame) if deform_curves.offset_y else 0.0)
					) - Vector2(
						parent_pivot_curves.X.get_value(frame),
						-(parent_pivot_curves.Y.get_value(frame))
					)
					var parent_length = deform_curves.parent_length.get_value(frame) if deform_curves.parent_length else 0.0
					var radius = deform_curves.radius.get_value(frame) if deform_curves.radius else 1.0
					var rest_radius = deform_curves.rest_radius.get_value(frame) if deform_curves.rest_radius else 1.0
					var rotation = (deform_curves.rotation.get_value(frame) if deform_curves.rotation else 0.0) + kinematic_rotation
					var length = deform_curves.length.get_value(frame) if deform_curves.length else 1.0
					var rest_length = deform_curves.rest_length.get_value(frame) if deform_curves.rest_length else 1.0
					var child_radius = deform_curves.child_radius.get_value(frame) if deform_curves.child_radius else 1.0
					var rest_child_radius = deform_curves.rest_child_radius.get_value(frame) if deform_curves.rest_child_radius else 1.0
					
					if options["Optimization/RemoveEmptyTracks"] and node_to_attr_to_frames.has(node_name):
						var result = {}
						if node_to_attr_to_frames[node_name].get("length", false):
							result["length"] = deform_curves.rest_length.get_value(frame) if deform_curves.rest_length else 1.0
							
						if node_to_attr_to_frames[node_name].get("deform.rotation.z", false) or \
								node_to_attr_to_frames[node_name].get("deform.offset.x", false) or \
								node_to_attr_to_frames[node_name].get("deform.offset.y", false) or \
								node_to_attr_to_frames[node_name].get("deform.length", false) or \
								parent_attr_to_frames.get("deform.length", false) or \
								node_to_attr_to_frames[node_name].get("deform.radius", false) or \
								parent_attr_to_frames.get("deform.radius", false) or \
								child_attr_to_frames.get("deform.radius", false):
							result["transform"] = Transform2D(0, Vector2(length_scale, 1), 0, Vector2.ZERO) \
									* deform_transform(is_deformation_root, offset, parent_length, rotation, radius, rest_radius) \
									* Transform2D(0, Vector2(DeformTransformScale(length, rest_length, radius, rest_radius, child_radius, rest_child_radius), 1), 0, Vector2.ZERO)
						if not options["Optimization/CompressAnimationTracks"] or not result:
							return result
					return {
						"length": deform_curves.rest_length.get_value(frame) if deform_curves.rest_length else 1.0,
						"transform": Transform2D(0, Vector2(length_scale, 1), 0, Vector2.ZERO) \
							* deform_transform(is_deformation_root, offset, parent_length, rotation, radius, rest_radius) \
							* Transform2D(0, Vector2(DeformTransformScale(length, rest_length, radius, rest_radius, child_radius, rest_child_radius), 1), 0, Vector2.ZERO)
					})
		
		# position_z Animations --- For every sprite, gather all parent nodes to the root, aggregate their position.z animations, and set that to the position_z.
		for sprite_entry in created_drawing_nodes:
			var sprite_node = sprite_entry.node
			var sprite_name = sprite_entry.node_info.name
			var position_z_curves = []
			var cur_node = sprite_name
			while cur_node != "Top":
				var curve = node_to_attr_to_curve.get(cur_node, {}).get("position.z")
				if curve != null:
					position_z_curves.append(curve)
				var parent_nodes = name_to_parent_node
				if parent_nodes.size() > 0 and parent_nodes.has(cur_node):
					cur_node = parent_nodes[cur_node].name
				else:
					cur_node = "Top"
			
			var pivot_curves = node_to_pivot_curves.get(sprite_name, {"X": ConstCurve.from_value(0), "Y": ConstCurve.from_value(0)})
			
			build_animation_tracks(animation, framerate, sprite_node, Animation.UPDATE_CONTINUOUS, func(frame):
				var z_sum = 0.0
				for curve in position_z_curves:
					z_sum += curve.get_value(frame)
				return {
					"position_z": int(z_sum * 1024 * 16),
					"pivot": Vector2(pivot_curves.X.get_value(frame), pivot_curves.Y.get_value(frame))
				})

		# Drawing Animations --- The drawing substitutions of each sprite.
		for drawing_node in created_drawing_nodes:
			var drws = xml_data.drawing_animations[stage.name].drawings[drawing_node.node_info.name]
			var sprite_path = root_node.get_path_to(drawing_node.node)
			var texture_id_track_id = animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(texture_id_track_id, "%s:texture_id" % sprite_path)
			animation.value_track_set_update_mode(texture_id_track_id, Animation.UPDATE_CONTINUOUS)
			animation.track_set_interpolation_type(texture_id_track_id, Animation.INTERPOLATION_NEAREST)
			animation.track_set_interpolation_loop_wrap(texture_id_track_id, false)
			animation.track_insert_key(texture_id_track_id, 0, "", 0)
			for drw in drws:
				if drw.skin_id == drawing_node.skin_id:
					animation.track_insert_key(texture_id_track_id, float(drw.frame - 1) / float(framerate), drw.name, 0) # Reveal the texture
					if drw.frame + drw.repeat - 1 < stage.play.length:
						animation.track_insert_key(texture_id_track_id, float(drw.frame + drw.repeat - 1) / float(framerate), "", 0) # Hide the texture

		# Optimize transform animations --- find all tracks relating to transform manipulation and replace with a new track specifically setting the transform. This avoids lots of notification steps!
		if options["Optimization/CompressAnimationTracks"]:
			for node_entry in created_hierarchy_nodes:
				var node = node_entry.node
				var node_name = node_entry.node_info.name
				# Get all tracks relating to this node's transform.
				var position_track_id = animation.find_track("%s:position" % root_node.get_path_to(node), Animation.TYPE_VALUE)
				var rotation_track_id = animation.find_track("%s:rotation" % root_node.get_path_to(node), Animation.TYPE_VALUE)
				var scale_track_id = animation.find_track("%s:scale" % root_node.get_path_to(node), Animation.TYPE_VALUE)
				var skew_track_id = animation.find_track("%s:skew" % root_node.get_path_to(node), Animation.TYPE_VALUE)

				# If there's no transform tracks, skip this node.
				if position_track_id == -1 and rotation_track_id == -1 and scale_track_id == -1 and skew_track_id == -1:
					continue

				# Create new track.
				var previous_position = null
				var previous_rotation = null
				var previous_scale = null
				var previous_skew = null
				var previous_transform = null
				
				
				build_animation_track(animation, framerate, node, "transform", Animation.UPDATE_CONTINUOUS, func(frame):
					var position = node.position if position_track_id == -1 else track_find_value.call(animation, position_track_id, float(frame) / float(framerate))
					var rotation = node.rotation if rotation_track_id == -1 else track_find_value.call(animation, rotation_track_id, float(frame) / float(framerate))
					var scale = node.scale if scale_track_id == -1 else track_find_value.call(animation, scale_track_id, float(frame) / float(framerate))
					var skew = node.skew if skew_track_id == -1 else track_find_value.call(animation, skew_track_id, float(frame) / float(framerate))
					if previous_position != null and position.is_equal_approx(previous_position) and is_equal_approx(rotation, previous_rotation) and scale.is_equal_approx(previous_scale) and is_equal_approx(skew, previous_skew):
						return null
					var transform = Transform2D(rotation, scale, skew, position)
					previous_position = position
					previous_rotation = rotation
					previous_scale = scale
					previous_skew = skew
					previous_transform = transform
					return transform
					)
				
				# Delete old tracks.
				if position_track_id != -1:
					animation.remove_track(animation.find_track("%s:position" % root_node.get_path_to(node), Animation.TYPE_VALUE))
				if rotation_track_id != -1:
					animation.remove_track(animation.find_track("%s:rotation" % root_node.get_path_to(node), Animation.TYPE_VALUE))
				if scale_track_id != -1:
					animation.remove_track(animation.find_track("%s:scale" % root_node.get_path_to(node), Animation.TYPE_VALUE))
				if skew_track_id != -1:
					animation.remove_track(animation.find_track("%s:skew" % root_node.get_path_to(node), Animation.TYPE_VALUE))
	
	# Generate RESET animation --- this is the first frame of the first animation - Useful for blending animations.
	var reset_animation = Animation.new()
	animation_library.add_animation("RESET", reset_animation)
	reset_animation.length = 0
	reset_animation.step = 1
	reset_animation.loop_mode = Animation.LOOP_NONE
	var reference_animation = animation_library.get_animation(stages[0].name)
	var track_count = reference_animation.get_track_count()
	
	for track_index in range(track_count):
		# Gather all track info from reference animation
		var track_type = reference_animation.track_get_type(track_index)
		var track_path = reference_animation.track_get_path(track_index)
		var interpolation_type = reference_animation.track_get_interpolation_type(track_index)
		var update_mode = reference_animation.value_track_get_update_mode(track_index)
		var value = reference_animation.track_get_key_value(track_index, 0)

		# Apply to reset animation.
		var track_id = reset_animation.add_track(track_type)
		reset_animation.track_set_path(track_id, track_path)
		reset_animation.track_set_interpolation_type(track_id, interpolation_type)
		reset_animation.value_track_set_update_mode(track_id, update_mode)
		reset_animation.track_insert_key(track_id, 0, value, 0)

		# Apply this track value to the node directly as well.
		var prop = (track_path as String).split(":")[-1]
		var node = root_node.get_node_or_null(track_path)
		if node != null:
			node.set(prop, value)
	
	scene.pack(root_node) # SetThreadSafetyChecksEnabled(false) required so this doesn't complain - TODO: investigate
	
	ResourceSaver.save(scene, save_path + ".scn")
	
	var end_time = Time.get_ticks_msec()
	
	print("Imported " + source_file + " to " + save_path + " in " + str(float(end_time - start_time)/1000.0) + " seconds");
	
	return OK

func animation_attr_link_to_curve(animation, attr_link):
	var timed_values = animation.timed_values.get(attr_link.timed_value)
	
	if timed_values == null:
		return ConstCurve.from_value(attr_link.value)
	elif timed_values.tag == "bezier":
		return BezierCurve.from_timed_values(timed_values.points)
	else:
		return LinearCurve.from_timed_values(timed_values.points)

func build_animation_track(animation, framerate, node, godot_attribute, update_mode, frame_to_value):
	var track_id = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_id, "%s:%s" % [root_node.get_path_to(node), godot_attribute])
	animation.track_set_interpolation_type(track_id, Animation.INTERPOLATION_NEAREST)
	animation.value_track_set_update_mode(track_id, update_mode)
	animation.track_set_interpolation_loop_wrap(track_id, false)
	var previous_frame_value = null
	for frame in range(int(animation.length * float(framerate))):
		var value = frame_to_value.call(frame)
		if value == null:
			continue
		if previous_frame_value == null or not previous_frame_value.is_equal_approx(value):
			animation.track_insert_key(track_id, float(frame) / float(framerate), value, 0)
			previous_frame_value = value

func build_animation_tracks(animation, framerate, node, update_mode, frame_to_prop_to_value):
	var key_to_track_id = {}
	var initial_props = frame_to_prop_to_value.call(0)
	for key in initial_props:
		var track_id = animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track_id, "%s:%s" % [root_node.get_path_to(node), key])
		animation.track_set_interpolation_type(track_id, Animation.INTERPOLATION_NEAREST)
		animation.value_track_set_update_mode(track_id, update_mode)
		animation.track_set_interpolation_loop_wrap(track_id, false)
		key_to_track_id[key] = track_id
	
	var prop_to_previous_value = {}
	for frame in range(int(animation.length * float(framerate))):
		var prop_to_value = frame_to_prop_to_value.call(frame)
		for key in prop_to_value:
			var previous_frame_value = prop_to_previous_value.get(key)
			if previous_frame_value == null or previous_frame_value != prop_to_value[key]:
				
				animation.track_insert_key(key_to_track_id[key], float(frame) / float(framerate), prop_to_value[key], 0)
				prop_to_previous_value[key] = prop_to_value[key]

func track_find_value(animation, track_id, time):
	var key_index = animation.track_find_key(track_id, time)
	return animation.track_get_key_value(track_id, key_index)

func DeformTransformScale(length, rest_length, radius, rest_radius, child_radius, child_rest_radius):
	var length_minus_radius_delta = length - (radius - rest_radius) - (child_radius - child_rest_radius)
	return length_minus_radius_delta / rest_length

func deform_transform(is_deformation_root: bool, offset: Vector2, parent_length: float, rotation: float, radius: float, rest_radius: float) -> Transform2D:
	return Transform2D(
		-rotation,
		offset + (Vector2.ZERO if is_deformation_root else Vector2(parent_length, 0)) + Vector2(radius - rest_radius, 0).rotated(-rotation)
	)


# Used to change polygon accuracy, lower = more accuracy
const MASK_EPSILON := 2.0
# Used to reduce small polygons
const SMOOTH_POLY_OUTLINES := true
# Determines small polygon length
const SMOOTH_EPSILON := 0.75
# Won't really do much if above 1.0
const MASK_SCALE := 1.0

func get_polygons(image: Image, options: Dictionary) -> Array:
	## Don't bother when there's no motioncharacterconfig
	if not (options["Optimization/GeneratePolygons"] and options["Motions/ImportAsMotionCharacter"]):
		return []
	
	# Get/Generate bitmask
	var mask : = BitMap.new()
	mask.create_from_image_alpha(image, 0.5)
	if MASK_SCALE != 1.0:
		mask.resize(mask.get_size() * MASK_SCALE)
	
	var polys = mask.opaque_to_polygons(Rect2i(Vector2i(), mask.get_size()), MASK_EPSILON)
	
	if SMOOTH_POLY_OUTLINES:
		polys = polys.map(func(polygon):
			polygon = TBG.DrawingCollider.remove_short_segments(polygon, SMOOTH_EPSILON)
			var n = polygon.size()
			if n < 3:
				return null
			
			var a = polygon[n-1]
			for i in n:
				var b = polygon[i]
				polygon[i] = (a + b) * 0.5
				a = b
			
			return polygon
			)
		
		polys = polys.filter(func(e): if e: return true )
	
	var offset = image.get_size() * 0.5
	
	for polygon in polys:
		for i in polygon.size():
			polygon[i] = polygon[i] / MASK_SCALE - offset
	
	return polys
