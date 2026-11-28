shader_type spatial;
// Chapter terrain: region splat (forest / swamp / barrow + route), height from a map, tiled textures
// with a second scale to hide repeats, wet darkening near water, leaf litter under the tree walls.
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D splat : filter_linear, repeat_disable;     // r forest, g swamp, b barrow
uniform sampler2D aux : filter_linear, repeat_disable;       // r under-trees, g wetness, b stone floor, a path
uniform sampler2D heightmap : filter_linear, repeat_disable; // r height (m)
uniform sampler2D tex_grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_litter : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_mud : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_path : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_barrow : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_stone : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 map_size = vec2(360.0, 360.0);
uniform float tile = 4.0;

varying vec2 wxz;

float h_at(vec2 w) {
	return textureLod(heightmap, w / map_size, 0.0).r;
}

void vertex() {
	wxz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	float h = h_at(wxz);
	VERTEX.y += h;
	float e = 1.0;
	float hx = h_at(wxz + vec2(e, 0.0)) - h_at(wxz - vec2(e, 0.0));
	float hz = h_at(wxz + vec2(0.0, e)) - h_at(wxz - vec2(0.0, e));
	NORMAL = normalize(vec3(-hx, 2.0 * e, -hz));
}

vec3 tri(sampler2D t, vec2 uv) {
	// two scales, slightly rotated, to break up tiling
	vec3 a = texture(t, uv).rgb;
	vec2 uv2 = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * uv * 0.37;
	vec3 b = texture(t, uv2).rgb;
	return mix(a, b, 0.35);
}

void fragment() {
	vec2 muv = wxz / map_size;
	vec4 s = texture(splat, muv);
	vec4 x = texture(aux, muv);
	vec2 uv = wxz / tile;
	vec3 grass = tri(tex_grass, uv);
	vec3 mud = tri(tex_mud, uv * 0.8);
	vec3 bar = tri(tex_barrow, uv);
	float sum = max(0.001, s.r + s.g + s.b);
	vec3 col = (grass * s.r + mud * s.g + bar * s.b) / sum;
	col = mix(col, tri(tex_litter, uv * 0.9), clamp(x.r, 0.0, 1.0) * 0.85);
	col = mix(col, tri(tex_path, uv * 1.2), smoothstep(0.05, 0.8, x.a) * 0.9);
	col = mix(col, tri(tex_stone, uv * 0.5), x.b);
	float wet = clamp(x.g, 0.0, 1.0);
	col *= mix(1.0, 0.55, wet);
	// macro tone variation
	float macro = texture(tex_mud, wxz / 61.0).g;
	col *= 0.85 + macro * 0.5;
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.75, wet);
	SPECULAR = mix(0.25, 0.35, wet);
}
