FiveFly = FiveFly or {}

---@class FrameworkAdapter
---@field name string
---@field resource? string resource that must be started for this adapter to be used
---@field Init? fun(): boolean
---@field GetIdentifier fun(source: integer): string|nil stable per character, never the server id
---@field GetDisplayName? fun(source: integer): string|nil character name
---@field HasPermission? fun(source: integer, permission: string): boolean

FiveFly.Bridge = {
    Adapters = {},
    active = nil
}

local Bridge = FiveFly.Bridge
local DETECTION_ORDER <const> = { "qbx", "qb", "esx", "vrp" }

---@param adapter FrameworkAdapter
function Bridge.Register(adapter)
    Bridge.Adapters[adapter.name] = adapter
end

local function tryActivate(name)
    local adapter = Bridge.Adapters[name]

    if not adapter then
        return false
    end

    if adapter.resource and GetResourceState(adapter.resource) ~= "started" then
        return false
    end

    if adapter.Init then
        local ok, ready = pcall(adapter.Init)

        if not ok or ready == false then
            FiveFly.Log("warn", FiveFly.T("log.adapter_failed", name, tostring(ready)))
            return false
        end
    end

    Bridge.active = adapter
    return true
end

local warnedUnavailable = false

local function getWantedFramework()
    return tostring(Config.Framework or "auto"):lower()
end

--- With an explicit Config.Framework, only that adapter is ever used: while its resource is not started,
--- no adapter is active and players get `identity_unavailable` instead of being saved under another
--- identifier (which would split their data). With "auto", the first started framework wins and
--- standalone is the last resort.
function Bridge.Detect()
    local wanted = getWantedFramework()

    if wanted ~= "auto" then
        if not Bridge.Adapters[wanted] then
            FiveFly.Log("error", FiveFly.T("log.unknown_framework", wanted))
            return nil
        end

        if tryActivate(wanted) then
            return Bridge.active
        end

        if not warnedUnavailable then
            warnedUnavailable = true
            FiveFly.Log("warn", FiveFly.T("log.waiting_framework", wanted))
        end

        return nil
    end

    for _, name in ipairs(DETECTION_ORDER) do
        if tryActivate(name) then
            return Bridge.active
        end
    end

    tryActivate("standalone")
    return Bridge.active
end

local function getAdapter()
    return Bridge.active or Bridge.Detect()
end

--- A framework started after FiveFly (wrong ensure order or a framework restart) replaces standalone.
AddEventHandler("onResourceStart", function(resourceName)
    for _, name in ipairs(DETECTION_ORDER) do
        local adapter = Bridge.Adapters[name]

        if adapter and adapter.resource == resourceName then
            local current = Bridge.active and Bridge.active.name or "none"
            local wanted = getWantedFramework()

            if wanted == name or (wanted == "auto" and (current == "standalone" or current == name or current == "none")) then
                Bridge.active = nil

                if tryActivate(name) then
                    FiveFly.Log(current == "standalone" and "warn" or "info", FiveFly.T(current == "standalone" and "log.framework_late_standalone" or "log.framework_late", name))
                end
            end

            return
        end
    end
end)

function Bridge.GetName()
    local adapter = getAdapter()
    return adapter and adapter.name or "none"
end

---@param source integer
---@return string|nil identifier e.g. "qb:ABC12345", "vrp:42", "license:..."
function Bridge.GetIdentifier(source)
    local adapter = getAdapter()

    if not adapter then
        return nil
    end

    local ok, identifier = pcall(adapter.GetIdentifier, source)

    if not ok then
        FiveFly.Log("debug", "GetIdentifier failed for %s: %s", tostring(source), tostring(identifier))
        return nil
    end

    if type(identifier) ~= "string" or identifier == "" or #identifier > 64 then
        return nil
    end

    return identifier
end

---@param source integer
---@return string
function Bridge.GetDisplayName(source)
    local adapter = getAdapter()
    local name = nil

    if adapter and adapter.GetDisplayName then
        local ok, result = pcall(adapter.GetDisplayName, source)

        if ok and type(result) == "string" then
            name = FiveFly.Utils.Trim(result)
        end
    end

    if not name or name == "" then
        name = FiveFly.Utils.Trim(GetPlayerName(source) or "")
    end

    return name ~= "" and name:sub(1, 48) or ("Player " .. tostring(source))
end

---@param source integer
---@param permission string
---@return boolean
function Bridge.HasPermission(source, permission)
    local adapter = getAdapter()

    if adapter and adapter.HasPermission then
        local ok, allowed = pcall(adapter.HasPermission, source, permission)

        if ok and allowed == true then
            return true
        end
    end

    return IsPlayerAceAllowed(source, permission)
end

--- Rockstar license without the "license:" prefix, used by standalone and as a helper.
function Bridge.GetLicense(source)
    for _, identifier in ipairs(GetPlayerIdentifiers(source) or {}) do
        if identifier:sub(1, 8) == "license:" then
            return identifier:sub(9)
        end
    end

    return nil
end

CreateThread(function()
    -- Give frameworks a moment to finish their own start before detecting.
    Wait(0)
    local adapter = Bridge.Detect()
    FiveFly.Log("info", FiveFly.T("log.framework", adapter and adapter.name or "none"))
end)
