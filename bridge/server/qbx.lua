local function getPlayer(source)
    return exports.qbx_core:GetPlayer(source)
end

FiveFY.Bridge.Register({
    name = "qbx",
    resource = "qbx_core",

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
        return IsPlayerAceAllowed(source, permission)
    end
})
