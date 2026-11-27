shader_type canvas_item;
// Hit flash + status tint for pixel-art sprites.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	c.rgb = mix(c.rgb * tint.rgb, vec3(1.0), flash);
	COLOR = c;
}
