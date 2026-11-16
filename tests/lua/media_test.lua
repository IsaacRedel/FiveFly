local H = require("helpers")

local function load()
    H.reset()
    dofile("server/services/media.lua")
    return FiveFly.Media
end

return {
    {
        name = "GetHostname only accepts plain hosts",
        run = function()
            local media = load()

            H.eq(media.GetHostname("https://cdn.discordapp.com/a.png"), "cdn.discordapp.com", "plain host")
            H.eq(media.GetHostname("https://CDN.discordapp.com:443/a.png"), "cdn.discordapp.com", "case and port")
            H.eq(media.GetHostname("https://evil.com\\@cdn.discordapp.com/a.png"), nil, "backslash trick")
            H.eq(media.GetHostname("https://user@cdn.discordapp.com/a.png"), nil, "credentials")
            H.eq(media.GetHostname("ftp://cdn.discordapp.com/a.png"), nil, "non-http scheme")
            H.eq(media.GetHostname("https://a..b.com/x"), nil, "empty label")
        end
    },
    {
        name = "IsAllowed applies whitelist and blacklist rules",
        run = function()
            local media = load()

            assert(media.IsAllowed("https://cdn.discordapp.com/a.png"), "whitelisted hostname")
            assert(media.IsAllowed("https://abc.fivemanage.com/a.png"), "whitelisted domain subdomain")
            assert(not media.IsAllowed("https://evil.com/a.png"), "not whitelisted")
            assert(not media.IsAllowed("https://evil.com\\@cdn.discordapp.com/a.png"), "bypass attempt rejected")

            Config.Media.ExternalBlacklistedHostnames = { "cdn.discordapp.com" }
            assert(not media.IsAllowed("https://cdn.discordapp.com/a.png"), "blacklist wins")
        end
    },
    {
        name = "Hostname entries with hyphens are matched literally",
        run = function()
            local media = load()
            Config.Media.ExternalWhitelistedHostnames = { "my-cdn.example.com" }
            Config.Media.ExternalWhitelistedDomains = {}
            Config.Media.UploadWhitelistedHostnames = {}
            Config.Media.UploadWhitelistedDomains = {}

            assert(media.IsAllowed("https://my-cdn.example.com/a.png"), "exact host")
            assert(not media.IsAllowed("https://mcdn.example.com/a.png"), "hyphen is not a pattern quantifier")
        end
    },
    {
        name = "Base64Encode matches the standard encoding",
        run = function()
            local media = load()

            H.eq(media.Base64Encode(""), "", "empty")
            H.eq(media.Base64Encode("f"), "Zg==", "one byte")
            H.eq(media.Base64Encode("fo"), "Zm8=", "two bytes")
            H.eq(media.Base64Encode("foobar"), "Zm9vYmFy", "six bytes")
            H.eq(media.Base64Encode("\0\255\128"), "AP+A", "binary")
        end
    }
}
