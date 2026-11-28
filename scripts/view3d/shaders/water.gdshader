shader_type spatial;
// Chapter water: rivers, lakes and swamp shallows from a mask. Scrolling normals, fresnel tint,
// sun glints, darker depths, soft shores and a little foam where it meets the bank.
render_mode diffuse_burley, specular_disabled, cull_disabled, depth_draw_always;

uniform sampler2D mask : filter_linear, repeat_disable;   // r: water amount (0.5 shallow, 1 deep), blurred
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec2 map_size = vec2(360.0, 360.0);
uniform vec3 deep_col : source_color = vec3(0.02, 0.07, 0.1);
uniform vec3 shallow_col : source_color = vec3(0.07, 0.16, 0.17);
uniform vec3 sky_col : source_color = vec3(0.35, 0.42, 0.48);
uniform float murk = 0.0;   // swamp: greener, cloudier
uniform vec2 flow = vec2(0.02, 0.01);

varying vec2 wxz;

void vertex() {
	wxz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	VERTEX.y += sin(wxz.x * 0.7 + TIME * 1.3) * 0.015 + cos(wxz.y * 0.5 + TIME) * 0.015;
}

void fragment() {
	float m = texture(mask, wxz / map_size).r;
	if (m < 0.02) { discard; }
	vec2 uv = wxz / 7.0;
	vec3 n1 = texture(normal_tex, uv + TIME * flow).rgb;
	vec3 n2 = texture(normal_tex, uv * 1.7 - TIME * flow.yx * 1.3).rgb;
	NORMAL_MAP = normalize(n1 + n2 - 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.6;
	float depth = smoothstep(0.25, 1.0, m);
	vec3 base = mix(shallow_col, deep_col, depth);
	base = mix(base, vec3(0.06, 0.1, 0.04), murk * 0.65);
	// the camera looks down at a fixed angle, so fake the sky reflection from the ripples instead of fresnel
	float ripple = clamp((n1.r - 0.5) * 2.0 + (n2.g - 0.5) * 1.5, -1.0, 1.0);
	vec3 col = base + sky_col * (0.22 + 0.16 * ripple) * (1.0 - murk * 0.5);
	// foam line where the water starts
	float foam = smoothstep(0.12, 0.2, m) * (1.0 - smoothstep(0.2, 0.34, m));
	float fn = texture(normal_tex, wxz / 2.3 + TIME * 0.03).r;
	col += vec3(0.55, 0.58, 0.55) * foam * smoothstep(0.42, 0.62, fn) * (1.0 - murk * 0.5);
	// small sun glints from the ripples (the top-down camera would otherwise see one flat sheen)
	float gl = smoothstep(0.78, 0.9, n1.r * n2.g) * (1.0 - murk * 0.7);
	ALBEDO = col;
	EMISSION = vec3(0.9, 0.85, 0.7) * gl * 0.8;
	ROUGHNESS = 0.6;
	METALLIC = 0.0;
	ALPHA = clamp(smoothstep(0.08, 0.3, m) * mix(0.72, 0.95, depth), 0.0, 1.0);
}
