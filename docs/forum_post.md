# ReaperHaptic - Forum Post

## Thread Title
```
[SCRIPT] ReaperHaptic - Haptic feedback for Logitech MX Master 4 mouse
```

---

## Post Content (BBCode for Cockos Forum)

```bbcode
[B][SIZE=4]ReaperHaptic[/SIZE][/B]
[I]Feel your edits - haptic feedback for Logitech MX Master 4 mouse[/I]

[IMG]https://raw.githubusercontent.com/b451c/ReaperHaptic/main/docs/images/ReaperHaptic.png[/IMG]

[B]What is it?[/B]
ReaperHaptic triggers haptic feedback on your Logitech MX Master 4 mouse based on REAPER events. Get tactile "clicks" when items snap together, vibrations when audio clips, subtle feedback when recording starts, and more.

[B]Features[/B]
[LIST]
[*][B]Item Snap Detection[/B] - haptic "click" when items touch other items, markers, time selection, or playhead
[*][B]Clipping Alert[/B] - strong vibration when master track exceeds 0dB
[*][B]Transport Feedback[/B] - subtle haptics for record/play start and stop
[*][B]Render Complete[/B] - notification when rendering finishes
[*][B]Marker Crossing[/B] - light feedback when playhead crosses markers during playback
[*][B]Configuration GUI[/B] - toggle individual events, LED indicator, dockable window
[/LIST]

[B]Requirements[/B]
[LIST]
[*]macOS 14+ (Sonoma or later)
[*]Logitech MX Master 4 mouse
[*]Logi Options+ installed and running
[*]REAPER 7.0+
[*][URL="https://github.com/mavriq-dev/mavriq-lua-sockets/releases"]mavriq-lua-sockets[/URL] for REAPER
[/LIST]

[B]How it works[/B]
[CODE]
REAPER (Lua Script) --OSC/UDP--> ReaperHaptic (Logi Options+ Plugin) --Haptic API--> MX Master 4
[/CODE]

The Lua script monitors REAPER events and sends OSC messages to a Logi Options+ plugin, which triggers the appropriate haptic waveforms on your mouse.

[B]Installation[/B]
1. Download [B]ReaperHaptic.lplug4[/B] from GitHub releases - double-click to install
2. Download [B]reaper_haptic_monitor.lua[/B] to your REAPER Scripts folder
3. Install [URL="https://github.com/mavriq-dev/mavriq-lua-sockets/releases"]mavriq-lua-sockets[/URL]
4. In REAPER: Actions > Load ReaScript > select the script
5. (Optional) Add to startup actions for automatic loading

[B]Download[/B]
[URL="https://github.com/b451c/ReaperHaptic/releases"]https://github.com/b451c/ReaperHaptic/releases[/URL]

[B]Source Code & Documentation[/B]
[URL="https://github.com/b451c/ReaperHaptic"]https://github.com/b451c/ReaperHaptic[/URL]

[HR][/HR]
[SIZE=2]Feedback and bug reports welcome! This is my first REAPER script and Logi Options+ plugin.[/SIZE]
```

---

## Notes

- Post to: https://forum.cockos.com/forumdisplay.php?f=3 (ReaScript, JSFX, REAPER Plug-in Extensions)
- BBCode format is used on Cockos forum
- Image hosted on GitHub raw URL
