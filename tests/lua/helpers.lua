--- Minimal FiveM runtime stubs so resource files can be loaded with plain Lua 5.4.
--- Run every test from the repository root: lua tests/lua/run.lua
local Helpers = {}

local Vector = {}
Vector.__index = Vector

function Vector.__sub(a, b)
    return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, Vector)
end

function Vector.__len(v)
    return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
end

function Vector.__eq(a, b)
    return a.x == b.x and a.y == b.y and a.z == b.z
end

--- Resets globals and loads config + shared utils. Returns a table to register handlers/events.
function Helpers.reset()
    local runtime = {
        netEvents = {},
        events = {},
        nuiCallbacks = {},
        exports = {},
        threads = 0,
        resourceStates = {},
        aces = {},
        playerPeds = {},
        entities = {},
        clientEvents = {},
        serverEvents = {},
        logs = {}
    }

    _G.FiveFly = nil
    _G.Config = nil
    _G.source = nil
    _G.module = nil
    _G.async = nil
    _G.LoadResourceFile = function() return nil end

    _G.vector3 = function(x, y, z)
        return setmetatable({ x = x, y = y, z = z }, Vector)
    end

    _G.GetCurrentResourceName = function() return "fivefly" end
    _G.GetGameTimer = function() return runtime.now or 0 end
    _G.CreateThread = function() runtime.threads = runtime.threads + 1 end
    _G.Wait = function() end
    _G.SetTimeout = function() end
    _G.print = function(...) runtime.logs[#runtime.logs + 1] = table.concat({ ... }, " ") end
    _G.GetResourceState = function(name) return runtime.resourceStates[name] or "missing" end
    _G.IsPlayerAceAllowed = function(src, ace) return runtime.aces[tostring(src) .. ":" .. ace] == true end
    _G.GetPlayerName = function(src) return "Player" .. tostring(src) end
    _G.GetPlayerIdentifiers = function(src) return runtime.identifiers and runtime.identifiers[src] or {} end
    _G.GetConvar = function(_, default) return default end
    _G.GetPlayers = function()
        local players = {}
        for id in pairs(runtime.playerPeds) do players[#players + 1] = tostring(id) end
        return players
    end
    _G.GetPlayerPed = function(src) return runtime.playerPeds[src] and ("ped:" .. src) or 0 end
    _G.DoesEntityExist = function(entity) return entity ~= nil and entity ~= 0 end
    _G.GetEntityCoords = function(entity)
        if type(entity) == "string" and entity:sub(1, 4) == "ped:" then
            return runtime.playerPeds[tonumber(entity:sub(5))]
        end
        return runtime.entities[entity]
    end
    _G.NetworkGetEntityFromNetworkId = function(netId) return runtime.entities[netId] and netId or 0 end
    _G.RegisterNetEvent = function(name, handler) runtime.netEvents[name] = handler end
    _G.AddEventHandler = function(name, handler) runtime.events[name] = handler end
    _G.RegisterNUICallback = function(name, handler) runtime.nuiCallbacks[name] = handler end
    _G.TriggerClientEvent = function(name, target, ...) runtime.clientEvents[#runtime.clientEvents + 1] = { name = name, target = target, args = { ... } } end
    _G.TriggerServerEvent = function(name, ...) runtime.serverEvents[#runtime.serverEvents + 1] = { name = name, args = { ... } } end
    _G.exports = setmetatable({}, {
        __call = function(_, name, fn) runtime.exports[name] = fn end
    })
    _G.MySQL = { ready = function() end }

    dofile("config.lua")
    dofile("shared/utils.lua")
    dofile("shared/locale.lua")

    return runtime
end

--- Calls a net event handler as if `src` triggered it.
function Helpers.trigger(handler, src, ...)
    _G.source = src
    return handler(...)
end

function Helpers.eq(actual, expected, message)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(message or "assertion failed", tostring(expected), tostring(actual)), 2)
    end
end

function Helpers.near(actual, expected, tolerance, message)
    if math.abs(actual - expected) > (tolerance or 1e-6) then
        error(("%s: expected ~%s, got %s"):format(message or "assertion failed", tostring(expected), tostring(actual)), 2)
    end
end

return Helpers
