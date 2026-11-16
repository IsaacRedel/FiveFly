local Actions = FiveFY.Actions
local Sessions = FiveFY.Sessions

local PLAYBACK_MS <const> = Config.RateLimits.PlaybackMs

--- Wraps a Sessions function that returns (success, session, error).
local function sessionResult(success, session, err)
    if not success then
        return nil, err
    end

    return { session = session }
end

Actions.Register("playback.state.get", {
    handler = function(ctx)
        return Sessions.GetState(ctx.source)
    end
})

Actions.Register("playback.play", {
    rateLimit = PLAYBACK_MS,
    handler = function(ctx, payload)
        return sessionResult(Sessions.Play(ctx.source, payload))
    end
})

Actions.Register("playback.transport", {
    rateLimit = PLAYBACK_MS,
    handler = function(ctx, payload)
        return sessionResult(Sessions.Transport(ctx.source, payload))
    end
})

Actions.Register("playback.queue.set", {
    rateLimit = PLAYBACK_MS,
    handler = function(ctx, payload)
        return sessionResult(Sessions.SetQueue(ctx.source, payload))
    end
})

Actions.Register("playback.mode.set", {
    rateLimit = PLAYBACK_MS,
    handler = function(ctx, payload)
        return sessionResult(Sessions.SetMode(ctx.source, payload))
    end
})

Actions.Register("playback.seek", {
    rateLimit = PLAYBACK_MS,
    handler = function(ctx, payload)
        return sessionResult(Sessions.Seek(ctx.source, payload.position))
    end
})

Actions.Register("playback.sessions.get", {
    handler = function(ctx)
        return { sessions = Sessions.GetSharedSessions(ctx.source) }
    end
})

Actions.Register("playback.friends.get", {
    handler = function(ctx)
        return { friends = Sessions.GetFriendsListening(ctx.source, ctx.userId) }
    end
})

Actions.Register("playback.sessions.join", {
    rateLimit = PLAYBACK_MS,
    handler = function(ctx, payload)
        return sessionResult(Sessions.JoinSharedSession(ctx.source, payload.source))
    end
})
