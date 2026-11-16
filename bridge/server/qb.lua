local QBCore

local function getPlayer(source)
    return QBCore and QBCore.Functions.GetPlayer(source)
end

FiveFly.Bridge.Register({
    name = "qb",
    resource = "qb-core",

    Init = function()
        QBCore = exports["qb-core"]:GetCoreObject()
        return QBCore ~= nil
    end,

    -- Same prefix as qbx: both use citizenid, so a server can migrate between them without losing data.
    GetIdentifier = function(source)
        local player = getPlayer(source)
        local citizenId = player and player.PlayerData and player.PlayerData.citizenid
        return citizenId and ("qb:" .. citizenId) or nil
    end,

    GetDisplayName = function(source)
        local player = getPlayer(source)
        local charinfo = player and player.PlayerData and player.PlayerData.charinfo

        if type(charinfo) ~= "table" then
            return nil
        end

        return ("%s %s"):format(charinfo.firstname or "", charinfo.lastname or "")
    end,

    HasPermission = function(source, permission)
        return QBCore.Functions.HasPermission(source, permission) == true
    end
})
