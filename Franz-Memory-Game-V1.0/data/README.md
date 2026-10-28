# Sets und Menü anpassen

Im Menü unter **Deine Sets → + → Manuell eingeben** zuerst einen Namen und danach Deutsch-Französisch-Paare eingeben. Nach **Set speichern** erscheint das Set in der Liste und kann über **Play** gespielt werden. Das Spiel speichert jedes eigene Set doppelt im Godot-Benutzerordner `user://vocab_sets/`: als Godot-Resource (`.tres`) und als lesbare JSON-Datei (`.json`). Beim nächsten Start wird die Liste aus diesen Dateien wieder aufgebaut.

Das mitgelieferte **Beispielset** liegt in `data/vocabulary.json` und wird über `data/sets.json` im Menü angezeigt. Weitere bereits vorhandene JSON-Dateien können dort ebenfalls eingetragen werden. Ein Paar hat die Form `{"de": "das Haus", "fr": "la maison"}`; eigene gespeicherte Dateien enthalten zusätzlich einen Namen und ein `entries`-Array.

Menütexte stehen in `data/ui_text.json`, Farben und optionale Button-Bilder in `data/ui_style.json`. Für Pixel-Art-Buttons können dort Pfade zu Texturen für `button_normal_texture`, `button_hover_texture` und `button_pressed_texture` eingetragen werden. `scripts/MenuUI.gd` erzeugt daraus die Buttons; `scripts/SetRepository.gd` kümmert sich nur um Sets und Dateien.

## Pixel-Art-Buttons

Die fünf Menübilder (inklusive `power.png` für Beenden unten rechts) liegen unter `assets/ui/`; ihre Zuordnung zu den Buttons steht in `data/ui_style.json` unter `art_buttons`. `scripts/MenuUI.gd` zeigt sie mit **Nearest**-Filter und vergrößert sie nur in ganzen Faktoren, ohne das Seitenverhältnis zu ändern. Um eigene Pixel-Art scharf zu halten, wähle in Godot bei der Textur **Texture Filter → Nearest**, schalte beim PNG-Import **Mipmaps → Generate** aus und skaliere am besten mit 2×, 3× oder anderen ganzen Faktoren. Wenn bereits die Quelldatei weichgezeichnet ist, hilft der Filter allein nicht; dann braucht es eine scharfe Originalgrafik.
