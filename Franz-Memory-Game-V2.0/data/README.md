# Sets und Menü anpassen

Im Menü unter **Deine Sets → + → Manuell eingeben** zuerst einen Namen und danach Deutsch-Französisch-Paare eingeben. Nach **Set speichern** erscheint das Set in der Liste und kann über **Play** gespielt werden. Das Spiel speichert jedes eigene Set doppelt im Godot-Benutzerordner `user://vocab_sets/`: als Godot-Resource (`.tres`) und als lesbare JSON-Datei (`.json`). Beim nächsten Start wird die Liste aus diesen Dateien wieder aufgebaut.

Das mitgelieferte **Beispielset** liegt in `data/vocabulary.json` und wird über `data/sets.json` im Menü angezeigt. Weitere bereits vorhandene JSON-Dateien können dort ebenfalls eingetragen werden. Ein Paar hat die Form `{"de": "das Haus", "fr": "la maison"}`; eigene gespeicherte Dateien enthalten zusätzlich einen Namen und ein `entries`-Array.

Menütexte stehen in `data/ui_text.json`, Farben und optionale Button-Bilder in `data/ui_style.json`. Für Pixel-Art-Buttons können dort Pfade zu Texturen für `button_normal_texture`, `button_hover_texture` und `button_pressed_texture` eingetragen werden. `scripts/MenuUI.gd` erzeugt daraus die Buttons; `scripts/SetRepository.gd` kümmert sich nur um Sets und Dateien.

## Seitenleiste und eigene Kategorien

Die Seitenleiste zeigt zuerst das Beispielset, dann die eigenen Sets und am Schluss die Themen-Sets der Kampagne. Ein Klick auf **VOKABELSETS** klappt die ganze Liste zu, ein Klick auf eine Überschrift (z. B. **ALLTAG**) klappt nur diese Gruppe zu. Was zugeklappt ist, wird gespeichert. Die Themen der Kampagne sind am Anfang zugeklappt.

Unter **Deine Sets** hat jedes eigene Set und das Beispielset einen **Löschen**-Button. Der erste Klick fragt „Sicher?“, erst der zweite löscht. Eigene Sets werden wirklich gelöscht (`.json` und `.tres`). Das Beispielset gehört zum Spiel und wird deshalb nur ausgeblendet (`user://hidden_sets.json`). Über **Einstellungen → Beispielset wiederherstellen** kommt es zurück. Die Kampagne nutzt es weiterhin. Die Themen-Sets der Kampagne kann man nicht löschen. Beim Erstellen eines Sets kann man freiwillig eine **Kategorie** eingeben (oder eine bestehende antippen). Sets ohne Kategorie landen unter „Eigene Sets“. Die Kategorie steht im Feld `category` der gespeicherten JSON-Datei.

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

Die Kartenbilder liegen in `assets/cards/` und sind in `data/ui_style.json` unter `card_textures` eingetragen: `back` (Rückseite mit Logo), `front` (aufgedeckt, das Wort steht auf dem Streifen) und `matched` (gefundenes Paar, türkis). Durchsichtige Stellen im Bild werden mit `background` gefüllt (Standard: weiss). Die Bilder werden mit Nearest-Filter gezeigt und bleiben so pixelscharf. Im Bossfight stehen die Karten schräg zur Kamera (`BOSS_CARD_TILT` in `scripts/Main.gd`).

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

## Musik

`scripts/MusicPlayer.gd` spielt die Stücke aus `assets/music/` in Schleife und blendet beim Wechsel weich über: `menu` (Menü), `game` (freies Spiel und Kampagne) und je ein Thema pro Boss (`sonneur`, `veuve`, `prince`, `patre`, siehe `look.music`). Alle Stücke sind selbst komponiert und mit einem kleinen Synthesizer erzeugt (gezupfte Saiten, Glocken, Orgel, Streicher, Chor-Flächen, Trommeln, Hall). Die Lautstärke stellt man unter **Einstellungen → Musik** ein.
## Einstellungen und Admin-Panel

Die Einstellungen werden in `user://settings.json` gespeichert (`scripts/GameSettings.gd`). Dazu gehören Vollbild, Kartenschrift, Button-Animationen, wie lange falsche Karten offen bleiben, Paare pro Runde im freien Spiel, die Zeitanzeige, eine Nachfrage beim Beenden und die Lautstärke.

Unten in den Einstellungen gibt es ein Feld für den Admin-Code. Im Projekt steht nur sein SHA-256-Hash (`ADMIN_HASH`), nicht der Code selbst. Das Admin-Panel kann Level freischalten, Sterne setzen, XP geben, Belohnungen freischalten oder sperren und direkt zum Boss springen. Ausserdem gibt es Schalter für Unverwundbarkeit, einen Boss mit nur 1 HP und eine kurze Kartenvorschau. Diese Schalter gelten nur, bis das Spiel geschlossen wird.

## UI-Platzhalter ersetzen

Alle neuen Buttons laufen über `UI.art_button(text, key)`. Solange unter `art_buttons` in `data/ui_style.json` kein Bild für den Key eingetragen ist, erscheint ein grauer Text-Button als Platzhalter. Sobald ihr ein Bild eintragt, wird es automatisch verwendet:

| Key | Wo |
|---|---|
| `rewards` | Hauptmenü, Belohnungen |
| `game_menu` | Im Spiel oben links, zurück ins Menü |
| `game_restart` | Im Spiel, Neustart |
| `retry` | Endbildschirm, Nochmal |
| `next` | Endbildschirm, nächstes Kampagnen-Level |
| `menu` | Endbildschirm, Menü |

Alle Texte (auch Sterne `star_full`/`star_empty`, `locked`, Belohnungs-Symbole) stehen in `data/ui_text.json`. Die Farben des XP-Balkens sind `bar_fill` und `bar_background` in `data/ui_style.json`. Die Karten selbst nutzen weiterhin die Materialien in `scenes/Main.tscn` (`symbol_materials`, `back_material`).

## Pixel-Art-Buttons

Die fünf Menübilder (inklusive `power.png` für Beenden unten rechts) liegen unter `assets/ui/`; ihre Zuordnung zu den Buttons steht in `data/ui_style.json` unter `art_buttons`. `scripts/MenuUI.gd` zeigt sie mit **Nearest**-Filter und vergrößert sie nur in ganzen Faktoren, ohne das Seitenverhältnis zu ändern. Um eigene Pixel-Art scharf zu halten, wähle in Godot bei der Textur **Texture Filter → Nearest**, schalte beim PNG-Import **Mipmaps → Generate** aus und skaliere am besten mit 2×, 3× oder anderen ganzen Faktoren. Wenn bereits die Quelldatei weichgezeichnet ist, hilft der Filter allein nicht; dann braucht es eine scharfe Originalgrafik.
