// Gentle festival cloth. MultiMesh tints travel as linear INSTANCE_CUSTOM, avoiding
// Compatibility's unreliable COLOR path. Adjacent bands share their world XZ phase.
shader_type spatial;
render_mode cull_disabled;

uniform float amplitude;
uniform float speed;
uniform float cycles;
uniform float phase_spread;
uniform float roughness;
uniform bool hanging = false;
uniform bool pennant = false;
uniform bool instance_colors = false;
uniform vec4 cloth_color : source_color;

varying vec3 tint;

void vertex() {
	float free_edge = hanging ? UV.y : UV.x;
	float phase = (MODEL_MATRIX[3].x + MODEL_MATRIX[3].z) * phase_spread;
	if (pennant) {
		VERTEX.x *= 1.0 - UV.y;
	}
	VERTEX.z += sin(TIME * speed - free_edge * cycles * 6.28318530718 + phase)
		* amplitude * free_edge * free_edge;
	tint = instance_colors ? INSTANCE_CUSTOM.rgb : cloth_color.rgb;
}

void fragment() {
	ALBEDO = tint;
	ROUGHNESS = roughness;
}
