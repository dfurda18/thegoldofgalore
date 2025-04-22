@tool
extends Node2D

@export var motion:Vector2
@export var showLabels:bool = true
@export var gridLines:Array = [10,100,1000]
@export var majorUnit:int = 100
@export var color:Color = Color(0,0,0,0.25)

var offset = Vector2.ZERO

var viewTransform:Transform2D

var _last_draw = Time.get_ticks_msec() / 1000.0

func _ready():
	pass

func _draw():
	viewTransform = get_global_transform_with_canvas()
	var tx = viewTransform.affine_inverse()
	var k = sqrt(tx.x.cross(tx.y))
	var t = Time.get_ticks_msec() / 1000.0
	var delta = t - _last_draw
	_last_draw = t
		
	var _rc = get_viewport_rect()
	
	var rc = Rect2(tx * _rc.position, tx * _rc.end - tx * _rc.position)
	
	if true: # draw some background squares to illustrate motion
		var scale = majorUnit * 2
		var w = max(int(rc.size.x / scale) * 2, 8)
		var h = max(int(rc.size.y / scale) * 2, 8)

		offset = Vector2(fposmod(offset.x, scale * w), fposmod(offset.y, scale * h))
		w *= 2
		h *= 2

		for _x in w:
			for _y in h:
				if (_x ^ _y) & 1:
					draw_rect(Rect2(offset + Vector2(_x-w*0.75, _y-h*0.75) * scale, Vector2.ONE * scale * 0.5), Color(1,1,1,0.025), true)
	
	for scale in gridLines:
		for i in int(rc.size.x / scale + 2):
			var x = rc.position.x - fposmod(rc.position.x, scale) + i * scale
			draw_line(Vector2(x, rc.position.y), Vector2(x, rc.end.y), color)
		for i in int(rc.size.y / scale + 2):
			var y = rc.position.y - fposmod(rc.position.y, scale) + i * scale
			draw_line(Vector2(rc.position.x, y), Vector2(rc.end.x, y), color)

	# we set this scale here so that labels can be drawn ok (as adjusting font-size causes ugly artefacts)
	if showLabels:
		draw_set_transform(Vector2.ZERO, 0, tx.get_scale())
		var scale = majorUnit
		for i in int(rc.size.x / scale + 2):
			var x = rc.position.x - fposmod(rc.position.x, scale) + i * scale
			draw_string(ThemeDB.get_default_theme().get_font("font", ""), Vector2(x, rc.position.y) / k + Vector2(2,20), str(x), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, color)
		for i in int(rc.size.y / scale + 2):
			var y = rc.position.y - fposmod(rc.position.y, scale) + i * scale
			draw_string(ThemeDB.get_default_theme().get_font("font", ""), Vector2(rc.position.x, y) / k + Vector2(2,-2), str(y), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, color)

func _process(delta):
	offset = offset + motion * -delta
	if !motion.is_zero_approx() || viewTransform != get_global_transform_with_canvas():
		queue_redraw()
