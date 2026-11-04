# French Memory Game – Dokumentation

## Grobplanung

Wir entwickeln ein französisches Memory-Spiel mit der Game Engine **Godot**.
Godot ermöglicht eine schnellere und übersichtlichere Umsetzung als beispielsweise Windows Forms und bietet gleichzeitig bessere Möglichkeiten für ein ansprechendes und einheitliches Design.

## Anforderungen

* [x] Funktionierendes Memory-Spiel
* [x] Zufällige Anordnung der Memory-Karten in jeder Runde
* [x] Möglichkeit, eigene Begriffe und Bilder hinzuzufügen
* [x] Einheitliches und übersichtliches Design
* [x] Mehrere Spielmodi

## Erweiterte Anforderungen

* [x] Belohnungssystem
* [x] Levelsystem, um das Lernen abwechslungsreicher und motivierender zu gestalten
* [x] Speicherung des Spielfortschritts
* [x] Möglichkeit, verschiedene Themenbereiche bzw. Vokabelsets auszuwählen
* [x] Zeitangaben

## 21.09.2026
PAP, IPERKA und start des Games

## 28.10.2026

Heute haben wir das Menü und die Bedienoberfläche des Memory-Spiels überarbeitet. Das Spiel zeigt die Vokabeln in 5×5-Feldern und wechselt nach einer Runde zum nächsten Feld. Wir haben die Verwaltung eigener Vokabelsets und die Auswahl eines Sets ergänzt. Danach haben wir eure Pixel-Art-Knöpfe ins Menü eingebunden und ihre Darstellung angepasst. Zuletzt haben wir aus den Originalbildern zehn leere Knopfhintergründe in fünf Farben und zwei Größen erstellt.


<img width="50" height="25" alt="Campaign button" src="https://github.com/user-attachments/assets/2495ba20-8883-4c58-ba7b-694731eb0716" />

<img width="959" height="599" alt="Screenshot 2026-10-28 092438" src="https://github.com/user-attachments/assets/4e0690db-0e88-428f-906a-524fa53ab351" />

## 04.11.2026

Heute war ein langer Tag. Wir haben fast alle erweiterten Anforderungen umgesetzt und das Spiel um eine ganze Kampagne mit Bossfights erweitert. Weil sich im Projekt so viel verändert hat, haben wir es als neue Version **Franz-Memory-Game-V2.0** hochgeladen. Die alte Version V1.0 bleibt zum Vergleich drin. Alle Screenshots von heute liegen im Ordner **Dokumentation Fotos/04.11.2026**.

**Punkte, Level und Belohnungen**

Für jedes gefundene Paar gibt es jetzt Punkte. Wer mehrere Paare hintereinander findet oder schnell spielt, bekommt einen Bonus. Mit den Punkten steigt man im Level auf, das Level sieht man oben links im Menü. Dazu gibt es Belohnungen, die man freischaltet, zum Beispiel für das erste Spiel, für Serien oder für einen besiegten Boss. Auf der Seite „Belohnungen" sieht man alle Erfolge und eine kleine Statistik.

<img width="640" alt="Hauptmenü mit Level-Anzeige" src="Dokumentation%20Fotos/04.11.2026/01%20Hauptmenue%20mit%20Level-Anzeige%20und%20Themen.png" />

<img width="640" alt="Belohnungen und Statistik" src="Dokumentation%20Fotos/04.11.2026/03%20Belohnungen%20und%20Statistik.png" />

**Zeit, Versuche und Endbildschirm**

Während man spielt, laufen oben die Zeit, die Versuche, die Treffer und die Punkte mit. Es gibt jetzt auch einen Neustart-Knopf. Am Ende zeigt ein Endbildschirm Sterne, Zeit und Punkte und ob man ein Level aufgestiegen ist.

<img width="640" alt="Spiel mit Zeit und Punkten" src="Dokumentation%20Fotos/04.11.2026/04%20Spiel%20mit%20Zeit%2C%20Versuchen%20und%20Punkten.png" />

<img width="640" alt="Endbildschirm" src="Dokumentation%20Fotos/04.11.2026/05%20Endbildschirm%20mit%20Sternen%20und%20Belohnungen.png" />

**Speichern**

Punkte, Level, Belohnungen, Sterne, Bestzeiten und Einstellungen werden jetzt gespeichert. Wenn man das Spiel neu startet, ist alles noch da.

**Themenbereiche und eigene Sets**

Wir haben neue Vokabelsets zu verschiedenen Themen gemacht (Familie, Essen, Schule, Tiere, Berufe und weitere). In der Seitenleiste sind sie nach Themen sortiert und lassen sich zuklappen. Die Sets der Kampagne haben einen eigenen Überordner. Eigene Sets kann man jetzt einer Kategorie zuordnen und auch wieder löschen. Beim Löschen kommt zuerst eine Nachfrage, damit man nicht aus Versehen etwas löscht.

<img width="640" alt="Seitenleiste mit Überordner Kampagne" src="Dokumentation%20Fotos/04.11.2026/17%20Ueberordner%20Kampagne%20in%20der%20Seitenleiste.png" />

<img width="640" alt="Löschen mit Nachfrage" src="Dokumentation%20Fotos/04.11.2026/16%20Loeschen%20mit%20Nachfrage.png" />

**Einstellungen und Admin-Panel**

In den Einstellungen kann man jetzt Vollbild, Kartenschrift, Animationen, Musik und Effekte einstellen. Für uns zum Testen gibt es ein Admin-Panel, das man nur mit einem Code öffnen kann. Damit kann man zum Beispiel alle Level freischalten oder direkt zum Boss springen.

<img width="640" alt="Einstellungen" src="Dokumentation%20Fotos/04.11.2026/10%20Neue%20Einstellungen.png" />

<img width="640" alt="Admin-Panel" src="Dokumentation%20Fotos/04.11.2026/11%20Admin-Panel.png" />

**Kampagne und Bossfights**

Die Kampagne hat jetzt 20 Level, die immer schwieriger werden, mit Zeitlimit oder begrenzten Versuchen. Nach Level 5, 10 und 15 kommt ein Zwischenboss, am Schluss der Endboss. Im Bossfight macht jedes gefundene Paar Schaden am Boss, falsche Paare kosten eigene Leben. Der Boss greift regelmässig an: Er holt aus, die Zielkarten werden rot markiert, und danach fliegen die getroffenen Karten an andere Plätze. Wenn man während dem Ausholen ein Paar findet, unterbricht man den Angriff.

Unsere erste Version vom Bossfight hatte eine selbst gebaute Arena mit Blutmond und einen Boss aus einfachen Formen. Das sah aber eher nach Plastik aus als nach einem richtigen Boss.

<img width="640" alt="Erste Version der Bossarena" src="Dokumentation%20Fotos/04.11.2026/20%20Bossarena%20Gothic%20mit%20Blutmond%20final.png" />

Darum haben wir für die Bosse die Modelle und Arenen aus unserem anderen Projekt „Claude 1" genommen. Jetzt hat jeder Boss seine eigene Arena und eigene Angriffe: Le Sonneur im Glockenturm lässt Glocken auf die Karten fallen, La Veuve de Cendre in der Kathedrale wirft Sicheln und zerfällt zu Asche, Le Prince des Os im Beinhaus lässt Knochenspitzen wachsen und Schädel regnen. Der Endboss, Le Pâtre des Racines im Toten Hain, ist der stärkste. Er hat Wurzeln, Dornenknechte und Sporen und kann sich verwurzeln. Vor jedem Bossfight kommt der Ladebildschirm aus „Claude 1".

<img width="800" alt="Alle vier Boss-Arenen" src="Dokumentation%20Fotos/04.11.2026/58%20Alle%20Arenen%20nach%20Reparatur.png" />

<img width="640" alt="Ladebildschirm" src="Dokumentation%20Fotos/04.11.2026/59%20Original-Ladebild%20aus%20Claude%201.png" />

**Kartendesign, Musik und Sounds**

Unser eigenes Pixel-Art-Kartendesign ist jetzt im Spiel. Die Rückseite zeigt das Logo, gefundene Paare werden türkis. Ausserdem gibt es Musik fürs Menü, fürs normale Spiel und für jeden Boss ein eigenes Stück, dazu Soundeffekte für Klicks, Karten, Treffer und Angriffe.

<img width="640" alt="Kartendesign im Spiel" src="Dokumentation%20Fotos/04.11.2026/28%20Neues%20Kartendesign%20im%20Spiel%20final.png" />

**Probleme, die wir hatten**

Es hat nicht alles auf Anhieb funktioniert. Diese Probleme hatten wir heute:

* Bei der Vorderseite der Karten war die Mitte im Bild durchsichtig. Dadurch sah man den Text kaum. Jetzt wird diese Stelle weiss gefüllt.
* Bei einigen Bossen fehlten die leuchtenden Augen. Wir haben sie so eingesetzt wie in „Claude 1". Jetzt leuchten sie kurz auf, bevor der Boss zuschlägt.
* Die Animationen waren am Anfang ganz kaputt. Die Bosse haben sich verdreht, und die Arme standen komisch vor dem Körper. Die Bewegungen haben sich bei wenig Bildern pro Sekunde aufgeschaukelt, und die Arme wurden seitlich in die falsche Richtung gedreht.
* Am längsten hat uns das Problem mit den weissen Fäden gekostet. Beim Angreifen, vor allem bei den Hieben von links und rechts, wurden die Arme zu langen weissen Bändern gezogen. Wir haben herausgefunden, dass die Modelle aus festen Teilen bestehen und die Haut dazwischen beim Bewegen gedehnt wird. Jetzt hängen die Teile fest an ihren Knochen, und es gibt keine Fäden mehr.
* In der Kathedrale sah es so aus, als würden die Bänke fliegen. Schuld war der Bodennebel, der nach dem Vergrössern der Arena viel zu dicht war.
* Das Ausholen der Bosse hat viel zu lange gedauert. Wir haben es verkürzt.
* Unter den Karten lag zuerst eine Steinplatte, die nicht zur Arena gepasst hat. Jetzt liegt dort nur der Boden der Arena mit einem leuchtenden Kreis.
* Bei den hinteren Kartenreihen hat man den Text manchmal nicht gesehen. Jetzt haben die Reihen mehr Abstand, und die Schrift ist grösser.

<img width="640" alt="Vorher: weisse Fäden an den Armen" src="Dokumentation%20Fotos/04.11.2026/55%20Diagnose%20weisse%20Baender.png" />

<img width="640" alt="Nachher: Arme ohne Fäden" src="Dokumentation%20Fotos/04.11.2026/57%20Arme%20nach%20Spiegelung.png" />

<img width="640" alt="Vorher: Steinplatte unter den Karten" src="Dokumentation%20Fotos/04.11.2026/61%20Diagnose%20Untergrund%20vorher.png" />

<img width="640" alt="Nachher: nur der Arenaboden mit Leuchtkreis" src="Dokumentation%20Fotos/04.11.2026/61%20Diagnose%20Untergrund%20nachher.png" />

**Was noch offen ist**

Eigene Bilder für die Karten kann man noch nicht hinzufügen, das wollen wir als Nächstes machen. Die Bewegungen der Bosse haben wir bis jetzt vor allem auf Standbildern angeschaut, das wollen wir noch genauer im Spiel testen. Ausserdem fehlen noch ein paar Knopfbilder (Erfolge, Zurück, Sets, Set-Auswahl).
