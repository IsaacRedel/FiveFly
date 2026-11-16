--- Favorites, listening history and per-user track statistics.
FiveFY.Repo = FiveFY.Repo or {}
FiveFY.Repo.Tracks = {}

local Tracks = FiveFY.Repo.Tracks
local historyPrunedAt = {}

---@return Track
function Tracks.MapRow(row)
    return {
        videoId = tostring(row.video_id or ""),
        title = tostring(row.title or "Untitled"),
        thumbnail = tostring(row.thumbnail or ""),
        duration = tostring(row.duration or "--:--"),
        author = tostring(row.author or "")
    }
end

---@return Track[]
function Tracks.MapRows(rows)
    local tracks = {}

    for _, row in ipairs(rows or {}) do
        tracks[#tracks + 1] = Tracks.MapRow(row)
    end

    return tracks
end

---------------------------------------------------------------------------------------------------
-- Favorites
---------------------------------------------------------------------------------------------------

function Tracks.GetFavorites(userId)
    return Tracks.MapRows(MySQL.query.await([[
        SELECT video_id, title, thumbnail, duration, author
        FROM fivefy_favorites
        WHERE user_id = ?
        ORDER BY created_at DESC
    ]], { userId }))
end

--- Adds or removes a favorite. `track` must already be normalized.
---@return boolean favorite
function Tracks.ToggleFavorite(userId, track)
    local removed = MySQL.update.await([[
        DELETE FROM fivefy_favorites WHERE user_id = ? AND video_id = ?
    ]], { userId, track.videoId })

    if removed and removed > 0 then
        return false
    end

    MySQL.insert.await([[
        INSERT IGNORE INTO fivefy_favorites (user_id, video_id, title, thumbnail, duration, author)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { userId, track.videoId, track.title, track.thumbnail, track.duration, track.author })

    return true
end

---------------------------------------------------------------------------------------------------
-- History and statistics
---------------------------------------------------------------------------------------------------

function Tracks.GetHistory(userId, limit)
    return Tracks.MapRows(MySQL.query.await([[
        SELECT video_id, title, thumbnail, duration, author
        FROM fivefy_history
        WHERE user_id = ?
        ORDER BY played_at DESC, id DESC
        LIMIT ?
    ]], { userId, limit or 50 }))
end

function Tracks.ClearHistory(userId)
    MySQL.update.await("DELETE FROM fivefy_history WHERE user_id = ?", { userId })
end

--- Keeps at most Config.Library.MaxHistoryRowsPerUser rows per user, checked at most once per interval.
function Tracks.PruneHistory(userId)
    local maxRows = tonumber(Config.Library.MaxHistoryRowsPerUser) or 300
    local interval = tonumber(Config.Library.HistoryPruneIntervalSeconds) or 600
    local now = os.time()

    if maxRows <= 0 or (historyPrunedAt[userId] and historyPrunedAt[userId] + interval > now) then
        return
    end

    historyPrunedAt[userId] = now

    local cutoff = MySQL.query.await([[
        SELECT id FROM fivefy_history
        WHERE user_id = ?
        ORDER BY id DESC
        LIMIT 1 OFFSET ?
    ]], { userId, maxRows - 1 }) or {}

    if cutoff[1] then
        MySQL.update.await("DELETE FROM fivefy_history WHERE user_id = ? AND id < ?", { userId, cutoff[1].id })
    end
end

---@param kind "play"|"skip"
function Tracks.RecordStat(userId, track, kind)
    local plays = kind == "play" and 1 or 0
    local skips = kind == "skip" and 1 or 0

    MySQL.insert.await([[
        INSERT INTO fivefy_track_stats (user_id, video_id, title, thumbnail, duration, author, play_count, skip_count)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            title = VALUES(title),
            thumbnail = VALUES(thumbnail),
            duration = VALUES(duration),
            author = VALUES(author),
            play_count = play_count + VALUES(play_count),
            skip_count = skip_count + VALUES(skip_count)
    ]], { userId, track.videoId, track.title, track.thumbnail, track.duration, track.author, plays, skips })
end

--- Records a play in the history and statistics. `track` must already be normalized.
function Tracks.AddHistory(userId, track)
    MySQL.insert.await([[
        INSERT INTO fivefy_history (user_id, video_id, title, thumbnail, duration, author)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { userId, track.videoId, track.title, track.thumbnail, track.duration, track.author })

    Tracks.RecordStat(userId, track, "play")
    Tracks.PruneHistory(userId)
end

function Tracks.GetRecentFavorites(userId, limit)
    return Tracks.MapRows(MySQL.query.await([[
        SELECT video_id, title, thumbnail, duration, author
        FROM fivefy_favorites
        WHERE user_id = ?
        ORDER BY created_at DESC
        LIMIT ?
    ]], { userId, limit }))
end

--- Recent plays of the artist the user listened to most recently.
function Tracks.GetLastArtistTracks(userId, limit)
    return Tracks.MapRows(MySQL.query.await([[
        SELECT h.video_id, MAX(h.title) AS title, MAX(h.thumbnail) AS thumbnail,
               MAX(h.duration) AS duration, MAX(h.author) AS author
        FROM fivefy_history h
        INNER JOIN (
            SELECT author
            FROM fivefy_history
            WHERE user_id = ? AND author <> ''
            ORDER BY id DESC
            LIMIT 1
        ) a ON a.author = h.author
        WHERE h.user_id = ?
        GROUP BY h.video_id
        ORDER BY MAX(h.id) DESC
        LIMIT ?
    ]], { userId, userId, limit }))
end

---@param order "play"|"skip"
function Tracks.GetTopStats(userId, order, limit)
    local column = order == "skip" and "skip_count" or "play_count"

    return Tracks.MapRows(MySQL.query.await(([[
        SELECT video_id, title, thumbnail, duration, author
        FROM fivefy_track_stats
        WHERE user_id = ? AND %s > 0
        ORDER BY %s DESC, updated_at DESC
        LIMIT ?
    ]]):format(column, column), { userId, limit }))
end

--- Most favorited tracks across the whole server.
function Tracks.GetServerTopFavorites(limit)
    return Tracks.MapRows(MySQL.query.await([[
        SELECT video_id, MAX(title) AS title, MAX(thumbnail) AS thumbnail, MAX(duration) AS duration, MAX(author) AS author
        FROM fivefy_favorites
        GROUP BY video_id
        ORDER BY COUNT(*) DESC, MAX(created_at) DESC
        LIMIT ?
    ]], { limit }))
end
