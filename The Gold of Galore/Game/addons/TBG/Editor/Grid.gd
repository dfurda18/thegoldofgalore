@tool
## Node to render the grid of the ToonBoom view
extends Node2D

#const TbgPlugin = preload("Plugin.gd")

@export var motion := Vector2.ZERO
@export var show_labels: bool = true
@export var grid_lines: Array = [10,100,1000]
@export var major_unit: int = 100
@export var color: Color = Color(0,0,0,0.25)

var offset := Vector2.ZERO
var view_transform: Transform2D
@onready
var font = ThemeDB.get_default_theme().get_font("font", "")


#func _ready():
	 #set_process(true)


func _process(delta):
	if motion:
		offset = offset + motion * -delta
		queue_redraw()
	elif offset:
		offset = Vector2.ZERO
		queue_redraw()
	elif view_transform != get_global_transform_with_canvas():
		queue_redraw()


var _last_draw = TBG.time()
func _draw():
	view_transform = get_global_transform_with_canvas()
	var tx = view_transform.affine_inverse()
	var k = sqrt(tx.x.cross(tx.y))
	var t = TBG.time()
	var delta = t - _last_draw
	_last_draw = t
	
	var _rc = get_viewport_rect() #.grow(-100)
	#var container = TbgPlugin.find_containing(self, Container)
	#if container:
	#	_rc.position = container.global_position
	#	_rc.size = container.size
	
	var rc = Rect2(tx * _rc.position, tx * _rc.end - tx * _rc.position)
	
	# draw_rect(rc, Color(1,1,1,0.5), false)
	# draw_circle(rc.end, 100 * k, Color(1,1,1,0.5))
	
	# draw some background squares to illustrate motion
	if motion != Vector2.ZERO:
		var _scale = major_unit * 2
		var w = max(int(rc.size.x / _scale) * 2, 8)
		var h = max(int(rc.size.y / _scale) * 2, 8)

		offset = Vector2(fposmod(offset.x, _scale * w), fposmod(offset.y, _scale * h))
		w *= 2
		h *= 2
		
		for _x in w:
			for _y in h:
				if (_x ^ _y) & 1:
					draw_rect(Rect2(offset + Vector2(_x-w*0.75, _y-h*0.75) * _scale, Vector2.ONE * _scale * 0.5), Color(1,1,1,0.325), true)
	
	for _scale in grid_lines:
		for i in int(rc.size.x / _scale + 2):
			var x = rc.position.x - fposmod(rc.position.x, _scale) + i * _scale
			draw_line(Vector2(x, rc.position.y), Vector2(x, rc.end.y), color)
		for i in int(rc.size.y / _scale + 2):
			var y = rc.position.y - fposmod(rc.position.y, _scale) + i * _scale
			draw_line(Vector2(rc.position.x, y), Vector2(rc.end.x, y), color)

	# we set this scale here so that labels can be drawn ok (as adjusting font-size causes ugly artefacts)
	if show_labels:
		draw_set_transform(Vector2.ZERO, 0, tx.get_scale())
		var _scale = major_unit
		for i in int(rc.size.x / _scale + 2):
			var x = rc.position.x - fposmod(rc.position.x, _scale) + i * _scale
			draw_string(font, Vector2(x, rc.position.y) / k + Vector2(2,20), str(x), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, color)
		for i in int(rc.size.y / _scale + 2):
			var y = rc.position.y - fposmod(rc.position.y, _scale) + i * _scale
			draw_string(font, Vector2(rc.position.x, y) / k + Vector2(2,-2), str(y), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, color)
