// Festival crowd for the stands (ArenaDressing): one MultiMesh per pose of the baked
// villager (LowPoly.crowd_villager_mesh), all sharing this material.
// UV.x tags the part (LowPoly.CROWD_*): 0 skin, 0.1 hair, 0.2 shirt, 0.3 trousers, 0.4 hat.
// INSTANCE_CUSTOM.rgb is the shirt colour, already linear (converted on the CPU); INSTANCE_CUSTOM.a < 0.5 = no hat.
// Idle: a slow, small sway. `excitement` (0..1, set by CrowdReaction) makes a share of the
// crowd bounce and rise. Target: GL Compatibility; vertex-only work, no textures.
shader_type spatial;
render_mode cull_back;

uniform float excitement = 0.0;
uniform float idle_amount = 0.02;
uniform float idle_speed = 1.3;
uniform float cheer_height = 0.16;
uniform float cheer_speed = 9.0;
// Share of people who jump at full excitement (the rest only sway harder).
uniform float cheer_share = 0.65;
uniform vec3 skin : source_color = vec3(0.788, 0.608, 0.455);
uniform vec3 hair : source_color = vec3(0.118, 0.098, 0.078);
uniform vec3 trousers : source_color = vec3(0.169, 0.141, 0.125);
uniform vec3 hat : source_color = vec3(0.824, 0.729, 0.51);

varying vec3 tint;

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void vertex() {
	float id = float(INSTANCE_ID);
	float part = UV.x;
	tint = part < 0.05 ? skin : part < 0.15 ? hair : part < 0.25 ? INSTANCE_CUSTOM.rgb : part < 0.35 ? trousers : hat;
	// Bareheaded people: collapse the hat to a point inside the head.
	if (part > 0.35 && INSTANCE_CUSTOM.a < 0.5) {
		VERTEX = vec3(0.0, 1.5, 0.0);
	}
	float phase = hash(id) * 6.2831;
	float rate = 0.8 + hash(id + 3.1) * 0.4;
	// Idle: everyone sways a little, out of step with their neighbours (more at the head).
	VERTEX.x += sin(TIME * idle_speed * rate + phase) * idle_amount * clamp(VERTEX.y, 0.0, 1.7);
	VERTEX.y += sin(TIME * idle_speed * 2.0 * rate + phase) * idle_amount * 0.5;
	// Cheering: a bounce (|sin|) scaled by excitement, only for the chosen share.
	float joins = step(hash(id + 7.7), cheer_share);
	float bounce = abs(sin(TIME * cheer_speed * rate + phase));
	VERTEX.y += bounce * cheer_height * excitement * mix(0.25, 1.0, joins);
	// Small per-person shade change so neighbours with the same palette still differ.
	tint *= mix(0.85, 1.05, hash(id + 1.9));
}

void fragment() {
	ALBEDO = tint;
	ROUGHNESS = 0.9;
}
