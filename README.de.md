# Victron-Tools unter Linux

[🇬🇧 English version](README.md) · 🇩🇪 Deutsch

Victrons Konfigurationssoftware gibt es nur für Windows — **VEConfigure**, den
**VE.Bus System Configurator**, **VE.Bus Quick Configure** und **VEFlash**.
Dieses Projekt bringt sie unter Linux mit Wine zum Laufen, und zwar so, dass
sie über das **MK3-USB-Interface** wirklich mit einem Wechselrichter reden.

Wine und die Tools zu installieren ist der einfache Teil. Dass das MK3-USB
erkannt wird, ist es nicht — genau das automatisiert dieses Repository. Ohne
Vorbereitung passiert typischerweise eins von beidem:

* der Adapter wird gar nicht erkannt, oder
* die COM-Autoerkennung sucht eine Weile und findet nichts.

Beides hat konkrete Ursachen, und alle sind lösbar. `install.sh` setzt die
Lösungen um, `doctor.sh` sagt dir bei Problemen, welche davon fehlt.

## Voraussetzungen

* Ein Linux-System mit **systemd** (die Distribution ist egal — Arch, Debian,
  Ubuntu, Fedora, openSUSE, Mint … werden automatisch erkannt)
* **Wine** samt 32-Bit-Unterstützung — die Victron-Tools sind 32-Bit-Programme
* Ein **Victron MK3-USB**-Interface (FTDI FT-X, USB-ID `0403:6015`)
* Die Victron-Software selbst, kostenlos unter
  <https://www.victronenergy.com/support-and-downloads/software>

## Schnellstart

```sh
git clone https://github.com/byPARSE/victron-tools-under-linux.git
cd victron-tools-under-linux
./install.sh
```

Der Installer fragt einmal nach deinem Passwort (für die udev-Regel) und
erledigt den Rest. Danach in den Victron-Tools die **Autoerkennung ausschalten
und COM1 von Hand wählen** — warum, steht unter [Im Betrieb](#im-betrieb).

Unsicher, ob es geklappt hat?

```sh
./doctor.sh
```

Zum ersten Mal damit zu tun? Die **[Schritt-für-Schritt-Anleitung](docs/INSTALL.de.md)**
führt dich ohne Vorkenntnisse durch alles, von der Wine-Installation bis zur
ersten Verbindung.

### Optionen

| Option | Bedeutung |
|---|---|
| `--prefix PFAD` | anderes Wine-Prefix (Vorgabe `~/.wine`) |
| `--com comN` | anderer COM-Port, falls COM1 belegt ist |
| `--lang XX` | Sprache der Victron-Oberfläche |
| `--no-udev` | Systemteil überspringen, kein root nötig |
| `--no-tools` | nur Systemseite, Victron-Software nicht installieren |
| `-y` | keine Rückfragen |

Die Skripte sprechen Deutsch oder Englisch, je nach Spracheinstellung. Fest
vorgeben lässt sich das mit `VICTRON_LANG=de ./install.sh` bzw.
`VICTRON_LANG=en ./install.sh`.

## Warum das nötig ist

**1. Zugriff auf den Adapter.** `/dev/ttyUSB0` gehört `root:uucp` bzw.
`root:dialout`; der eigene Benutzer ist da normalerweise nicht drin. Die Regel
`70-victron-mk3.rules` löst das per `TAG+="uaccess"` (eine ACL für den lokal
angemeldeten Benutzer) und legt nebenbei den stabilen Namen
`/dev/victron-mk3` an.

> Der Präfix **70** ist Pflicht. Den `uaccess`-Tag wertet `73-seat-late.rules`
> aus — eine `99-`-Regel greift zu spät, die ACL bleibt aus. Das hat einen
> kompletten Nachmittag gekostet.

**2. Eine niedrige COM-Nummer.** Wine belegt `com1..com32` fest mit
`/dev/ttyS0..31` und schiebt den MK3 damit auf **COM33** — zu hoch, die
Victron-Tools schauen dort nicht hin. Deshalb zeigt `dosdevices/com1` direkt
auf `/dev/victron-mk3`.

**3. Dass das so bleibt.** Wine setzt `dosdevices` bei jedem `wineboot` und
jedem Prefix-Update zurück. Dagegen laufen zwei systemd-User-Units:
`victron-com1.path` beobachtet das Verzeichnis und startet
`victron-com1.service`, der `victron-com1-fix` aufruft. Das Skript stellt das
Mapping wieder her und räumt die toten Einträge weg — idempotent, sonst würde
die Path-Unit sich endlos selbst triggern.

**4. Autoerkennung aus.** Die COM-Autoerkennung **kann unter Wine nicht
funktionieren**: die Tools fragen WMI nach `Win32_SerialPort`, und Wines
`wbemprox` implementiert diese Klasse nicht — die Abfrage liefert null Ports.
Die Registry-Vorlage setzt darum überall `"Scan COM ports"="0"`. **VEFlash**
kennt den Schalter nicht; dort einfach nie *Auto detect comport* drücken.

## Im Betrieb

* **COM1 immer manuell wählen.** Nie die Autoerkennung benutzen.
* **Kein `WINEDEBUG=+comm`.** Das Tracing protokolliert jeden seriellen IOCTL
  und bremst den zeitkritischen VE.Bus-Thread (2400 Baud) so stark, dass
  VEConfigure beim Einlesen des Wechselrichters abstürzt. Normal ist
  `WINEDEBUG=-all`; wenn es unbedingt Tracing sein muss, dann `+seh`.
* **Während VEConfigure läuft, nicht selbst auf den Port zugreifen.** Serielle
  Ports sind exklusiv; ein paralleler Zugriff sieht null Bytes und sieht damit
  exakt aus wie ein Hardware-Defekt.
* **VE.Bus System Configurator, Erststart:** er fragt nach einer Datei für die
  Multi-Namen, und mit *Cancel* kommt man da nicht raus — der Dialog erscheint
  endlos wieder. **Save** drücken. `install.sh` verhindert den Dialog von
  vornherein, indem es `Multinames.dat` anlegt und einträgt.

## Was installiert wird

| Pfad | Zweck |
|---|---|
| `/etc/udev/rules.d/70-victron-mk3.rules` | Zugriffsrechte und der Symlink `/dev/victron-mk3` |
| `~/.local/bin/victron-com1-fix` | hält Wines COM-Mapping korrekt |
| `~/.config/victron-wine/config` | Prefix, COM-Port und Gerätename |
| `~/.config/systemd/user/victron-com1.{path,service}` | Selbstheilung nach `wineboot` |
| Registry `HKCU\Software\Victron Energy` | Autoerkennung aus, Multi-Namen-Datei |

`./uninstall.sh` entfernt das alles wieder. Das Wine-Prefix und die
Victron-Software bleiben absichtlich unangetastet.

## Unterschiede zwischen Distributionen

`install.sh` erkennt das selbst; hier nur zum Nachlesen.

| | Arch / Fedora | Debian / Ubuntu / openSUSE |
|---|---|---|
| Gruppe für serielle Geräte | `uucp` | `dialout` |
| Wine-Pakete | `wine` | `wine` + `wine32:i386`, nach `dpkg --add-architecture i386` |

## Keine persönlichen Daten in diesem Repository

Nirgendwo hier steht ein Benutzername, ein Rechnername oder ein
Home-Verzeichnis. Die zwei Stellen, an denen einer gebraucht wird, werden
**auf deinem Rechner beim Installieren** eingesetzt:

* Der Linux-Benutzername kommt aus `id -un` — für die Gruppenmitgliedschaft und
  die Prüfung der Dateirechte.
* Der Wine-Benutzername wird aus dem Prefix gelesen und in
  `files/registry/victron-settings.reg.in` für `@WINEUSER@` eingesetzt, weil der
  Victron-Registry-Eintrag den vollständigen Pfad
  `C:\users\<name>\Documents\Multinames.dat` braucht.

Zurück ins Repository geschrieben wird nie ein Name. `git status` bleibt sauber,
und ein Fork trägt nichts von dir mit sich herum.

## Fehlersuche

Siehe **[docs/TROUBLESHOOTING.de.md](docs/TROUBLESHOOTING.de.md)** — dort stehen
auch die Sackgassen, die schon ausgeschlossen sind, damit du sie nicht noch
einmal untersuchst.

## Mitmachen

Issues und Pull Requests sind willkommen, auf Deutsch oder Englisch. Besonders
hilfreich: Rückmeldungen von anderen Distributionen als Arch und von anderen
MK2-/MK3-Varianten als dem FTDI `0403:6015`.

## Lizenz

[MIT](LICENSE) — mit den Skripten und der Dokumentation kannst du machen, was
du willst.

Die Victron-Software selbst ist **nicht** Teil dieses Repositories und wird
hier auch nicht weitergegeben; sie gehört Victron Energy B.V. Dieses Projekt
steht in keiner Verbindung zu Victron Energy B.V. und wird von dort weder
unterstützt noch betreut.
