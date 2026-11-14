shader_type spatial;
// Wet mud patch laid flat on the arena floor. The edge is broken up by noise and fades
// into the dry earth; the centre is darker, with glossy puddles and churned clods.
// Purely visual: the gameplay mud zone stays the circle in ArenaBounds.
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
uniform float normal_strength;
uniform float seed = 0.0;

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
	float clods = mix(0.5, fbm(p * 8.0 + seed * 2.0), detail);
	vec3 col = mix(rim_color.rgb, mud_color.rgb, smoothstep(0.15, 0.85, depth));
	col *= 0.85 + clods * 0.3;
	col *= 1.0 - wet_rim * wet_rim_darken;
	col = mix(col, puddle_color.rgb, puddle);
	// Churned lip: a lighter, drier band just inside the rim, so the patch reads as
	// trodden mud rather than a shadow on the ground.
	float lip = smoothstep(0.62, 0.85, r - wobble * 0.5) * (1.0 - smoothstep(0.9, 1.02, r - wobble * 0.5));
	col = mix(col, rim_color.rgb * 1.35, lip * 0.6);
	ALBEDO = col;
	float wet = smoothstep(0.0, wet_depth, depth);
	ROUGHNESS = mix(mix(0.9, wet_roughness, wet), puddle_roughness, puddle);
	SPECULAR = mix(mix(0.1, wet_specular, wet), puddle_specular, puddle);
	// Subtle sky sheen works without screen-space reflections on Compatibility.
	float sheen = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), sheen_power);
	float streak = pow(abs(sin(dot(p, normalize(VIEW.xz)) * sheen_frequency + noise(q))), sheen_sharpness);
	EMISSION = rim_color.rgb * sheen * sheen_strength * puddle * streak;
	NORMAL = normalize(NORMAL + vec3(dFdx(clods), dFdy(clods), 0.0) * normal_strength * (1.0 - puddle));
	ALPHA = mask;
}
