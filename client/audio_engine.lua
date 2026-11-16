--- Bridge to the hidden audio engine page (ui/engine), which plays the local track and nearby speakers.
FiveFly.AudioEngine = {
    ready = false,
    lastSession = nil,
    masterVolume = 100,
    progress = {
        videoId = nil,
        position = 0,
        duration = 0
    }
}

local clampVolume = FiveFly.Utils.ClampVolume

function FiveFly.AudioEngine.IsReady()
    return FiveFly.AudioEngine.ready == true
end

function FiveFly.AudioEngine.HasActiveSession()
    local session = FiveFly.AudioEngine.lastSession
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
    return tostring(FiveFly.Bluetooth.GetOutput() or "private")
end

function FiveFly.AudioEngine.PlaySession(session)
    if type(session) ~= "table" or type(session.currentTrack) ~= "table" then
        return false
    end

    FiveFly.AudioEngine.lastSession = session

    sendEngineMessage("engine.play", {
        track = session.currentTrack,
        playback = session.playback or {
            position = 0
        }
    })

    FiveFly.Sync.SetCurrentSession(session)

    return true
end

--- Updates the stored session (queue, modes, position) without restarting the current track.
function FiveFly.AudioEngine.UpdateSession(session)
    FiveFly.AudioEngine.lastSession = session
    FiveFly.Sync.SetCurrentSession(session)
end

function FiveFly.AudioEngine.Transport(action)
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
        FiveFly.AudioEngine.lastSession = nil

        if FiveFly.Sync then
            FiveFly.Sync.ClearCurrentSession()
        end

        return true
    end

    return false
end

function FiveFly.AudioEngine.GetEffectiveVolume(value)
    return FiveFly.AudioEngine.GetExternalVolume(value)
end

function FiveFly.AudioEngine.GetLocalVolume(value)
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

function FiveFly.AudioEngine.GetExternalVolume(value)
    local safeValue = clampVolume(value)
    return safeValue
end

--- Re-applies the volume after an output change (the local volume depends on the output).
function FiveFly.AudioEngine.SetOutput()
    FiveFly.AudioEngine.SetVolume(FiveFly.Volume.value, FiveFly.Volume.muted)
end

function FiveFly.AudioEngine.SetVolume(value, muted)
    local localValue = FiveFly.AudioEngine.GetLocalVolume(value)
    local externalValue = FiveFly.AudioEngine.GetExternalVolume(value)

    sendEngineMessage("engine.volume", {
        value = localValue,
        externalValue = externalValue,
        muted = muted == true or localValue <= 0,
        externalMuted = muted == true or externalValue <= 0,
        output = getOutput()
    })
end

function FiveFly.AudioEngine.SetMasterVolume(value)
    local safeValue = clampVolume(value)
    FiveFly.AudioEngine.masterVolume = safeValue

    sendEngineMessage("engine.masterVolume", {
        value = safeValue
    })
end

function FiveFly.AudioEngine.Seek(position)
    local safePosition = tonumber(position) or 0
    safePosition = math.max(0, safePosition)

    sendEngineMessage("engine.seek", {
        position = safePosition
    })
end

function FiveFly.AudioEngine.AddExternalSource(sourceId, payload)
    sendEngineMessage("engine.external.add", {
        sourceId = tostring(sourceId),
        source = payload or {}
    })
end

function FiveFly.AudioEngine.UpdateExternalSource(sourceId, payload)
    sendEngineMessage("engine.external.update", {
        sourceId = tostring(sourceId),
        source = payload or {}
    })
end

function FiveFly.AudioEngine.SetExternalVolume(sourceId, volume)
    local safeVolume = tonumber(volume) or 0
    safeVolume = math.max(0, math.min(100, math.floor(safeVolume + 0.5)))

    sendEngineMessage("engine.external.volume", {
        sourceId = tostring(sourceId),
        volume = safeVolume
    })
end

function FiveFly.AudioEngine.RemoveExternalSource(sourceId)
    sendEngineMessage("engine.external.remove", {
        sourceId = tostring(sourceId)
    })
end

RegisterNUICallback("engine.ready", function(_, cb)
    FiveFly.AudioEngine.ready = true

    if FiveFly.Volume then
        FiveFly.AudioEngine.SetVolume(FiveFly.Volume.value, FiveFly.Volume.muted)
    end

    FiveFly.AudioEngine.SetMasterVolume(FiveFly.AudioEngine.masterVolume)

    if FiveFly.AudioEngine.lastSession then
        FiveFly.AudioEngine.PlaySession(FiveFly.AudioEngine.lastSession)
    end

    cb({
        ok = true
    })
end)

RegisterNUICallback("engine.progress", function(data, cb)
    FiveFly.AudioEngine.progress = {
        videoId = type(data) == "table" and data.videoId or nil,
        position = tonumber(type(data) == "table" and data.position or 0) or 0,
        duration = tonumber(type(data) == "table" and data.duration or 0) or 0
    }

    FiveFly.SendUiMessage("playback.progress", FiveFly.AudioEngine.progress)

    cb({
        ok = true
    })
end)

RegisterNUICallback("engine.ended", function(_, cb)
    FiveFly.Nui.HandleTrackEnded()
    cb({ ok = true })
end)

RegisterNUICallback("engine.error", function(data, cb)
    FiveFly.SendUiMessage("playback.error", type(data) == "table" and data or {
        error = "engine_error"
    })

    cb({ ok = true })
end)

---------------------------------------------------------------------------------------------------
-- Master volume from an external mixer (Config.MasterVolume).
---------------------------------------------------------------------------------------------------

local function setMasterVolumeFromExport(first, second)
    -- Accepts (volume) or (self, volume) for mixers that call exports with a table first.
    FiveFly.AudioEngine.SetMasterVolume(type(first) == "table" and second or first)
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
        FiveFly.AudioEngine.SetMasterVolume(volume)
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
