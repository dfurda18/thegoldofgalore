@tool
extends TextureRect

#This script is needed to avoid errors when  plugin is opened for the first time from Toon Boom Jump!

@export var use_godot_builtin:bool = false
@export var use_resource_loader:bool = false
@export var icon_name:String : set=set_icon
@export var icons_path:String = "res://addons/tbg_sb_preview/Editor/assets/icons/"
@export var multiplay_by_screen_res = true
@export var icon_size = 30 :
	get:
		return icon_size
	set(value):
		custom_minimum_size = Vector2.ONE * (value * SB.get_screen_scale())
		if not multiplay_by_screen_res:
			custom_minimum_size = Vector2.ONE * (value / SB.get_screen_scale())
		icon_size = value

func _ready():
	#trigger the setter to correctly set the size each time plugin is loaded
	icon_size = icon_size

func set_icon(v):
	if not SB or not SB.plugin:return
	icon_name = v
	if not use_godot_builtin:
		if use_resource_loader:
			texture = ResourceLoader.load(icons_path+icon_name, "ImageTexture", ResourceLoader.CACHE_MODE_IGNORE)
		else:
			var img = Image.new()
			img.load(icons_path+icon_name)
			var img_tex := ImageTexture.new()
			img_tex.set_image(Image.load_from_file(icons_path+icon_name))
			if img_tex.get_image() != null:
				texture = img_tex
	else:
		var _icon = SB.plugin.editor.get_base_control().theme.get_icon(icon_name, "EditorIcons")
		if _icon != null:
			texture = _icon
