--- NUI callbacks shared by the phone app and the panel. Most actions are forwarded to the server as-is;
--- playback actions also drive the local audio engine with the session returned by the server.
FiveFly.Nui = {}

local Nui = FiveFly.Nui
local pendingRequests = {}
local requestCounter = 0
local REQUEST_TIMEOUT_MS <const> = 10000

function Nui.Ok(data)
    return { ok = true, data = data }
end

function Nui.Fail(errorCode)
    return { ok = false, error = tostring(errorCode or "unknown_error") }
end

--- Sends an action to the server and calls `cb` with the response envelope (or a timeout error).
function Nui.RequestServer(action, payload, cb)
    requestCounter = requestCounter + 1

    local requestId = ("%d:%d"):format(GetGameTimer(), requestCounter)
    pendingRequests[requestId] = cb

    TriggerServerEvent("fivefly:server:request", requestId, action, payload or {})

    SetTimeout(REQUEST_TIMEOUT_MS, function()
        local pending = pendingRequests[requestId]

        if pending then
            pendingRequests[requestId] = nil
            pending(Nui.Fail("server_timeout"))
        end
    end)
end

RegisterNetEvent("fivefly:client:response", function(requestId, response)
    local key = tostring(requestId or "")
    local cb = pendingRequests[key]

    if not cb then
        return
    end

    pendingRequests[key] = nil
    cb(type(response) == "table" and response or Nui.Fail("invalid_server_response"))
end)

--- Strips client-only fields before forwarding and remembers which UI started playback.
local function readPayload(data)
    local payload = type(data) == "table" and data or {}
    local origin = payload._origin
    payload._origin = nil
    return payload, (origin == "panel" or origin == "phone") and origin or nil
end

local function getAudioState()
    return {
        output = FiveFly.Bluetooth.GetOutput(),
        volume = FiveFly.Volume.value,
        muted = FiveFly.Volume.muted
    }
end

-- Actions forwarded to the server without client-side handling.
local FORWARDED_ACTIONS <const> = {
    "playback.state.get",
    "music.search",
    "music.stations.get",
    "music.recommendations.get",
    "social.search",
    "social.profile.get",
    "social.profile.update",
    "social.follow.toggle",
    "library.favorites.get",
    "library.favorites.toggle",
    "library.history.get",
    "library.history.clear",
    "library.smart-playlists.get",
    "library.playlists.get",
    "library.playlists.create",
    "library.playlists.import",
    "library.playlists.cover.set",
    "library.playlists.visibility.set",
    "library.playlists.delete",
    "library.playlists.tracks.get",
    "library.playlists.tracks.add",
    "library.playlists.tracks.remove",
    "playback.sessions.get",
    "playback.friends.get"
}

-- Successful mutations are announced so the other UI (phone or panel) reloads its data.
local LIBRARY_MUTATIONS <const> = {
    ["social.profile.update"] = true,
    ["social.follow.toggle"] = true,
    ["library.favorites.toggle"] = true,
    ["library.history.clear"] = true,
    ["library.playlists.create"] = true,
    ["library.playlists.import"] = true,
    ["library.playlists.cover.set"] = true,
    ["library.playlists.visibility.set"] = true,
    ["library.playlists.delete"] = true,
    ["library.playlists.tracks.add"] = true,
    ["library.playlists.tracks.remove"] = true
}

for _, action in ipairs(FORWARDED_ACTIONS) do
    RegisterNUICallback(action, function(data, cb)
        local payload, origin = readPayload(data)

        Nui.RequestServer(action, payload, function(response)
            if response.ok and LIBRARY_MUTATIONS[action] then
                FiveFly.SendUiMessage("library.changed", { origin = origin, action = action })
            end

            cb(response)
        end)
    end)
end

RegisterNUICallback("app.ready", function(_, cb)
    cb(Nui.Ok({
        identifier = Config.Phone.Identifier,
        name = Config.Phone.Name,
        locale = Config.Locale,
        phoneAvailable = FiveFly.IsPhoneAvailable(),
        panelEnabled = Config.Panel.Enabled == true
    }))
end)

RegisterNUICallback("app.get-initial-state", function(data, cb)
    local payload = readPayload(data)

    Nui.RequestServer("app.get-initial-state", payload, function(response)
        if response.ok and type(response.data) == "table" then
            response.data.audio = getAudioState()
        end

        cb(response)
    end)
end)

--- Plays the session returned by the server and broadcasts it to the other UI.
local function applySession(session, origin)
    if type(session) ~= "table" then
        return
    end

    if session.currentTrack then
        FiveFly.AudioEngine.PlaySession(session)

        if origin then
            FiveFly.PlaybackOrigin = origin
        end
    else
        FiveFly.AudioEngine.Transport("stop")
        FiveFly.PlaybackOrigin = nil
    end

    FiveFly.SendUiMessage("playback.state", session)
end

--- Keeps the engine's session in sync without restarting the current track.
local function updateSession(session)
    if type(session) == "table" and session.currentTrack then
        FiveFly.AudioEngine.UpdateSession(session)
    end

    FiveFly.SendUiMessage("playback.state", session)
end

for _, action in ipairs({ "playback.play", "playback.sessions.join" }) do
    RegisterNUICallback(action, function(data, cb)
        local payload, origin = readPayload(data)

        Nui.RequestServer(action, payload, function(response)
            if response.ok and response.data then
                applySession(response.data.session, origin)
            end

            cb(response)
        end)
    end)
end

RegisterNUICallback("playback.transport", function(data, cb)
    local payload = readPayload(data)
    local action = payload.action

    Nui.RequestServer("playback.transport", payload, function(response)
        if response.ok and response.data then
            local session = response.data.session

            if action == "next" or action == "prev" or action == "stop" then
                applySession(session, nil)
            else
                FiveFly.AudioEngine.Transport(action)
                updateSession(session)
            end
        end

        cb(response)
    end)
end)

for _, action in ipairs({ "playback.queue.set", "playback.mode.set" }) do
    RegisterNUICallback(action, function(data, cb)
        Nui.RequestServer(action, readPayload(data), function(response)
            if response.ok and response.data then
                updateSession(response.data.session)
            end

            cb(response)
        end)
    end)
end

RegisterNUICallback("playback.seek", function(data, cb)
    local payload = readPayload(data)

    Nui.RequestServer("playback.seek", payload, function(response)
        if response.ok and response.data then
            FiveFly.AudioEngine.Seek(payload.position)
            updateSession(response.data.session)
        end

        cb(response)
    end)
end)

---------------------------------------------------------------------------------------------------
-- Local audio settings (never reach the server).
---------------------------------------------------------------------------------------------------

RegisterNUICallback("audio.output.get", function(_, cb)
    cb(Nui.Ok({ output = FiveFly.Bluetooth.GetOutput() }))
end)

RegisterNUICallback("audio.output.set", function(data, cb)
    local output = type(data) == "table" and tostring(data.output or "") or ""
    local success, errorCode = FiveFly.Bluetooth.SetOutput(output)

    if not success then
        cb(Nui.Fail(errorCode))
        return
    end

    cb(Nui.Ok({ output = output }))
end)

local function applyVolume()
    FiveFly.AudioEngine.SetVolume(FiveFly.Volume.value, FiveFly.Volume.muted)
    FiveFly.Sync.UpdateCurrentSource(true)
    FiveFly.SendUiMessage("audio.state", getAudioState())
end

RegisterNUICallback("audio.volume.set", function(data, cb)
    FiveFly.Volume.value = FiveFly.Utils.ClampVolume(type(data) == "table" and data.value or 100)
    applyVolume()
    cb(Nui.Ok({ value = FiveFly.Volume.value }))
end)

RegisterNUICallback("audio.mute.set", function(data, cb)
    FiveFly.Volume.muted = type(data) == "table" and data.muted == true
    applyVolume()
    cb(Nui.Ok({ muted = FiveFly.Volume.muted }))
end)

--- Auto-advance when the engine reports the end of a track.
function Nui.HandleTrackEnded()
    Nui.RequestServer("playback.transport", { action = "next", reason = "ended" }, function(response)
        if response.ok and response.data then
            applySession(response.data.session, nil)
        end
    end)
end
