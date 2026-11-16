--- Desktop panel: a larger UI rendered in the same page as the audio engine (ui/engine/index.html).
FiveFly.Panel = {
    open = false
}

local Panel = FiveFly.Panel

local function setOpen(open)
    if Panel.open == open then
        return
    end

    Panel.open = open
    SetNuiFocus(open, open)
    SendNUIMessage({ target = "panel", action = open and "open" or "close" })
end

function Panel.Open()
    if not Config.Panel.Enabled or Panel.open then
        return
    end

    local canOpen = Config.Panel.CanOpen

    if type(canOpen) == "function" then
        local ok, allowed = pcall(canOpen)

        if ok and allowed == false then
            return
        end
    end

    setOpen(true)
end

function Panel.Close()
    setOpen(false)
end

function Panel.Toggle()
    if Panel.open then
        Panel.Close()
    else
        Panel.Open()
    end
end

RegisterNUICallback("panel.close", function(_, cb)
    Panel.Close()
    cb({ ok = true })
end)

if Config.Panel.Enabled then
    local command = tostring(Config.Panel.Command or "fivefly")

    RegisterCommand(command, Panel.Toggle, false)

    if Config.Panel.DefaultKey ~= nil then
        RegisterKeyMapping(command, Config.Panel.KeyDescription or FiveFly.T("panel.key_description"), "keyboard", Config.Panel.DefaultKey)
    end

    -- Close when the player dies while the panel is open.
    CreateThread(function()
        while true do
            if Panel.open then
                if IsEntityDead(PlayerPedId()) then
                    Panel.Close()
                end

                Wait(500)
            else
                Wait(1500)
            end
        end
    end)
end

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() and Panel.open then
        SetNuiFocus(false, false)
    end
end)
