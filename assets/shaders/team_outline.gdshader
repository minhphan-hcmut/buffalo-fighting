// Team outline for the buffaloes (GDD 5.1: red side bright rim, blue side dark rim).
// Inverted hull: added as next_pass on each body surface by Buffalo.add_team_outline().
// Target: GL Compatibility; one extra unshaded pass per surface, no textures.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, fog_disabled;

uniform vec4 outline_color : source_color = vec4(1.0, 0.55, 0.42, 1.0);
// Rim width in metres at `reference_distance`; widened with distance so it keeps a
// near-constant on-screen thickness from the shoulder camera.
uniform float outline_width = 0.018;
uniform float reference_distance = 6.0;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float distance_scale = clamp(length(CAMERA_POSITION_WORLD - world) / reference_distance, 0.6, 3.0);
	// Divide out the model's own scale so the width is in world metres.
	float model_scale = length(MODEL_MATRIX[0].xyz);
	VERTEX += normalize(NORMAL) * outline_width * distance_scale / max(model_scale, 0.001);
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
