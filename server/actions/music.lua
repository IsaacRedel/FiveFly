local Actions = FiveFY.Actions
local Library = FiveFY.Library
local Repo = FiveFY.Repo

-- Heaviest read (about ten queries): a short limit blocks spam without breaking reloads after mutations.
Actions.Register("app.get-initial-state", {
    rateLimit = 300,
    handler = function(ctx)
        local profile = Library.GetPlayerProfile(ctx.source, ctx.userId)

        return {
            locale = Config.Locale,
            profile = profile,
            playback = FiveFY.Sessions.GetState(ctx.source),
            library = {
                favorites = Repo.Tracks.GetFavorites(ctx.userId),
                playlists = Repo.Playlists.GetByUser(ctx.userId),
                history = Repo.Tracks.GetHistory(ctx.userId, 50),
                stations = Library.GetStations(),
                sharedSessions = FiveFY.Sessions.GetSharedSessions(ctx.source),
                friendsListening = FiveFY.Sessions.GetFriendsListening(ctx.source, ctx.userId),
                recommendations = Library.GetRecommendations(ctx.userId),
                smartPlaylists = Library.GetSmartPlaylists(ctx.userId),
                followingProfiles = profile.followingProfiles or {}
            }
        }
    end
})

Actions.Register("music.search", {
    rateLimit = Config.Search.CooldownMs,
    handler = function(_, payload)
        local success, results, searchError = FiveFY.Search.SearchTracks(payload.query)

        if not success then
            return nil, searchError
        end

        return { results = results }
    end
})

Actions.Register("music.stations.get", {
    handler = function()
        return { stations = Library.GetStations() }
    end
})

Actions.Register("music.recommendations.get", {
    rateLimit = Config.RateLimits.LibraryReadMs,
    handler = function(ctx)
        return { recommendations = Library.GetRecommendations(ctx.userId) }
    end
})
