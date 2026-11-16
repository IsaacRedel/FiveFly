--- Spatial audio: tracks speakers/vehicles playing music and streams them to nearby players.
FiveFY.ServerSync = {}

local ServerSync = FiveFY.ServerSync
local Utils = FiveFY.Utils

---@type table<integer, table>
local sources = {}
local VALID_SOURCE_TYPES <const> = { prop = true, vehicle = true }

function ServerSync.GetSources()
    return sources
end

--- Largest range in Config.Range: no client-reported range can exceed it.
local function computeMaxRange()
    local maxRange = 1.0
    local ranges = Config.Range or {}
    local vehicle = ranges.vehicle or {}

    local function consider(profile)
        if type(profile) == "table" and tonumber(profile.range) then
            maxRange = math.max(maxRange, tonumber(profile.range))
        end
    end

    consider(ranges.prop)
    consider(vehicle.default)
    consider(vehicle.soundSystem)

    for _, profile in pairs(vehicle.classProfiles or {}) do
        consider(profile)
    end

    return maxRange
end

local MAX_RANGE <const> = computeMaxRange()

local function getDefaultRange(sourceType)
    local ranges = Config.Range or {}

    if sourceType == "vehicle" then
        return tonumber(ranges.vehicle and ranges.vehicle.default and ranges.vehicle.default.range) or 24.0
    end

    return tonumber(ranges.prop and ranges.prop.range) or 16.0
end

local function getPedCoords(source)
    local ped = GetPlayerPed(source)

    if ped and ped ~= 0 and DoesEntityExist(ped) then
        return GetEntityCoords(ped)
    end

    return nil
end

--- Position of the audio source: the networked entity when it exists, otherwise the reported position
--- only if it is close to the player (prevents placing a speaker anywhere on the map).
local function resolveSourceCoords(source, sourceType, netId, reportedCoords)
    if not VALID_SOURCE_TYPES[sourceType] then
        return nil
    end

    local pedCoords = getPedCoords(source)
    local maxDistance = tonumber(Config.Sync.MaxSourceDistance) or 120.0

    if netId and netId > 0 then
        local entity = NetworkGetEntityFromNetworkId(netId)

        if entity and entity ~= 0 and DoesEntityExist(entity) then
            local entityCoords = GetEntityCoords(entity)

            -- A speaker is carried by the player: any other entity id is ignored. Vehicles may be left behind
            -- and are limited by ownerMaxDistance (isVehicleOwnerTooFar) instead.
            if sourceType == "vehicle" or (pedCoords and #(entityCoords - pedCoords) <= maxDistance) then
                return entityCoords
            end
        end
    end

    if not pedCoords then
        return nil
    end

    local coords = Utils.ToVector3(reportedCoords)

    if coords and #(coords - pedCoords) <= maxDistance then
        return coords
    end

    return pedCoords
end

local function getOwnerMaxDistance()
    local vehicle = Config.Range and Config.Range.vehicle or {}
    return tonumber(vehicle.ownerMaxDistance) or 80.0
end

local function isVehicleOwnerTooFar(source, sourceInfo)
    if sourceInfo.sourceType ~= "vehicle" then
        return false
    end

    local pedCoords = getPedCoords(source)
    return pedCoords ~= nil and #(pedCoords - sourceInfo.sourceCoords) > getOwnerMaxDistance()
end

local function buildSource(source, payload, coords)
    local track = Utils.NormalizeClientTrack(payload.track)

    if not track then
        return nil
    end

    local playback = type(payload.playback) == "table" and payload.playback or {}

    return {
        sourcePlayer = source,
        sourceType = payload.sourceType,
        sourceCoords = coords,
        propNetId = tonumber(payload.propNetId),
        vehicleNetId = tonumber(payload.vehicleNetId),
        range = Utils.Clamp(tonumber(payload.range) or getDefaultRange(payload.sourceType), 1.0, MAX_RANGE),
        volume = Utils.Clamp(payload.volume, 0, 100),
        profile = tostring(payload.profile or ""):sub(1, 32),
        vehicleClass = tonumber(payload.vehicleClass),
        soundSystem = payload.soundSystem == true,
        status = payload.status == "paused" and "paused" or "online",
        playback = {
            position = Utils.Clamp(playback.position, 0, 86400),
            startedAt = tonumber(playback.startedAt) or 0,
            nonce = tonumber(playback.nonce) or 0
        },
        track = track,
        listeners = {}
    }
end

local function toClientPayload(sourceInfo)
    return {
        track = sourceInfo.track,
        sourceType = sourceInfo.sourceType,
        sourcePlayer = sourceInfo.sourcePlayer,
        sourceCoords = sourceInfo.sourceCoords,
        propNetId = sourceInfo.propNetId,
        vehicleNetId = sourceInfo.vehicleNetId,
        range = sourceInfo.range,
        volume = sourceInfo.volume,
        profile = sourceInfo.profile,
        vehicleClass = sourceInfo.vehicleClass,
        soundSystem = sourceInfo.soundSystem,
        status = sourceInfo.status,
        playback = sourceInfo.playback
    }
end

local function stopSource(source)
    local sourceInfo = sources[source]

    if sourceInfo then
        for listener in pairs(sourceInfo.listeners) do
            TriggerClientEvent("fivefy:client:sourceRemoved", listener, source)
        end
    end

    sources[source] = nil
end

function ServerSync.RefreshListeners(source)
    local sourceInfo = sources[source]

    if not sourceInfo then
        return
    end

    local nearby = {}

    for _, playerId in ipairs(GetPlayers()) do
        local target = tonumber(playerId)
        local coords = target and getPedCoords(target)

        if coords and #(coords - sourceInfo.sourceCoords) <= sourceInfo.range then
            nearby[target] = true
        end
    end

    for listener in pairs(sourceInfo.listeners) do
        if not nearby[listener] then
            TriggerClientEvent("fivefy:client:sourceRemoved", listener, source)
            sourceInfo.listeners[listener] = nil
        end
    end

    local payload = toClientPayload(sourceInfo)

    for listener in pairs(nearby) do
        if sourceInfo.listeners[listener] then
            TriggerClientEvent("fivefy:client:sourceUpdated", listener, source, payload)
        else
            TriggerClientEvent("fivefy:client:sourceAdded", listener, source, payload)
            sourceInfo.listeners[listener] = true
        end
    end
end

local function refreshAllSources()
    for source, sourceInfo in pairs(sources) do
        local coords = resolveSourceCoords(source, sourceInfo.sourceType, sourceInfo.propNetId or sourceInfo.vehicleNetId, sourceInfo.sourceCoords)

        if not coords then
            stopSource(source)
        else
            sourceInfo.sourceCoords = coords

            if isVehicleOwnerTooFar(source, sourceInfo) then
                TriggerClientEvent("fivefy:client:forceStopPlayback", source, "vehicle_owner_too_far")
                stopSource(source)
            else
                ServerSync.RefreshListeners(source)
            end
        end
    end
end

RegisterNetEvent("fivefy:server:updateSource", function(payload)
    local source = source

    if type(payload) ~= "table" or not FiveFY.Permissions.CanUse(source) then
        return
    end

    if not FiveFY.RateLimit.Allow(source, "sync.updateSource", Config.RateLimits.SyncUpdateMs) then
        return
    end

    local sourceType = tostring(payload.sourceType or "")
    local coords = resolveSourceCoords(source, sourceType, tonumber(payload.propNetId or payload.vehicleNetId), payload.sourceCoords)

    if not coords then
        return
    end

    payload.sourceType = sourceType

    local sourceInfo = buildSource(source, payload, coords)

    if not sourceInfo then
        return
    end

    if isVehicleOwnerTooFar(source, sourceInfo) then
        TriggerClientEvent("fivefy:client:forceStopPlayback", source, "vehicle_owner_too_far")
        stopSource(source)
        return
    end

    sourceInfo.listeners = sources[source] and sources[source].listeners or {}
    sources[source] = sourceInfo

    ServerSync.RefreshListeners(source)
end)

RegisterNetEvent("fivefy:server:stopSource", function()
    stopSource(source)
end)

AddEventHandler("playerDropped", function()
    local dropped = source
    stopSource(dropped)

    for _, sourceInfo in pairs(sources) do
        sourceInfo.listeners[dropped] = nil
    end
end)

CreateThread(function()
    while true do
        Wait(Config.Sync.ListenerRefreshMs or 1000)

        if next(sources) then
            refreshAllSources()
        end
    end
end)
