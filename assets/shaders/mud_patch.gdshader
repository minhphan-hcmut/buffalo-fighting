shader_type spatial;
// Wet mud patch laid flat on the arena floor. The edge is broken up by noise and fades
// into the dry earth; the centre is darker, with glossy puddles and churned clods.
// Purely visual: the gameplay mud zone stays the circle in ArenaBounds.
// Surface detail comes from a scanned CC0 mud set (Poly Haven "Brown Mud 03"), tinted to
// the palette below; the noise only shapes the patch, its puddles and its rim.
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;

uniform vec4 mud_color : source_color = vec4(0.15, 0.10, 0.07, 1.0);
uniform vec4 rim_color : source_color = vec4(0.25, 0.17, 0.11, 1.0);
uniform vec4 puddle_color : source_color = vec4(0.09, 0.075, 0.065, 1.0);
// Fraction of the quad's half-size where the patch reaches the gameplay radius.
uniform float radius_fraction = 0.8;
uniform float edge_noise = 0.16;
uniform float edge_soft = 0.08;
uniform float puddle_amount = 0.42;
uniform float wet_roughness;
uniform float wet_depth;
uniform float puddle_roughness;
uniform float wet_specular;
uniform float puddle_specular;
uniform float sheen_strength;
uniform float sheen_power;
uniform float sheen_frequency;
uniform float sheen_sharpness;
uniform float wet_rim_width;
uniform float wet_rim_darken;
uniform float seed = 0.0;
uniform sampler2D mud_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// AO (r), roughness (g), metal (b).
uniform sampler2D mud_arm : filter_linear_mipmap_anisotropic, repeat_enable;
// How many texture tiles span the quad, so one tile keeps its real-world size.
uniform float tile_count = 5.0;
uniform float texture_normal_depth = 1.0;
uniform float texture_ao = 1.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		// Rotate each octave so the value-noise grid never lines up into squares.
		p = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	vec2 q = p * 3.0 + seed;
	float r = length(p) / radius_fraction;
	float wobble = (fbm(q) - 0.5) * 2.0 * edge_noise;
	float mask = 1.0 - smoothstep(1.0 - edge_soft + wobble, 1.0 + edge_soft + wobble, r);
	// Splatter flecks just outside the rim.
	// Fine detail fades out when a pixel covers several noise cells (far or high camera),
	// otherwise it aliases into visible squares.
	float detail = 1.0 - clamp(fwidth(p.x) * 30.0, 0.0, 1.0);
	float fleck = smoothstep(0.8, 0.9, fbm(p * 9.0 + seed)) * (1.0 - smoothstep(1.0, 1.25, r + wobble)) * detail;
	mask = max(mask, fleck * 0.75);
	float depth = 1.0 - smoothstep(0.0, 1.0 + wobble, r);
	float water_noise = fbm(q * 1.4 + 3.1) * (0.6 + depth * 0.7);
	float puddle = smoothstep(1.0 - puddle_amount, 1.0 - puddle_amount + 0.08, water_noise);
	float wet_rim = smoothstep(1.0 - puddle_amount - wet_rim_width, 1.0 - puddle_amount, water_noise) * (1.0 - puddle);
	vec2 tile_uv = UV * tile_count + vec2(seed * 0.37, seed * 0.61);
	vec3 scan = texture(mud_albedo, tile_uv).rgb;
	vec3 arm = texture(mud_arm, tile_uv).rgb;
	vec3 col = mix(rim_color.rgb, mud_color.rgb, smoothstep(0.15, 0.85, depth));
	// Divide by the scan's own mean (its smallest mip) so it only adds detail around the
	// palette. Read from the texture because Compatibility may sample it undecoded (sRGB).
	col *= scan / max(textureLod(mud_albedo, vec2(0.5), 16.0).rgb, vec3(0.01));
	col *= mix(1.0, arm.r, texture_ao);
	col *= 1.0 - wet_rim * wet_rim_darken;
	col = mix(col, puddle_color.rgb, puddle);
	// Churned lip: a lighter, drier band just inside the rim, so the patch reads as
	// trodden mud rather than a shadow on the ground.
	float lip = smoothstep(0.62, 0.85, r - wobble * 0.5) * (1.0 - smoothstep(0.9, 1.02, r - wobble * 0.5));
	col = mix(col, rim_color.rgb * 1.35, lip * 0.6);
	ALBEDO = col;
	float wet = smoothstep(0.0, wet_depth, depth);
	// The scan's roughness varies around ~0.52; wet mud shifts it down, puddles flatten it.
	float scan_rough = arm.g - 0.52;
	ROUGHNESS = clamp(mix(mix(0.9, wet_roughness, wet) + scan_rough, puddle_roughness, puddle), 0.0, 1.0);
	SPECULAR = mix(mix(0.1, wet_specular, wet), puddle_specular, puddle);
	// Subtle sky sheen works without screen-space reflections on Compatibility.
	float sheen = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), sheen_power);
	float streak = pow(abs(sin(dot(p, normalize(VIEW.xz)) * sheen_frequency + noise(q))), sheen_sharpness);
	EMISSION = rim_color.rgb * sheen * sheen_strength * puddle * streak;
	// Standing water is flat: the scanned relief sinks under the puddles.
	NORMAL_MAP = texture(mud_normal, tile_uv).rgb;
	NORMAL_MAP_DEPTH = texture_normal_depth * (1.0 - puddle);
	ALPHA = mask;
}
