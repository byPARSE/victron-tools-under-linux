# Step-by-step installation

[🇩🇪 Deutsche Fassung](INSTALL.de.md)

This guide assumes no prior knowledge. It takes about 20 minutes. If a step
already applies to you, skip it.

Lines starting with `$` are commands. Type the part after the `$` into a
terminal and press Enter. You open a terminal with `Ctrl`+`Alt`+`T` on most
desktops, or by searching for "Terminal" in your application menu.

---

## Before you start — please read

**You use this at your own risk.** This project does not come from Victron
Energy; it changes system settings on your computer. Nobody accepts liability
for damage to your hardware, software or installation.

**The Victron tools are meant for professionals.** Victron addresses
VEConfigure and the VE.Bus tools to trained engineers, installers and dealers,
not to system owners and end users — those should ask their installer. A faulty
configuration can permanently damage an inverter installation, and Victron
offers no support for configuration done by untrained people.

This guide only shows you how to get the software talking to the adapter. It
does not teach you what the settings mean. Full text: [NOTICE.md](../NOTICE.md).

---

## What you need

* A Linux computer.
* A **Victron MK3-USB** interface — the small blue box with a USB plug on one
  side and an RJ45 socket on the other.
* The **RJ45 cable** to your inverter, and the inverter powered on. The MK3
  gets its USB side from the computer, but the VE.Bus side is powered by the
  inverter. Without power there, it cannot answer.
* About 300 MB of free disk space.

---

## Step 1 — Install Wine

Wine runs Windows programs on Linux. The Victron tools are 32-bit programs, so
32-bit support has to be there as well.

Find your distribution below and run the command:

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

Check that it worked:

```sh
$ wine --version
```

You should see something like `wine-11.16`. If you get "command not found",
Wine is not installed yet — go back and check for errors.

> **On `sudo`:** this asks for your own password, and nothing is shown while
> you type it. That is normal, just type it and press Enter.

---

## Step 2 — Download this project

If you have `git`:

```sh
$ git clone https://github.com/byPARSE/victron-tools-under-linux.git
$ cd victron-tools-under-linux
```

Without `git`, download the ZIP from the project page on GitHub
("Code" → "Download ZIP"), unpack it, and change into the folder:

```sh
$ cd ~/Downloads/victron-tools-under-linux-main
```

---

## Step 3 — Download the Victron software

The Victron tools are not part of this project — they belong to Victron and you
get them directly from them, free of charge and without an account:

1. Open <https://www.victronenergy.com/support-and-downloads/software>
2. Look for **VE Configure tools** and download the installer
   (a file named something like `VECSetup_B.exe`).
3. Move that file into the `installers/` folder of this project:

```sh
$ mv ~/Downloads/VECSetup_B.exe installers/
```

You can skip this step. The installer will then set up everything else and
remind you where to get the software.

---

## Step 4 — Run the installer

```sh
$ ./install.sh
```

What happens:

* It reports your distribution and Wine version.
* It asks for your password **once**, to install the udev rule into
  `/etc/udev/rules.d/`. That rule is what gives you access to the adapter.
* It sets up the COM port mapping and two small background services.
* If you put the Victron installer into `installers/`, its setup window opens
  now. Click through it and keep the suggested installation path.
* It writes the Victron settings that switch COM auto-detection off.
* Finally it runs the check from Step 6 automatically.

If it says your user was added to a group (`uucp` or `dialout`), that only
takes effect after logging out and back in. Usually you do not need it — the
udev rule grants access a second way.

---

## Step 5 — Plug in the MK3-USB

Connect it to the computer, and connect the RJ45 cable to the inverter. Switch
the inverter on.

---

## Step 6 — Check

```sh
$ ./doctor.sh
```

Every line should say `OK`. Two lines are about the adapter itself:

```
  OK    MK3-USB on the bus (FTDI 0403:6015)
  OK    Device /dev/victron-mk3 -> /dev/ttyUSB0
```

If those two say `FAIL`, the adapter is not plugged in, or not being seen. Try
a different USB port and a different cable first.

For anything else that says `FAIL`, the line right underneath tells you what to
do. More detail in [TROUBLESHOOTING.en.md](TROUBLESHOOTING.en.md).

---

## Step 7 — Start VEConfigure

Your application menu now has a **VE Configure tools** entry. If you prefer the
terminal:

```sh
$ wine "$HOME/.wine/drive_c/Program Files (x86)/VE Configure tools/VEConfig.exe"
```

---

## Step 8 — The first connection

> ⚠️ **From here on you are changing a live installation.** Only carry on if you
> have the training for it. A wrong setting can damage the inverter or the
> system around it. If you are the owner rather than the installer, this is the
> point to hand over to your installer.

This is the part that trips everyone up:

1. In VEConfigure, open the port selection.
2. **Switch off auto-detection.** It cannot work under Wine, no matter how long
   you let it run.
3. **Select COM1 by hand.** COM1 is your MK3-USB — that is exactly what
   `install.sh` arranged.
4. Read the inverter.

You should get a "target device found" message and then the configuration.

**In VEFlash** there is no auto-detection switch, only a button called
*Auto detect comport*. Do not press it. Pick COM1 from the list instead.

---

## Step 9 — Things to know for everyday use

* **Do not start the tools with `WINEDEBUG=+comm`.** It slows the timing down
  enough to crash VEConfigure while it reads the inverter.
* **Do not access the port from a terminal while VEConfigure is open.** Serial
  ports can only be opened by one program at a time.
* **On first start of the VE.Bus System Configurator**, if a save dialog for
  the "Multi names" appears: press **Save**, not Cancel. Cancel puts it into an
  endless loop. Normally `install.sh` prevents this dialog from appearing.
* **After a Wine update**, everything keeps working — a background service
  restores the COM port mapping automatically. If in doubt, run `./doctor.sh`.

---

## Updating and removing

Update to a newer version of this project:

```sh
$ git pull
$ ./install.sh
```

Remove everything it installed:

```sh
$ ./uninstall.sh
```

The Wine prefix and the Victron software stay — remove those yourself if you
want them gone.

---

## Taking it to another computer

The project is self-contained. On the second machine, either clone it again, or
copy the folder over on a USB stick and run `./install.sh` there.

For a machine without internet, you can pack up the Victron software you
already installed:

```sh
$ ./pack-tools.sh
```

That creates `installers/ve-configure-tools.tar.gz`, which `install.sh` unpacks
on the other machine. Keep that archive for yourself — Victron's software is
theirs to distribute.
