class_name BezierCurve

var points : Array = []

func _init(points = []):
	for point in points:
		self.points.append(point)

static func from_timed_values(timed_value_points):
	var curve = BezierCurve.new()
	for timed_value_point in timed_value_points:
		var left_handle_x = timed_value_point.lx if timed_value_point.lx != null else timed_value_point.x
		var left_handle_y = timed_value_point.ly if timed_value_point.ly != null else timed_value_point.y
		var right_handle_x = timed_value_point.rx if timed_value_point.rx != null else timed_value_point.x
		var right_handle_y = timed_value_point.ry if timed_value_point.ry != null else timed_value_point.y
		var bp = BezierPoint.new(timed_value_point.x - 1, timed_value_point.y)
		bp.const_seg = timed_value_point.const_seg if timed_value_point.const_seg != null else false
		bp.left_handle = Point.new(left_handle_x - 1, left_handle_y)
		bp.right_handle = Point.new(right_handle_x - 1, right_handle_y)
		curve.points.append(bp)
	return curve

func get_value(time):
	if time < points[0].x:
		return points[0].y
	elif time >= points[-1].x:
		return points[-1].y
	else:
		for i in range(points.size() - 1):
			if time >= points[i].x and time < points[i + 1].x:
				if points[i].const_seg:
					return points[i].y
				var u = find_u(time, points[i], points[i + 1])
				return get_value_y(u, points[i], points[i + 1])
	
	# Instead of throwing an exception, print an error message
	push_error("Could not find value for frame " + str(time))
	return null

func get_value_x(u, left, right):
	var a = LinearCurve.interpolate(u, left.x, left.right_handle.x)
	var b = LinearCurve.interpolate(u, left.right_handle.x, right.left_handle.x)
	var c = LinearCurve.interpolate(u, right.left_handle.x, right.x)
	var d = LinearCurve.interpolate(u, a, b)
	var e = LinearCurve.interpolate(u, b, c)
	var f = LinearCurve.interpolate(u, d, e)
	return f

func get_value_y(u, left, right):
	var a = LinearCurve.interpolate(u, left.y, left.right_handle.y)
	var b = LinearCurve.interpolate(u, left.right_handle.y, right.left_handle.y)
	var c = LinearCurve.interpolate(u, right.left_handle.y, right.y)
	var d = LinearCurve.interpolate(u, a, b)
	var e = LinearCurve.interpolate(u, b, c)
	var f = LinearCurve.interpolate(u, d, e)
	return f

func find_u(time, left, right):
	if left.x == time:
		return 0.0
	elif right.x == time:
		return 1.0
	else:
		var i = 0
		var u
		var v
		var u1 = 0.0
		var u2 = 1.0
		while true:
			u = 0.5 * (u1 + u2)
			v = get_value_x(u, left, right)
			if v < time:
				u1 = u
			else:
				u2 = u
			if not (abs(v - time) > 5e-10 and (++i < 52)):
				break
		return u
