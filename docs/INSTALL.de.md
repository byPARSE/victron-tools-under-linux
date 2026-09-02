# Schritt-für-Schritt-Installation

[🇬🇧 English version](INSTALL.en.md)

Diese Anleitung setzt keine Vorkenntnisse voraus und dauert etwa 20 Minuten.
Schritte, die bei dir schon erledigt sind, überspringst du einfach.

Zeilen, die mit `$` beginnen, sind Befehle. Tippe das, was hinter dem `$`
steht, in ein Terminal und drücke Enter. Ein Terminal öffnest du auf den
meisten Desktops mit `Strg`+`Alt`+`T` oder indem du im Anwendungsmenü nach
"Terminal" suchst.

---

## Bitte vorher lesen

**Du benutzt das auf eigene Gefahr.** Dieses Projekt stammt nicht von Victron
Energy; es verändert Systemeinstellungen auf deinem Rechner. Für Schäden an
deiner Hardware, Software oder Anlage wird keine Haftung übernommen.

**Die Victron-Tools sind für Fachleute gedacht.** Victron richtet VEConfigure
und die VE.Bus-Werkzeuge an geschulte Techniker, Installateure und Fachhändler,
nicht an Anlagenbesitzer und Endanwender — die sollten ihren Installateur
fragen. Eine fehlerhafte Konfiguration kann eine Wechselrichter-Anlage dauerhaft
beschädigen, und Victron leistet keinen Support für Konfigurationen durch
ungeschulte Personen.

Diese Anleitung zeigt dir nur, wie die Software mit dem Adapter spricht. Was
die Einstellungen bedeuten, lernst du hier nicht. Vollständig:
[NOTICE.md](../NOTICE.md).

---

## Was du brauchst

* Einen Linux-Rechner.
* Ein **Victron MK3-USB**-Interface — die kleine blaue Box mit USB-Stecker auf
  der einen und RJ45-Buchse auf der anderen Seite.
* Das **RJ45-Kabel** zum Wechselrichter, und der Wechselrichter muss
  eingeschaltet sein. Die USB-Seite des MK3 versorgt der Rechner, die
  VE.Bus-Seite aber der Wechselrichter. Ohne Strom dort kann er nicht
  antworten.
* Rund 300 MB freien Speicherplatz.

---

## Schritt 1 — Wine installieren

Wine führt Windows-Programme unter Linux aus. Die Victron-Tools sind
32-Bit-Programme, deshalb muss auch die 32-Bit-Unterstützung dabei sein.

Suche deine Distribution heraus und führe den Befehl aus:

**Arch, EndeavourOS, Manjaro, CachyOS**

```sh
$ sudo pacman -S --needed wine
```

**Debian, Ubuntu, Linux Mint, Pop!\_OS**

```sh
$ sudo dpkg --add-architecture i386
$ sudo apt update
$ sudo apt install wine wine32:i386
```

**Fedora**

```sh
$ sudo dnf install wine wine-core.i686
```

**openSUSE**

```sh
$ sudo zypper install wine wine-32bit
```

Prüfen, ob es geklappt hat:

```sh
$ wine --version
```

Es sollte so etwas wie `wine-11.16` erscheinen. Kommt "Befehl nicht gefunden",
ist Wine noch nicht installiert — dann noch einmal zurück und nach
Fehlermeldungen schauen.

> **Zu `sudo`:** Das fragt nach deinem eigenen Passwort, und während du tippst,
> ist nichts zu sehen. Das ist normal — einfach tippen und Enter drücken.

---

## Schritt 2 — Dieses Projekt herunterladen

Wenn du `git` hast:

```sh
$ git clone https://github.com/byPARSE/victron-tools-under-linux.git
$ cd victron-tools-under-linux
```

Ohne `git` lädst du auf der GitHub-Seite des Projekts das ZIP herunter
("Code" → "Download ZIP"), entpackst es und wechselst in den Ordner:

```sh
$ cd ~/Downloads/victron-tools-under-linux-main
```

---

## Schritt 3 — Victron-Software herunterladen

Die Victron-Tools sind nicht Teil dieses Projekts — sie gehören Victron, und du
holst sie direkt dort, kostenlos und ohne Konto:

1. Öffne <https://www.victronenergy.com/support-and-downloads/software>
2. Suche nach **VE Configure tools** und lade das Installationsprogramm
   herunter (eine Datei, die etwa `VECSetup_B.exe` heißt).
3. Verschiebe diese Datei in den Ordner `installers/` dieses Projekts:

```sh
$ mv ~/Downloads/VECSetup_B.exe installers/
```

Du kannst diesen Schritt auch überspringen. Der Installer richtet dann alles
Übrige ein und sagt dir, woher du die Software bekommst.

---

## Schritt 4 — Installer starten

```sh
$ ./install.sh
```

Was dabei passiert:

* Er meldet deine Distribution und die Wine-Version.
* Er fragt **einmal** nach deinem Passwort, um die udev-Regel nach
  `/etc/udev/rules.d/` zu schreiben. Diese Regel verschafft dir überhaupt erst
  Zugriff auf den Adapter.
* Er richtet das COM-Port-Mapping und zwei kleine Hintergrunddienste ein.
* Liegt das Victron-Installationsprogramm in `installers/`, öffnet sich jetzt
  dessen Fenster. Klick dich durch und lass den vorgeschlagenen
  Installationspfad stehen.
* Er schreibt die Victron-Einstellungen, die die COM-Autoerkennung abschalten.
* Zum Schluss führt er die Prüfung aus Schritt 6 automatisch aus.

Wenn dabei steht, dass dein Benutzer einer Gruppe hinzugefügt wurde (`uucp`
oder `dialout`), wirkt das erst nach dem nächsten An- und Abmelden. Meistens
brauchst du es gar nicht — die udev-Regel verschafft dir den Zugriff auf einem
zweiten Weg.

---

## Schritt 5 — MK3-USB anstecken

Steck ihn an den Rechner und verbinde das RJ45-Kabel mit dem Wechselrichter.
Schalte den Wechselrichter ein.

---

## Schritt 6 — Prüfen

```sh
$ ./doctor.sh
```

In jeder Zeile sollte `OK` stehen. Zwei Zeilen betreffen den Adapter selbst:

```
  OK    MK3-USB am Bus (FTDI 0403:6015)
  OK    Geraet /dev/victron-mk3 -> /dev/ttyUSB0
```

Steht dort `FEHLT`, ist der Adapter nicht angesteckt oder wird nicht gesehen.
Probiere zuerst einen anderen USB-Anschluss und ein anderes Kabel.

Bei allen anderen `FEHLT`-Zeilen steht direkt darunter, was zu tun ist. Mehr
Details in [TROUBLESHOOTING.de.md](TROUBLESHOOTING.de.md).

---

## Schritt 7 — VEConfigure starten

In deinem Anwendungsmenü gibt es jetzt einen Eintrag **VE Configure tools**.
Wenn du das Terminal bevorzugst:

```sh
$ wine "$HOME/.wine/drive_c/Program Files (x86)/VE Configure tools/VEConfig.exe"
```

---

## Schritt 8 — Die erste Verbindung

> ⚠️ **Ab hier veränderst du eine reale Anlage.** Mach nur weiter, wenn du die
> Fachkenntnis dafür hast. Eine falsche Einstellung kann den Wechselrichter oder
> die Anlage drumherum beschädigen. Wenn du der Betreiber und nicht der
> Installateur bist, ist das der Punkt, an dem du übergeben solltest.

Das ist die Stelle, an der alle hängenbleiben:

1. Öffne in VEConfigure die Port-Auswahl.
2. **Schalte die Autoerkennung aus.** Sie kann unter Wine nicht funktionieren,
   egal wie lange du sie laufen lässt.
3. **Wähle COM1 von Hand.** COM1 ist dein MK3-USB — genau das hat `install.sh`
   eingerichtet.
4. Lies den Wechselrichter ein.

Es sollte "Zielgerät gefunden" erscheinen und danach die Konfiguration.

**In VEFlash** gibt es keinen Schalter für die Autoerkennung, sondern nur einen
Knopf namens *Auto detect comport*. Drück ihn nicht, sondern wähle COM1 aus der
Liste.

---

## Schritt 9 — Was du im Alltag wissen solltest

* **Starte die Tools nicht mit `WINEDEBUG=+comm`.** Das bremst das Timing so
  weit aus, dass VEConfigure beim Einlesen des Wechselrichters abstürzt.
* **Greif nicht vom Terminal aus auf den Port zu, während VEConfigure offen
  ist.** Serielle Ports lassen sich immer nur von einem Programm öffnen.
* **Beim ersten Start des VE.Bus System Configurator**: Falls ein
  Speichern-Dialog für die "Multi names" erscheint, drücke **Save**, nicht
  Cancel. Cancel führt in eine Endlosschleife. Normalerweise verhindert
  `install.sh`, dass dieser Dialog überhaupt auftaucht.
* **Nach einem Wine-Update** läuft alles weiter — ein Hintergrunddienst stellt
  das COM-Port-Mapping automatisch wieder her. Im Zweifel `./doctor.sh`.

---

## Aktualisieren und entfernen

Auf eine neuere Fassung dieses Projekts aktualisieren:

```sh
$ git pull
$ ./install.sh
```

Alles wieder entfernen, was installiert wurde:

```sh
$ ./uninstall.sh
```

Das Wine-Prefix und die Victron-Software bleiben stehen — die löschst du bei
Bedarf selbst.

---

## Auf einen anderen Rechner mitnehmen

Das Projekt ist in sich vollständig. Auf dem zweiten Rechner klonst du es
entweder erneut, oder du kopierst den Ordner per USB-Stick hinüber und startest
dort `./install.sh`.

Für einen Rechner ohne Internet kannst du die bereits installierte
Victron-Software einpacken:

```sh
$ ./pack-tools.sh
```

Das erzeugt `installers/ve-configure-tools.tar.gz`, was `install.sh` auf dem
anderen Rechner automatisch entpackt. Behalte dieses Archiv für dich — die
Weitergabe der Victron-Software ist Victrons Sache.
