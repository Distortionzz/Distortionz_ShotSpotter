-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Distortionz Shot Spotter — server (v1.1.5 diag build)            ║
-- ║ Receives reportShot events, validates, applies clustering, fans  ║
-- ║ dispatch alerts to EVERY connected player. Optionally logs to    ║
-- ║ Discord webhook.                                                 ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- v1.1.5 — Top-of-file print runs SYNCHRONOUSLY at script load.
-- If THIS doesn't appear in the server console, server.lua isn't being
-- loaded at all (despite manifest listing it), which would point to a
-- file-encoding issue or a manifest parse error.
print('===========================================')
print('[distortionz_shotspotter] server.lua TOP-OF-FILE LOAD MARKER')
print('[distortionz_shotspotter] If you see this, server.lua is being parsed')
print('===========================================')

local activeIncidents = {}  -- incidentId -> { coords, weaponHash, weaponLabel, weaponClass, shotCount, lastShotAt, ... }
local nextIncidentId  = 1

-- ─── Helpers ────────────────────────────────────────────────────────
local function Debug(...)
    if Config.Debug then
        print(('[shotspotter:server] %s'):format(table.concat({...}, ' ')))
    end
end

local function classifyWeapon(weaponHash)
    local entry = Config.WeaponLabels[weaponHash]
    if entry then return entry.label, entry.class end
    return 'Firearm', 'unknown'
end

-- ─── Position fuzzing ───────────────────────────────────────────────
-- Random offset within fuzzRadiusMeters using polar coordinates so the
-- distribution is uniform over the disk (NOT square, NOT corner-biased).
local function fuzzPosition(x, y, z)
    local r = Config.Alert.fuzzRadiusMeters or 0.0
    if r <= 0.0 then return x, y, z end
    local angle = math.random() * 2.0 * math.pi
    local dist  = math.sqrt(math.random()) * r   -- sqrt for uniform disk
    return x + math.cos(angle) * dist,
           y + math.sin(angle) * dist,
           z
end

-- ─── Street + zone name lookup (server-side natives) ───────────────
local function resolveLocation(x, y, z)
    local streetName, zoneName = 'Unknown area', ''
    if GetStreetNameAtCoord then
        local s1, _ = GetStreetNameAtCoord(x, y, z)
        if GetStreetNameFromHashKey then
            local sn = GetStreetNameFromHashKey(s1)
            if sn and sn ~= '' then streetName = sn end
        end
    end
    if GetNameOfZone then
        local zn = GetNameOfZone(x, y, z)
        if zn then zoneName = zn end
    end
    return streetName, zoneName
end

-- ─── Clustering: find existing incident within radius + time window ─
local function findCluster(x, y, z)
    local now = os.time()
    local rSq = (Config.Clustering.radiusMeters or 75.0) ^ 2
    local windowSec = Config.Clustering.windowSeconds or 5.0
    for id, inc in pairs(activeIncidents) do
        if (now - inc.lastShotAt) <= windowSec then
            local dx = inc.coords.x - x
            local dy = inc.coords.y - y
            local dz = inc.coords.z - z
            if (dx*dx + dy*dy + dz*dz) <= rSq then
                return id, inc
            end
        end
    end
    return nil, nil
end

-- ─── Discord webhook ────────────────────────────────────────────────
local function discordLog(incident, fuzzedX, fuzzedY, fuzzedZ)
    if not Config.Discord.enabled then return end
    if not Config.Discord.url or Config.Discord.url == '' then return end

    local embed = {
        {
            ['color']     = Config.Discord.color or 16711680,
            ['title']     = '🔫 Shots Fired',
            ['fields']    = {
                { ['name'] = 'Weapon',    ['value'] = incident.weaponLabel or 'Unknown', ['inline'] = true },
                { ['name'] = 'Shots',     ['value'] = tostring(incident.shotCount),     ['inline'] = true },
                { ['name'] = 'Street',    ['value'] = incident.streetName or 'Unknown', ['inline'] = false },
                { ['name'] = 'Zone',      ['value'] = incident.zoneName   or '—',       ['inline'] = true },
                { ['name'] = 'Real coords', ['value'] = ('%.1f, %.1f, %.1f'):format(incident.coords.x, incident.coords.y, incident.coords.z), ['inline'] = false },
                { ['name'] = 'Fuzzed coords', ['value'] = ('%.1f, %.1f, %.1f'):format(fuzzedX, fuzzedY, fuzzedZ), ['inline'] = false },
            },
            ['footer']    = { ['text'] = ('Incident #%d · %s'):format(incident.id, os.date('!%Y-%m-%d %H:%M:%SZ')) },
        }
    }

    PerformHttpRequest(Config.Discord.url, function(_, _, _) end, 'POST',
        json.encode({
            username   = Config.Discord.username or 'Shot Spotter',
            avatar_url = Config.Discord.avatar,
            embeds     = embed,
        }),
        { ['Content-Type'] = 'application/json' }
    )
end

-- ─── Fan-out: send alert to EVERY connected player ──────────────────
-- v1.1.0: TriggerClientEvent with src=-1 broadcasts to all clients.
-- Cheaper than iterating GetPlayers() and triggering one-by-one.
local function broadcastAlert(payload)
    TriggerClientEvent('distortionz_shotspotter:client:dispatchAlert', -1, payload)
end

-- ─── Startup banner (always prints, so we know the resource loaded) ─
CreateThread(function()
    Wait(500)
    print(('^5[distortionz_shotspotter:server]^7 v%s loaded — fan-out mode: BROADCAST (everyone) — debug=%s')
        :format(Config.Script.version or '?', tostring(Config.Debug)))
end)

-- ─── Main: report a shot ────────────────────────────────────────────
RegisterNetEvent('distortionz_shotspotter:server:reportShot', function(payload)
    local src = source
    if type(payload) ~= 'table' then
        print(('[shotspotter] ⚠ reportShot from src=%s rejected — payload is not a table'):format(tostring(src)))
        return
    end
    local x, y, z = tonumber(payload.x), tonumber(payload.y), tonumber(payload.z)
    local weaponHash = tonumber(payload.weaponHash)
    if not x or not y or not z or not weaponHash then
        print(('[shotspotter] ⚠ reportShot from src=%s rejected — missing fields. weapon=%s xyz=%s,%s,%s'):format(
            tostring(src), tostring(weaponHash), tostring(x), tostring(y), tostring(z)))
        return
    end

    print(('[shotspotter] reportShot received from src=%s weapon=%d at (%.1f, %.1f, %.1f)'):format(src, weaponHash, x, y, z))

    -- v1.1.0 — NO police bypass. Every shot is a public alert.

    local label, class = classifyWeapon(weaponHash)
    local now = os.time()

    -- Cluster check
    local incidentId, incident = findCluster(x, y, z)
    if incident then
        incident.shotCount  = math.min(incident.shotCount + 1, Config.Clustering.maxShotsTracked or 99)
        incident.lastShotAt = now
        incident.weaponHash  = weaponHash   -- update to latest weapon used
        incident.weaponLabel = label
        incident.weaponClass = class
        print(('[shotspotter] cluster hit incident #%d shots=%d'):format(incidentId, incident.shotCount))

        broadcastAlert({
            id          = incidentId,
            shotCount   = incident.shotCount,
            weaponLabel = incident.weaponLabel,
            weaponClass = incident.weaponClass,
            fuzzedX     = incident.fuzzedX,
            fuzzedY     = incident.fuzzedY,
            fuzzedZ     = incident.fuzzedZ,
            streetName  = incident.streetName,
            zoneName    = incident.zoneName,
        })
        return
    end

    -- New incident
    incidentId = nextIncidentId
    nextIncidentId = nextIncidentId + 1

    local fx, fy, fz = fuzzPosition(x, y, z)
    local streetName, zoneName = resolveLocation(x, y, z)

    incident = {
        id          = incidentId,
        coords      = vector3(x, y, z),
        fuzzedX     = fx,
        fuzzedY     = fy,
        fuzzedZ     = fz,
        weaponHash  = weaponHash,
        weaponLabel = label,
        weaponClass = class,
        shotCount   = 1,
        lastShotAt  = now,
        streetName  = streetName,
        zoneName    = zoneName,
    }
    activeIncidents[incidentId] = incident

    print(('[shotspotter] NEW incident #%d  weapon=%s  class=%s  street=%s  zone=%s  src=%s')
        :format(incidentId, label, class, streetName, zoneName, tostring(src)))

    -- Schedule auto-cleanup of the incident record after duration + buffer
    local cleanupAfterMs = (Config.Alert.durationSeconds + 5) * 1000
    SetTimeout(cleanupAfterMs, function()
        activeIncidents[incidentId] = nil
        Debug(('incident=%d cleaned up'):format(incidentId))
    end)

    -- Fan out to everyone
    print(('[shotspotter] Broadcasting incident #%d to ALL connected players'):format(incidentId))
    broadcastAlert({
        id          = incidentId,
        shotCount   = incident.shotCount,
        weaponLabel = incident.weaponLabel,
        weaponClass = incident.weaponClass,
        fuzzedX     = fx,
        fuzzedY     = fy,
        fuzzedZ     = fz,
        streetName  = streetName,
        zoneName    = zoneName,
    })

    -- Discord audit
    discordLog(incident, fx, fy, fz)
end)

-- v1.1.5 — Sanity ping command. NO admin check, available to everyone.
-- If `/shotspot_ping` works in chat but `/shotspot_force` doesn't, then
-- commands ARE registered and the issue is the admin check. If this
-- ping doesn't work either, server.lua isn't loading at all.
RegisterCommand('shotspot_ping', function(src)
    print(('[distortionz_shotspotter] PING received from src=%s name=%s'):format(tostring(src), GetPlayerName(src) or 'console'))
    if src ~= 0 then
        TriggerClientEvent('chat:addMessage', src, {
            args = { 'shotspotter', '✓ Server is alive — server.lua is loaded and commands work.' }
        })
    end
end, false)

-- ─── Diagnostic / test commands ─────────────────────────────────────
-- /shotspot_status  - shows active incident count
-- /shotspot_test    - fakes a shot at the admin's position, fans to ALL players
-- /shotspot_force   - fakes a shot AND force-sends to YOUR client only
-- All commands require ace permission (group.admin or shotspotter.admin).
local function isAdmin(src)
    return IsPlayerAceAllowed(src, 'command.shotspot_test')
        or IsPlayerAceAllowed(src, 'group.admin')
        or IsPlayerAceAllowed(src, 'shotspotter.admin')
end

local function countActiveIncidents()
    local n = 0
    for _ in pairs(activeIncidents) do n = n + 1 end
    return n
end

RegisterCommand('shotspot_status', function(src)
    if src == 0 then
        print(('[shotspotter] STATUS — connected players: %d  active incidents: %d'):format(#GetPlayers(), countActiveIncidents()))
        return
    end

    if not isAdmin(src) then
        TriggerClientEvent('chat:addMessage', src, { args = { 'shotspotter', 'You need admin privileges.' } })
        return
    end

    TriggerClientEvent('chat:addMessage', src, {
        args = { 'shotspotter', ('Connected players: %d  |  Active incidents: %d'):format(#GetPlayers(), countActiveIncidents()) }
    })
end, false)

RegisterCommand('shotspot_test', function(src)
    if src == 0 then
        print('[shotspotter] /shotspot_test must be run by a player (needs world coords).')
        return
    end
    if not isAdmin(src) then
        TriggerClientEvent('chat:addMessage', src, { args = { 'shotspotter', 'You need admin privileges.' } })
        return
    end

    local ped = GetPlayerPed(src)
    local pCoords = GetEntityCoords(ped)
    local fakeWeapon = `weapon_pistol`

    print(('[shotspotter] /shotspot_test from src=%d at (%.1f, %.1f, %.1f)'):format(src, pCoords.x, pCoords.y, pCoords.z))

    TriggerEvent('distortionz_shotspotter:server:reportShot', {
        weaponHash = fakeWeapon,
        x          = pCoords.x,
        y          = pCoords.y,
        z          = pCoords.z,
    })

    TriggerClientEvent('chat:addMessage', src, {
        args = { 'shotspotter', 'Test shot fired at your position. Check console for dispatch log.' }
    })
end, false)

RegisterCommand('shotspot_force', function(src)
    if src == 0 then
        print('[shotspotter] /shotspot_force must be run by a player.')
        return
    end
    if not isAdmin(src) then
        TriggerClientEvent('chat:addMessage', src, { args = { 'shotspotter', 'You need admin privileges.' } })
        return
    end

    local ped = GetPlayerPed(src)
    local pCoords = GetEntityCoords(ped)
    local fx, fy, fz = fuzzPosition(pCoords.x, pCoords.y, pCoords.z)
    local streetName, zoneName = resolveLocation(pCoords.x, pCoords.y, pCoords.z)

    local fakeId = nextIncidentId
    nextIncidentId = nextIncidentId + 1

    print(('[shotspotter] /shotspot_force — pushing fake alert directly to src=%d (UI test)'):format(src))

    TriggerClientEvent('distortionz_shotspotter:client:dispatchAlertForce', src, {
        id          = fakeId,
        shotCount   = 1,
        weaponLabel = 'Test Pistol',
        weaponClass = 'pistol',
        fuzzedX     = fx,
        fuzzedY     = fy,
        fuzzedZ     = fz,
        streetName  = streetName,
        zoneName    = zoneName,
    })
end, false)
