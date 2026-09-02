# Troubleshooting

[🇩🇪 Deutsche Fassung](TROUBLESHOOTING.de.md)

Always start with `./doctor.sh`. Whatever it marks as failed is explained here
in detail.

## The adapter does not show up at all

```sh
lsusb | grep 0403:6015          # is the MK3-USB on the bus?
ls -l /dev/victron-mk3          # did udev create the symlink?
getfacl /dev/ttyUSB0            # does it list user:<yourname>:rw- ?
```

* **No `0403:6015`** → cable or adapter. The FTDI chip is powered from USB, so
  it shows up even when the inverter is off.
* **Symlink missing** → reload the rules:
  `sudo udevadm control --reload && sudo udevadm trigger --subsystem-match=tty`,
  then unplug and replug the adapter.
* **No ACL** → almost always the wrong file name. The rule must be called
  `70-victron-mk3.rules`; `73-seat-late.rules` is what evaluates the `uaccess`
  tag, so anything numbered `73` or higher runs too late. Logging out and back
  in also helps, because then the group membership applies.

## VEConfigure does not find the MK3

Almost always **auto-detection**. It cannot work under Wine (WMI
`Win32_SerialPort` is missing from Wine's `wbemprox`), and the 32 ttyS dummy
ports make the scan run into timeouts on top of that.

→ Switch auto-detection off and select **COM1 manually**. Expected result:
"target device found".

If COM1 cannot even be selected, the mapping is wrong:

```sh
ls -l ~/.wine/dosdevices/          # only com1 -> /dev/victron-mk3 should be there
~/.local/bin/victron-com1-fix      # repairs it
systemctl --user status victron-com1.path
```

## Everything broke again after a Wine update

Expected: `wineboot` recreates `dosdevices`. The path unit repairs that within
seconds. If it does not:

```sh
systemctl --user enable --now victron-com1.path
systemctl --user start victron-com1.service
journalctl --user -u victron-com1.service -n 20
```

## Checking whether the MK3 answers at all

Only with VEConfigure **closed** — serial ports are exclusive, otherwise you
are measuring a port collision instead of the hardware:

```sh
stty -F /dev/victron-mk3 2400 raw -echo
timeout 3 od -A d -t x1z < /dev/victron-mk3
```

The MK3 sends its version frame unprompted as soon as the port is opened, for
example `07 ff 56 28 db 11 00 42 4e`. If that arrives, the entire Linux side is
fine and the problem is further up.

## VEConfigure crashes while reading the inverter

First question: are you running it with `WINEDEBUG`? Then **that** is the
cause. `+comm` logs every serial IOCTL (1.4 MB in three minutes) and starves
the timing-critical VE.Bus thread, which runs at
`THREAD_PRIORITY_TIME_CRITICAL`. Use `WINEDEBUG=-all` for normal work.

The crash report lands in `~/Downloads/backtrace.txt`, and only once you close
VEConfigure. `coredumpctl` sees nothing, because Wine catches the exception
itself and `winedbg --auto` stays attached to the process.

For targeted diagnosis use `WINEDEBUG=+seh` — exceptions only, almost no timing
impact. Note that Delphi and C++Builder programs throw a lot of first-chance
exceptions, so the log grows quickly.

## VE.Bus System Configurator is stuck in a dialog

On first start it asks for a file to store the Multi names. **Cancel leads to
an endless loop** — the dialog comes back every time. Way out: press **Save**.
`install.sh` takes care of this permanently by creating
`Documents\Multinames.dat` and registering it.

## Dead ends already ruled out

Do not spend time on these again:

* **`wine regsvr32 wbemdisp.dll` / `winetricks wmi`** changes nothing. The CLSID
  `{172bddf8-ceea-11d1-8b05-00600806d9b6}` is `WinMGMTS` and **is** registered;
  the error `0x80004002` means `E_NOINTERFACE` — Wine's `wbemdisp` does not
  hand out `IDispatch` for `WinMGMTS`. Even if it did, `Win32_SerialPort` is
  missing from `wbemprox`. Auto-detection stays dead either way.
* **The FTDI `latency_timer`** (16 ms → 1 ms) speeds up transfers but was never
  required for detection. There is an optional, commented-out line for it in
  the udev rule.
* **Suspecting the hardware when you measure 0 bytes** was wrong once already:
  the actual cause was a port collision with a running VEConfigure.
