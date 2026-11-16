
FiveFY.Sync = {
    activeSession = nil,
    lastUpdateAt = 0,
    lastCoords = nil,
    active = false,
    externalVolumeAction = "engine.external.volume",
    externalSources = {}
}

function FiveFY.Sync.IsActive()
    return FiveFY.Sync.active == true
end

local function distanceBetween(a, b)
    if not a or not b then
        return 999999.0
    end

    return #(a - b)
end

local function spatialDistance(listenerCoords, sourceCoords, attenuation)
    if not listenerCoords or not sourceCoords then
        return 999999.0
    end

    local verticalScale = tonumber(attenuation and attenuation.verticalScale) or 1.0
    local dx = (listenerCoords.x or 0.0) - (sourceCoords.x or 0.0)
    local dy = (listenerCoords.y or 0.0) - (sourceCoords.y or 0.0)
    local dz = ((listenerCoords.z or 0.0) - (sourceCoords.z or 0.0)) * verticalScale

    return math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
end

local function clamp(value, minValue, maxValue)
    local safeValue = tonumber(value) or minValue
    return math.max(minValue, math.min(maxValue, safeValue))
end

local function applyOutputProfileVolume(sourceVolume, outputVolume)
    local safeSourceVolume = clamp(sourceVolume, 0, 100)
    local safeOutputVolume = clamp(outputVolume or 100, 0, 100)

    return clamp((safeSourceVolume * safeOutputVolume) / 100, 0, 100)
end

local function toVector3(coords)
    if not coords then
        return nil
    end

    if type(coords) == "vector3" then
        return coords
    end

    if type(coords) == "table" and coords.x and coords.y and coords.z then
        return vector3(tonumber(coords.x) or 0.0, tonumber(coords.y) or 0.0, tonumber(coords.z) or 0.0)
    end

    return nil
end

local function buildSourcePayload(force)
    local session = FiveFY.Sync.activeSession

    if type(session) ~= "table" or type(session.currentTrack) ~= "table" then
        return nil
    end

    if FiveFY.Bluetooth.ValidateOutputTarget and not FiveFY.Bluetooth.ValidateOutputTarget() then
        return {
            stop = true
        }
    end

    local target = FiveFY.Bluetooth.GetOutputTarget()

    if not target or target.sourceType == "private" or target.sourceType == "off" then
        return {
            stop = true
        }
    end

    if not target.sourceCoords then
        return nil
    end

    local now = GetGameTimer()
    local moved = distanceBetween(target.sourceCoords, FiveFY.Sync.lastCoords) >= Config.Sync.PositionThreshold

    if not force and not moved and now - FiveFY.Sync.lastUpdateAt < Config.Sync.PositionIntervalMs then
        return nil
    end

    FiveFY.Sync.lastUpdateAt = now
    FiveFY.Sync.lastCoords = target.sourceCoords

    local sourceVolume = FiveFY.Volume and FiveFY.Volume.value or 100

    if FiveFY.Volume and FiveFY.Volume.muted then
        sourceVolume = 0
    elseif FiveFY.AudioEngine and FiveFY.AudioEngine.GetEffectiveVolume then
        sourceVolume = FiveFY.AudioEngine.GetEffectiveVolume(sourceVolume)
    end

    sourceVolume = applyOutputProfileVolume(sourceVolume, target.volume)

    local progress = FiveFY.AudioEngine and FiveFY.AudioEngine.progress or {}
    local playback = session.playback or {}
    local progressVideoId = tostring(progress.videoId or "")
    local trackVideoId = tostring(session.currentTrack.videoId or "")
    local position = tonumber(playback.position) or 0

    if progressVideoId ~= "" and progressVideoId == trackVideoId then
        position = tonumber(progress.position) or position
    end

    return {
        track = session.currentTrack,
        status = session.status or "online",
        playback = {
            position = math.max(0, position),
            startedAt = tonumber(playback.startedAt) or 0,
            nonce = tonumber(playback.nonce) or 0
        },
        sourceType = target.sourceType,
        sourceCoords = target.sourceCoords,
        propNetId = target.propNetId,
        vehicleNetId = target.vehicleNetId,
        range = tonumber(target.range),
        volume = sourceVolume,
        profile = target.profile,
        vehicleClass = target.vehicleClass,
        soundSystem = target.soundSystem == true
    }
end

function FiveFY.Sync.SetCurrentSession(session)
    FiveFY.Sync.activeSession = session
    FiveFY.Sync.active = type(session) == "table" and type(session.currentTrack) == "table"
    FiveFY.Sync.UpdateCurrentSource(true)
end

function FiveFY.Sync.ClearCurrentSession()
    FiveFY.Sync.activeSession = nil
    FiveFY.Sync.active = false
    TriggerServerEvent("fivefy:server:stopSource")
end

function FiveFY.Sync.UpdateCurrentSource(force)
    local payload = buildSourcePayload(force == true)

    if not payload then
        return
    end

    if payload.stop then
        TriggerServerEvent("fivefy:server:stopSource")
        return
    end

    TriggerServerEvent("fivefy:server:updateSource", payload)
end

function FiveFY.Sync.CalculateExternalVolume(sourceInfo)
    if type(sourceInfo) ~= "table" then
        return 0
    end

    local sourceCoords = toVector3(sourceInfo.sourceCoords)

    if not sourceCoords then
        return 0
    end

    local attenuation = Config.Attenuation or {}
    local distance = spatialDistance(GetEntityCoords(PlayerPedId()), sourceCoords, attenuation)

    return FiveFY.Utils.AttenuatedVolume(distance, sourceInfo.range, sourceInfo.volume, attenuation)
end

function FiveFY.Sync.UpdateExternalVolumes()
    if not FiveFY.AudioEngine then
        return
    end

    local attenuation = Config.Attenuation or {}
    local smoothing = clamp(attenuation.smoothingFactor or 0.15, 0.0, 1.0)

    for sourceId, sourceInfo in pairs(FiveFY.Sync.externalSources) do
        local targetVolume = FiveFY.Sync.CalculateExternalVolume(sourceInfo)
        local currentVolume = tonumber(sourceInfo.currentVolume)

        if not currentVolume then
            currentVolume = targetVolume
        else
            currentVolume = currentVolume + ((targetVolume - currentVolume) * smoothing)
        end

        if currentVolume < 0.5 then
            currentVolume = 0
        end

        sourceInfo.currentVolume = currentVolume

        FiveFY.AudioEngine.SetExternalVolume(sourceId, currentVolume)
    end
end

RegisterNetEvent("fivefy:client:sourceAdded", function(sourceId, payload)
    if not FiveFY.AudioEngine or type(payload) ~= "table" then
        return
    end

    FiveFY.Sync.externalSources[sourceId] = payload
    FiveFY.AudioEngine.AddExternalSource(sourceId, payload)
    FiveFY.Sync.UpdateExternalVolumes()
end)

RegisterNetEvent("fivefy:client:sourceUpdated", function(sourceId, payload)
    if not FiveFY.AudioEngine or type(payload) ~= "table" then
        return
    end

    local previous = FiveFY.Sync.externalSources[sourceId] or {}
    payload.currentVolume = previous.currentVolume
    FiveFY.Sync.externalSources[sourceId] = payload
    FiveFY.AudioEngine.UpdateExternalSource(sourceId, payload)
    FiveFY.Sync.UpdateExternalVolumes()
end)

RegisterNetEvent("fivefy:client:sourceRemoved", function(sourceId)
    if not FiveFY.AudioEngine then
        return
    end

    FiveFY.Sync.externalSources[sourceId] = nil
    FiveFY.AudioEngine.RemoveExternalSource(sourceId)
end)

CreateThread(function()
    while true do
        if FiveFY.Sync.IsActive() then
            FiveFY.Sync.UpdateCurrentSource(false)
            Wait(Config.Sync.PositionIntervalMs)
        else
            Wait(1000)
        end
    end
end)

CreateThread(function()
    while true do
        local hasExternalSources = next(FiveFY.Sync.externalSources) ~= nil

        if hasExternalSources then
            FiveFY.Sync.UpdateExternalVolumes()
            Wait(Config.Sync.VolumeIntervalMs)
        else
            Wait(1000)
        end
    end
end)
