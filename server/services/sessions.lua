--- Per-player playback sessions (queue, current track, repeat/shuffle). In memory only.
FiveFly.Sessions = {}

local Sessions = FiveFly.Sessions
local Utils = FiveFly.Utils

---@class Session
---@field queue Track[]
---@field currentTrack Track|nil
---@field currentIndex integer|nil
---@field status "idle"|"online"|"paused"
---@field repeatMode "off"|"all"|"one"
---@field shuffle boolean
---@field playback { position: number, startedAt: integer, nonce: integer }

---@type table<integer, Session>
local sessions = {}

---@return Session
function Sessions.Empty()
    return {
        queue = {},
        currentTrack = nil,
        currentIndex = nil,
        status = "idle",
        repeatMode = "off",
        ["repeat"] = "off",
        shuffle = false,
        playback = { position = 0, startedAt = 0, nonce = 0 }
    }
end

local function normalizeQueue(queue)
    return Utils.NormalizeClientTrackList(queue, Config.Playback.MaxQueueSize)
end

---@return Session
local function getSession(source)
    local session = sessions[source]

    if not session then
        session = Sessions.Empty()
        sessions[source] = session
    end

    return session
end

local function bumpNonce(session)
    session.playback.nonce = (session.playback.nonce or 0) + 1
end

local function resetProgress(session)
    session.playback.position = 0
    session.playback.startedAt = os.time()
end

local function setCurrentIndex(session, index)
    local track = session.queue[index]

    if not track then
        return false
    end

    session.currentIndex = index
    session.currentTrack = track
    session.status = "online"
    resetProgress(session)

    return true
end

local function chooseShuffleIndex(session)
    local size = #session.queue
    local current = tonumber(session.currentIndex) or 1

    if size <= 1 then
        return current
    end

    local nextIndex = math.random(1, size - 1)
    return nextIndex >= current and nextIndex + 1 or nextIndex
end

local function setRepeat(session, mode)
    session.repeatMode = mode
    session["repeat"] = mode
end

local function recordPlay(source, track)
    local userId = FiveFly.Identity.GetUserId(source)

    if userId then
        FiveFly.Repo.Tracks.AddHistory(userId, track)
    end
end

local function recordSkip(source, track)
    local userId = FiveFly.Identity.GetUserId(source)

    if userId then
        FiveFly.Repo.Tracks.RecordStat(userId, track, "skip")
    end
end

---@return Session
function Sessions.GetState(source)
    return getSession(source)
end

--- Copy of a host session for a listener joining it, restarting at the host's current position.
local function cloneSession(session)
    local cloned = Sessions.Empty()

    cloned.queue = normalizeQueue(session.queue)
    cloned.currentIndex = tonumber(session.currentIndex)
    cloned.currentTrack = Utils.NormalizeTrack(session.currentTrack)
    cloned.status = session.status == "paused" and "paused" or "online"
    cloned.shuffle = session.shuffle == true
    setRepeat(cloned, session.repeatMode or "off")
    cloned.playback = {
        position = tonumber(session.playback and session.playback.position) or 0,
        startedAt = os.time(),
        nonce = ((session.playback and session.playback.nonce) or 0) + 1
    }

    return cloned
end

local function describeHost(hostSource, sourceInfo, session)
    return {
        source = hostSource,
        host = FiveFly.Bridge.GetDisplayName(hostSource),
        output = tostring(sourceInfo.sourceType or "prop"),
        currentTrack = Utils.NormalizeTrack(session.currentTrack),
        queueCount = #session.queue
    }
end

--- Sessions currently playing through a speaker or vehicle (audible to others).
function Sessions.GetSharedSessions(source)
    local shared = {}

    for hostSource, sourceInfo in pairs(FiveFly.ServerSync.GetSources()) do
        local session = sessions[hostSource]

        if hostSource ~= source and session and session.currentTrack then
            shared[#shared + 1] = describeHost(hostSource, sourceInfo, session)
        end
    end

    return shared
end

--- Shared sessions hosted by profiles the player follows and that allow showing activity.
function Sessions.GetFriendsListening(source, userId)
    local candidates = {}
    local userIds = {}

    for hostSource, sourceInfo in pairs(FiveFly.ServerSync.GetSources()) do
        local session = sessions[hostSource]

        if hostSource ~= source and session and session.currentTrack then
            local hostUserId = FiveFly.Identity.GetUserId(hostSource)

            if hostUserId then
                candidates[#candidates + 1] = { source = hostSource, userId = hostUserId, info = sourceInfo, session = session }
                userIds[#userIds + 1] = hostUserId
            end
        end
    end

    local followed = FiveFly.Repo.Profiles.GetFollowedSet(userId, userIds)
    local friends = {}

    for _, candidate in ipairs(candidates) do
        if followed[candidate.userId] and FiveFly.Repo.Profiles.CanShowActivity(candidate.userId) then
            local entry = describeHost(candidate.source, candidate.info, candidate.session)
            entry.userId = candidate.userId
            friends[#friends + 1] = entry
        end
    end

    return friends
end

---@return boolean success, Session session, string|nil error
function Sessions.JoinSharedSession(source, targetSource)
    local hostSource = tonumber(targetSource)

    if not hostSource or hostSource == source then
        return false, getSession(source), "invalid_session"
    end

    local hostSession = sessions[hostSource]

    if not FiveFly.ServerSync.GetSources()[hostSource] or not hostSession or not hostSession.currentTrack then
        return false, getSession(source), "session_not_found"
    end

    local session = cloneSession(hostSession)
    sessions[source] = session

    return true, session, nil
end

---@return boolean success, Session session, string|nil error
function Sessions.Play(source, payload)
    local session = getSession(source)
    local queue = normalizeQueue(payload.queue)
    local track = Utils.NormalizeClientTrack(payload.track)
    local hint = math.floor(tonumber(payload.startIndex) or 1)
    local startIndex = nil

    -- The chosen track decides where playback starts: the queue may have been trimmed or had invalid
    -- entries removed, so startIndex is only a tiebreaker between duplicates of the same track.
    if track then
        for index, queued in ipairs(queue) do
            if queued.videoId == track.videoId and (not startIndex or math.abs(index - hint) < math.abs(startIndex - hint)) then
                startIndex = index
            end
        end

        if not startIndex then
            table.insert(queue, 1, track)
            startIndex = 1

            if #queue > Config.Playback.MaxQueueSize then
                queue[#queue] = nil
            end
        end
    end

    if #queue == 0 then
        return false, session, "empty_queue"
    end

    if not startIndex then
        startIndex = (hint >= 1 and hint <= #queue) and hint or 1
    end

    session.queue = queue
    setCurrentIndex(session, startIndex)
    bumpNonce(session)
    recordPlay(source, session.currentTrack)

    return true, session, nil
end

---@return boolean success, Session session, string|nil error
function Sessions.Transport(source, payload)
    local session = getSession(source)
    local action = tostring(payload.action or "")
    local position = tonumber(payload.position)

    local function applyPosition()
        if position and position >= 0 then
            session.playback.position = math.floor(position + 0.5)
        end

        session.playback.startedAt = os.time()
    end

    if action == "pause" then
        applyPosition()
        session.status = session.currentTrack and "paused" or "idle"
    elseif action == "resume" or action == "play" then
        applyPosition()
        session.status = session.currentTrack and "online" or "idle"
    elseif action == "next" then
        if payload.reason ~= "ended" and session.currentTrack then
            recordSkip(source, session.currentTrack)
        end

        local nextIndex = (tonumber(session.currentIndex) or 0) + 1

        if session.repeatMode == "one" and session.currentTrack then
            resetProgress(session)
            session.status = "online"
        elseif session.shuffle and #session.queue > 0 then
            setCurrentIndex(session, chooseShuffleIndex(session))
        elseif session.queue[nextIndex] then
            setCurrentIndex(session, nextIndex)
        elseif session.repeatMode == "all" and session.queue[1] then
            setCurrentIndex(session, 1)
        else
            session.status = "idle"
            session.currentIndex = nil
            session.currentTrack = nil
        end

        if session.currentTrack and payload.reason == "ended" then
            recordPlay(source, session.currentTrack)
        end
    elseif action == "prev" then
        local previousIndex = math.max(1, (tonumber(session.currentIndex) or 1) - 1)

        if session.shuffle and #session.queue > 0 then
            setCurrentIndex(session, chooseShuffleIndex(session))
        elseif session.queue[previousIndex] then
            setCurrentIndex(session, previousIndex)
        elseif session.repeatMode == "all" and session.queue[#session.queue] then
            setCurrentIndex(session, #session.queue)
        end
    elseif action == "stop" then
        local nonce = session.playback.nonce
        session = Sessions.Empty()
        session.playback.nonce = nonce
        sessions[source] = session
    else
        return false, session, "invalid_action"
    end

    bumpNonce(session)
    return true, session, nil
end

---@return boolean success, Session session, string|nil error
function Sessions.SetQueue(source, payload)
    local session = getSession(source)

    if not session.currentTrack then
        return false, session, "nothing_playing"
    end

    local queue = normalizeQueue(payload.queue)
    local currentVideoId = session.currentTrack.videoId
    local currentIndex = nil

    for index, track in ipairs(queue) do
        if track.videoId == currentVideoId then
            currentIndex = index
            break
        end
    end

    if not currentIndex then
        table.insert(queue, 1, session.currentTrack)
        currentIndex = 1

        if #queue > Config.Playback.MaxQueueSize then
            queue[#queue] = nil
        end
    end

    session.queue = queue
    session.currentIndex = currentIndex
    session.currentTrack = queue[currentIndex]
    bumpNonce(session)

    return true, session, nil
end

---@return boolean success, Session session, string|nil error
function Sessions.SetMode(source, payload)
    local session = getSession(source)

    if payload.shuffle ~= nil then
        session.shuffle = payload.shuffle == true
    end

    if payload["repeat"] ~= nil then
        local mode = tostring(payload["repeat"])

        if mode ~= "off" and mode ~= "all" and mode ~= "one" then
            return false, session, "invalid_repeat"
        end

        setRepeat(session, mode)
    end

    bumpNonce(session)
    return true, session, nil
end

---@return boolean success, Session session, string|nil error
function Sessions.Seek(source, position)
    local session = getSession(source)

    if not session.currentTrack then
        return false, session, "nothing_playing"
    end

    local safePosition = tonumber(position)

    if not safePosition or safePosition < 0 or safePosition > 86400 then
        return false, session, "invalid_position"
    end

    session.playback.position = math.floor(safePosition + 0.5)
    session.playback.startedAt = os.time()
    bumpNonce(session)

    return true, session, nil
end

AddEventHandler("playerDropped", function()
    sessions[source] = nil
end)
