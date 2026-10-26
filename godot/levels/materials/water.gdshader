shader_type spatial;
// Water: two layers of ripples scrolling with the flow, darker looking straight down,
// lighter and shinier at a glance (a cheap fresnel). levels/builders/builder_base.gd
// water_mat(). docs/godot-starter/LOOK.md, "Water and sky".
render_mode blend_mix, cull_back, depth_draw_opaque;

uniform vec4 shallow : source_color = vec4(0.26, 0.4, 0.44, 0.7);
uniform vec4 deep : source_color = vec4(0.07, 0.15, 0.2, 0.9);
uniform sampler2D ripples : hint_normal;
uniform float ripple_scale = 0.07;
uniform vec2 flow = vec2(0.0, 0.0);   // which way, and how fast, the water moves

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world.xz * ripple_scale;
	vec3 a = texture(ripples, uv + flow * TIME + vec2(TIME * 0.006, 0.0)).rgb;
	vec3 b = texture(ripples, uv * 1.9 + flow * TIME * 1.3 - vec2(0.0, TIME * 0.009) + vec2(0.37)).rgb;
	NORMAL_MAP = normalize(a + b - 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.7;
	float glance = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(deep.rgb, shallow.rgb, glance);
	ALPHA = mix(deep.a, 0.97, glance);
	ROUGHNESS = 0.06;
	SPECULAR = 0.7;
}
