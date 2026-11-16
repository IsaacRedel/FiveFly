local H = require("helpers")

local function load()
    local runtime = H.reset()
    local recorded = { plays = {}, skips = {} }

    FiveFly.Identity = { GetUserId = function(src) return src * 10 end }
    FiveFly.Repo = {
        Tracks = {
            AddHistory = function(userId, track) recorded.plays[#recorded.plays + 1] = userId .. ":" .. track.videoId end,
            RecordStat = function(userId, track, kind) if kind == "skip" then recorded.skips[#recorded.skips + 1] = userId .. ":" .. track.videoId end end
        },
        Profiles = {
            GetFollowedSet = function() return {} end,
            CanShowActivity = function() return true end
        }
    }
    FiveFly.Bridge = { GetDisplayName = function(src) return "Host" .. src end }
    FiveFly.ServerSync = { GetSources = function() return runtime.syncSources or {} end }

    dofile("server/services/sessions.lua")
    return FiveFly.Sessions, recorded, runtime
end

local queue = {
    { videoId = "a", title = "A" },
    { videoId = "b", title = "B" },
    { videoId = "c", title = "C" }
}

return {
    {
        name = "Play keeps the queue order and starts at startIndex",
        run = function()
            local sessions, recorded = load()
            local ok, session = sessions.Play(1, { queue = queue, startIndex = 2 })

            assert(ok, "play succeeded")
            H.eq(session.currentTrack.videoId, "b", "current track")
            H.eq(session.queue[1].videoId, "a", "queue order preserved")
            H.eq(session.status, "online", "status")
            H.eq(recorded.plays[1], "10:b", "history recorded with internal user id")
        end
    },
    {
        name = "Play rejects an empty queue and clamps an invalid startIndex",
        run = function()
            local sessions = load()
            local ok, _, err = sessions.Play(1, { queue = { { title = "invalid" } } })

            H.eq(ok, false, "empty queue rejected")
            H.eq(err, "empty_queue", "error code")

            local _, session = sessions.Play(1, { queue = queue, startIndex = 99 })
            H.eq(session.currentIndex, 1, "startIndex out of range")
        end
    },
    {
        name = "Play starts at the chosen track even when the queue was trimmed or had invalid entries",
        run = function()
            local sessions = load()

            -- An invalid entry before the chosen track shifts every index by one.
            local _, session = sessions.Play(1, { track = queue[3], startIndex = 4, queue = { queue[1], { title = "bad" }, queue[2], queue[3] } })
            H.eq(session.currentTrack.videoId, "c", "chosen track, not its neighbour")

            -- The chosen track is missing from the (trimmed) queue: it is inserted first.
            _, session = sessions.Play(1, { track = { videoId = "z", title = "Z" }, startIndex = 80, queue = queue })
            H.eq(session.currentTrack.videoId, "z", "chosen track played")
            H.eq(session.queue[2].videoId, "a", "rest of the queue kept")

            -- Duplicates: startIndex picks the closest occurrence.
            _, session = sessions.Play(1, { track = queue[1], startIndex = 3, queue = { queue[1], queue[2], queue[1] } })
            H.eq(session.currentIndex, 3, "closest duplicate")
        end
    },
    {
        name = "client stream URLs are kept only for configured stations",
        run = function()
            local sessions = load()
            Config.Stations = { { id = "radio", tracks = { { videoId = "radio-1", streamUrl = "https://radio.example/live.mp3" } } } }

            local _, session = sessions.Play(1, { queue = {
                { videoId = "radio-1", title = "Radio", streamUrl = "https://evil.example/track.mp3" },
                { videoId = "x", title = "X", streamUrl = "https://evil.example/x.mp3" }
            } })

            H.eq(session.queue[1].streamUrl, "https://radio.example/live.mp3", "replaced by the configured URL")
            H.eq(session.queue[2].streamUrl, "", "unknown stream removed")
        end
    },
    {
        name = "next skips record stats only when the user skipped",
        run = function()
            local sessions, recorded = load()
            sessions.Play(1, { queue = queue })

            sessions.Transport(1, { action = "next" })
            H.eq(recorded.skips[1], "10:a", "manual skip recorded")

            local _, session = sessions.Transport(1, { action = "next", reason = "ended" })
            H.eq(#recorded.skips, 1, "natural end is not a skip")
            H.eq(session.currentTrack.videoId, "c", "advanced")

            _, session = sessions.Transport(1, { action = "next", reason = "ended" })
            H.eq(session.status, "idle", "end of queue")
            H.eq(session.currentTrack, nil, "nothing playing")
        end
    },
    {
        name = "repeat all wraps and repeat one restarts the same track",
        run = function()
            local sessions = load()
            sessions.Play(1, { queue = queue, startIndex = 3 })
            sessions.SetMode(1, { ["repeat"] = "all" })

            local _, session = sessions.Transport(1, { action = "next", reason = "ended" })
            H.eq(session.currentTrack.videoId, "a", "wrapped to first")

            sessions.SetMode(1, { ["repeat"] = "one" })
            _, session = sessions.Transport(1, { action = "next", reason = "ended" })
            H.eq(session.currentTrack.videoId, "a", "same track")

            local ok, _, err = sessions.SetMode(1, { ["repeat"] = "forever" })
            H.eq(ok, false, "invalid repeat mode")
            H.eq(err, "invalid_repeat", "error code")
        end
    },
    {
        name = "SetQueue keeps the current track and Seek validates the position",
        run = function()
            local sessions = load()
            sessions.Play(1, { queue = queue, startIndex = 2 })

            local _, session = sessions.SetQueue(1, { queue = { queue[3], queue[1] } })
            H.eq(session.queue[1].videoId, "b", "current track reinserted first")
            H.eq(session.currentIndex, 1, "index follows the current track")

            local ok = sessions.Seek(1, -5)
            H.eq(ok, false, "negative position rejected")
            ok, session = sessions.Seek(1, 61.6)
            H.eq(session.playback.position, 62, "rounded position")
        end
    },
    {
        name = "stop keeps the nonce increasing and playerDropped clears the session",
        run = function()
            local sessions, _, runtime = load()
            local _, session = sessions.Play(1, { queue = queue })
            local nonce = session.playback.nonce

            _, session = sessions.Transport(1, { action = "stop" })
            assert(session.playback.nonce > nonce, "nonce increased after stop")

            sessions.Play(2, { queue = queue })
            H.trigger(runtime.events.playerDropped, 2)
            H.eq(sessions.GetState(2).currentTrack, nil, "a new player with the same id starts clean")
        end
    },
    {
        name = "joining a shared session copies the host queue",
        run = function()
            local sessions, _, runtime = load()
            sessions.Play(4, { queue = queue, startIndex = 2 })

            local ok, _, err = sessions.JoinSharedSession(1, 4)
            H.eq(ok, false, "host without a speaker source")
            H.eq(err, "session_not_found", "error code")

            runtime.syncSources = { [4] = { sourceType = "prop" } }
            local joined, session = sessions.JoinSharedSession(1, 4)
            assert(joined, "joined")
            H.eq(session.currentTrack.videoId, "b", "host track")
            H.eq(sessions.GetSharedSessions(1)[1].host, "Host4", "listed as shared")
            H.eq(#sessions.GetSharedSessions(4), 0, "host does not see itself")
        end
    }
}
