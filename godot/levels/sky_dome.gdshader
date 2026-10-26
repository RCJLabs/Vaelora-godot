shader_type spatial;
// Clouds and stars on a great dome round the camera (levels/sky_dome.gd), not in the
// sky shader: a sky that moves with TIME recomputes the scene's ambient light every
// frame, which phones can't spare. DayNight sets night, cloud_color and cover.
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D noise;
uniform float cover : hint_range(0.0, 1.0) = 0.4;
uniform vec4 cloud_color : source_color = vec4(1.0, 1.0, 1.0, 0.9);
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform float drift = 0.004;

varying vec3 dir;

void vertex() {
	dir = normalize(VERTEX);
}

void fragment() {
	float up = dir.y;
	if (up < 0.0) {
		discard;
	}
	vec2 p = dir.xz / (up + 0.2) * 0.3;   // the dome flattened onto a ceiling
	float n = texture(noise, p + vec2(TIME * drift, TIME * drift * 0.5)).r * 0.65
			+ texture(noise, p * 2.3 - vec2(TIME * drift * 1.5, 0.0)).r * 0.35;
	float c = smoothstep(1.0 - cover, 1.0 - cover + 0.3, n) * smoothstep(0.0, 0.2, up);
	// Stars: a few cells of the dome, lit, where no cloud is.
	vec3 cell = floor(dir * 320.0);
	float h = fract(sin(dot(cell, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
	float twinkle = 0.7 + 0.3 * sin(TIME * 2.0 + h * 40.0);
	float star = step(0.9972, h) * night * smoothstep(0.05, 0.35, up) * (1.0 - c) * twinkle;
	float shade = 0.82 + 0.18 * smoothstep(0.3, 0.9, n);   // lit tops, darker bellies
	ALBEDO = mix(vec3(1.0), cloud_color.rgb * shade, step(star, c));
	ALPHA = max(c * cloud_color.a, star);
}
