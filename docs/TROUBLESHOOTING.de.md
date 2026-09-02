# Fehlersuche

[🇬🇧 English version](TROUBLESHOOTING.en.md)

Erster Griff immer: `./doctor.sh`. Was dort als fehlend gemeldet wird, steht
hier im Detail.

## Das Gerät taucht gar nicht auf

```sh
lsusb | grep 0403:6015          # MK3-USB am Bus?
ls -l /dev/victron-mk3          # udev-Symlink da?
getfacl /dev/ttyUSB0            # steht dort user:<deinname>:rw- ?
```

* **Kein `0403:6015`** → Kabel oder Adapter. Der FTDI-Chip hängt am USB-Strom
  und meldet sich auch, wenn der Wechselrichter aus ist.
* **Symlink fehlt** → Regeln neu einlesen:
  `sudo udevadm control --reload && sudo udevadm trigger --subsystem-match=tty`,
  danach den Adapter ab- und wieder anstecken.
* **Keine ACL** → fast immer der falsche Dateiname. Die Regel muss
  `70-victron-mk3.rules` heißen; `73-seat-late.rules` wertet den
  `uaccess`-Tag aus, alles ab `73` kommt also zu spät. Eine Neuanmeldung hilft
  ebenfalls, dann greift die Gruppenmitgliedschaft.

## VEConfigure findet den MK3 nicht

Fast immer die **Autoerkennung**. Sie kann unter Wine nicht funktionieren (WMI
`Win32_SerialPort` fehlt in Wines `wbemprox`), und die 32 ttyS-Attrappen lassen
den Scan zusätzlich in Timeouts laufen.

→ Autoerkennung abschalten und **COM1 manuell** wählen. Erwartete Meldung:
"Zielgerät gefunden".

Ist COM1 gar nicht anwählbar, stimmt das Mapping nicht:

```sh
ls -l ~/.wine/dosdevices/          # nur com1 -> /dev/victron-mk3 soll dastehen
~/.local/bin/victron-com1-fix      # repariert es
systemctl --user status victron-com1.path
```

## Nach einem Wine-Update ist alles wieder kaputt

Erwartbar: `wineboot` legt `dosdevices` neu an. Die Path-Unit repariert das
innerhalb von Sekunden. Wenn nicht:

```sh
systemctl --user enable --now victron-com1.path
systemctl --user start victron-com1.service
journalctl --user -u victron-com1.service -n 20
```

## Prüfen, ob der MK3 überhaupt antwortet

Nur bei **geschlossenem** VEConfigure — serielle Ports sind exklusiv, sonst
misst du eine Portkollision statt der Hardware:

```sh
stty -F /dev/victron-mk3 2400 raw -echo
timeout 3 od -A d -t x1z < /dev/victron-mk3
```

Der MK3 schickt seinen Versionsframe unaufgefordert, sobald der Port geöffnet
wird, zum Beispiel `07 ff 56 28 db 11 00 42 4e`. Kommt der an, ist die gesamte
Linux-Seite in Ordnung und das Problem liegt weiter oben.

## VEConfigure stürzt beim Einlesen ab

Erste Frage: läuft es mit `WINEDEBUG`? Dann ist **das** die Ursache. `+comm`
protokolliert jeden seriellen IOCTL (1,4 MB in drei Minuten) und bremst den
zeitkritischen VE.Bus-Thread aus, der mit `THREAD_PRIORITY_TIME_CRITICAL`
läuft. Für den normalen Betrieb `WINEDEBUG=-all` verwenden.

Der Absturzbericht landet in `~/Downloads/backtrace.txt`, und zwar erst, wenn
du VEConfigure beendest. `coredumpctl` sieht nichts, weil Wine die Exception
selbst abfängt und `winedbg --auto` am Prozess hängen bleibt.

Für gezielte Diagnose `WINEDEBUG=+seh` nehmen — nur Exceptions, kaum
Timing-Einfluss. Delphi- und C++Builder-Programme werfen allerdings viele
First-Chance-Exceptions, das Log wird also schnell groß.

## VE.Bus System Configurator hängt in einem Dialog fest

Beim ersten Start fragt er nach einer Datei für die Multi-Namen. **Cancel führt
in eine Endlosschleife** — der Dialog kommt jedes Mal wieder. Ausweg: **Save**
drücken. `install.sh` erledigt das dauerhaft, indem es
`Documents\Multinames.dat` anlegt und einträgt.

## Sackgassen, die schon ausgeschlossen sind

Damit musst du dich nicht noch einmal aufhalten:

* **`wine regsvr32 wbemdisp.dll` / `winetricks wmi`** bringt nichts. Die CLSID
  `{172bddf8-ceea-11d1-8b05-00600806d9b6}` ist `WinMGMTS` und **ist**
  registriert; der Fehler `0x80004002` bedeutet `E_NOINTERFACE` — Wines
  `wbemdisp` liefert für `WinMGMTS` kein `IDispatch`. Und selbst wenn, fehlt
  `Win32_SerialPort` in `wbemprox`. Die Autoerkennung bleibt so oder so tot.
* **Der FTDI `latency_timer`** (16 ms → 1 ms) beschleunigt die Übertragung, war
  für die Erkennung aber nie nötig. In der udev-Regel steht dafür eine
  optionale, auskommentierte Zeile.
* **Hardware-Verdacht bei 0 gemessenen Bytes** war schon einmal falsch: die
  tatsächliche Ursache war eine Portkollision mit dem laufenden VEConfigure.
