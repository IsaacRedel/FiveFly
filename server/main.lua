--- Request dispatcher: every NUI action reaches the server through `fivefly:server:request`
--- and is answered with `fivefly:client:response` using the envelope { ok, data } / { ok = false, error }.
--- Actions are registered in server/actions/*.lua, which load after this file.
FiveFly.Actions = {
    registry = {}
}

local Actions = FiveFly.Actions

---@class ActionContext
---@field source integer
---@field userId integer

---@class ActionDefinition
---@field rateLimit? integer cooldown in ms per player
---@field handler fun(ctx: ActionContext, payload: table): any, string|nil returns data, or nil plus an error code

---@param name string
---@param definition ActionDefinition
function Actions.Register(name, definition)
    Actions.registry[name] = definition
end

local function ok(data)
    return { ok = true, data = data }
end

local function fail(errorCode)
    return { ok = false, error = tostring(errorCode or "unknown_error") }
end

---@return table response
function Actions.Dispatch(source, action, payload)
    local definition = Actions.registry[action]

    if not definition then
        return fail("unknown_action")
    end

    if not FiveFly.Database.ready then
        return fail("database_not_ready")
    end

    if not FiveFly.Permissions.CanUse(source) then
        return fail("permission_denied")
    end

    if definition.rateLimit and not FiveFly.RateLimit.Allow(source, action, definition.rateLimit) then
        return fail("rate_limited")
    end

    local userId = FiveFly.Identity.GetUserId(source)

    if not userId then
        return fail("identity_unavailable")
    end

    local success, data, errorCode = pcall(definition.handler, { source = source, userId = userId }, payload)

    if not success then
        FiveFly.Log("error", FiveFly.T("log.action_failed", action, tostring(data)))
        return fail("internal_error")
    end

    if errorCode then
        return fail(errorCode)
    end

    return ok(data)
end

RegisterNetEvent("fivefly:server:request", function(requestId, action, payload)
    local source = source
    local safeRequestId = tostring(requestId or ""):sub(1, 64)

    if safeRequestId == "" then
        return
    end

    local response = Actions.Dispatch(source, tostring(action or ""), type(payload) == "table" and payload or {})
    TriggerClientEvent("fivefly:client:response", source, safeRequestId, response)
end)
