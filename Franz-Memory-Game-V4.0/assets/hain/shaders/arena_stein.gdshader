// Stein für die Boss-Arenen.
// Das Bild wird von drei Seiten auf die Form projiziert. Darüber liegen
// grosse Flecken, Schmutz am Boden, Moos, Nässe, ein Bodenmuster und Glutrisse.
// So sieht jede Wand anders aus, obwohl alle dieselbe Steintextur benutzen.
shader_type spatial;

uniform sampler2D farbe_bild : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_bild : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D rauh_bild : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D rausch_bild : repeat_enable, filter_linear_mipmap;

uniform float massstab = 0.3;                // Wie gross die Steine sind
uniform float normal_staerke = 0.7;
uniform float rauh_zusatz = 0.0;             // Macht den Stein matter
uniform vec3 toenung : source_color = vec3(1.0);

// Schmutz: wird nach unten hin stärker
uniform vec3 schmutz_farbe : source_color = vec3(0.05, 0.045, 0.04);
uniform float schmutz_hoehe = 1.4;
uniform float schmutz_staerke = 0.6;

// Moos wächst dort, wo die Fläche nach oben schaut
uniform vec3 moos_farbe : source_color = vec3(0.07, 0.1, 0.05);
uniform float moos = 0.0;

// Nässe: 0 = trocken, 1 = überall Pfützen
uniform float naesse = 0.0;

// Bodenmuster: R Höhe, G Helligkeit, B Einlage, A Abnutzung
uniform sampler2D muster_bild : repeat_disable, filter_linear_mipmap_anisotropic;
uniform vec2 muster_mitte = vec2(0.0);
uniform float muster_groesse = 0.0;          // 0 = kein Muster
uniform vec3 einlage_farbe : source_color = vec3(0.5, 0.42, 0.26);
uniform float einlage_metall = 0.8;

// Vertexfarbe als Verdunkelung in Fugen: 0 = aus, 1 = an (nur beim Bossstein)
uniform float vertex_ao = 0.0;

// Glutrisse: leuchten und pulsieren langsam
uniform float glut = 0.0;
uniform vec3 glut_farbe : source_color = vec3(1.0, 0.32, 0.06);

varying vec3 welt_ort;
varying vec3 welt_normal;
varying float fugen_licht;


// Normalenbilder speichern oft nur Rot und Grün. Blau rechnen wir selbst aus.
vec3 normal_auspacken(vec2 rg, float staerke_wert) {
	vec2 xy = (rg * 2.0 - 1.0) * staerke_wert;
	return vec3(xy, sqrt(max(1.0 - dot(xy, xy), 0.05)));
}


void vertex() {
	welt_ort = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	welt_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
	fugen_licht = mix(1.0, COLOR.r, vertex_ao);
}


void fragment() {
	vec3 n = normalize(welt_normal);
	vec3 anteil = pow(abs(n), vec3(5.0));
	anteil = anteil / (anteil.x + anteil.y + anteil.z);

	// Etwas Verzerrung, damit die Kacheln nicht in Reihen auffallen
	vec2 versatz = texture(rausch_bild, welt_ort.xz * 0.013 + welt_ort.y * 0.011).rg - 0.5;
	vec3 p = welt_ort * massstab + vec3(versatz.x, versatz.y, versatz.y) * 0.12;

	vec3 farbe = texture(farbe_bild, p.zy).rgb * anteil.x
		+ texture(farbe_bild, p.xz).rgb * anteil.y
		+ texture(farbe_bild, p.xy).rgb * anteil.z;
	float rauh = texture(rauh_bild, p.zy).r * anteil.x
		+ texture(rauh_bild, p.xz).r * anteil.y
		+ texture(rauh_bild, p.xy).r * anteil.z;

	vec3 nx = normal_auspacken(texture(normal_bild, p.zy).rg, normal_staerke);
	vec3 ny = normal_auspacken(texture(normal_bild, p.xz).rg, normal_staerke);
	vec3 nz = normal_auspacken(texture(normal_bild, p.xy).rg, normal_staerke);
	vec3 wn = normalize(
		vec3(nx.z * sign(n.x), nx.y + n.y, nx.x + n.z) * anteil.x
		+ vec3(ny.x + n.x, ny.z * sign(n.y), ny.y + n.z) * anteil.y
		+ vec3(nz.x + n.x, nz.y + n.y, nz.z * sign(n.z)) * anteil.z);

	// Grosse Flecken: die Wand ist nie überall gleich hell
	vec4 gross = texture(rausch_bild, welt_ort.xz * 0.021 + welt_ort.yy * 0.017);
	vec4 mittel = texture(rausch_bild, welt_ort.xz * 0.07 - welt_ort.yy * 0.053);
	farbe *= toenung * (0.68 + 0.7 * gross.r) * (0.82 + 0.36 * mittel.g);

	// Schmutz am Fuss der Wände, Wasserspuren laufen nach unten
	float unten = 1.0 - smoothstep(0.0, schmutz_hoehe, welt_ort.y + mittel.g * 1.2 - 0.3);
	float streifen = smoothstep(0.55, 0.8, texture(rausch_bild, vec2(p.x + p.z, 0.0) * 0.9 + vec2(0.0, welt_ort.y * 0.012)).g) * (1.0 - anteil.y);
	farbe = mix(farbe, schmutz_farbe, clamp(max(unten * (1.0 - anteil.y), streifen * 0.6) * schmutz_staerke, 0.0, 1.0));

	// Moos
	float moos_maske = smoothstep(0.5, 0.75, gross.g * 0.6 + mittel.b * 0.5 + max(n.y, 0.0) * 0.25 + unten * 0.2) * moos;
	farbe = mix(farbe, moos_farbe * (0.6 + mittel.b), moos_maske);
	rauh = mix(rauh, 0.95, moos_maske);

	float metall = 0.0;
	float ao = 1.0;
	vec3 leuchten = vec3(0.0);

	// Bodenmuster: nur auf nach oben gerichteten Flächen
	if (muster_groesse > 0.0 && n.y > 0.7) {
		vec2 uv = (welt_ort.xz - muster_mitte) / muster_groesse + 0.5;
		if (uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0) {
			float d = 1.0 / 2048.0;
			vec4 m = texture(muster_bild, uv);
			float hx = texture(muster_bild, uv + vec2(d, 0.0)).r - texture(muster_bild, uv - vec2(d, 0.0)).r;
			float hz = texture(muster_bild, uv + vec2(0.0, d)).r - texture(muster_bild, uv - vec2(0.0, d)).r;
			wn = normalize(wn + vec3(-hx, 0.0, -hz) * 5.0);
			farbe *= mix(0.3, 1.0, smoothstep(0.1, 0.6, m.r)) * (0.5 + m.g);
			ao = mix(0.45, 1.0, smoothstep(0.1, 0.6, m.r));
			float blank = smoothstep(0.3, 0.7, m.a);
			rauh = mix(rauh, rauh * 0.55, blank);
			float einlage = smoothstep(0.4, 0.6, m.b);
			farbe = mix(farbe, einlage_farbe * (0.6 + 0.6 * mittel.g), einlage);
			metall = einlage * einlage_metall;
			rauh = mix(rauh, 0.38, einlage);
		}
	}

	// Nässe: Pfützen sammeln sich in den grossen Flecken
	float nass = smoothstep(0.62 - naesse * 0.34, 0.74 - naesse * 0.34, gross.r * 0.7 + mittel.g * 0.3) * step(0.0001, naesse) * smoothstep(0.7, 0.95, n.y);
	farbe *= 1.0 - nass * 0.45;
	rauh = mix(rauh, 0.13, nass);
	wn = normalize(mix(wn, vec3(0.0, 1.0, 0.0), nass * 0.92));

	// Glutrisse
	if (glut > 0.0) {
		float riss = smoothstep(0.35, 0.95, texture(rausch_bild, welt_ort.xz * 0.11).a) * step(0.5, n.y);
		riss += smoothstep(0.3, 0.9, texture(rausch_bild, welt_ort.xz * 0.04 + welt_ort.yy * 0.04).a) * (1.0 - step(0.5, n.y)) * 0.5;
		float puls = 0.7 + 0.3 * sin(TIME * 1.4 + gross.g * 9.0);
		leuchten = glut_farbe * riss * glut * puls * smoothstep(0.62, 0.8, gross.g * 0.7 + mittel.r * 0.45);
	}

	ALBEDO = farbe * fugen_licht;
	ROUGHNESS = clamp(rauh + rauh_zusatz * (1.0 - nass), 0.04, 1.0);
	METALLIC = metall;
	AO = ao * fugen_licht;
	EMISSION = leuchten;
	NORMAL = normalize(mat3(VIEW_MATRIX) * wn);
}
