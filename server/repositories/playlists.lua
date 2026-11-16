FiveFY.Repo = FiveFY.Repo or {}
FiveFY.Repo.Playlists = {}

local Playlists = FiveFY.Repo.Playlists
local Utils = FiveFY.Utils

local SHARE_CODE_ALPHABET <const> = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

---@class Playlist
---@field id integer
---@field name string
---@field trackCount integer
---@field cover string
---@field shareCode string
---@field visibility "public"|"private"
---@field ownerUserId? integer
---@field ownerName? string

local function normalizeVisibility(value)
    return Utils.Trim(value):lower() == "public" and "public" or "private"
end

---@return Playlist
function Playlists.MapRow(row)
    return {
        id = tonumber(row.id),
        name = tostring(row.name or "Playlist"),
        trackCount = tonumber(row.track_count) or 0,
        cover = tostring(row.cover or ""),
        shareCode = tostring(row.share_code or ""),
        visibility = normalizeVisibility(row.visibility),
        ownerUserId = tonumber(row.user_id),
        ownerName = row.owner_name and tostring(row.owner_name) or nil
    }
end

local function mapRows(rows)
    local playlists = {}

    for _, row in ipairs(rows or {}) do
        playlists[#playlists + 1] = Playlists.MapRow(row)
    end

    return playlists
end

local function generateShareCode()
    for _ = 1, 12 do
        local chars = {}

        for index = 1, 8 do
            local position = math.random(1, #SHARE_CODE_ALPHABET)
            chars[index] = SHARE_CODE_ALPHABET:sub(position, position)
        end

        local code = table.concat(chars)
        local taken = MySQL.query.await("SELECT 1 FROM fivefy_playlists WHERE share_code = ? LIMIT 1", { code }) or {}

        if not taken[1] then
            return code
        end
    end

    return nil
end

local function isOwner(userId, playlistId)
    local rows = MySQL.query.await("SELECT 1 FROM fivefy_playlists WHERE id = ? AND user_id = ? LIMIT 1", { playlistId, userId }) or {}
    return rows[1] ~= nil
end

local function countPlaylists(userId)
    local rows = MySQL.query.await("SELECT COUNT(*) AS total FROM fivefy_playlists WHERE user_id = ?", { userId }) or {}
    return tonumber(rows[1] and rows[1].total) or 0
end

local function get(userId, playlistId)
    local rows = MySQL.query.await([[
        SELECT p.id, p.user_id, p.name, p.cover, p.share_code, p.visibility,
               (SELECT COUNT(*) FROM fivefy_playlist_tracks t WHERE t.playlist_id = p.id) AS track_count
        FROM fivefy_playlists p
        WHERE p.id = ? AND p.user_id = ?
        LIMIT 1
    ]], { playlistId, userId }) or {}

    return rows[1] and Playlists.MapRow(rows[1]) or nil
end

---@return Playlist[]
function Playlists.GetByUser(userId)
    return mapRows(MySQL.query.await([[
        SELECT p.id, p.user_id, p.name, p.cover, p.share_code, p.visibility, COUNT(t.video_id) AS track_count
        FROM fivefy_playlists p
        LEFT JOIN fivefy_playlist_tracks t ON t.playlist_id = p.id
        WHERE p.user_id = ?
        GROUP BY p.id, p.user_id, p.name, p.cover, p.share_code, p.visibility, p.created_at
        ORDER BY p.created_at DESC
    ]], { userId }))
end

--- Public playlists of the given users, with the owner's display name.
---@param userIds integer[]
---@return table<integer, Playlist[]> playlists grouped by owner id
function Playlists.GetPublicByUsers(userIds)
    local grouped = {}

    if #userIds == 0 then
        return grouped
    end

    local rows = MySQL.query.await(([[
        SELECT p.id, p.user_id, p.name, p.cover, p.share_code, p.visibility, pr.display_name AS owner_name,
               COUNT(t.video_id) AS track_count
        FROM fivefy_playlists p
        LEFT JOIN fivefy_playlist_tracks t ON t.playlist_id = p.id
        LEFT JOIN fivefy_profiles pr ON pr.user_id = p.user_id
        WHERE p.visibility = 'public' AND p.user_id IN (%s)
        GROUP BY p.id, p.user_id, p.name, p.cover, p.share_code, p.visibility, pr.display_name, p.created_at
        ORDER BY p.created_at DESC
    ]]):format(string.rep("?", #userIds, ",")), userIds) or {}

    for _, row in ipairs(rows) do
        local playlist = Playlists.MapRow(row)
        local list = grouped[playlist.ownerUserId] or {}

        if #list < 20 then
            list[#list + 1] = playlist
        end

        grouped[playlist.ownerUserId] = list
    end

    return grouped
end

---@return Playlist[]
function Playlists.SearchPublic(query)
    local pattern = "%" .. query .. "%"

    return mapRows(MySQL.query.await([[
        SELECT p.id, p.user_id, p.name, p.cover, p.share_code, p.visibility, pr.display_name AS owner_name,
               COUNT(t.video_id) AS track_count
        FROM fivefy_playlists p
        LEFT JOIN fivefy_playlist_tracks t ON t.playlist_id = p.id
        LEFT JOIN fivefy_profiles pr ON pr.user_id = p.user_id
        WHERE p.visibility = 'public' AND (p.name LIKE ? OR pr.display_name LIKE ?)
        GROUP BY p.id, p.user_id, p.name, p.cover, p.share_code, p.visibility, pr.display_name, p.created_at
        ORDER BY p.created_at DESC
        LIMIT 12
    ]], { pattern, pattern }))
end

---@return Playlist|nil playlist, string|nil error
function Playlists.Create(userId, name)
    local safeName = Utils.Trim(name):sub(1, Config.Library.MaxPlaylistNameLength)

    if safeName == "" then
        return nil, "invalid_name"
    end

    if countPlaylists(userId) >= Config.Library.MaxPlaylists then
        return nil, "playlist_limit"
    end

    local shareCode = generateShareCode()
    local id = MySQL.insert.await([[
        INSERT INTO fivefy_playlists (user_id, name, share_code) VALUES (?, ?, ?)
    ]], { userId, safeName, shareCode })

    return get(userId, id), nil
end

---@return boolean success, string|nil error
function Playlists.Delete(userId, playlistId)
    local id = tonumber(playlistId)

    if not id then
        return false, "invalid_playlist"
    end

    if not isOwner(userId, id) then
        return false, "playlist_not_found"
    end

    MySQL.update.await("DELETE FROM fivefy_playlist_tracks WHERE playlist_id = ?", { id })
    MySQL.update.await("DELETE FROM fivefy_playlists WHERE id = ? AND user_id = ?", { id, userId })

    return true, nil
end

---@return Track[]|nil tracks, string|nil error
function Playlists.GetTracks(userId, playlistId)
    local id = tonumber(playlistId)

    if not id then
        return nil, "invalid_playlist"
    end

    if not isOwner(userId, id) then
        return nil, "playlist_not_found"
    end

    return FiveFY.Repo.Tracks.MapRows(MySQL.query.await([[
        SELECT video_id, title, thumbnail, duration, author
        FROM fivefy_playlist_tracks
        WHERE playlist_id = ?
        ORDER BY position ASC, created_at ASC
    ]], { id })), nil
end

---@return boolean success, string|nil error
function Playlists.SetCover(userId, playlistId, cover)
    local id = tonumber(playlistId)

    if not id then
        return false, "invalid_playlist"
    end

    if cover == "" then
        return false, "invalid_cover"
    end

    if not isOwner(userId, id) then
        return false, "playlist_not_found"
    end

    MySQL.update.await("UPDATE fivefy_playlists SET cover = ? WHERE id = ? AND user_id = ?", { cover, id, userId })

    return true, nil
end

---@return string|nil visibility, string|nil error
function Playlists.SetVisibility(userId, playlistId, visibility)
    local id = tonumber(playlistId)

    if not id then
        return nil, "invalid_playlist"
    end

    if not isOwner(userId, id) then
        return nil, "playlist_not_found"
    end

    local safeVisibility = normalizeVisibility(visibility)
    MySQL.update.await("UPDATE fivefy_playlists SET visibility = ? WHERE id = ? AND user_id = ?", { safeVisibility, id, userId })

    return safeVisibility, nil
end

--- Copies a playlist (public or private) by its share code into the user's library.
---@return Playlist|nil playlist, string|nil error
function Playlists.ImportByCode(userId, shareCode)
    local code = Utils.Trim(shareCode):upper():sub(1, 12)

    if code == "" or not code:match("^[%w]+$") then
        return nil, "invalid_share_code"
    end

    local rows = MySQL.query.await("SELECT id, name, cover FROM fivefy_playlists WHERE share_code = ? LIMIT 1", { code }) or {}
    local source = rows[1]

    if not source then
        return nil, "playlist_not_found"
    end

    if countPlaylists(userId) >= Config.Library.MaxPlaylists then
        return nil, "playlist_limit"
    end

    local baseName = Utils.Trim(source.name or "Playlist"):sub(1, Config.Library.MaxPlaylistNameLength - 7)
    local name = (baseName ~= "" and baseName or "Playlist") .. " (copy)"
    local newId = MySQL.insert.await([[
        INSERT INTO fivefy_playlists (user_id, name, cover, share_code) VALUES (?, ?, ?, ?)
    ]], { userId, name, Utils.NormalizeHttpUrl(source.cover), generateShareCode() })

    MySQL.insert.await([[
        INSERT INTO fivefy_playlist_tracks (playlist_id, video_id, title, thumbnail, duration, author, position)
        SELECT ?, video_id, title, thumbnail, duration, author, position
        FROM fivefy_playlist_tracks
        WHERE playlist_id = ?
        ORDER BY position ASC, created_at ASC
        LIMIT ?
    ]], { newId, tonumber(source.id), Config.Library.MaxTracksPerPlaylist })

    return get(userId, newId), nil
end

--- Adds a normalized track at the end of the playlist. The first track with artwork becomes the cover.
---@return boolean success, string|nil error
function Playlists.AddTrack(userId, playlistId, track)
    local playlist = get(userId, tonumber(playlistId))

    if not playlist then
        return false, tonumber(playlistId) and "playlist_not_found" or "invalid_playlist"
    end

    if playlist.trackCount >= Config.Library.MaxTracksPerPlaylist then
        return false, "playlist_full"
    end

    MySQL.insert.await([[
        INSERT INTO fivefy_playlist_tracks (playlist_id, video_id, title, thumbnail, duration, author, position)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            title = VALUES(title),
            thumbnail = VALUES(thumbnail),
            duration = VALUES(duration),
            author = VALUES(author)
    ]], { playlist.id, track.videoId, track.title, track.thumbnail, track.duration, track.author, playlist.trackCount + 1 })

    if playlist.cover == "" and track.thumbnail ~= "" then
        MySQL.update.await("UPDATE fivefy_playlists SET cover = ? WHERE id = ? AND user_id = ?", { track.thumbnail, playlist.id, userId })
    end

    return true, nil
end

---@return boolean success, string|nil error
function Playlists.RemoveTrack(userId, playlistId, videoId)
    local id = tonumber(playlistId)
    local safeVideoId = Utils.ExtractVideoId(videoId)

    if not id then
        return false, "invalid_playlist"
    end

    if safeVideoId == "" then
        return false, "invalid_track"
    end

    if not isOwner(userId, id) then
        return false, "playlist_not_found"
    end

    MySQL.update.await("DELETE FROM fivefy_playlist_tracks WHERE playlist_id = ? AND video_id = ?", { id, safeVideoId })

    return true, nil
end
