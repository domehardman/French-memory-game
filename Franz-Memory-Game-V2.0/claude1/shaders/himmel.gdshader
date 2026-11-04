// Nachthimmel mit Mond, Wolken und Sternen.
shader_type sky;

uniform vec3 himmel_oben : source_color = vec3(0.06, 0.07, 0.09);
uniform vec3 himmel_unten : source_color = vec3(0.36, 0.40, 0.45);
uniform vec3 mond_farbe : source_color = vec3(0.86, 0.9, 1.0);
uniform vec3 schimmer_farbe : source_color = vec3(0.32, 0.2, 0.46);
uniform float mond_groesse = 0.042;
uniform float mond_krater = 0.0;           // 0 = glatte Scheibe, 1 = sichtbare Krater

// Zufallszahl und weiches Rauschen für die Wolken.
float zufall(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float rauschen(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = zufall(i);
	float b = zufall(i + vec2(1.0, 0.0));
	float c = zufall(i + vec2(0.0, 1.0));
	float d = zufall(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float wolken(vec2 p) {
	float wert = 0.0;
	float staerke = 0.5;
	for (int i = 0; i < 5; i++) {
		wert += rauschen(p) * staerke;
		p *= 2.1;
		staerke *= 0.5;
	}
	return wert;
}

void sky() {
	vec3 richtung = normalize(EYEDIR);
	float hoehe = clamp(richtung.y, 0.0, 1.0);
	vec3 farbe = mix(himmel_unten, himmel_oben, pow(hoehe, 0.55));

	// Der Mond scheint nur matt durch die Wolkendecke.
	float winkel = distance(richtung, LIGHT0_DIRECTION);
	float scheibe = 1.0 - smoothstep(mond_groesse - 0.01, mond_groesse + 0.01, winkel);
	float krater = 1.0;
	if (mond_krater > 0.0) {
		vec2 flaeche = (richtung - LIGHT0_DIRECTION).xy / mond_groesse;
		krater = 1.0 - mond_krater * (0.5 * smoothstep(0.42, 0.62, wolken(flaeche * 1.8 + vec2(7.0))) + 0.22 * smoothstep(0.5, 0.7, wolken(flaeche * 6.0)));
	}
	farbe += mond_farbe * scheibe * 0.5 * krater;
	farbe += mond_farbe * exp(-winkel * 5.0) * 0.2;

	// Fahler violetter Schimmer in der Ferne
	float schimmer = exp(-distance(richtung, normalize(vec3(-0.55, 0.28, -0.8))) * 3.2);
	farbe += schimmer_farbe * schimmer * 0.55;

	// Dichte Wolkendecke, die langsam zieht
	vec2 wolken_ort = richtung.xz / (richtung.y + 0.25) * 1.3 + vec2(TIME * 0.012, TIME * 0.005);
	float wolke = smoothstep(0.26, 0.66, wolken(wolken_ort));
	vec3 wolken_farbe = mix(vec3(0.05, 0.06, 0.075), vec3(0.3, 0.33, 0.38), wolken(wolken_ort * 0.6 + vec2(4.0)));
	wolken_farbe += mond_farbe * exp(-winkel * 3.0) * 0.14;
	farbe = mix(farbe, wolken_farbe, wolke * 0.92);

	COLOR = farbe;
}
