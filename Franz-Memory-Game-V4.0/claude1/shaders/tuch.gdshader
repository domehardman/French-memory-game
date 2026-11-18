// Stoff, der leicht im Wind weht. Oben bleibt er fest.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D stoff_bild : source_color, repeat_disable, filter_linear_mipmap;
uniform vec3 toenung : source_color = vec3(0.3, 0.05, 0.04);
uniform float wind = 0.12;

void vertex() {
	float frei = UV.y;
	float zeit = TIME * 1.3 + MODEL_MATRIX[3].x * 0.7 + MODEL_MATRIX[3].z * 0.4;
	VERTEX.z += (sin(zeit + UV.y * 5.0) + sin(zeit * 1.7 + UV.y * 11.0 + UV.x * 3.0) * 0.4) * wind * frei * 4.0;
	VERTEX.x += sin(zeit * 0.8 + UV.y * 4.0) * wind * frei;
}

void fragment() {
	vec4 t = texture(stoff_bild, UV);
	if (t.a < 0.5) {
		discard;
	}
	ALBEDO = t.rgb * toenung * 2.0;
	ROUGHNESS = 0.9;
	BACKLIGHT = toenung * 0.35;
}
