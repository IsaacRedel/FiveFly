local Actions = FiveFY.Actions
local Library = FiveFY.Library

local WRITE_MS <const> = Config.RateLimits.LibraryWriteMs

Actions.Register("social.search", {
    handler = function(ctx, payload)
        return Library.SearchSocial(ctx.userId, payload.query)
    end
})

Actions.Register("social.profile.get", {
    handler = function(ctx, payload)
        local profile, err = Library.GetSocialProfile(ctx.userId, payload.userId)
        return profile and { profile = profile } or nil, err
    end
})

Actions.Register("social.profile.update", {
    rateLimit = WRITE_MS,
    handler = function(ctx, payload)
        local profile, err = Library.UpdateProfile(ctx.source, ctx.userId, payload)
        return profile and { profile = profile } or nil, err
    end
})

Actions.Register("social.follow.toggle", {
    rateLimit = WRITE_MS,
    handler = function(ctx, payload)
        local following, err = FiveFY.Repo.Profiles.ToggleFollow(ctx.userId, payload.userId)

        if following == nil then
            return nil, err
        end

        return { following = following }
    end
})
