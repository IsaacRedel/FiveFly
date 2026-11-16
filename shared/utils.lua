---@diagnostic disable: lowercase-global
FiveFly = FiveFly or {}
FiveFly.Utils = {}

local Utils = FiveFly.Utils

---@class Track
---@field videoId string YouTube video id, or a station id when streamUrl is set
---@field streamUrl? string direct audio stream (radio stations)
---@field title string
---@field thumbnail string
---@field duration string
---@field author string

---@param value any
---@return string
function Utils.Trim(value)
    if type(value) ~= "string" then
        return ""
    end

    return value:match("^%s*(.-)%s*$") or ""
end

---@param value any
---@param minValue number
---@param maxValue number
---@return number
function Utils.Clamp(value, minValue, maxValue)
    local number = tonumber(value) or minValue
    return math.max(minValue, math.min(maxValue, number))
end

---@param value any
---@return integer
function Utils.ClampVolume(value)
    local number = tonumber(value) or 100
    return math.max(0, math.min(100, math.floor(number + 0.5)))
end

--- Converts a vector3 or a {x, y, z} table into a vector3 (nil when invalid).
function Utils.ToVector3(coords)
    if type(coords) == "vector3" then
        return coords
    end

    if type(coords) == "table" and tonumber(coords.x) and tonumber(coords.y) and tonumber(coords.z) then
        return vector3(tonumber(coords.x) + 0.0, tonumber(coords.y) + 0.0, tonumber(coords.z) + 0.0)
    end

    return nil
end

--- Extracts a YouTube video id from an id or a YouTube URL.
---@param value any
---@return string
function Utils.ExtractVideoId(value)
    local input = Utils.Trim(value)

    if input == "" then
        return ""
    end

    if input:match("^[%w_-]+$") and #input <= 32 then
        return input
    end

    return input:match("[?&]v=([%w_-]+)")
        or input:match("youtu%.be/([%w_-]+)")
        or input:match("/embed/([%w_-]+)")
        or input:match("/live/([%w_-]+)")
        or input:match("/shorts/([%w_-]+)")
        or ""
end

--- Validates and normalizes a track received from the client or the database.
---@param track any
---@return Track|nil
function Utils.NormalizeTrack(track)
    if type(track) ~= "table" then
        return nil
    end

    local videoId = Utils.ExtractVideoId(track.videoId or track.id or track.youtubeUrl)

    if videoId == "" or #videoId > 32 then
        return nil
    end

    local streamUrl = Utils.Trim(track.streamUrl or track.url)

    if streamUrl ~= "" and (not streamUrl:match("^https?://") or #streamUrl > 512) then
        return nil
    end

    local title = Utils.Trim(track.title)
    local duration = Utils.Trim(track.duration)
    local thumbnail = Utils.Trim(track.thumbnail)

    if thumbnail ~= "" and (not thumbnail:match("^https?://") or #thumbnail > 512) then
        thumbnail = ""
    end

    return {
        videoId = videoId,
        streamUrl = streamUrl,
        title = title ~= "" and title:sub(1, 255) or "Untitled",
        thumbnail = thumbnail,
        duration = duration ~= "" and duration:sub(1, 24) or "--:--",
        author = Utils.Trim(track.author or track.artist):sub(1, 128)
    }
end

--- Normalizes a list of tracks, dropping invalid entries and limiting the size.
---@param list any
---@param limit integer
---@return Track[]
function Utils.NormalizeTrackList(list, limit)
    local normalized = {}

    if type(list) ~= "table" then
        return normalized
    end

    for _, track in ipairs(list) do
        if #normalized >= limit then
            break
        end

        local safeTrack = Utils.NormalizeTrack(track)

        if safeTrack then
            normalized[#normalized + 1] = safeTrack
        end
    end

    return normalized
end

--- Replaces a client-provided stream URL with the one configured in Config.Stations for the same id, or
--- removes it. Prevents a modified client from making nearby players' browsers load arbitrary URLs.
---@param track Track|nil
---@return Track|nil
function Utils.ApplyTrustedStream(track)
    if not track or track.streamUrl == "" then
        return track
    end

    for _, station in ipairs(Config and Config.Stations or {}) do
        for _, stationTrack in ipairs(type(station) == "table" and station.tracks or {}) do
            if type(stationTrack) == "table" and stationTrack.videoId == track.videoId and type(stationTrack.streamUrl) == "string" then
                track.streamUrl = stationTrack.streamUrl
                return track
            end
        end
    end

    track.streamUrl = ""
    return track
end

--- Server-side: normalizes a track received from a client, keeping only configured stream URLs.
---@return Track|nil
function Utils.NormalizeClientTrack(track)
    return Utils.ApplyTrustedStream(Utils.NormalizeTrack(track))
end

--- Server-side: normalizes a list of client tracks, keeping only configured stream URLs.
---@return Track[]
function Utils.NormalizeClientTrackList(list, limit)
    local tracks = Utils.NormalizeTrackList(list, limit)

    for _, track in ipairs(tracks) do
        Utils.ApplyTrustedStream(track)
    end

    return tracks
end

---@param url any
---@return string
function Utils.NormalizeHttpUrl(url, maxLength)
    local value = Utils.Trim(url)

    if value == "" or not value:match("^https?://") then
        return ""
    end

    return value:sub(1, maxLength or 512)
end

--- Volume heard at `distance` from a source: full volume up to the fade start, then a smoothstep fade
--- shaped by `attenuation.curve`, reaching 0 at `range`.
---@param distance number
---@param range number
---@param baseVolume number 0-100
---@param attenuation { nearRadius?: number, fadeStartRatio?: number, curve?: number }
---@return number
function Utils.AttenuatedVolume(distance, range, baseVolume, attenuation)
    local safeRange = math.max(0.1, tonumber(range) or 12.0)
    local volume = Utils.Clamp(baseVolume or 100, 0, 100)
    local nearRadius = math.max(0.0, tonumber(attenuation.nearRadius) or 1.5)
    local fadeStart = math.max(nearRadius, safeRange * Utils.Clamp(attenuation.fadeStartRatio or 0.5, 0.0, 1.0))
    local curve = math.max(0.2, tonumber(attenuation.curve) or 1.0)

    if distance >= safeRange then
        return 0
    end

    if distance <= fadeStart then
        return volume
    end

    local progress = Utils.Clamp((distance - fadeStart) / math.max(0.1, safeRange - fadeStart), 0.0, 1.0)
    local smooth = progress * progress * (3.0 - 2.0 * progress)

    return volume * (1.0 - smooth) ^ curve
end

local resourceName = GetCurrentResourceName and GetCurrentResourceName() or "fivefly"

--- Prints a log line prefixed with the resource name. "debug" lines only print with Config.Debug.
---@param level "debug"|"info"|"warn"|"error"
function FiveFly.Log(level, message, ...)
    if level == "debug" and not (Config and Config.Debug) then
        return
    end

    local colors = { debug = "^5", info = "^2", warn = "^3", error = "^1" }
    local text = select("#", ...) > 0 and message:format(...) or tostring(message)

    print(("%s[%s]^7 %s"):format(colors[level] or "^7", resourceName, text))
end
