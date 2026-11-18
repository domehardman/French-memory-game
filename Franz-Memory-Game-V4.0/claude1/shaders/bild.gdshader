// Letzter Schritt vor der Anzeige: gibt dem ganzen Bild den düsteren Look.
shader_type canvas_item;

uniform sampler2D bildschirm : hint_screen_texture, filter_linear;

// Dunkle Bildecken
uniform float vignette_staerke = 0.88;
// Feines Filmkorn
uniform float korn_staerke = 0.034;
// Schatten leicht blau, Helles leicht warm
uniform vec3 schatten_ton = vec3(0.90, 0.97, 1.08);
uniform vec3 licht_ton = vec3(0.98, 1.0, 1.03);

float zufall(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 farbe = texture(bildschirm, SCREEN_UV).rgb;

	float helligkeit = dot(farbe, vec3(0.299, 0.587, 0.114));
	farbe *= mix(schatten_ton, licht_ton, smoothstep(0.05, 0.6, helligkeit));

	vec2 mitte = SCREEN_UV - vec2(0.5);
	float abstand = dot(mitte, mitte);
	farbe *= 1.0 - smoothstep(0.08, 0.5, abstand) * vignette_staerke;

	float korn = zufall(SCREEN_UV + vec2(TIME * 0.37, TIME * 0.13)) - 0.5;
	farbe += korn * korn_staerke;

	COLOR = vec4(farbe, 1.0);
}
