--- Registers FiveFly as a custom lb-phone app (only when Config.Phone.Enabled and lb-phone is running).
local RESOURCE_NAME <const> = GetCurrentResourceName()
local REGISTER_DELAY_MS <const> = 1000

local function getPhoneResource()
    return Config.Phone.Resource or "lb-phone"
end

local function registerApp()
    if not FiveFly.IsPhoneAvailable() then
        return
    end

    local phone = getPhoneResource()
    local app = {
        identifier = Config.Phone.Identifier,
        name = Config.Phone.Name,
        description = Config.Phone.Description or FiveFly.T("app.description"),
        developer = Config.Phone.Developer,
        resourceName = RESOURCE_NAME,
        defaultApp = Config.Phone.DefaultApp,
        size = Config.Phone.Size,
        fixBlur = true,
        ui = ("%s/ui/dist/index.html"):format(RESOURCE_NAME),
        icon = ("https://cfx-nui-%s/ui/dist/icon.svg"):format(RESOURCE_NAME)
    }

    pcall(function()
        exports[phone]:RemoveCustomApp(Config.Phone.Identifier)
    end)

    local ok, added, errorMessage = pcall(function()
        return exports[phone]:AddCustomApp(app)
    end)

    if not ok or not added then
        FiveFly.Log("error", FiveFly.T("log.phone_register_failed", tostring(errorMessage or added)))
    end
end

CreateThread(function()
    if not Config.Phone.Enabled then
        return
    end

    -- Wait a limited time for lb-phone; onClientResourceStart covers a later start.
    for _ = 1, 60 do
        if GetResourceState(getPhoneResource()) == "started" then
            Wait(REGISTER_DELAY_MS)
            registerApp()
            return
        end

        Wait(1000)
    end
end)

AddEventHandler("onClientResourceStart", function(resourceName)
    if resourceName == getPhoneResource() then
        Wait(REGISTER_DELAY_MS)
        registerApp()
    end
end)

AddEventHandler("onClientResourceStop", function(resourceName)
    if resourceName ~= RESOURCE_NAME or not FiveFly.IsPhoneAvailable() then
        return
    end

    pcall(function()
        exports[getPhoneResource()]:RemoveCustomApp(Config.Phone.Identifier)
    end)
end)
