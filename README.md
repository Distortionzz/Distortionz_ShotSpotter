# Distortionz Shot Spotter

> Premium server-wide gunshot alert system for FiveM / Qbox.

[![FiveM](https://img.shields.io/badge/FiveM-cerulean-yellow)](https://fivem.net)
[![Qbox](https://img.shields.io/badge/Qbox-compatible-c8c828)](https://github.com/Qbox-project)
[![License: MIT](https://img.shields.io/badge/License-MIT-success)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.1.7-blue)](version.json)

A polished, production-grade gunshot detection and dispatch alert system. Detects every gunshot fired anywhere on the server in real time, classifies the weapon, clusters nearby shots into a single incident, and broadcasts a premium HUD popup + map blip + radius circle to every connected player.

Built ground-up by Distortionz for clean Qbox installs. No bloat, no junk dependencies — drop it in and it works.

---

## ✨ Features

- **100% gunshot detection** — Catches every shot fired by every player using `IsPedShooting`, polled at 250ms with a 1.5s per-shooter cooldown
- **Smart clustering** — Multiple shots within 75m + 5s of each other merge into a single incident with a live shot counter (no spam during shootouts)
- **Weapon classification** — 40+ weapons mapped to one of six classes (`pistol`, `smg`, `rifle`, `shotgun`, `sniper`, `heavy`), each with its own color-coded UI pill
- **Fuzzed locations** — Map blip is offset from the actual shooter using a uniform-disk distribution (default 100m), so players have to search the area instead of teleporting to the exact spot
- **Pulsing radius blip** — A breathing red circle on the map visualizes the search area, sized to encompass the fuzz radius
- **Premium dispatch HUD** — Animated card popup with weapon class, location, zone, live distance, shot count, and 30-second progress bar
- **Client-side location resolution** — Street and zone names resolved per-client (more reliable than server-side natives), with 80+ GTA V zones mapped to friendly names
- **Server-wide broadcast** — Every connected player receives the alert (no role gating, no police-only mode)
- **Optional Discord webhook** — Audit log every dispatched incident with weapon, shot count, location, and coords (off by default, opt-in via config)
- **Built-in admin diagnostics** — `/shotspot_test`, `/shotspot_force`, `/shotspot_status`, `/shotspot_ping` for testing and debugging

---

## 📥 Installation

### 1. Download & extract

Download the latest release zip from the [Releases](https://github.com/Distortionzz/Distortionz_ShotSpotter/releases) page (or clone this repo) and extract it into your server resources folder:

```
your-server/resources/[distortionz]/distortionz_shotspotter/
```

### 2. Add to `server.cfg`

```cfg
ensure ox_lib
ensure distortionz_shotspotter
```

That's it — no SQL, no setup steps, no additional dependencies beyond `ox_lib`.

### 3. Restart the server

Look for these startup banners in your server console:

```
[distortionz_shotspotter] server.lua TOP-OF-FILE LOAD MARKER
[distortionz_shotspotter:server] v1.1.7 loaded — fan-out mode: BROADCAST (everyone) — debug=true
```

And in your F8 client console after joining:

```
[distortionz_shotspotter:client] v1.1.7 loaded — detection poll=250ms cooldown=1500ms
```

If you see those, the script is live.

---

## ⚙️ Configuration

All tunables live in `config.lua`. Highlights:

### Detection
```lua
Config.Detection = {
    pollIntervalMs   = 250,    -- how often to check for gunshots
    clientCooldownMs = 1500,   -- per-shooter cooldown to prevent spam
    ignoredDamageTypes = {     -- weapon types that should NOT trigger
        [0] = true,            -- WEAPON_DAMAGE_TYPE_NONE (fists)
        [1] = true,            -- WEAPON_DAMAGE_TYPE_MELEE (knives, bats)
        [5] = true,            -- WEAPON_DAMAGE_TYPE_FIRE (molotov, flare)
    },
}
```

### Clustering
```lua
Config.Clustering = {
    radiusMeters    = 75.0,   -- shots within this distance cluster
    windowSeconds   = 5.0,    -- and within this time window
    maxShotsTracked = 99,     -- cap on displayed shot count
}
```

### Alert
```lua
Config.Alert = {
    fuzzRadiusMeters = 100.0,    -- blip offset from real shooter location
    durationSeconds  = 30,       -- how long the popup + blip stay
    blipSprite       = 110,      -- gun icon
    blipColor        = 1,        -- red

    radiusBlip = {
        enabled       = true,
        radiusMeters  = 120.0,
        color         = 1,
        alpha         = 80,
        pulseEnabled  = true,
        minAlpha      = 40,
        maxAlpha      = 120,
        pulseStepMs   = 80,
    },

    soundEnabled = true,
    soundSet     = 'GTAO_FM_Events_Soundset',
    soundName    = 'OOB_Start',
}
```

### Discord webhook (optional)
```lua
Config.Discord = {
    enabled  = false,
    url      = '',  -- paste your webhook URL here
    username = 'Distortionz Shot Spotter',
    color    = 16711680,  -- red embed
}
```

### Debug
```lua
Config.Debug = true   -- flip to false for production silence
```

Even with `Debug = false`, critical-path events (incident creation, broadcast counts) still log to console.

---

## 🛠️ Admin Commands

All admin commands require ace permission `command.shotspot_test`, `group.admin`, or `shotspotter.admin`.

| Command | Description |
|---|---|
| `/shotspot_ping` | No admin check — open to anyone. Returns "Server is alive" if `server.lua` is loaded. Useful for verifying the script is running. |
| `/shotspot_status` | Reports the number of connected players and active incidents in chat. |
| `/shotspot_test` | Fires a fake shot at your current position through the normal pipeline. Triggers detection → cluster → broadcast → popup for everyone. |
| `/shotspot_force` | Sends a fake alert directly to your client only. Pure UI test, bypasses all detection logic and broadcast. |

---

## 🎨 UI Customization

The popup card uses the Distortionz design language: matte black panels, `#c8c828` brand accents, dispatch-red urgency dot, sharp typography. All styling lives in `html/style.css` and is customizable.

The popup is positioned at `right: 24px` and vertically centered (`top: 50%`). To reposition, edit the `.dispatch-stack` rule in `html/style.css`.

---

## 🔧 How It Works

```
┌─────────────────┐
│ Player fires    │
└────────┬────────┘
         │ IsPedShooting() detects (250ms poll)
         ▼
┌─────────────────────┐
│ Client cooldown gate│  (1.5s per shooter)
└────────┬────────────┘
         │ TriggerServerEvent
         ▼
┌────────────────────────┐
│ Server: classify weapon│
│ Server: find cluster   │  (75m + 5s window)
│ Server: fuzz position  │  (uniform-disk 100m)
└────────┬───────────────┘
         │ TriggerClientEvent(-1, ...)  // broadcast to everyone
         ▼
┌──────────────────────────────────┐
│ Every client renders:            │
│   • Popup card (right side)      │
│   • Map blip (gun icon)          │
│   • Radius circle (pulsing red)  │
│   • Audio chirp                  │
│   • Chat notify                  │
│   Plus: client-side street/zone  │
│         resolution               │
└──────────────────────────────────┘
```

---

## 🩺 Troubleshooting

**No popup, no banner in console?**
- Make sure you fully restarted the resource (`ensure distortionz_shotspotter`)
- Verify `ox_lib` is started before `distortionz_shotspotter`
- Check the server console for red error lines mentioning the script

**Popup is offscreen or overlapping with other UI?**
- Edit `html/style.css` → `.dispatch-stack` and adjust `top` / `right` values

**`/shotspot_force` shows the popup but actual gunshots don't?**
- Detection is broken. Enable `Config.Debug = true` and check F8 console for `[shotspotter:client] reporting shot...` messages

**Shots reporting but no popup appears for anyone?**
- Server-side broadcast issue. Check server console for `[shotspotter] Broadcasting incident #N to ALL connected players`

---

## 📋 Changelog

See [version.json](version.json) for the full release history.

**Latest: v1.1.7** — Dispatch card moved to right-side, vertically centered to clear chat-notify zone.

---

## 🛡️ Compatibility

- **FiveM** — `cerulean` fxmanifest, Lua 5.4 enabled
- **Framework** — Built and tested on **Qbox**, but framework-agnostic (no `qbx_core` dependency since v1.1.0)
- **Required** — `ox_lib`
- **Optional** — `distortionz_notify` (falls back to `ox_lib` notify)

---

## 📜 License

[MIT](LICENSE) — fully free for personal and commercial use, modifications welcome, attribution appreciated.

---

## 👤 Author

Built by **Distortionz** for **DistortionzRP**.

Find more Distortionz resources at [github.com/Distortionzz](https://github.com/Distortionzz).

---

## ❤️ Credits

- [Qbox Project](https://github.com/Qbox-project) — the framework this was built around
- [overextended](https://github.com/overextended) — `ox_lib`, the toolkit we all stand on
