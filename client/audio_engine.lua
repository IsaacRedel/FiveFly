--- Bridge to the hidden audio engine page (ui/engine), which plays the local track and nearby speakers.
FiveFY.AudioEngine = {
    ready = false,
    lastSession = nil,
    masterVolume = 100,
    progress = {
        videoId = nil,
        position = 0,
        duration = 0
    }
}

local clampVolume = FiveFY.Utils.ClampVolume

function FiveFY.AudioEngine.IsReady()
    return FiveFY.AudioEngine.ready == true
end

function FiveFY.AudioEngine.HasActiveSession()
    local session = FiveFY.AudioEngine.lastSession
    return type(session) == "table" and type(session.currentTrack) == "table"
end

local function sendEngineMessage(action, payload)
    SendNUIMessage({
        target = "audio-engine",
        action = action,
        payload = payload or {}
    })
end

local function getOutput()
    return tostring(FiveFY.Bluetooth.GetOutput() or "private")
end

function FiveFY.AudioEngine.PlaySession(session)
    if type(session) ~= "table" or type(session.currentTrack) ~= "table" then
        return false
    end

    FiveFY.AudioEngine.lastSession = session

    sendEngineMessage("engine.play", {
        track = session.currentTrack,
        playback = session.playback or {
            position = 0
        }
    })

    FiveFY.Sync.SetCurrentSession(session)

    return true
end

--- Updates the stored session (queue, modes, position) without restarting the current track.
function FiveFY.AudioEngine.UpdateSession(session)
    FiveFY.AudioEngine.lastSession = session
    FiveFY.Sync.SetCurrentSession(session)
end

function FiveFY.AudioEngine.Transport(action)
    local safeAction = tostring(action or "")

    if safeAction == "pause" then
        sendEngineMessage("engine.pause")
        return true
    end

    if safeAction == "resume" or safeAction == "play" then
        sendEngineMessage("engine.resume")
        return true
    end

    if safeAction == "stop" then
        sendEngineMessage("engine.stop")
        FiveFY.AudioEngine.lastSession = nil

        if FiveFY.Sync then
            FiveFY.Sync.ClearCurrentSession()
        end

        return true
    end

    return false
end

function FiveFY.AudioEngine.GetEffectiveVolume(value)
    return FiveFY.AudioEngine.GetExternalVolume(value)
end

function FiveFY.AudioEngine.GetLocalVolume(value)
    local safeValue = clampVolume(value)
    local output = getOutput()

    if output == "off" or output == "prop" or output == "vehicle" then
        return 0
    end

    if output == "private" then
        local localConfig = Config.LocalAudio or {}
        local multiplier = tonumber(localConfig.privateVolumeMultiplier) or 0.35
        return clampVolume(safeValue * multiplier)
    end

    return safeValue
end

function FiveFY.AudioEngine.GetExternalVolume(value)
    local safeValue = clampVolume(value)
    return safeValue
end

--- Re-applies the volume after an output change (the local volume depends on the output).
function FiveFY.AudioEngine.SetOutput()
    FiveFY.AudioEngine.SetVolume(FiveFY.Volume.value, FiveFY.Volume.muted)
end

function FiveFY.AudioEngine.SetVolume(value, muted)
    local localValue = FiveFY.AudioEngine.GetLocalVolume(value)
    local externalValue = FiveFY.AudioEngine.GetExternalVolume(value)

    sendEngineMessage("engine.volume", {
        value = localValue,
        externalValue = externalValue,
        muted = muted == true or localValue <= 0,
        externalMuted = muted == true or externalValue <= 0,
        output = getOutput()
    })
end

function FiveFY.AudioEngine.SetMasterVolume(value)
    local safeValue = clampVolume(value)
    FiveFY.AudioEngine.masterVolume = safeValue

    sendEngineMessage("engine.masterVolume", {
        value = safeValue
    })
end

function FiveFY.AudioEngine.Seek(position)
    local safePosition = tonumber(position) or 0
    safePosition = math.max(0, safePosition)

    sendEngineMessage("engine.seek", {
        position = safePosition
    })
end

function FiveFY.AudioEngine.AddExternalSource(sourceId, payload)
    sendEngineMessage("engine.external.add", {
        sourceId = tostring(sourceId),
        source = payload or {}
    })
end

function FiveFY.AudioEngine.UpdateExternalSource(sourceId, payload)
    sendEngineMessage("engine.external.update", {
        sourceId = tostring(sourceId),
        source = payload or {}
    })
end

function FiveFY.AudioEngine.SetExternalVolume(sourceId, volume)
    local safeVolume = tonumber(volume) or 0
    safeVolume = math.max(0, math.min(100, math.floor(safeVolume + 0.5)))

    sendEngineMessage("engine.external.volume", {
        sourceId = tostring(sourceId),
        volume = safeVolume
    })
end

function FiveFY.AudioEngine.RemoveExternalSource(sourceId)
    sendEngineMessage("engine.external.remove", {
        sourceId = tostring(sourceId)
    })
end

RegisterNUICallback("engine.ready", function(_, cb)
    FiveFY.AudioEngine.ready = true

    if FiveFY.Volume then
        FiveFY.AudioEngine.SetVolume(FiveFY.Volume.value, FiveFY.Volume.muted)
    end

    FiveFY.AudioEngine.SetMasterVolume(FiveFY.AudioEngine.masterVolume)

    if FiveFY.AudioEngine.lastSession then
        FiveFY.AudioEngine.PlaySession(FiveFY.AudioEngine.lastSession)
    end

    cb({
        ok = true
    })
end)

RegisterNUICallback("engine.progress", function(data, cb)
    FiveFY.AudioEngine.progress = {
        videoId = type(data) == "table" and data.videoId or nil,
        position = tonumber(type(data) == "table" and data.position or 0) or 0,
        duration = tonumber(type(data) == "table" and data.duration or 0) or 0
    }

    FiveFY.SendUiMessage("playback.progress", FiveFY.AudioEngine.progress)

    cb({
        ok = true
    })
end)

RegisterNUICallback("engine.ended", function(_, cb)
    FiveFY.Nui.HandleTrackEnded()
    cb({ ok = true })
end)

RegisterNUICallback("engine.error", function(data, cb)
    FiveFY.SendUiMessage("playback.error", type(data) == "table" and data or {
        error = "engine_error"
    })

    cb({ ok = true })
end)

---------------------------------------------------------------------------------------------------
-- Master volume from an external mixer (Config.MasterVolume).
---------------------------------------------------------------------------------------------------

local function setMasterVolumeFromExport(first, second)
    -- Accepts (volume) or (self, volume) for mixers that call exports with a table first.
    FiveFY.AudioEngine.SetMasterVolume(type(first) == "table" and second or first)
end

exports("SetMasterVolume", setMasterVolumeFromExport)

for _, alias in ipairs(Config.MasterVolume and Config.MasterVolume.ExportAliases or {}) do
    exports(alias, setMasterVolumeFromExport)
end

local function readMixerVolume()
    local mixer = Config.MasterVolume or {}

    if not mixer.Resource or GetResourceState(mixer.Resource) ~= "started" then
        return
    end

    local ok, volume = pcall(function()
        return exports[mixer.Resource][mixer.Export or "GetVolume"](nil, GetCurrentResourceName())
    end)

    if ok and tonumber(volume) then
        FiveFY.AudioEngine.SetMasterVolume(volume)
    end
end

AddEventHandler("onClientResourceStart", function(resourceName)
    if Config.MasterVolume and resourceName == Config.MasterVolume.Resource then
        readMixerVolume()
    end
end)

CreateThread(function()
    Wait(1000)
    readMixerVolume()
end)
