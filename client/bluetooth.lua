
FiveFly.Bluetooth = {
    output = Config.Outputs.Default,
    lastAutoOffAt = 0
}

function FiveFly.Bluetooth.GetOutput()
    return FiveFly.Bluetooth.output
end

local function notifyAudioState(reason)
    FiveFly.SendUiMessage("audio.state", {
        output = FiveFly.Bluetooth.GetOutput(),
        reason = reason
    })
end

function FiveFly.Bluetooth.SetOutput(output)
    local safeOutput = tostring(output or Config.Outputs.Default)

    if not Config.Outputs.Allowed[safeOutput] then
        return false, "invalid_output"
    end

    if safeOutput == "vehicle" then
        if not FiveFly.Vehicle or not FiveFly.Vehicle.ConnectCurrent or not FiveFly.Vehicle.ConnectCurrent() then
            return false, "vehicle_missing"
        end
    elseif FiveFly.Vehicle and FiveFly.Vehicle.ClearConnected then
        FiveFly.Vehicle.ClearConnected()
    end

    FiveFly.Bluetooth.output = safeOutput

    if FiveFly.AudioEngine and FiveFly.AudioEngine.SetOutput then
        FiveFly.AudioEngine.SetOutput(safeOutput)
    end

    if safeOutput == "prop" then
        FiveFly.Prop.Ensure()
    elseif safeOutput ~= "prop" and FiveFly.Prop then
        FiveFly.Prop.Delete()
    end

    if FiveFly.Sync then
        FiveFly.Sync.UpdateCurrentSource(true)
    end

    notifyAudioState(nil)

    return true, nil
end

function FiveFly.Bluetooth.AutoOffOutput(reason)
    local output = FiveFly.Bluetooth.GetOutput()

    if output == "off" or output == "private" then
        return false
    end

    FiveFly.Bluetooth.lastAutoOffAt = GetGameTimer()
    FiveFly.Bluetooth.SetOutput("off")
    notifyAudioState(reason or "auto_off")

    return true
end

function FiveFly.Bluetooth.ValidateOutputTarget()
    local output = FiveFly.Bluetooth.GetOutput()

    if output == "off" or output == "private" then
        return true
    end

    if IsEntityDead(PlayerPedId()) then
        FiveFly.Bluetooth.AutoOffOutput("player_dead")
        return false
    end

    if output == "prop" then
        if not FiveFly.Prop or not FiveFly.Prop.Exists() then
            FiveFly.Bluetooth.AutoOffOutput("prop_missing")
            return false
        end

        return true
    end

    if output == "vehicle" then
        local target = FiveFly.Vehicle and FiveFly.Vehicle.GetOutputTarget and FiveFly.Vehicle.GetOutputTarget() or nil

        if not target or not target.sourceCoords then
            if FiveFly.StopPlayback then
                FiveFly.StopPlayback("vehicle_missing")
            end

            FiveFly.Bluetooth.AutoOffOutput("vehicle_missing")
            return false
        end

        if FiveFly.Vehicle.IsOwnerTooFar and FiveFly.Vehicle.IsOwnerTooFar() then
            if FiveFly.StopPlayback then
                FiveFly.StopPlayback("vehicle_owner_too_far")
            end

            FiveFly.Bluetooth.AutoOffOutput("vehicle_owner_too_far")
            return false
        end

        return true
    end

    return true
end

function FiveFly.Bluetooth.GetOutputTarget()
    local output = FiveFly.Bluetooth.GetOutput()

    if output == "off" or output == "private" then
        return {
            sourceType = output
        }
    end

    if output == "prop" then
        local entity, propNetId = FiveFly.Prop.Ensure()
        local propConfig = Config.Range and Config.Range.prop or {}

        if not entity then
            return nil
        end

        return {
            sourceType = "prop",
            sourceCoords = FiveFly.Prop.GetCoords(),
            propNetId = propNetId,
            range = tonumber(propConfig.range) or 16.0,
            volume = tonumber(propConfig.volume) or 78.0
        }
    end

    if output == "vehicle" then
        return FiveFly.Vehicle.GetOutputTarget()
    end

    return nil
end

CreateThread(function()
    while true do
        local output = FiveFly.Bluetooth.GetOutput()

        if output == "prop" or output == "vehicle" then
            FiveFly.Bluetooth.ValidateOutputTarget()
            Wait(1000)
        else
            Wait(1500)
        end
    end
end)
