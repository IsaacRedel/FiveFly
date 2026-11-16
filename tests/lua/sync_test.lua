local H = require("helpers")

local function load()
    local runtime = H.reset()
    FiveFly.Permissions = { CanUse = function() return true end }
    FiveFly.RateLimit = { Allow = function() return true end }
    dofile("server/services/sync.lua")
    return FiveFly.ServerSync, runtime
end

local track = { videoId = "abc", title = "Song" }

return {
    {
        name = "reported range is capped to the largest configured range",
        run = function()
            local sync, runtime = load()
            runtime.playerPeds[1] = vector3(0, 0, 0)

            H.trigger(runtime.netEvents["fivefly:server:updateSource"], 1, {
                track = track,
                sourceType = "prop",
                sourceCoords = { x = 1, y = 0, z = 0 },
                range = 100000,
                volume = 900
            })

            local source = sync.GetSources()[1]
            assert(source, "source registered")
            H.eq(source.range, 58.0, "range capped to soundSystem range")
            H.eq(source.volume, 100, "volume capped")
        end
    },
    {
        name = "reported coordinates far from the player fall back to the player position",
        run = function()
            local sync, runtime = load()
            runtime.playerPeds[1] = vector3(10, 10, 10)

            H.trigger(runtime.netEvents["fivefly:server:updateSource"], 1, {
                track = track,
                sourceType = "prop",
                sourceCoords = { x = 5000, y = 5000, z = 0 }
            })

            local coords = sync.GetSources()[1].sourceCoords
            H.eq(coords.x, 10, "x from ped")
            H.eq(coords.y, 10, "y from ped")
        end
    },
    {
        name = "a speaker netId far from the player is ignored",
        run = function()
            local sync, runtime = load()
            runtime.playerPeds[1] = vector3(0, 0, 0)
            runtime.entities[77] = vector3(3000, 3000, 0)

            H.trigger(runtime.netEvents["fivefly:server:updateSource"], 1, { track = track, sourceType = "prop", propNetId = 77 })

            local coords = sync.GetSources()[1].sourceCoords
            H.eq(coords.x, 0, "player position instead of the remote entity")
        end
    },
    {
        name = "invalid source types and tracks are ignored",
        run = function()
            local sync, runtime = load()
            runtime.playerPeds[1] = vector3(0, 0, 0)
            local handler = runtime.netEvents["fivefly:server:updateSource"]

            H.trigger(handler, 1, { track = track, sourceType = "global" })
            H.eq(sync.GetSources()[1], nil, "unknown source type")

            H.trigger(handler, 1, { track = { title = "no id" }, sourceType = "prop" })
            H.eq(sync.GetSources()[1], nil, "invalid track")

            H.trigger(handler, 1, "not a table")
            H.eq(sync.GetSources()[1], nil, "invalid payload")
        end
    },
    {
        name = "only players inside the range receive the source",
        run = function()
            local sync, runtime = load()
            runtime.playerPeds[1] = vector3(0, 0, 0)
            runtime.playerPeds[2] = vector3(5, 0, 0)
            runtime.playerPeds[3] = vector3(500, 0, 0)

            H.trigger(runtime.netEvents["fivefly:server:updateSource"], 1, { track = track, sourceType = "prop", range = 16 })

            local targets = {}
            for _, event in ipairs(runtime.clientEvents) do
                if event.name == "fivefly:client:sourceAdded" then
                    targets[event.target] = true
                end
            end

            assert(targets[1] and targets[2], "nearby players added")
            assert(not targets[3], "far player not added")
            assert(sync.GetSources()[1].listeners[2], "listener tracked")
        end
    },
    {
        name = "dropping the owner removes the source from listeners",
        run = function()
            local sync, runtime = load()
            runtime.playerPeds[1] = vector3(0, 0, 0)
            runtime.playerPeds[2] = vector3(2, 0, 0)

            H.trigger(runtime.netEvents["fivefly:server:updateSource"], 1, { track = track, sourceType = "prop" })
            runtime.clientEvents = {}
            H.trigger(runtime.events.playerDropped, 1)

            H.eq(sync.GetSources()[1], nil, "source removed")
            H.eq(runtime.clientEvents[1] and runtime.clientEvents[1].name, "fivefly:client:sourceRemoved", "listeners notified")
        end
    }
}
