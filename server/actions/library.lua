local Actions = FiveFY.Actions
local Utils = FiveFY.Utils
local Tracks = FiveFY.Repo.Tracks
local Playlists = FiveFY.Repo.Playlists

local READ_MS <const> = Config.RateLimits.LibraryReadMs
local WRITE_MS <const> = Config.RateLimits.LibraryWriteMs

Actions.Register("library.favorites.get", {
    handler = function(ctx)
        return { favorites = Tracks.GetFavorites(ctx.userId) }
    end
})

Actions.Register("library.favorites.toggle", {
    rateLimit = WRITE_MS,
    handler = function(ctx, payload)
        local track = Utils.NormalizeTrack(payload.track)

        if not track then
            return nil, "invalid_track"
        end

        return { favorite = Tracks.ToggleFavorite(ctx.userId, track), track = track }
    end
})

Actions.Register("library.history.get", {
    handler = function(ctx)
        return { history = Tracks.GetHistory(ctx.userId, 50) }
    end
})

Actions.Register("library.history.clear", {
    rateLimit = WRITE_MS,
    handler = function(ctx)
        Tracks.ClearHistory(ctx.userId)
        return { cleared = true }
    end
})

Actions.Register("library.smart-playlists.get", {
    rateLimit = READ_MS,
    handler = function(ctx)
        return { playlists = FiveFY.Library.GetSmartPlaylists(ctx.userId) }
    end
})

Actions.Register("library.playlists.get", {
    handler = function(ctx)
        return { playlists = Playlists.GetByUser(ctx.userId) }
    end
})

Actions.Register("library.playlists.create", {
    rateLimit = WRITE_MS,
    handler = function(ctx, payload)
        local playlist, err = Playlists.Create(ctx.userId, payload.name)
        return playlist and { playlist = playlist } or nil, err
    end
})

Actions.Register("library.playlists.import", {
    rateLimit = WRITE_MS,
    handler = function(ctx, payload)
        local playlist, err = Playlists.ImportByCode(ctx.userId, payload.shareCode)
        return playlist and { playlist = playlist } or nil, err
    end
})

Actions.Register("library.playlists.cover.set", {
    rateLimit = WRITE_MS,
    handler = function(ctx, payload)
        local cover, mediaError = FiveFY.Media.ResolveImageUrl(payload.cover)

        if cover == nil then
            return nil, mediaError
        end

        local updated, err = Playlists.SetCover(ctx.userId, payload.playlistId, cover)
        return updated and { updated = true, cover = cover } or nil, err
    end
})

Actions.Register("library.playlists.visibility.set", {
    rateLimit = WRITE_MS,
    handler = function(ctx, payload)
        local visibility, err = Playlists.SetVisibility(ctx.userId, payload.playlistId, payload.visibility)
        return visibility and { visibility = visibility } or nil, err
    end
})

Actions.Register("library.playlists.delete", {
    rateLimit = WRITE_MS,
    handler = function(ctx, payload)
        local deleted, err = Playlists.Delete(ctx.userId, payload.playlistId)
        return deleted and { deleted = true } or nil, err
    end
})

Actions.Register("library.playlists.tracks.get", {
    handler = function(ctx, payload)
        local tracks, err = Playlists.GetTracks(ctx.userId, payload.playlistId)
        return tracks and { tracks = tracks } or nil, err
    end
})

Actions.Register("library.playlists.tracks.add", {
    rateLimit = WRITE_MS,
    handler = function(ctx, payload)
        local track = Utils.NormalizeTrack(payload.track)

        if not track then
            return nil, "invalid_track"
        end

        local added, err = Playlists.AddTrack(ctx.userId, payload.playlistId, track)
        return added and { added = true } or nil, err
    end
})

Actions.Register("library.playlists.tracks.remove", {
    rateLimit = WRITE_MS,
    handler = function(ctx, payload)
        local removed, err = Playlists.RemoveTrack(ctx.userId, payload.playlistId, payload.videoId)
        return removed and { removed = true } or nil, err
    end
})
