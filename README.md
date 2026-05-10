# Distortionz Shot Spotter

> Premium gunshot detection + dispatch HUD for Qbox/FiveM — smart clustering, fuzzed locations, weapon classification, optional Discord audit logging.

![FiveM](https://img.shields.io/badge/FiveM-cerulean-yellow?style=flat-square&labelColor=181b20)
![Qbox](https://img.shields.io/badge/Qbox-required-red?style=flat-square&labelColor=dfb317)
![License](https://img.shields.io/badge/License-MIT-brightgreen?style=flat-square)
![Version](https://img.shields.io/github/v/release/Distortionzz/Distortionz_ShotSpotter?style=flat-square&color=d4aa62&label=version)

---

## Overview

Real-time gunshot detection that auto-dispatches police units. Players firing weapons trigger location-fuzzed alerts to on-duty cops with weapon classification (handgun / SMG / rifle / shotgun / heavy), smart clustering so a single firefight doesn't spam 30 alerts, and optional Discord audit logging.

## Features

- **Real-time detection** — fires on every player gunshot
- **Weapon classification** with category tagging
- **Location fuzzing** — alert points dispersed slightly so the shooter isn't pinpointed
- **Smart clustering** — multiple shots in a window collapse into one dispatch
- **Dispatch HUD card** — slide-in from the right edge, vertically centred for cops on duty
- **Discord webhook audit** (optional) — every detection logged
- **Configurable thresholds** — fire rate, weapon ignore list, time window
- **Cop-only visibility** — alerts only fire for players with `police` job

## Dependencies

| Resource | Required | Purpose |
|---|---|---|
| `qbx_core` | yes | Player job lookup |
| `ox_lib` | yes | Callbacks, notify fallback |
| `distortionz_notify` | optional | Branded notifications |

## Installation

```cfg
ensure distortionz_shotspotter
```

## Configuration

See [`config.lua`](config.lua) for ignored weapons, cluster window, location fuzz radius, alert duration, Discord webhook, police job names.

## Credits

- **Author:** Distortionz
- **Framework:** [Qbox Project](https://github.com/Qbox-project)

## License

MIT — see [LICENSE](LICENSE).
