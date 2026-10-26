shader_type spatial;
// Grass, reeds, flowers and stones scattered by props/ground_cover.gd.
// COLOR: the mesh's own shading (darker at the roots). INSTANCE_CUSTOM: the
// instance's colour, applied as much as UV.x says (flower stems keep their green).
// UV.y: how much a vertex sways (0 at the root, 1 at the tip).
render_mode cull_disabled, specular_disabled;

uniform float sway = 0.08;

varying vec3 tint;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float wind = sin(TIME * 1.6 + world.x * 0.31 + world.z * 0.23) + 0.5 * sin(TIME * 2.7 + world.z * 0.57);
	float bend = UV.y * UV.y * sway * wind;
	VERTEX.x += bend;
	VERTEX.z += bend * 0.5;
	tint = mix(vec3(1.0), INSTANCE_CUSTOM.rgb, UV.x);
}

void fragment() {
	ALBEDO = COLOR.rgb * tint;
	ROUGHNESS = 1.0;
}
