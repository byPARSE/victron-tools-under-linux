# installers/

**English** — This directory is empty on purpose. Put the Victron installer
here and `install.sh` will run it:

1. Download **VE Configure tools** from
   <https://www.victronenergy.com/support-and-downloads/software> (free, no
   account needed).
2. Drop the `.exe` into this directory.
3. Run `./install.sh`.

Without an installer here, `install.sh` sets up everything else and tells you
where to get the software.

For an offline machine you can build an archive from an installation you
already have, using `./pack-tools.sh`. That archive stays local — Victron's
software is theirs to distribute, so `.gitignore` keeps it out of the
repository.

---

**Deutsch** — Dieses Verzeichnis ist absichtlich leer. Lege das
Victron-Installationsprogramm hier ab, dann startet `install.sh` es:

1. **VE Configure tools** herunterladen von
   <https://www.victronenergy.com/support-and-downloads/software> (kostenlos,
   kein Konto nötig).
2. Die `.exe` in dieses Verzeichnis legen.
3. `./install.sh` starten.

Ohne Installationsprogramm richtet `install.sh` alles Übrige ein und sagt dir,
woher du die Software bekommst.

Für einen Rechner ohne Internet kannst du dir mit `./pack-tools.sh` ein Archiv
aus einer vorhandenen Installation bauen. Das bleibt lokal — die Software
gehört Victron, deshalb hält `.gitignore` sie aus dem Repository heraus.
