FiveFY.Permissions = {}

--- Whether the player may use FiveFY (always true unless Config.RequirePermission is enabled).
---@param source integer
---@return boolean
function FiveFY.Permissions.CanUse(source)
    if not Config.RequirePermission then
        return true
    end

    local permission = tostring(Config.Permission or "")
    return permission ~= "" and FiveFY.Bridge.HasPermission(source, permission)
end
