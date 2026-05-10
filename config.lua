Config = Config or {}

-- ─── Script meta ────────────────────────────────────────────────────
Config.Script = {
    name    = 'Distortionz Shot Spotter',
    version = '1.1.8',
}

Config.VersionCheck = {
    enabled = true,
    url     = 'https://raw.githubusercontent.com/Distortionzz/Distortionz_ShotSpotter/main/version.json',
}
Config.CurrentVersion = '1.1.8'

-- ─── Detection ──────────────────────────────────────────────────────
-- Polls IsPedShooting on the local player at this interval. 250ms is
-- the sweet spot — fast enough to catch every shot, light enough to
-- not show on a profiler.
Config.Detection = {
    pollIntervalMs       = 250,
    -- After a player fires, suppress further client-side reports for this
    -- many ms (prevents 30 reports during a magdump). Server still gets
    -- ONE event per detection burst.
    clientCooldownMs     = 1500,
    -- A weapon class returning one of these will be ignored entirely
    -- (taser, melee, etc — we only care about real guns). Group hashes:
    -- https://docs.fivem.net/natives/?_0xC54D8B (GetWeaponDamageType)
    ignoredDamageTypes   = {
        [0] = true,   -- WEAPON_DAMAGE_TYPE_NONE (fists)
        [1] = true,   -- WEAPON_DAMAGE_TYPE_MELEE (knives, bats)
        [5] = true,   -- WEAPON_DAMAGE_TYPE_FIRE (molotov, flare gun)
    },
}

-- ─── v1.1.0 — Public alert mode ─────────────────────────────────────
-- This script is now a server-wide gunshot alert system. Every shot
-- detected gets broadcast to EVERY connected player. Cops have no
-- special status; they get the same popup as everyone else, and they
-- are NOT bypassed when they fire (their shots alert everyone too).
--
-- If you want the older "police-only dispatch" behavior back, see
-- v1.0.x in the GitHub release history.

-- ─── Server-side dedup / clustering ─────────────────────────────────
-- If two shot events from different shooters land within this radius
-- AND within this time window, they merge into a single dispatch (the
-- shot count increments, the popup updates, no second blip). Lets a
-- shootout register as ONE incident instead of 14 alerts.
Config.Clustering = {
    radiusMeters    = 75.0,   -- shots within this distance cluster
    windowSeconds   = 5.0,    -- and within this time window
    maxShotsTracked = 99,     -- cap displayed shot count
}

-- ─── Alert dispatch ─────────────────────────────────────────────────
Config.Alert = {
    -- Fuzz the blip position so cops have to search the block, not
    -- teleport to the exact shooter. 0 = exact, 100 = realistic spread.
    fuzzRadiusMeters     = 100.0,
    -- How long the popup card + blip persist on cop clients.
    durationSeconds      = 30,
    -- Point blip (the gun icon)
    blipSprite           = 110,        -- pistol/gun blip
    blipColor            = 1,          -- red
    blipScale            = 1.1,
    blipFlash            = true,       -- pulsing
    blipFlashTimerMs     = 30000,      -- stops flashing when popup is dismissed
    blipShortRange       = false,      -- show on full map, not just radar

    -- v1.1.3 — Pulsing radius circle on the map (search area visualization)
    radiusBlip = {
        enabled       = true,
        radiusMeters  = 120.0,         -- visible search area; ~ fuzzRadius + buffer
        color         = 1,             -- red (matches point blip)
        alpha         = 80,            -- 0-255 — lower = more transparent
        -- Pulse animation: alpha bounces between minAlpha and maxAlpha
        pulseEnabled  = true,
        minAlpha      = 40,
        maxAlpha      = 120,
        pulseStepMs   = 80,            -- speed of the pulse animation
    },

    -- Audio chirp when alert arrives
    soundEnabled         = true,
    soundSet             = 'GTAO_FM_Events_Soundset',
    soundName            = 'OOB_Start',  -- subtle radio chirp
}

-- ─── Weapon classification ──────────────────────────────────────────
-- Weapon hashes are mapped to display labels + class colors on the popup.
-- Anything not in this map falls back to 'Firearm' / generic.
-- Hashes from https://docs.fivem.net/docs/game-references/weapon-models/
Config.WeaponLabels = {
    -- Pistols
    [`weapon_pistol`]            = { label = 'Pistol',           class = 'pistol' },
    [`weapon_combatpistol`]      = { label = 'Combat Pistol',    class = 'pistol' },
    [`weapon_appistol`]          = { label = 'AP Pistol',        class = 'pistol' },
    [`weapon_pistol50`]          = { label = '.50 Pistol',       class = 'pistol' },
    [`weapon_snspistol`]         = { label = 'SNS Pistol',       class = 'pistol' },
    [`weapon_heavypistol`]       = { label = 'Heavy Pistol',     class = 'pistol' },
    [`weapon_vintagepistol`]     = { label = 'Vintage Pistol',   class = 'pistol' },
    [`weapon_marksmanpistol`]    = { label = 'Marksman Pistol',  class = 'pistol' },
    [`weapon_revolver`]          = { label = 'Revolver',         class = 'pistol' },
    [`weapon_doubleaction`]      = { label = 'Double Action',    class = 'pistol' },
    -- SMGs
    [`weapon_microsmg`]          = { label = 'Micro SMG',        class = 'smg'    },
    [`weapon_smg`]               = { label = 'SMG',              class = 'smg'    },
    [`weapon_assaultsmg`]        = { label = 'Assault SMG',      class = 'smg'    },
    [`weapon_combatpdw`]         = { label = 'Combat PDW',       class = 'smg'    },
    [`weapon_machinepistol`]     = { label = 'Machine Pistol',   class = 'smg'    },
    [`weapon_minismg`]           = { label = 'Mini SMG',         class = 'smg'    },
    -- Rifles
    [`weapon_assaultrifle`]      = { label = 'Assault Rifle',    class = 'rifle'  },
    [`weapon_carbinerifle`]      = { label = 'Carbine Rifle',    class = 'rifle'  },
    [`weapon_advancedrifle`]     = { label = 'Advanced Rifle',   class = 'rifle'  },
    [`weapon_specialcarbine`]    = { label = 'Special Carbine',  class = 'rifle'  },
    [`weapon_bullpuprifle`]      = { label = 'Bullpup Rifle',    class = 'rifle'  },
    [`weapon_compactrifle`]      = { label = 'Compact Rifle',    class = 'rifle'  },
    [`weapon_militaryrifle`]     = { label = 'Military Rifle',   class = 'rifle'  },
    -- Shotguns
    [`weapon_pumpshotgun`]       = { label = 'Pump Shotgun',     class = 'shotgun'},
    [`weapon_sawnoffshotgun`]    = { label = 'Sawed-Off',        class = 'shotgun'},
    [`weapon_assaultshotgun`]    = { label = 'Assault Shotgun',  class = 'shotgun'},
    [`weapon_bullpupshotgun`]    = { label = 'Bullpup Shotgun',  class = 'shotgun'},
    [`weapon_heavyshotgun`]      = { label = 'Heavy Shotgun',    class = 'shotgun'},
    [`weapon_dbshotgun`]         = { label = 'Double Barrel',    class = 'shotgun'},
    -- Snipers
    [`weapon_sniperrifle`]       = { label = 'Sniper Rifle',     class = 'sniper' },
    [`weapon_heavysniper`]       = { label = 'Heavy Sniper',     class = 'sniper' },
    [`weapon_marksmanrifle`]     = { label = 'Marksman Rifle',   class = 'sniper' },
    -- Heavy
    [`weapon_mg`]                = { label = 'MG',               class = 'heavy'  },
    [`weapon_combatmg`]          = { label = 'Combat MG',        class = 'heavy'  },
    [`weapon_gusenberg`]         = { label = 'Gusenberg',        class = 'heavy'  },
    [`weapon_minigun`]           = { label = 'Minigun',          class = 'heavy'  },
    [`weapon_rpg`]               = { label = 'RPG',              class = 'heavy'  },
    [`weapon_grenadelauncher`]   = { label = 'Grenade Launcher', class = 'heavy'  },
}

-- ─── Notifications ──────────────────────────────────────────────────
Config.Notify = {
    title    = 'Dispatch',
    resource = 'distortionz_notify',  -- preferred; falls back to ox_lib if not started
}

-- ─── Discord webhook (optional) ─────────────────────────────────────
-- Off by default. When enabled, every dispatched alert gets logged.
-- Use a discord webhook URL: https://discord.com/api/webhooks/...
Config.Discord = {
    enabled    = false,
    url        = '',
    username   = 'Distortionz Shot Spotter',
    avatar     = 'https://i.imgur.com/4M34hi2.png',
    color      = 16711680,   -- red
}

-- ─── Debug ──────────────────────────────────────────────────────────
-- v1.0.1 default: ON. Critical-path dispatch logs run regardless.
-- Flip to false for production once you've confirmed it works.
Config.Debug = true
