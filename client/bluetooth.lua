
FiveFY.Bluetooth = {
    output = Config.Outputs.Default,
    lastAutoOffAt = 0
}

function FiveFY.Bluetooth.GetOutput()
    return FiveFY.Bluetooth.output
end

local function notifyAudioState(reason)
    FiveFY.SendUiMessage("audio.state", {
        output = FiveFY.Bluetooth.GetOutput(),
        reason = reason
    })
end

function FiveFY.Bluetooth.SetOutput(output)
    local safeOutput = tostring(output or Config.Outputs.Default)

    if not Config.Outputs.Allowed[safeOutput] then
        return false, "invalid_output"
    end

    if safeOutput == "vehicle" then
        if not FiveFY.Vehicle or not FiveFY.Vehicle.ConnectCurrent or not FiveFY.Vehicle.ConnectCurrent() then
            return false, "vehicle_missing"
        end
    elseif FiveFY.Vehicle and FiveFY.Vehicle.ClearConnected then
        FiveFY.Vehicle.ClearConnected()
    end

    FiveFY.Bluetooth.output = safeOutput

    if FiveFY.AudioEngine and FiveFY.AudioEngine.SetOutput then
        FiveFY.AudioEngine.SetOutput(safeOutput)
    end

    if safeOutput == "prop" then
        FiveFY.Prop.Ensure()
    elseif safeOutput ~= "prop" and FiveFY.Prop then
        FiveFY.Prop.Delete()
    end

    if FiveFY.Sync then
        FiveFY.Sync.UpdateCurrentSource(true)
    end

    notifyAudioState(nil)

    return true, nil
end

function FiveFY.Bluetooth.AutoOffOutput(reason)
    local output = FiveFY.Bluetooth.GetOutput()

    if output == "off" or output == "private" then
        return false
    end

    FiveFY.Bluetooth.lastAutoOffAt = GetGameTimer()
    FiveFY.Bluetooth.SetOutput("off")
    notifyAudioState(reason or "auto_off")

    return true
end

function FiveFY.Bluetooth.ValidateOutputTarget()
    local output = FiveFY.Bluetooth.GetOutput()

    if output == "off" or output == "private" then
        return true
    end

    if IsEntityDead(PlayerPedId()) then
        FiveFY.Bluetooth.AutoOffOutput("player_dead")
        return false
    end

    if output == "prop" then
        if not FiveFY.Prop or not FiveFY.Prop.Exists() then
            FiveFY.Bluetooth.AutoOffOutput("prop_missing")
            return false
        end

        return true
    end

    if output == "vehicle" then
        local target = FiveFY.Vehicle and FiveFY.Vehicle.GetOutputTarget and FiveFY.Vehicle.GetOutputTarget() or nil

        if not target or not target.sourceCoords then
            if FiveFY.StopPlayback then
                FiveFY.StopPlayback("vehicle_missing")
            end

            FiveFY.Bluetooth.AutoOffOutput("vehicle_missing")
            return false
        end

        if FiveFY.Vehicle.IsOwnerTooFar and FiveFY.Vehicle.IsOwnerTooFar() then
            if FiveFY.StopPlayback then
                FiveFY.StopPlayback("vehicle_owner_too_far")
            end

            FiveFY.Bluetooth.AutoOffOutput("vehicle_owner_too_far")
            return false
        end

        return true
    end

    return true
end

function FiveFY.Bluetooth.GetOutputTarget()
    local output = FiveFY.Bluetooth.GetOutput()

    if output == "off" or output == "private" then
        return {
            sourceType = output
        }
    end

    if output == "prop" then
        local entity, propNetId = FiveFY.Prop.Ensure()
        local propConfig = Config.Range and Config.Range.prop or {}

        if not entity then
            return nil
        end

        return {
            sourceType = "prop",
            sourceCoords = FiveFY.Prop.GetCoords(),
            propNetId = propNetId,
            range = tonumber(propConfig.range) or 16.0,
            volume = tonumber(propConfig.volume) or 78.0
        }
    end

    if output == "vehicle" then
        return FiveFY.Vehicle.GetOutputTarget()
    end

    return nil
end

CreateThread(function()
    while true do
        local output = FiveFY.Bluetooth.GetOutput()

        if output == "prop" or output == "vehicle" then
            FiveFY.Bluetooth.ValidateOutputTarget()
            Wait(1000)
        else
            Wait(1500)
        end
    end
end)
