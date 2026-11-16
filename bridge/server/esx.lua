local ESX

local function getPlayer(source)
    return ESX and ESX.GetPlayerFromId(source)
end

FiveFY.Bridge.Register({
    name = "esx",
    resource = "es_extended",

    Init = function()
        ESX = exports.es_extended:getSharedObject()
        return ESX ~= nil
    end,

    GetIdentifier = function(source)
        local player = getPlayer(source)
        local identifier = player and player.identifier
        return identifier and ("esx:" .. identifier) or nil
    end,

    GetDisplayName = function(source)
        local player = getPlayer(source)

        if not player then
            return nil
        end

        if type(player.getName) == "function" then
            return player.getName()
        end

        return player.name
    end,

    HasPermission = function(source, permission)
        local player = getPlayer(source)
        return player ~= nil and type(player.getGroup) == "function" and player.getGroup() == permission
    end
})
