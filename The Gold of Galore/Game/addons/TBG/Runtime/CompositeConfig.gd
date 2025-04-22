@tool
## Resource used to store and use skin data
extends Resource
class_name CompositeConfig

@export var node_to_texture_to_polygon_data: Dictionary = {}
@export var id_to_texture: Dictionary = {}
@export var group_to_skin_to_nodes: Dictionary = {}
@export var id_to_visibility: Dictionary = {}
@export var polygons: Dictionary = {}
