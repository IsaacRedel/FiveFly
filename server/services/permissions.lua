FiveFly.Permissions = {}

--- Whether the player may use FiveFly (always true unless Config.RequirePermission is enabled).
---@param source integer
---@return boolean
function FiveFly.Permissions.CanUse(source)
    if not Config.RequirePermission then
        return true
    end

    local permission = tostring(Config.Permission or "")
    return permission ~= "" and FiveFly.Bridge.HasPermission(source, permission)
end
