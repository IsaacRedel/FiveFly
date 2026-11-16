local H = require("helpers")

--- Vehicle entities: id -> { model, display, class, trailer }
local function load(vehicles, pedVehicle)
    H.reset()

    _G.PlayerPedId = function() return "player" end
    _G.GetVehiclePedIsIn = function() return pedVehicle or 0 end
    _G.DoesEntityExist = function(entity) return vehicles[entity] ~= nil end
    _G.GetEntityModel = function(entity) return vehicles[entity].model end
    _G.GetDisplayNameFromVehicleModel = function(model)
        for _, vehicle in pairs(vehicles) do
            if vehicle.model == model then return vehicle.display end
        end
        return "CARNOTFOUND"
    end
    _G.GetVehicleClass = function(entity) return vehicles[entity].class end
    _G.GetHashKey = function(name) return "hash:" .. name:lower() end
    _G.GetVehicleTrailerVehicle = function(entity)
        local trailer = vehicles[entity].trailer
        return trailer ~= nil, trailer or 0
    end
    _G.NetworkGetNetworkIdFromEntity = function(entity) return entity end
    _G.NetworkGetEntityFromNetworkId = function(netId) return netId end
    _G.GetEntityCoords = function() return vector3(0, 0, 0) end

    dofile("client/vehicle.lua")
    return FiveFY.Vehicle
end

return {
    {
        name = "a hitched sound-system trailer becomes the audio source",
        run = function()
            local vehicle = load({
                [1] = { model = "hash:sultan", display = "SULTAN", class = 4, trailer = 2 },
                [2] = { model = "hash:speakertrailer", display = "SPEAKERTRL", class = 11 }
            }, 1)

            assert(vehicle.ConnectCurrent(), "connected")
            local target = vehicle.GetOutputTarget()

            H.eq(target.vehicleNetId, 2, "trailer is the emitter")
            H.eq(target.soundSystem, true, "sound-system profile")
            H.eq(target.range, Config.Range.vehicle.soundSystem.range, "sound-system range")
        end
    },
    {
        name = "a regular trailer keeps the sound in the towing vehicle",
        run = function()
            local vehicle = load({
                [1] = { model = "hash:sultan", display = "SULTAN", class = 4, trailer = 2 },
                [2] = { model = "hash:boattrailer", display = "BOATTRAILER", class = 11 }
            }, 1)

            vehicle.ConnectCurrent()
            local target = vehicle.GetOutputTarget()

            H.eq(target.vehicleNetId, 1, "car is the emitter")
            H.eq(target.profile, "class:4", "class profile")
            H.eq(target.range, Config.Range.vehicle.classProfiles[4].range, "class range")
        end
    },
    {
        name = "configured models match by name",
        run = function()
            local vehicle = load({
                [1] = { model = "hash:pbus2", display = "PBUS2", class = 17 }
            }, 1)

            vehicle.ConnectCurrent()
            H.eq(vehicle.GetOutputTarget().soundSystem, true, "party bus from Config.Range.vehicle.soundSystem.models")
        end
    },
    {
        name = "without a vehicle there is nothing to connect",
        run = function()
            local vehicle = load({}, 0)
            H.eq(vehicle.ConnectCurrent(), false, "not connected")
            H.eq(vehicle.GetOutputTarget(), nil, "no target")
        end
    }
}
