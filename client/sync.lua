
FiveFly.Sync = {
    activeSession = nil,
    lastUpdateAt = 0,
    lastCoords = nil,
    active = false,
    externalVolumeAction = "engine.external.volume",
    externalSources = {}
}

function FiveFly.Sync.IsActive()
    return FiveFly.Sync.active == true
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
    local session = FiveFly.Sync.activeSession

    if type(session) ~= "table" or type(session.currentTrack) ~= "table" then
        return nil
    end

    if FiveFly.Bluetooth.ValidateOutputTarget and not FiveFly.Bluetooth.ValidateOutputTarget() then
        return {
            stop = true
        }
    end

    local target = FiveFly.Bluetooth.GetOutputTarget()

    if not target or target.sourceType == "private" or target.sourceType == "off" then
        return {
            stop = true
        }
    end

    if not target.sourceCoords then
        return nil
    end

    local now = GetGameTimer()
    local moved = distanceBetween(target.sourceCoords, FiveFly.Sync.lastCoords) >= Config.Sync.PositionThreshold

    if not force and not moved and now - FiveFly.Sync.lastUpdateAt < Config.Sync.PositionIntervalMs then
        return nil
    end

    FiveFly.Sync.lastUpdateAt = now
    FiveFly.Sync.lastCoords = target.sourceCoords

    local sourceVolume = FiveFly.Volume and FiveFly.Volume.value or 100

    if FiveFly.Volume and FiveFly.Volume.muted then
        sourceVolume = 0
    elseif FiveFly.AudioEngine and FiveFly.AudioEngine.GetEffectiveVolume then
        sourceVolume = FiveFly.AudioEngine.GetEffectiveVolume(sourceVolume)
    end

    sourceVolume = applyOutputProfileVolume(sourceVolume, target.volume)

    local progress = FiveFly.AudioEngine and FiveFly.AudioEngine.progress or {}
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

function FiveFly.Sync.SetCurrentSession(session)
    FiveFly.Sync.activeSession = session
    FiveFly.Sync.active = type(session) == "table" and type(session.currentTrack) == "table"
    FiveFly.Sync.UpdateCurrentSource(true)
end

function FiveFly.Sync.ClearCurrentSession()
    FiveFly.Sync.activeSession = nil
    FiveFly.Sync.active = false
    TriggerServerEvent("fivefly:server:stopSource")
end

function FiveFly.Sync.UpdateCurrentSource(force)
    local payload = buildSourcePayload(force == true)

    if not payload then
        return
    end

    if payload.stop then
        TriggerServerEvent("fivefly:server:stopSource")
        return
    end

    TriggerServerEvent("fivefly:server:updateSource", payload)
end

function FiveFly.Sync.CalculateExternalVolume(sourceInfo)
    if type(sourceInfo) ~= "table" then
        return 0
    end

    local sourceCoords = toVector3(sourceInfo.sourceCoords)

    if not sourceCoords then
        return 0
    end

    local attenuation = Config.Attenuation or {}
    local distance = spatialDistance(GetEntityCoords(PlayerPedId()), sourceCoords, attenuation)

    return FiveFly.Utils.AttenuatedVolume(distance, sourceInfo.range, sourceInfo.volume, attenuation)
end

function FiveFly.Sync.UpdateExternalVolumes()
    if not FiveFly.AudioEngine then
        return
    end

    local attenuation = Config.Attenuation or {}
    local smoothing = clamp(attenuation.smoothingFactor or 0.15, 0.0, 1.0)

    for sourceId, sourceInfo in pairs(FiveFly.Sync.externalSources) do
        local targetVolume = FiveFly.Sync.CalculateExternalVolume(sourceInfo)
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

        FiveFly.AudioEngine.SetExternalVolume(sourceId, currentVolume)
    end
end

RegisterNetEvent("fivefly:client:sourceAdded", function(sourceId, payload)
    if not FiveFly.AudioEngine or type(payload) ~= "table" then
        return
    end

    FiveFly.Sync.externalSources[sourceId] = payload
    FiveFly.AudioEngine.AddExternalSource(sourceId, payload)
    FiveFly.Sync.UpdateExternalVolumes()
end)

RegisterNetEvent("fivefly:client:sourceUpdated", function(sourceId, payload)
    if not FiveFly.AudioEngine or type(payload) ~= "table" then
        return
    end

    local previous = FiveFly.Sync.externalSources[sourceId] or {}
    payload.currentVolume = previous.currentVolume
    FiveFly.Sync.externalSources[sourceId] = payload
    FiveFly.AudioEngine.UpdateExternalSource(sourceId, payload)
    FiveFly.Sync.UpdateExternalVolumes()
end)

RegisterNetEvent("fivefly:client:sourceRemoved", function(sourceId)
    if not FiveFly.AudioEngine then
        return
    end

    FiveFly.Sync.externalSources[sourceId] = nil
    FiveFly.AudioEngine.RemoveExternalSource(sourceId)
end)

CreateThread(function()
    while true do
        if FiveFly.Sync.IsActive() then
            FiveFly.Sync.UpdateCurrentSource(false)
            Wait(Config.Sync.PositionIntervalMs)
        else
            Wait(1000)
        end
    end
end)

CreateThread(function()
    while true do
        local hasExternalSources = next(FiveFly.Sync.externalSources) ~= nil

        if hasExternalSources then
            FiveFly.Sync.UpdateExternalVolumes()
            Wait(Config.Sync.VolumeIntervalMs)
        else
            Wait(1000)
        end
    end
end)
