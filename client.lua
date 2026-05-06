-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Distortionz Shot Spotter — client (v1.1.0 public alert mode)     ║
-- ║                                                                  ║
-- ║ Detects local-player gunshots via IsPedShooting and reports to   ║
-- ║ server. Receives dispatch alerts (every connected player gets    ║
-- ║ them — no police gating) and renders the popup card + map blip   ║
-- ║ + sound.                                                         ║
-- ╚══════════════════════════════════════════════════════════════════╝

local lastShotReportAt = 0   -- ms timestamp of last server report (cooldown)
local activeAlerts     = {}  -- alertId -> { blip, expiresAt }

-- ─── Helpers ────────────────────────────────────────────────────────
local function Debug(...)
    if Config.Debug then
        print(('[shotspotter:client] %s'):format(table.concat({...}, ' ')))
    end
end

local function Notify(message, notifyType, duration, title)
    if not message then return end
    notifyType = notifyType or 'primary'
    duration   = tonumber(duration) or 5000
    title      = title or Config.Notify.title

    if notifyType == 'inform' then notifyType = 'info' end

    if GetResourceState(Config.Notify.resource) == 'started' then
        exports[Config.Notify.resource]:Notify(message, notifyType, duration, title)
        return
    end

    lib.notify({
        title       = title,
        description = message,
        type        = notifyType,
        duration    = duration,
    })
end

-- ─── Startup banner (always prints, so we know the resource loaded) ─
CreateThread(function()
    Wait(500)
    print(('^5[distortionz_shotspotter:client]^7 v%s loaded — detection poll=%dms cooldown=%dms')
        :format(Config.Script.version or '?', Config.Detection.pollIntervalMs, Config.Detection.clientCooldownMs))
end)

-- ─── Detection loop ─────────────────────────────────────────────────
-- v1.1.0: NO police bypass. Every shot from every player reports to
-- the server, which fans out the alert to everyone connected.
-- v1.1.1: Refactored from goto-based to nested-if to remove any
-- chance of label-scoping issues across Lua versions.
CreateThread(function()
    while true do
        Wait(Config.Detection.pollIntervalMs)

        local ped = PlayerPedId()
        if DoesEntityExist(ped) and IsPedShooting(ped) then
            local now = GetGameTimer()
            if (now - lastShotReportAt) >= Config.Detection.clientCooldownMs then

                local _, weaponHash = GetCurrentPedWeapon(ped, true)
                if weaponHash and weaponHash ~= 0 then
                    local damageType = GetWeaponDamageType(weaponHash)
                    if not Config.Detection.ignoredDamageTypes[damageType] then
                        local coords = GetEntityCoords(ped)
                        lastShotReportAt = now

                        Debug('reporting shot weapon=', weaponHash, 'damageType=', damageType, 'at', coords.x, coords.y, coords.z)
                        TriggerServerEvent('distortionz_shotspotter:server:reportShot', {
                            weaponHash = weaponHash,
                            x          = coords.x,
                            y          = coords.y,
                            z          = coords.z,
                        })
                    else
                        Debug('skip — ignored damage type', damageType, 'weapon', weaponHash)
                    end
                else
                    Debug('skip — no weapon hash')
                end
            end
        end
    end
end)

-- ─── v1.1.2 — Client-side street/zone resolver ──────────────────────
-- Server-side GetStreetNameAtCoord / GetNameOfZone are unreliable across
-- FXServer versions. These natives are 100% available client-side, so
-- we resolve the fuzzed coord into a friendly name on each receiving
-- client right before rendering. Falls back to "Unknown area" if the
-- natives fail.
local zoneDisplayMap = {
    AIRP    = 'LS Int. Airport',     ALAMO   = 'Alamo Sea',          ALTA    = 'Alta',
    ARMYB   = 'Zancudo Base',         BANHAMC = 'Banham Canyon',      BANNING = 'Banning',
    BEACH   = 'Vespucci Beach',       BHAMCA  = 'Banham Canyon',      BRADP   = 'Braddock Pass',
    BRADT   = 'Braddock Tunnel',      BURTON  = 'Burton',             CALAFB  = 'Calafia Bridge',
    CANNY   = 'Raton Canyon',         CCREAK  = 'Cassidy Creek',      CHAMH   = 'Chamberlain Hills',
    CHIL    = 'Vinewood Hills',       CHU     = 'Chumash',            CMSW    = 'Chiliad Wilderness',
    CYPRE   = 'Cypress Flats',        DAVIS   = 'Davis',              DELBE   = 'Del Perro Beach',
    DELPE   = 'Del Perro',            DELSOL  = 'La Puerta',          DESRT   = 'Grand Senora Desert',
    DOWNT   = 'Downtown',             DTVINE  = 'Downtown Vinewood',  EAST_V  = 'East Vinewood',
    EBURO   = 'El Burro Heights',     ELGORL  = 'El Gordo Lighthouse', ELYSIAN = 'Elysian Island',
    GALFISH = 'Galilee',              GALLI   = 'Galileo Park',       GOLF    = 'GWC Golf Course',
    GRAPES  = 'Grapeseed',            GREATC  = 'Great Chaparral',    HARMO   = 'Harmony',
    HAWICK  = 'Hawick',               HORS    = 'Vinewood Racetrack', HUMLAB  = 'Humane Labs',
    JAIL    = 'Bolingbroke',          KOREAT  = 'Little Seoul',       LACT    = 'Land Act Reservoir',
    LAGO    = 'Lago Zancudo',         LDAM    = 'Land Act Dam',       LEGSQU  = 'Legion Square',
    LMESA   = 'La Mesa',              LOSPUER = 'La Puerta',          MIRR    = 'Mirror Park',
    MORN    = 'Morningwood',          MOVIE   = 'Richards Majestic',  MTCHIL  = 'Mount Chiliad',
    MTGORDO = 'Mount Gordo',          MTJOSE  = 'Mount Josiah',       MURRI   = 'Murrieta Heights',
    NCHU    = 'North Chumash',        NOOSE   = 'NOOSE HQ',           OCEANA  = 'Pacific Ocean',
    PALCOV  = 'Paleto Cove',          PALETO  = 'Paleto Bay',         PALFOR  = 'Paleto Forest',
    PALHIGH = 'Palomino Highlands',   PALMPOW = 'Palmer-Taylor',      PBLUFF  = 'Pacific Bluffs',
    PBOX    = 'Pillbox Hill',         PROCOB  = 'Procopio Beach',     PROL    = 'North Yankton',
    RANCHO  = 'Rancho',               RGLEN   = 'Richman Glen',       RICHM   = 'Richman',
    ROCKF   = 'Rockford Hills',       RTRAK   = 'Redwood Lights',     SANAND  = 'San Andreas',
    SANCHIA = 'San Chianski Mtn',     SANDY   = 'Sandy Shores',       SKID    = 'Mission Row',
    SLAB    = 'Stab City',            STAD    = 'Maze Bank Arena',    STRAW   = 'Strawberry',
    TATAMO  = 'Tataviam Mountains',   TERMINA = 'Terminal',           TEXTI   = 'Textile City',
    TONGVAH = 'Tongva Hills',         TONGVAV = 'Tongva Valley',      VCANA   = 'Vespucci Canals',
    VESP    = 'Vespucci',             VINE    = 'Vinewood',           WINDF   = 'Ron Alternates Wind Farm',
    WVINE   = 'West Vinewood',        ZANCUDO = 'Zancudo River',      ZP_ORT  = 'Port of South LS',
    ZQ_UAR  = 'Davis Quartz',
}

local function resolveLocationLocal(x, y, z)
    local street = 'Unknown area'
    local zone   = ''

    -- Street: pick the closer of the two returned street hashes
    local s1, s2 = GetStreetNameAtCoord(x + 0.0, y + 0.0, z + 0.0)
    if s1 and s1 ~= 0 then
        local sn = GetStreetNameFromHashKey(s1)
        if sn and sn ~= '' then street = sn end
    end

    -- Zone: returns short code like 'PBOX', 'VINE'. Map to friendly name.
    local zoneCode = GetNameOfZone(x + 0.0, y + 0.0, z + 0.0)
    if zoneCode and zoneCode ~= '' then
        zone = zoneDisplayMap[zoneCode] or zoneCode
    end

    return street, zone
end

-- ─── Alert rendering (shared by main + force events) ────────────────
local function handleAlert(alert)
    -- Existing alert with same id → update shot count + reset expiry
    local existing = activeAlerts[alert.id]
    if existing then
        existing.expiresAt = GetGameTimer() + (Config.Alert.durationSeconds * 1000)
        SendNUIMessage({
            action      = 'update',
            id          = alert.id,
            shotCount   = alert.shotCount,
            weaponLabel = alert.weaponLabel,
            weaponClass = alert.weaponClass,
        })
        return
    end

    -- New alert — create point blip
    local blip = AddBlipForCoord(alert.fuzzedX, alert.fuzzedY, alert.fuzzedZ)
    SetBlipSprite(blip, Config.Alert.blipSprite)
    SetBlipColour(blip, Config.Alert.blipColor)
    SetBlipScale(blip, Config.Alert.blipScale)
    SetBlipAsShortRange(blip, Config.Alert.blipShortRange)
    SetBlipFlashes(blip, Config.Alert.blipFlash)
    SetBlipFlashTimer(blip, Config.Alert.blipFlashTimerMs)

    -- v1.1.3 — Pulsing radius circle ("search area" visualization)
    local radiusBlip = nil
    local radCfg = Config.Alert.radiusBlip
    if radCfg and radCfg.enabled then
        radiusBlip = AddBlipForRadius(alert.fuzzedX, alert.fuzzedY, alert.fuzzedZ, radCfg.radiusMeters or 120.0)
        SetBlipColour(radiusBlip, radCfg.color or 1)
        SetBlipAlpha(radiusBlip, radCfg.alpha or 80)
        SetBlipAsShortRange(radiusBlip, false)
    end

    -- v1.1.2 — Resolve street/zone client-side (more reliable than server)
    local resolvedStreet, resolvedZone = resolveLocationLocal(alert.fuzzedX, alert.fuzzedY, alert.fuzzedZ)
    -- Prefer client-resolved values; fall back to whatever the server sent
    local streetName = (resolvedStreet ~= 'Unknown area' and resolvedStreet) or alert.streetName or 'Unknown area'
    local zoneName   = (resolvedZone   ~= '' and resolvedZone)               or alert.zoneName   or ''

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('Shots Fired — %s'):format(streetName))
    EndTextCommandSetBlipName(blip)

    activeAlerts[alert.id] = {
        blip       = blip,
        radiusBlip = radiusBlip,    -- v1.1.3
        expiresAt  = GetGameTimer() + (Config.Alert.durationSeconds * 1000),
    }

    -- Audio chirp
    if Config.Alert.soundEnabled then
        PlaySoundFrontend(-1, Config.Alert.soundName, Config.Alert.soundSet, true)
    end

    -- Chat notify
    Notify(('Shots fired near %s — %s'):format(streetName, alert.weaponLabel or 'firearm'), 'error', 6000, Config.Notify.title)

    -- Fire the popup
    SendNUIMessage({
        action       = 'show',
        id           = alert.id,
        weaponLabel  = alert.weaponLabel,
        weaponClass  = alert.weaponClass,
        shotCount    = alert.shotCount,
        streetName   = streetName,
        zoneName     = zoneName,
        durationSec  = Config.Alert.durationSeconds,
        fuzzedX      = alert.fuzzedX,
        fuzzedY      = alert.fuzzedY,
        fuzzedZ      = alert.fuzzedZ,
    })
end

-- ─── Receive dispatch alerts (everyone) ─────────────────────────────
RegisterNetEvent('distortionz_shotspotter:client:dispatchAlert', function(alert)
    if not alert or not alert.id then return end
    Debug('dispatch alert received', alert.id)
    handleAlert(alert)
end)

-- Backwards-compat — same handler, kept so /shotspot_force still works
RegisterNetEvent('distortionz_shotspotter:client:dispatchAlertForce', function(alert)
    if not alert or not alert.id then return end
    Debug('force dispatch alert received', alert.id)
    handleAlert(alert)
end)

-- ─── Distance/timer tick — updates popup distance + auto-clears ─────
CreateThread(function()
    while true do
        Wait(1000)

        local ped = PlayerPedId()
        local pCoords = GetEntityCoords(ped)
        local now = GetGameTimer()

        for id, alert in pairs(activeAlerts) do
            if now >= alert.expiresAt then
                -- Expire — remove BOTH blips (v1.1.3)
                if alert.blip and DoesBlipExist(alert.blip) then
                    RemoveBlip(alert.blip)
                end
                if alert.radiusBlip and DoesBlipExist(alert.radiusBlip) then
                    RemoveBlip(alert.radiusBlip)
                end
                activeAlerts[id] = nil
                SendNUIMessage({ action = 'hide', id = id })
            else
                -- Push distance + remaining time so popup ticks live
                local blipCoord = GetBlipCoords(alert.blip)
                local dist = #(pCoords - blipCoord)
                local secLeft = math.max(0, math.floor((alert.expiresAt - now) / 1000))
                SendNUIMessage({
                    action     = 'tick',
                    id         = id,
                    distanceM  = math.floor(dist),
                    secondsLeft = secLeft,
                })
            end
        end
    end
end)

-- ─── v1.1.3 — Radius blip pulse animation ────────────────────────────
-- Bounces the radius blip's alpha between min/max for a "breathing"
-- effect. Cheaper than dynamically resizing the blip, and works
-- correctly across all map zoom levels.
CreateThread(function()
    local cfg = Config.Alert.radiusBlip
    if not cfg or not cfg.enabled or not cfg.pulseEnabled then return end

    local minA = cfg.minAlpha or 40
    local maxA = cfg.maxAlpha or 120
    local stepMs = cfg.pulseStepMs or 80
    local alpha = minA
    local direction = 1   -- +1 = increasing, -1 = decreasing
    local stride = 8      -- alpha units per tick

    while true do
        Wait(stepMs)

        alpha = alpha + (stride * direction)
        if alpha >= maxA then
            alpha = maxA
            direction = -1
        elseif alpha <= minA then
            alpha = minA
            direction = 1
        end

        for _, alert in pairs(activeAlerts) do
            if alert.radiusBlip and DoesBlipExist(alert.radiusBlip) then
                SetBlipAlpha(alert.radiusBlip, alpha)
            end
        end
    end
end)

-- ─── Resource cleanup ───────────────────────────────────────────────
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for id, alert in pairs(activeAlerts) do
        if alert.blip and DoesBlipExist(alert.blip) then
            RemoveBlip(alert.blip)
        end
        if alert.radiusBlip and DoesBlipExist(alert.radiusBlip) then
            RemoveBlip(alert.radiusBlip)
        end
    end
    activeAlerts = {}
    SendNUIMessage({ action = 'hideAll' })
end)
