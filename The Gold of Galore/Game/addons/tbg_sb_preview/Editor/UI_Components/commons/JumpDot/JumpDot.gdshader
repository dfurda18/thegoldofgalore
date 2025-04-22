shader_type canvas_item;

float circle(vec2 position, float radius, float feather)
{
	return smoothstep(radius, radius + feather, length(position - vec2(0.5)));
}

void fragment() {
	COLOR.a = 1.0-vec3( circle(UV, 0.45, 0.02)).r;
}
