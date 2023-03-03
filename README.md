# XBox Controller Mapping on Linux

I have a really neat little game controller: the [8BitDo SN30 Pro for Android](https://a.co/d/1IYg1G0). It has a small form factor and a USB cable (plus a Bluetooth option) so it is good for travelling. But it was designed only for playing XBox Cloud games on an Android device, and is not supported by the manufacturer on other platforms. If you plug it in to a Linux box it is detected and shows up in `lsusb`:

```
$ lsusb
...
Bus 002 Device 020: ID 2dc8:2101 8BitDo 8BitDo SN30 Pro for Android
...
```

but the buttons, even though they look like they have an XBox game controller layout, do not send the right events to games.

You can make it work with [`xboxdrv`](https://xboxdrv.gitlab.io/xboxdrv.html). The basic idea is to map the raw events in `/dev/input` to some software that reflects them back to another device with different identifiers.

Some additional reading:

* https://steamcommunity.com/app/236090/discussions/0/558748653724279774
* https://github.com/medusalix/xone (a possible alternative?)
* https://support.8bitdo.com/faq/sn30pro-for-android.html

## Pre-requisites

You will need

* Kernel modules: `joydev` and `uinput` (as described in the `xboxdrv` docs)
* `xboxdrv`: for mapping the controller https://xboxdrv.gitlab.io
* `evtest`: (optional) for testing the outputs
* `jstest-gtk`: (optional) handy UI for testing game controller

Per the `xboxdrv` docs you need to modify the kernel (so you can't test in a VM/container) if these modules are not already installed (they were on one of my machines):

```
$ modprobe uinput
$ modprobe joydev
```

## Up and Running

Identify the `event*` device that is linked to your gamepad:

```
$ ls -l /dev/input/by-path/ | grep joys
lrwxrwxrwx 1 root root 10 Mar  2 17:32 pci-0000:00:14.0-usb-0:2:1.0-event-joystick -> ../event16
lrwxrwxrwx 1 root root  6 Mar  2 17:32 pci-0000:00:14.0-usb-0:2:1.0-joystick -> ../js0
```

then run `xboxdrv` using that device:

```
sudo `which xboxdrv` --evdev /dev/input/event16 --verbose -d --evdev-debug -c xboxdrv.ini
[INFO]  CommandLineParser::read_config_file(): reading 'xboxdrv.ini'
xboxdrv 0.8.8 - http://pingus.seul.org/~grumbel/xboxdrv/ 
Copyright © 2008-2011 Ingo Ruhnke <grumbel@gmail.com> 
Licensed under GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html> 
This program comes with ABSOLUTELY NO WARRANTY. 
This is free software, and you are welcome to redistribute it under certain conditions; see 
the file COPYING for details. 


Your Xbox/Xbox360 controller should now be available as:
  /dev/input/js1
  /dev/input/event17

Press Ctrl-C to quit, use '--silent' to suppress the event output
```

The `xbox` gamepad should come up in user space and be picked up by Steam, XBox Cloud, GE-Force Now etc via that `/dev/input/js1` device listed in the command line. You might have to manually select the controller in the UI (depends on how they are detected). With SteamLink, for instance, you can select "Settings" (gear icon) before "Play" and choose a controller.

> NOTE: For some reason the [Gamepad Test](https://gamepadtest.com/) website detects the controller but does *not* correctly identify the mappings.

## Xpad Module

Some guides say to make sure `xpad` is not installed:

```
$ lsmod | grep xpad
```

but it seems to work for me either way. I think it just creates additional `/dev/js*` devices that you can ignore or configure in settings in your game. Also, it turns out that `--mimic-xpad` is a really important flag for `xboxdrv` (it's set to `true` in the `.ini` file used here). Without it, the virtual device (`/dev/input/event17` in the example above) has 4 additional buttons all with higher priority than `BTN_SOUTH` (aka `A`), and some (most) controller-aware apps (e.g. Chrome browser) take the buttons in order, not by name. You can see if it is going to work using `evtest` like this:

```

$ sudo `which evtest` /dev/input/event17
Input driver version is 1.0.1
Input device ID: bus 0x3 vendor 0x45e product 0x28e version 0x110
Input device name: "Microsoft X-Box 360 pad"
Supported events:
  Event type 0 (EV_SYN)
  Event type 1 (EV_KEY)
    Event code 304 (BTN_SOUTH)
    Event code 305 (BTN_EAST)
    Event code 307 (BTN_NORTH)
    Event code 308 (BTN_WEST)
    Event code 310 (BTN_TL)
    Event code 311 (BTN_TR)
    Event code 314 (BTN_SELECT)
    Event code 315 (BTN_START)
    Event code 316 (BTN_MODE)
    Event code 317 (BTN_THUMBL)
    Event code 318 (BTN_THUMBR)
  Event type 3 (EV_ABS)
    Event code 0 (ABS_X)
      Value      0
      Min   -32768
      Max    32767
    Event code 1 (ABS_Y)
      Value      0
      Min   -32768
      Max    32767
    Event code 2 (ABS_Z)
      Value      0
      Min        0
      Max      255
    Event code 3 (ABS_RX)
      Value      0
      Min   -32768
      Max    32767
    Event code 4 (ABS_RY)
      Value      0
      Min   -32768
      Max    32767
    Event code 5 (ABS_RZ)
      Value      0
      Min        0
      Max      255
    Event code 16 (ABS_HAT0X)
      Value      0
      Min       -1
      Max        1
    Event code 17 (ABS_HAT0Y)
      Value      0
      Min       -1
      Max        1
Properties:
Testing ... (interrupt to exit)
```

These are "normal" XBox controller settings. If there is a problem with button priority you either won't see all the `BTN_*` entries above, or you might see additional buttons, e.g.

```
$ sudo `which evtest` /dev/input/event17
[sudo] password for dsyer: 
Input driver version is 1.0.1
Input device ID: bus 0x0 vendor 0x0 product 0x0 version 0x0
Input device name: "Xbox Gamepad (userspace driver)"
Supported events:
  Event type 0 (EV_SYN)
  Event type 1 (EV_KEY)
    Event code 294 (BTN_BASE)
    Event code 295 (BTN_BASE2)
    Event code 296 (BTN_BASE3)
    Event code 297 (BTN_BASE4)
    Event code 304 (BTN_SOUTH)
    Event code 305 (BTN_EAST)
    Event code 307 (BTN_NORTH)
    Event code 308 (BTN_WEST)
...
```

Setting `xboxdrv.mimic-xpad = true` in the `.ini` file fixed this for me.

## Discovering Config Options

Not all the configuration options are well documented in the `xboxdrv` man page. You can get more insight by printing out a "blank" `.ini` file with

```
$ sudo `which xboxdrv` --evdev /dev/input/event16 --write-config config.ini
```