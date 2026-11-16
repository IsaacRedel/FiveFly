FiveFY = FiveFY or {}

FiveFY.Volume = {
    value = 100,
    muted = false
}

--- Where the current playback was started from ("phone" or "panel"). Used by the phone item guard.
FiveFY.PlaybackOrigin = nil

local function getPhoneResource()
    return Config.Phone.Resource or "lb-phone"
end

function FiveFY.IsPhoneAvailable()
    return Config.Phone.Enabled == true and GetResourceState(getPhoneResource()) == "started"
end

--- Sends a state update to every UI: the lb-phone app (when available) and the panel/engine page.
function FiveFY.SendUiMessage(action, data)
    local message = { action = action, data = data or {} }

    if FiveFY.IsPhoneAvailable() then
        pcall(function()
            exports[getPhoneResource()]:SendCustomAppMessage(Config.Phone.Identifier, message)
        end)
    end

    SendNUIMessage({ target = "ui", action = action, data = message.data })
end

function FiveFY.GetEmptyPlaybackState()
    return {
        queue = {},
        currentTrack = nil,
        currentIndex = nil,
        status = "idle",
        playback = { position = 0, startedAt = 0, nonce = 0 }
    }
end

function FiveFY.StopPlayback(reason)
    FiveFY.AudioEngine.Transport("stop")
    FiveFY.PlaybackOrigin = nil

    FiveFY.Nui.RequestServer("playback.transport", { action = "stop", reason = tostring(reason or "stopped") }, function() end)
    FiveFY.SendUiMessage("playback.state", FiveFY.GetEmptyPlaybackState())
end

RegisterNetEvent("fivefy:client:forceStopPlayback", function(reason)
    if FiveFY.Bluetooth.GetOutput() ~= "off" then
        FiveFY.Bluetooth.SetOutput("off")
    end

    FiveFY.StopPlayback(reason or "force_stop")
end)

---------------------------------------------------------------------------------------------------
-- Phone item guard: stops music started from the phone when the player no longer has a phone.
---------------------------------------------------------------------------------------------------

local function playerHasPhone()
    local ok, hasPhone = pcall(function()
        return exports[getPhoneResource()]:HasPhoneItem()
    end)

    return not ok or hasPhone == true
end

local function isGuardActive()
    return Config.Phone.StopWithoutPhoneItem == true
        and FiveFY.PlaybackOrigin == "phone"
        and FiveFY.IsPhoneAvailable()
        and FiveFY.AudioEngine.HasActiveSession()
end

local stopping = false

local function stopIfPhoneMissing()
    if stopping or not isGuardActive() or playerHasPhone() then
        return
    end

    stopping = true

    if FiveFY.Bluetooth.GetOutput() ~= "off" then
        FiveFY.Bluetooth.SetOutput("off")
    end

    FiveFY.StopPlayback("missing_phone")

    SetTimeout(2500, function()
        stopping = false
    end)
end

CreateThread(function()
    while true do
        if isGuardActive() then
            stopIfPhoneMissing()
            Wait(1000)
        else
            Wait(2500)
        end
    end
end)

RegisterNetEvent("lb-phone:itemRemoved", stopIfPhoneMissing)
