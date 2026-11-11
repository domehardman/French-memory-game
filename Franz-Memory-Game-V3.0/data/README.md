# Sets und Menü anpassen

Im Menü unter **Deine Sets → + → Manuell eingeben** zuerst einen Namen und danach Deutsch-Französisch-Paare eingeben. Nach **Set speichern** erscheint das Set in der Liste und kann über **Play** gespielt werden. Das Spiel speichert jedes eigene Set doppelt im Godot-Benutzerordner `user://vocab_sets/`: als Godot-Resource (`.tres`) und als lesbare JSON-Datei (`.json`). Beim nächsten Start wird die Liste aus diesen Dateien wieder aufgebaut.

Das mitgelieferte **Beispielset** liegt in `data/vocabulary.json` und wird über `data/sets.json` im Menü angezeigt. Weitere bereits vorhandene JSON-Dateien können dort ebenfalls eingetragen werden. Ein Paar hat die Form `{"de": "das Haus", "fr": "la maison"}`; eigene gespeicherte Dateien enthalten zusätzlich einen Namen und ein `entries`-Array.

Menütexte stehen in `data/ui_text.json`, Farben und optionale Button-Bilder in `data/ui_style.json`. Für Pixel-Art-Buttons können dort Pfade zu Texturen für `button_normal_texture`, `button_hover_texture` und `button_pressed_texture` eingetragen werden. `scripts/MenuUI.gd` erzeugt daraus die Buttons; `scripts/SetRepository.gd` kümmert sich nur um Sets und Dateien.

## Seitenleiste und eigene Kategorien

Die Seitenleiste zeigt zuerst das Beispielset, dann die eigenen Sets und am Schluss die Themen-Sets der Kampagne. Ein Klick auf **SET-AUSWAHL** klappt die ganze Liste zu, ein Klick auf eine Überschrift (z. B. **ALLTAG**) klappt nur diese Gruppe zu. Was zugeklappt ist, wird gespeichert. Die Themen der Kampagne sind am Anfang zugeklappt.

Über **+** auf der Seite **Deine Sets** erstellt man direkt ein neues Set (Name, freiwillig eine Kategorie, dann die Wortpaare). Unter **Deine Sets** hat jedes eigene Set und das Beispielset einen **Löschen**-Button. Der erste Klick fragt „Sicher?“, erst der zweite löscht. Eigene Sets werden wirklich gelöscht (`.json` und `.tres`). Das Beispielset gehört zum Spiel und wird deshalb nur ausgeblendet (`user://hidden_sets.json`). Über **Einstellungen → Beispielset wiederherstellen** kommt es zurück. Die Kampagne nutzt es weiterhin. Die Themen-Sets der Kampagne kann man nicht löschen. Beim Erstellen eines Sets kann man freiwillig eine **Kategorie** eingeben (oder eine bestehende antippen). Sets ohne Kategorie landen unter „Eigene Sets“. Die Kategorie steht im Feld `category` der gespeicherten JSON-Datei.

**Aussehen der Set-Buttons:** Jedes Set ist ein Pixel-Button. Die Hintergründe (rot, blau, orange, pink) stehen in `data/ui_style.json` unter `set_backgrounds`. Dort kann man Bilder austauschen oder neue Farben dazuschreiben. Jede Kategorie bekommt zufällig eine dieser Farben (nie dieselbe wie die Kategorie direkt darüber). Die Farbe wird im Spielstand gemerkt (`category_colors`), damit sie gleich bleibt. Der Rand des Bildes bleibt scharf, nur die Mitte wird breiter gezogen. Die Schrift ist die Pixel-Schrift der Button-Bilder (`scripts/PixelFont.gd`): Grossbuchstaben, 5 Pixel hoch, mit Umlauten und französischen Akzenten. Die Schriftfarbe ist die dunkle Randfarbe des jeweiligen Hintergrunds. Die Schrift kann man auch für eigene Labels benutzen: `label.add_theme_font_override("font", PixelFont.font())` und `label.add_theme_font_size_override("font_size", PixelFont.size(2))`.

**Eigene Kategorien:** Mit **+ Neue Kategorie** in der Seitenleiste oder dem Button **Kategorien** auf der Seite **Deine Sets** kann man Kategorien erstellen und löschen. Leere Kategorien werden auch angezeigt; sie stehen in `user://categories.json`. Mit **Kategorie** neben einem eigenen Set verschiebt man es in eine andere Kategorie. Löscht man eine Kategorie, kommen ihre Sets zurück zu „Eigene Sets“.

## Themen, Kampagne, Punkte und Belohnungen

| Datei | Inhalt |
|---|---|
| `data/sets.json` | Mitgelieferte Sets mit `topic` (Themenbereich). Die Seitenleiste gruppiert nach Thema. |
| `data/sets/*.json` | Die Vokabeln der Themen-Sets (Familie, Essen, Schule, Tiere, …). |
| `data/campaign.json` | Kampagnen-Level: Set, Anzahl Paare, `time_limit` (Sekunden, 0 = keins), `move_limit` (Versuche, 0 = keins). |
| `data/progression.json` | Punkte pro Paar, Serienbonus, Zeitbonus, Sterne-Grenzen und XP pro Level. |
| `data/rewards.json` | Belohnungen. `type`: `games_played`, `total_pairs`, `streak`, `level`, `topics`, `campaign`, `accuracy`, `speed`. `icon` ist für eure Grafik frei. |

Der Fortschritt (XP, Level, Belohnungen, Sterne, Bestzeiten) wird von `scripts/PlayerProgress.gd` in `user://progress.json` gespeichert. Unter **Einstellungen → Fortschritt zurücksetzen** lässt er sich löschen.

**Wertung:** Jedes Paar gibt Punkte, Paare hintereinander geben einen Serienbonus, wer schneller ist als die Richtzeit (8 s pro Paar), bekommt einen Zeitbonus. Sterne: 3 bei höchstens 1,75 Versuchen pro Paar, 2 bei höchstens 2,5, sonst 1. Ein Kampagnen-Level mit mindestens 1 Stern schaltet das nächste frei.

## Kartendesign

Die Kartenbilder liegen in `assets/cards/` und sind in `data/ui_style.json` unter `card_textures` eingetragen: `back` (Rückseite mit Logo), `front` (aufgedeckt, das Wort steht auf dem Streifen) und `matched` (gefundenes Paar, türkis). Durchsichtige Stellen im Bild werden mit `background` gefüllt (Standard: weiss). Die Bilder werden mit Nearest-Filter gezeigt und bleiben so pixelscharf. Im Bossfight stehen die Karten schräg zur Kamera (`BOSS_CARD_TILT` in `scripts/Main.gd`). Hintere Reihen stehen steiler (`BOSS_BACK_TILT`), schweben etwas höher (`BOSS_ROW_STEP`) und haben mehr Abstand (`BOSS_ROW_GROWTH`), damit man auch dort die ganzen Wörter sieht. Lange Wörter werden nie mitten im Wort umgebrochen: die Schrift wird kleiner, bis jedes Wort auf eine Zeile passt (Umbruch nur bei Leerzeichen und Bindestrichen).

## Bosse

Die Kampagne hat 20 Level, 3 Zwischenbosse (nach Level 5, 10 und 15) und den Endboss. Modelle (mit Skelett), Texturen, Himmel- und Stein-Shader, die Schrift Cinzel und die Knochen-Deko stammen aus dem eigenen Projekt "Claude 1" und liegen in `assets/hain/`.

| Boss | Modell | Arena (`look.arena`) | Fähigkeiten | Leben |
|---|---|---|---|---|
| Le Sonneur | Glöckner | `turm`: Glockenturm, Bernstein | Glocke fällt auf eine Karte und wirft die Nachbarn um, Glockenschlag-Welle. Taub: holt lange aus | 180 |
| La Veuve de Cendre | Aschenwitwe | `kathedrale`: kaltes Blau, Kirchenfenster | wirft 3 Sicheln, mäht eine Reihe, wird zu Asche (dann kein Schaden, Paare heilen dich) | 240 |
| Le Prince des Os | Gebeinfürst | `beinhaus`: Schädelwand, Türkis | Knochenspitzen durch eine Spalte, Schädelregen, Knochenpanzer (halber Schaden), wütend: Beben | 300 |
| **Le Pâtre des Racines** | Wurzelhirt | `hain`: Toter Hain, grünes Mondlicht | Wurzeln durch eine Reihe/Spalte, Herde der Dornenknechte, Sporen, Stampf-Welle, Verwurzeln (offenes Herz: doppelter Schaden) | 420 |

Alle Werte stehen im Block `boss` in `data/campaign.json` (`hp`, `attack_damage`, `attack_interval`, `rage_interval`, `windup_time`, `mismatch_damage`, `combo_bonus`, `attacks`, `rage_attacks` …). Mehrfach genannte Angriffe kommen öfter vor. Unter `look` stehen `model`, `model_scale`, `weapon`, `weapon_rot`, `arena`, `accent` und `music`.

**Ablauf eines Angriffs:** Der Boss holt `windup_time` Sekunden aus, die Zielkarten werden rot markiert. **Ein Paar in dieser Zeit unterbricht den Angriff.** Danach fliegen die getroffenen Karten an neue Plätze.

**Balance-Test:** Ein Testspieler mit unvollständigem Gedächtnis (er merkt sich 65 % bzw. 45 % der Karten) hat jeden Boss je dreimal gespielt. Der gute Spieler schafft alle Bosse, der schwächere alle Zwischenbosse und den Endboss in 1 von 3 Versuchen. Der Endboss ist damit der stärkste.

## Arenen und Hintergrund selber ändern

**Boss-Arenen** sind eigene Szenen in `scenes/arenen/`: `glockenturm.tscn` (Le Sonneur), `kathedrale.tscn` (La Veuve), `beinhaus.tscn` (Le Prince) und `hain.tscn` (Endboss). Welche Szene ein Boss benutzt, steht in `data/campaign.json` unter `look.scene`. Einfach in Godot öffnen und ändern; das Spiel lädt die Szene so, wie sie gespeichert ist. Die Knoten mit festen Namen:

| Knoten | Wofür |
|---|---|
| `Umgebung` | Himmel, Nebel, Farben und Bildfilter (WorldEnvironment) |
| `Level` | das ganze Bauwerk mit Lichtern und Fackeln. Hier darf man alles verschieben, löschen oder Neues dazutun |
| `LeuchtKreis` | die zwei leuchtenden Ringe unter den Karten (Farbe im Material) |
| `Spielfeldlicht`, `Kerzen`, `Asche` | Licht über den Karten, Kerzen (ihre Lichter flackern), fallende Asche |
| `BossPunkt` | hier steht der Boss. Verschieben = Boss steht woanders |
| `Kamera` | so schaut die Kamera im Spiel. In Godot auf **Vorschau** klicken, um durch sie zu schauen |
| `Vorschau` | Boss-Modell und Karten, nur damit man im Editor sieht, wo alles ist. Wird im Spiel gelöscht |

Eigene Sachen kann man irgendwo in die Szene hängen, sie werden mit angezeigt. Fehlt `look.scene` (oder die Datei), baut das Spiel die Arena wie früher selbst aus `look.level`.

**Normale Runden** sind in 3D: Die Kamera (`Camera3D` in `scenes/Main.tscn`) schaut mit Perspektive senkrecht von oben auf das Spielbrett, die Karten werfen Schatten (Licht: `DirectionalLight3D`) und drehen sich beim Aufdecken über die Kante um. Der Hintergrund ist die Szene `scenes/Hintergrund.tscn`:

- `Tisch`: die grosse Fläche ganz unten. Eigenes Bild: im Material bei **Albedo → Texture** hineinziehen (jetzt `assets/hintergrund/tisch.png`, kachelt).
- `Spielbrett`: das erhöhte Brett unter den Karten, darauf `Matte` mit dem Pixel-Rahmen (`assets/hintergrund/spielmatte.png`). Die Karten liegen auf Höhe 0, die Matte bei y = −0.53. Das Brett nicht höher schieben, sonst verdeckt es die Karten.
- `Deko3D`: für eigene 3D-Sachen, zum Beispiel neben dem Brett auf dem Tisch.

Im Bossfight wird dieser Hintergrund automatisch entfernt.

## Musik

`scripts/MusicPlayer.gd` spielt die Stücke aus `assets/music/` in Schleife und blendet beim Wechsel weich über: `menu` (Menü), `game` (freies Spiel und Kampagne) und je ein Thema pro Boss (`sonneur`, `veuve`, `prince`, `patre`, siehe `look.music`). Alle Stücke sind selbst komponiert und mit einem kleinen Synthesizer erzeugt (gezupfte Saiten, Glocken, Orgel, Streicher, Chor-Flächen, Trommeln, Hall). Die Lautstärke stellt man unter **Einstellungen → Musik** ein.
## Einstellungen und Admin-Panel

Die Einstellungen werden in `user://settings.json` gespeichert (`scripts/GameSettings.gd`). Dazu gehören Vollbild, Kartenschrift, Button-Animationen, wie lange falsche Karten offen bleiben, Paare pro Runde im freien Spiel, die Zeitanzeige, eine Nachfrage beim Beenden und die Lautstärke.

**Leistung:** Unter **Einstellungen → Leistung** gibt es Grafikqualität, Partikel, FPS-Limit, VSync und eine FPS-Anzeige. Gemessen im Bossfight auf demselben Laptop: Hoch etwa 50 FPS, Mittel 90–105 FPS (Standard), Niedrig 125–145 FPS.

| Stufe | Was abgeschaltet wird |
|---|---|
| Hoch | nichts |
| Mittel | Umgebungsverdeckung (SSAO), Spiegelungen, Schatten von Fackeln und Kerzen. Schattenkarten halb so gross |
| Niedrig | zusätzlich Volumen-Nebel, Glühen und alle Schatten. Die 3D-Welt wird mit 75 % Auflösung gerendert und hochskaliert (FSR) |

Partikel: Aus, Wenig (40 %), Normal, Viel (160 %). Partikel mit der Markierung `wichtig` (die Sporen, die Karten verdecken) bleiben immer mindestens zur Hälfte sichtbar. Die Einstellungen werden in `scripts/GameSettings.gd` angewendet (`apply_graphics`, `_scale_particles`). Neue Partikel und Lichter werden automatisch angepasst, sobald sie ins Spiel kommen.

Unten in den Einstellungen gibt es ein Feld für den Admin-Code. Im Projekt steht nur sein SHA-256-Hash (`ADMIN_HASH`), nicht der Code selbst. Das Admin-Panel kann Level freischalten, Sterne setzen, XP geben, Belohnungen freischalten oder sperren und direkt zum Boss springen. Ausserdem gibt es Schalter für Unverwundbarkeit, einen Boss mit nur 1 HP und eine kurze Kartenvorschau. Diese Schalter gelten nur, bis das Spiel geschlossen wird.

## Pixel-UI

Das ganze Spiel benutzt ein Pixel-Theme (`UI.theme()` in `scripts/MenuUI.gd`, gesetzt in `scripts/GameSettings.gd`). Alle Texte sind in der Pixel-Schrift, und zwar nur in drei Grössen: 18 (normal), 27 (Titel) und 36 (gross), damit die Pixel scharf bleiben. Rahmen, Eingabefelder, Regler, Schalter, Auswahl-Listen, Bildlaufleisten und Balken sind aus Pixeln gebaut. Die Farben stehen in `scripts/MenuUI.gd`: `FRAMES` (Rahmen, Indigo mit violettem Rand), `TITLE_COLOR` (Seitentitel, gold), `SECTION_COLOR` (Abschnitte, orange). Auswahl-Listen haben einen violetten Pixel-Rahmen, Kategorie-Überschriften haben die Farbe ihrer Sets. Die Hintergrundfarbe des Menüs ist `background` in `data/ui_style.json` (mit feinem Pixel-Muster), die der normalen Runden sind `Tisch` und `Matte` in `scenes/Hintergrund.tscn`.

**Eigene Pixel-Art für Rahmen:** In `data/ui_style.json` unter `"frames"` ein Bild eintragen, z. B. `"panel": "res://assets/ui/rahmen.png"`. Das Bild sollte 8×8 Pixel gross sein mit 3 Pixel Rand. Es wird 2× vergrössert, und nur die Mitte wird gestreckt. Mögliche Namen: `panel` (Kästen), `input` und `input_focus` (Eingabefelder), `track` (Regler- und Balken-Hintergrund), `track_fill` und `bar_fill` (Füllung), `option` und `option_hover` (Auswahl-Listen), `scroll`, `grabber` und `grabber_hover` (Bildlaufleiste).

Fehlt ein Button-Bild unter `art_buttons`, erscheint ein Pixel-Button mit Text (zum Beispiel für `game_menu`, `game_restart`, `retry`, `next` und `menu` im Spiel und im Endbildschirm). Alle Texte (auch Sterne `star_full`/`star_empty` und `locked`) stehen in `data/ui_text.json`.

## Pixel-Art-Buttons

Die Menübilder (Play, Kampagne, Sets, Erfolge, Zurück, Set-Auswahl, Einstellungen und `power.png` für Beenden unten rechts) liegen unter `assets/ui/`; ihre Zuordnung zu den Buttons steht in `data/ui_style.json` unter `art_buttons`. `scripts/MenuUI.gd` zeigt sie mit **Nearest**-Filter und vergrößert sie nur in ganzen Faktoren, ohne das Seitenverhältnis zu ändern. Um eigene Pixel-Art scharf zu halten, wähle in Godot bei der Textur **Texture Filter → Nearest**, schalte beim PNG-Import **Mipmaps → Generate** aus und skaliere am besten mit 2×, 3× oder anderen ganzen Faktoren. Wenn bereits die Quelldatei weichgezeichnet ist, hilft der Filter allein nicht; dann braucht es eine scharfe Originalgrafik.

**Alle anderen Buttons** (Löschen, Kategorie, Weiter, Kampagnen-Level, Menü, Neustart usw.) sind ebenfalls Pixel-Buttons: ein Hintergrund aus `set_backgrounds` plus die Pixel-Schrift, Text immer 2× gross. Die Farbe hängt nur vom Text ab, gleicher Text ergibt also überall dieselbe Farbe („Menü“ oben im Spiel und im Endbildschirm sind beide blau). Heisst ein Button wie eines der Bilder, bekommt er dessen Farbe („Zurück“ grün, „Einstellungen“ blau, „Kampagne“ orange, „Sets“ pink). Eigene Farben legt man in `data/ui_style.json` unter `"text_colors": {"Löschen": "red"}` fest. Ganz kurze Texte („+“, „×“, „OK“) nehmen die quadratischen `square_*.png`. Mit `"pixel_buttons": false` kommen die alten Platzhalter-Buttons zurück.

Bilder-Buttons: `set-auswahl.png` (SET-SCHNELLAUSWAHL) ist der Kopf der Seitenleiste, `set_auswahl.png` (SET-AUSWAHL) der Titel der Seite „Deine Sets“, `fortschrit weg.png` und `einstellungen zurück.png` sind die beiden Zurücksetzen-Buttons in den Einstellungen.

**Logo:** `assets/ui/logo.png` (Eintrag `logo` unter `art_buttons`) steht im Hauptmenü über den Buttons, 2× vergrössert. Der durchsichtige Rand wird dabei weggelassen. Es ist auch das Symbol des Spiels (`config/icon` in `project.godot`).
