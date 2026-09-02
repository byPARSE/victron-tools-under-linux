# Victron tools under Linux

🇬🇧 English · [🇩🇪 Deutsche Fassung](README.de.md)

Run Victron Energy's Windows-only configuration software — **VEConfigure**,
**VE.Bus System Configurator**, **VE.Bus Quick Configure** and **VEFlash** — on
Linux under Wine, talking to a real inverter through the **MK3-USB interface**.

Installing Wine and the tools is the easy part. Getting the MK3-USB actually
recognised is not, and that is what this repository automates. Out of the box
you typically see one of these:

* the adapter is not detected at all, or
* COM auto-detection runs for a while and finds nothing.

Both have concrete causes, and all of them are fixable. `install.sh` applies
the fixes, `doctor.sh` tells you which one is missing when something breaks.

## Requirements

* A Linux system with **systemd** (any distribution — Arch, Debian, Ubuntu,
  Fedora, openSUSE, Mint, … are detected automatically)
* **Wine**, including 32-bit support — the Victron tools are 32-bit programs
* A **Victron MK3-USB** interface (FTDI FT-X, USB ID `0403:6015`)
* The Victron software itself, free from
  <https://www.victronenergy.com/support-and-downloads/software>

## Quick start

```sh
git clone https://github.com/byPARSE/victron-tools-under-linux.git
cd victron-tools-under-linux
./install.sh
```

The installer asks for your password once (for the udev rule) and handles the
rest. Afterwards, **turn auto-detection off in the Victron tools and select
COM1 by hand** — see [Using the tools](#using-the-tools) for why.

Not sure whether it worked?

```sh
./doctor.sh
```

New to this? The **[step-by-step guide](docs/INSTALL.en.md)** walks through
everything from installing Wine to the first connection, assuming no prior
knowledge.

### Options

| Option | Meaning |
|---|---|
| `--prefix PATH` | use a different Wine prefix (default `~/.wine`) |
| `--com comN` | use a different COM port, if COM1 is taken |
| `--lang XX` | language of the Victron user interface |
| `--no-udev` | skip the system part, no root required |
| `--no-tools` | system side only, do not install the Victron software |
| `-y` | do not ask anything |

Scripts speak English or German, following your locale. Force it with
`VICTRON_LANG=de ./install.sh` or `VICTRON_LANG=en ./install.sh`.

## Why this is needed

**1. Permission to reach the adapter.** `/dev/ttyUSB0` belongs to `root:uucp`
or `root:dialout`, and your user normally is not in that group. The rule
`70-victron-mk3.rules` solves it with `TAG+="uaccess"` (an ACL for the locally
logged-in user) and adds a stable device name, `/dev/victron-mk3`.

> The **70** prefix is mandatory. The `uaccess` tag is evaluated by
> `73-seat-late.rules`, so a `99-` rule runs too late and no ACL is created.
> This one cost a full afternoon to find.

**2. A low COM number.** Wine hardwires `com1..com32` to `/dev/ttyS0..31` and
therefore puts the MK3 on **COM33** — too high, the Victron tools never look
there. So `dosdevices/com1` points straight at `/dev/victron-mk3`.

**3. Keeping it that way.** Wine resets `dosdevices` on every `wineboot` and
every prefix update. Two systemd user units handle that: `victron-com1.path`
watches the directory and starts `victron-com1.service`, which runs
`victron-com1-fix`. That script restores the mapping and clears out the dead
ones — idempotently, or the path unit would trigger itself forever.

**4. Auto-detection off.** COM auto-detection **cannot work under Wine**: the
tools ask WMI for `Win32_SerialPort`, and Wine's `wbemprox` does not implement
that class, so the query returns zero ports. The registry template therefore
sets `"Scan COM ports"="0"` everywhere. **VEFlash** has no such switch — there,
simply never press *Auto detect comport*.

## Using the tools

* **Always select COM1 manually.** Never use auto-detection.
* **Never run with `WINEDEBUG=+comm`.** The tracing logs every serial IOCTL and
  slows the timing-critical VE.Bus thread (2400 baud) enough to crash
  VEConfigure while reading the inverter. Use `WINEDEBUG=-all`, and `+seh` if
  you really need to trace something.
* **Do not touch the port while VEConfigure is running.** Serial ports are
  exclusive; a parallel read sees zero bytes and looks exactly like broken
  hardware.
* **VE.Bus System Configurator, first start:** it asks for a file to store the
  Multi names, and *Cancel* does not get you out — the dialog reappears
  forever. Press **Save**. `install.sh` prevents the dialog entirely by
  creating `Multinames.dat` and registering it.

## What gets installed

| Path | Purpose |
|---|---|
| `/etc/udev/rules.d/70-victron-mk3.rules` | access rights and the `/dev/victron-mk3` symlink |
| `~/.local/bin/victron-com1-fix` | keeps Wine's COM mapping correct |
| `~/.config/victron-wine/config` | prefix, COM port and device name |
| `~/.config/systemd/user/victron-com1.{path,service}` | self-healing after `wineboot` |
| registry `HKCU\Software\Victron Energy` | auto-detection off, Multi names file |

Everything is removed again by `./uninstall.sh`. The Wine prefix and the
Victron software are left alone on purpose.

## Distribution differences

`install.sh` detects these itself; listed here for reference.

| | Arch / Fedora | Debian / Ubuntu / openSUSE |
|---|---|---|
| group owning serial devices | `uucp` | `dialout` |
| Wine packages | `wine` | `wine` + `wine32:i386`, after `dpkg --add-architecture i386` |

## No personal data in this repository

Nothing here contains a user name, a host name or a home directory path. The
two places where one is needed are filled in **on your machine at install
time**:

* the Linux user name comes from `id -un`, for the group membership and the
  file ownership check;
* the Wine user name is read from the prefix and substituted into
  `files/registry/victron-settings.reg.in` (`@WINEUSER@`), because the Victron
  registry entry needs the absolute path
  `C:\users\<name>\Documents\Multinames.dat`.

No name is ever written back into the repository, so a `git status` stays clean
and a fork carries nothing of yours.

## Troubleshooting

See **[docs/TROUBLESHOOTING.en.md](docs/TROUBLESHOOTING.en.md)** — including the
dead ends that have already been ruled out, so you do not repeat them.

## Contributing

Issues and pull requests are welcome, in English or German. Especially useful:
reports from distributions other than Arch, and from MK2/MK3 variants other
than the FTDI `0403:6015`.

## License

[MIT](LICENSE) — do whatever you want with the scripts and docs.

The Victron software itself is **not** part of this repository and is not
redistributed here; it belongs to Victron Energy B.V. This project is not
affiliated with, endorsed by, or supported by Victron Energy B.V.
