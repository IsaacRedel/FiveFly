local H = require("helpers")

local function load(options)
    local runtime = H.reset()
    options = options or {}

    FiveFly.Database = { ready = options.dbReady ~= false }
    FiveFly.Permissions = { CanUse = function() return options.allowed ~= false end }
    FiveFly.Identity = {
        GetUserId = function(src)
            if options.noIdentity then
                return nil
            end

            return src + 100
        end
    }
    FiveFly.RateLimit = nil
    dofile("server/services/rate_limit.lua")
    dofile("server/main.lua")

    FiveFly.Actions.Register("test.echo", {
        rateLimit = 500,
        handler = function(ctx, payload) return { userId = ctx.userId, value = payload.value } end
    })
    FiveFly.Actions.Register("test.fail", {
        handler = function() return nil, "custom_error" end
    })
    FiveFly.Actions.Register("test.crash", {
        handler = function() error("boom") end
    })

    return FiveFly.Actions, runtime
end

return {
    {
        name = "dispatches to the handler with the internal user id",
        run = function()
            local actions, runtime = load()
            runtime.now = 1000

            local response = actions.Dispatch(1, "test.echo", { value = 7 })
            H.eq(response.ok, true, "ok")
            H.eq(response.data.userId, 101, "internal user id")
            H.eq(response.data.value, 7, "payload")
        end
    },
    {
        name = "applies the per-action rate limit",
        run = function()
            local actions, runtime = load()
            runtime.now = 1000
            actions.Dispatch(1, "test.echo", {})

            H.eq(actions.Dispatch(1, "test.echo", {}).error, "rate_limited", "second call blocked")
            H.eq(actions.Dispatch(2, "test.echo", {}).ok, true, "other player not affected")

            runtime.now = 1600
            H.eq(actions.Dispatch(1, "test.echo", {}).ok, true, "allowed after cooldown")
        end
    },
    {
        name = "returns error envelopes for unknown actions, permission, identity and database state",
        run = function()
            local actions = load()
            H.eq(actions.Dispatch(1, "nope", {}).error, "unknown_action", "unknown action")
            H.eq(actions.Dispatch(1, "test.fail", {}).error, "custom_error", "handler error")

            actions = load({ allowed = false })
            H.eq(actions.Dispatch(1, "test.fail", {}).error, "permission_denied", "permission")

            actions = load({ noIdentity = true })
            H.eq(actions.Dispatch(1, "test.fail", {}).error, "identity_unavailable", "identity")

            actions = load({ dbReady = false })
            H.eq(actions.Dispatch(1, "test.fail", {}).error, "database_not_ready", "database")
        end
    },
    {
        name = "handler errors are contained",
        run = function()
            local actions = load()
            H.eq(actions.Dispatch(1, "test.crash", {}).error, "internal_error", "internal error")
        end
    },
    {
        name = "the net event answers with the same request id",
        run = function()
            local _, runtime = load()
            runtime.now = 5000

            H.trigger(runtime.netEvents["fivefly:server:request"], 9, "req-1", "test.echo", { value = 1 })
            local event = runtime.clientEvents[1]

            H.eq(event.name, "fivefly:client:response", "response event")
            H.eq(event.target, 9, "sent to the caller")
            H.eq(event.args[1], "req-1", "request id")
            H.eq(event.args[2].ok, true, "envelope")

            runtime.clientEvents = {}
            H.trigger(runtime.netEvents["fivefly:server:request"], 9, "", "test.echo", {})
            H.eq(#runtime.clientEvents, 0, "empty request id ignored")
        end
    }
}
