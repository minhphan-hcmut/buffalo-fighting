// Horn glow for the hero buffalo (GDD Bảng 19). Replaces the shared keratin material
// at runtime; horns and hooves share that material, so `local_height` masks the glow
// to the horns only. Parameters are set by scripts/core/buffalo_feedback.gd.
shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color;
uniform sampler2D base_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D orm_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float base_roughness;
uniform float base_metallic;
uniform float base_specular;
uniform float normal_scale;
uniform vec4 glow_color : source_color;
uniform float glow_energy;
uniform float horn_base_height;
uniform float horn_full_height;
varying float local_height;
void vertex() { local_height = VERTEX.y; }
void fragment() {
	float horn = smoothstep(horn_base_height, horn_full_height, local_height);
	float lit = min(1.0, length(glow_color.rgb));
	ALBEDO = base_color.rgb * texture(base_texture, UV).rgb * (1.0 - horn * lit);
	vec3 orm = texture(orm_texture, UV).rgb;
	ROUGHNESS = base_roughness * orm.g;
	METALLIC = base_metallic * orm.b;
	SPECULAR = base_specular * (1.0 - horn * lit);
	NORMAL_MAP = texture(normal_texture, UV).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
	EMISSION = glow_color.rgb * glow_energy * horn;
}
