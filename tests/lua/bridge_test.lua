local H = require("helpers")

local function load(runtime)
    for _, file in ipairs({ "init", "standalone", "qbx", "qb", "esx", "vrp" }) do
        dofile(("bridge/server/%s.lua"):format(file))
    end

    return FiveFY.Bridge, runtime
end

return {
    {
        name = "falls back to standalone and uses the Rockstar license",
        run = function()
            local runtime = H.reset()
            runtime.identifiers = { [7] = { "steam:110000100000001", "license:abc123" } }
            local bridge = load(runtime)

            H.eq(bridge.Detect().name, "standalone", "adapter")
            H.eq(bridge.GetIdentifier(7), "license:abc123", "identifier")
            H.eq(bridge.GetIdentifier(8), nil, "player without license")
            H.eq(bridge.GetDisplayName(7), "Player7", "display name falls back to GetPlayerName")
        end
    },
    {
        name = "auto-detects qb-core and never falls back to the server id",
        run = function()
            local runtime = H.reset()
            runtime.resourceStates["qb-core"] = "started"
            local players = {
                [3] = { PlayerData = { citizenid = "ABC12345", charinfo = { firstname = "Ana", lastname = "Silva" } } }
            }
            exports["qb-core"] = {
                GetCoreObject = function()
                    return {
                        Functions = {
                            GetPlayer = function(src) return players[src] end,
                            HasPermission = function(src, perm) return src == 3 and perm == "admin" end
                        }
                    }
                end
            }
            local bridge = load(runtime)

            H.eq(bridge.Detect().name, "qb", "adapter")
            H.eq(bridge.GetIdentifier(3), "qb:ABC12345", "citizenid identifier")
            H.eq(bridge.GetIdentifier(4), nil, "no character loaded")
            H.eq(bridge.GetDisplayName(3), "Ana Silva", "character name")
            H.eq(bridge.HasPermission(3, "admin"), true, "framework permission")
            H.eq(bridge.HasPermission(4, "admin"), false, "no permission")
        end
    },
    {
        name = "an explicit Config.Framework never falls back to another identifier",
        run = function()
            local runtime = H.reset()
            Config.Framework = "esx"
            runtime.identifiers = { [1] = { "license:zzz" } }
            local bridge = load(runtime)

            H.eq(bridge.Detect(), nil, "esx not started -> no adapter")
            H.eq(bridge.GetIdentifier(1), nil, "no license fallback while waiting")
        end
    },
    {
        name = "a framework started after fivefy replaces standalone",
        run = function()
            local runtime = H.reset()
            runtime.identifiers = { [1] = { "license:zzz" } }
            local bridge = load(runtime)
            H.eq(bridge.Detect().name, "standalone", "nothing started yet")

            runtime.resourceStates.qbx_core = "started"
            exports.qbx_core = { GetPlayer = function() return { PlayerData = { citizenid = "CID1" } } end }
            runtime.events.onResourceStart("qbx_core")

            H.eq(bridge.GetName(), "qbx", "switched to qbx")
            H.eq(bridge.GetIdentifier(1), "qb:CID1", "citizenid")
        end
    },
    {
        name = "vRP adapter works with a Proxy that needs module, async and table.maxn (no utils.lua)",
        run = function()
            local runtime = H.reset()
            runtime.resourceStates.vrp = "started"
            table.maxn = nil

            -- Await stubs: the fake Proxy resolves synchronously.
            _G.promise = { new = function() return { resolve = function(self, value) self.value = value end } end }
            _G.Citizen = { Await = function(p) return p.value end, CreateThreadNow = function(fn) fn() end }

            local files = {
                ["lib/Tools.lua"] = "return { tag = 'tools' }",
                -- Mirrors the real vRP Proxy: depends on module(), async() and table.maxn().
                ["lib/Proxy.lua"] = [[
                    local Tools = module("lib/Tools")
                    assert(Tools.tag == "tools")
                    local impl = {
                        getUserId = function(src) return src == 5 and 42 or nil end,
                        getUserIdentity = function() return { firstname = "John", name = "Doe" } end,
                        hasPermission = function(userId, perm) return userId == 42 and perm == "vip" end
                    }
                    return {
                        getInterface = function()
                            return setmetatable({}, { __index = function(_, name)
                                return function(...)
                                    local r = async()
                                    local args = { ... }
                                    r(impl[name](table.unpack(args, 1, table.maxn(args))))
                                    return r:wait()
                                end
                            end })
                        end
                    }
                ]]
            }
            _G.LoadResourceFile = function(resource, path)
                return resource == "vrp" and files[path] or nil
            end
            local bridge = load(runtime)

            H.eq(bridge.Detect().name, "vrp", "adapter")
            H.eq(bridge.GetIdentifier(5), "vrp:42", "user id identifier")
            H.eq(bridge.GetIdentifier(6), nil, "not logged in")
            H.eq(bridge.GetDisplayName(5), "John Doe", "classic vRP identity")
            H.eq(bridge.HasPermission(5, "vip"), true, "vRP permission")
        end
    },
    {
        name = "vRP adapter runs vrp/lib/utils.lua when it exists",
        run = function()
            local runtime = H.reset()
            runtime.resourceStates.vrp = "started"
            local ranUtils = false
            _G.markUtils = function() ranUtils = true end
            local files = {
                ["lib/utils.lua"] = [[
                    markUtils()
                    function module() return { getInterface = function() return { getUserId = function() return 7 end } end } end
                    function async() return nil end
                ]],
                ["lib/Proxy.lua"] = "return {}"
            }
            _G.LoadResourceFile = function(resource, path)
                return resource == "vrp" and files[path] or nil
            end
            local bridge = load(runtime)

            H.eq(bridge.Detect().name, "vrp", "adapter")
            H.eq(ranUtils, true, "utils.lua executed")
            H.eq(bridge.GetIdentifier(1), "vrp:7", "Proxy from utils' module()")
            _G.markUtils = nil
        end
    },
    {
        name = "invalid identifiers are rejected",
        run = function()
            local runtime = H.reset()
            local bridge = load(runtime)
            bridge.Register({ name = "broken", GetIdentifier = function() return string.rep("x", 80) end })
            Config.Framework = "broken"
            bridge.active = nil

            H.eq(bridge.GetIdentifier(1), nil, "identifier longer than 64 chars")
        end
    }
}
