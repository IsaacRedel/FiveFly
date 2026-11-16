--- Composes profiles, social search, recommendations and stations on top of the repositories.
FiveFY.Library = {}

local Library = FiveFY.Library
local Utils = FiveFY.Utils
local Profiles = FiveFY.Repo.Profiles
local Playlists = FiveFY.Repo.Playlists
local Tracks = FiveFY.Repo.Tracks

local function attachPublicPlaylists(profiles)
    local ids = {}

    for _, profile in ipairs(profiles) do
        ids[#ids + 1] = profile.userId
    end

    local grouped = Playlists.GetPublicByUsers(ids)

    for _, profile in ipairs(profiles) do
        profile.publicPlaylists = grouped[profile.userId] or {}
    end

    return profiles
end

--- Profile of the player using the app. Also refreshes the stored display name from the framework.
function Library.GetPlayerProfile(source, userId)
    Profiles.Ensure(userId, FiveFY.Bridge.GetDisplayName(source))

    local profile = Profiles.Get(userId, userId) or Profiles.Map({ user_id = userId })
    attachPublicPlaylists({ profile })
    profile.followingProfiles = Profiles.GetFollowing(userId)

    return profile
end

---@return Profile|nil profile, string|nil error
function Library.GetSocialProfile(viewerUserId, targetUserId)
    local target = tonumber(targetUserId) or viewerUserId
    local profile = Profiles.Get(target, viewerUserId)

    if not profile then
        return nil, "profile_not_found"
    end

    if target ~= viewerUserId and not profile.isPublic then
        return nil, "private_profile"
    end

    attachPublicPlaylists({ profile })
    return profile, nil
end

---@return Profile|nil profile, string|nil error
function Library.UpdateProfile(source, userId, payload)
    local current = Library.GetPlayerProfile(source, userId)
    local fields = {
        bio = current.bio,
        avatar = current.avatar,
        isPublic = current.isPublic,
        showActivity = current.showActivity
    }

    if payload.bio ~= nil then
        fields.bio = tostring(payload.bio)
    end

    if payload.isPublic ~= nil then
        fields.isPublic = payload.isPublic == true
    end

    if payload.showActivity ~= nil then
        fields.showActivity = payload.showActivity == true
    end

    if payload.avatar ~= nil then
        local avatar, mediaError = FiveFY.Media.ResolveImageUrl(payload.avatar)

        if avatar == nil then
            return nil, mediaError
        end

        fields.avatar = avatar
    end

    Profiles.Update(userId, fields)
    return Library.GetPlayerProfile(source, userId), nil
end

function Library.SearchSocial(userId, query)
    local safeQuery = Utils.Trim(query):sub(1, 48)

    if safeQuery == "" then
        return { profiles = {}, playlists = {} }
    end

    return {
        profiles = attachPublicPlaylists(Profiles.Search(userId, safeQuery)),
        playlists = Playlists.SearchPublic(safeQuery)
    }
end

--- Stations from Config.Stations, with invalid tracks removed.
function Library.GetStations()
    local stations = {}

    for index, station in ipairs(Config.Stations or {}) do
        if type(station) == "table" then
            local tracks = Utils.NormalizeTrackList(station.tracks, 100)

            if #tracks > 0 then
                stations[#stations + 1] = {
                    id = tostring(station.id or ("station-" .. index)),
                    name = tostring(station.name or "Radio"),
                    description = tostring(station.description or ""),
                    cover = Utils.NormalizeHttpUrl(station.cover) ~= "" and Utils.NormalizeHttpUrl(station.cover) or tracks[1].thumbnail,
                    tracks = tracks
                }
            end
        end
    end

    return stations
end

local function getTimeOfDayTracks()
    local stations = Library.GetStations()

    if #stations == 0 then
        return {}
    end

    local hour = tonumber(os.date("%H")) or 12
    local index = 1

    if hour >= 18 or hour < 5 then
        index = math.min(#stations, 3)
    elseif hour >= 12 then
        index = math.min(#stations, 2)
    end

    return stations[index].tracks
end

--- Recommendation sections. The UI translates each section by `id`; `title` is an English fallback.
function Library.GetRecommendations(userId)
    local history = Tracks.GetHistory(userId, 8)
    local favorites = Tracks.GetRecentFavorites(userId, 8)
    local artist = Tracks.GetLastArtistTracks(userId, 8)

    return {
        { id = "history", title = "Based on your history", tracks = #history > 0 and history or favorites },
        { id = "time", title = "For this time of day", tracks = getTimeOfDayTracks() },
        { id = "artist", title = "Based on an artist", tracks = #artist > 0 and artist or favorites }
    }
end

function Library.GetSmartPlaylists(userId)
    return {
        { id = "most-played", title = "Most played", description = "", tracks = Tracks.GetTopStats(userId, "play", 12) },
        { id = "most-skipped", title = "Most skipped", description = "", tracks = Tracks.GetTopStats(userId, "skip", 12) },
        { id = "most-liked", title = "Most liked", description = "", tracks = Tracks.GetServerTopFavorites(12) }
    }
end
