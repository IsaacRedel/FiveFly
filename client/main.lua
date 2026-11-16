FiveFly = FiveFly or {}

FiveFly.Volume = {
    value = 100,
    muted = false
}

--- Where the current playback was started from ("phone" or "panel"). Used by the phone item guard.
FiveFly.PlaybackOrigin = nil

local function getPhoneResource()
    return Config.Phone.Resource or "lb-phone"
end

function FiveFly.IsPhoneAvailable()
    return Config.Phone.Enabled == true and GetResourceState(getPhoneResource()) == "started"
end

--- Sends a state update to every UI: the lb-phone app (when available) and the panel/engine page.
function FiveFly.SendUiMessage(action, data)
    local message = { action = action, data = data or {} }

    if FiveFly.IsPhoneAvailable() then
        pcall(function()
            exports[getPhoneResource()]:SendCustomAppMessage(Config.Phone.Identifier, message)
        end)
    end

    SendNUIMessage({ target = "ui", action = action, data = message.data })
end

function FiveFly.GetEmptyPlaybackState()
    return {
        queue = {},
        currentTrack = nil,
        currentIndex = nil,
        status = "idle",
        playback = { position = 0, startedAt = 0, nonce = 0 }
    }
end

function FiveFly.StopPlayback(reason)
    FiveFly.AudioEngine.Transport("stop")
    FiveFly.PlaybackOrigin = nil

    FiveFly.Nui.RequestServer("playback.transport", { action = "stop", reason = tostring(reason or "stopped") }, function() end)
    FiveFly.SendUiMessage("playback.state", FiveFly.GetEmptyPlaybackState())
end

RegisterNetEvent("fivefly:client:forceStopPlayback", function(reason)
    if FiveFly.Bluetooth.GetOutput() ~= "off" then
        FiveFly.Bluetooth.SetOutput("off")
    end

    FiveFly.StopPlayback(reason or "force_stop")
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
        and FiveFly.PlaybackOrigin == "phone"
        and FiveFly.IsPhoneAvailable()
        and FiveFly.AudioEngine.HasActiveSession()
end

local stopping = false

local function stopIfPhoneMissing()
    if stopping or not isGuardActive() or playerHasPhone() then
        return
    end

    stopping = true

    if FiveFly.Bluetooth.GetOutput() ~= "off" then
        FiveFly.Bluetooth.SetOutput("off")
    end

    FiveFly.StopPlayback("missing_phone")

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
