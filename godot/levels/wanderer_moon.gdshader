shader_type spatial;
// The Wanderer, drawn as a disc lit from one side: phase 0 dark, 0.5 full, 1 dark again.
render_mode unshaded, cull_disabled, fog_disabled, depth_draw_never, shadows_disabled, blend_mix;

uniform float phase = 0.5;
uniform vec4 color : source_color = vec4(0.62, 0.95, 0.7, 1.0);
uniform float fade = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r2 = dot(p, p);
	if (r2 > 1.0) {
		discard;
	}
	float z = sqrt(1.0 - r2);
	float a = phase * 6.2831853;
	vec3 light_dir = vec3(-sin(a), 0.0, -cos(a));   // waxing: lit on the right, as you look at it
	float lit = smoothstep(-0.05, 0.05, dot(vec3(p.x, p.y, z), light_dir));
	ALBEDO = color.rgb * mix(0.08, 1.0, lit);
	ALPHA = fade * mix(0.12, 1.0, lit) * smoothstep(1.0, 0.94, r2);
}
