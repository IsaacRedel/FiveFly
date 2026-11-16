local H = require("helpers")

return {
    {
        name = "ExtractVideoId accepts ids and common YouTube URLs",
        run = function()
            H.reset()
            local extract = FiveFly.Utils.ExtractVideoId

            H.eq(extract("dQw4w9WgXcQ"), "dQw4w9WgXcQ", "plain id")
            H.eq(extract("https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=10"), "dQw4w9WgXcQ", "watch url")
            H.eq(extract("https://youtu.be/dQw4w9WgXcQ"), "dQw4w9WgXcQ", "short url")
            H.eq(extract("https://www.youtube.com/shorts/dQw4w9WgXcQ"), "dQw4w9WgXcQ", "shorts url")
            H.eq(extract("not a url!"), "", "invalid text")
            H.eq(extract(nil), "", "nil")
        end
    },
    {
        name = "NormalizeTrack rejects invalid data and trims fields",
        run = function()
            H.reset()
            local normalize = FiveFly.Utils.NormalizeTrack

            H.eq(normalize(nil), nil, "nil track")
            H.eq(normalize({ title = "no id" }), nil, "missing id")
            H.eq(normalize({ videoId = "abc", streamUrl = "javascript:alert(1)" }), nil, "non-http stream")

            local track = normalize({ videoId = "abc", title = "  Song  ", artist = "Band", thumbnail = "ftp://x" })
            H.eq(track.videoId, "abc", "id")
            H.eq(track.title, "Song", "trimmed title")
            H.eq(track.author, "Band", "artist alias")
            H.eq(track.thumbnail, "", "non-http thumbnail dropped")
            H.eq(track.duration, "--:--", "default duration")
            H.eq(#normalize({ videoId = "abc", title = string.rep("x", 400) }).title, 255, "title capped")
        end
    },
    {
        name = "NormalizeTrackList drops invalid entries and respects the limit",
        run = function()
            H.reset()
            local list = FiveFly.Utils.NormalizeTrackList({ { videoId = "a" }, { title = "bad" }, { videoId = "b" }, { videoId = "c" } }, 2)

            H.eq(#list, 2, "size")
            H.eq(list[2].videoId, "b", "invalid skipped")
            H.eq(#FiveFly.Utils.NormalizeTrackList("nope", 5), 0, "non-table input")
        end
    },
    {
        name = "AttenuatedVolume is full near the source, fades and reaches zero at the range",
        run = function()
            H.reset()
            local attenuation = { nearRadius = 1.25, fadeStartRatio = 0.18, curve = 1.65 }
            local volume = FiveFly.Utils.AttenuatedVolume

            H.eq(volume(0, 20, 80, attenuation), 80, "at the source")
            H.eq(volume(3, 20, 80, attenuation), 80, "before fade start (3.6m)")
            H.eq(volume(20, 20, 80, attenuation), 0, "at the range")
            H.eq(volume(50, 20, 80, attenuation), 0, "beyond the range")

            local mid = volume(12, 20, 80, attenuation)
            assert(mid > 0 and mid < 80, "fades between start and range")
            assert(volume(14, 20, 80, attenuation) < mid, "monotonic fade")
        end
    },
    {
        name = "ClampVolume rounds and bounds values",
        run = function()
            H.reset()
            H.eq(FiveFly.Utils.ClampVolume(150), 100, "upper bound")
            H.eq(FiveFly.Utils.ClampVolume(-4), 0, "lower bound")
            H.eq(FiveFly.Utils.ClampVolume("49.6"), 50, "string input rounded")
            H.eq(FiveFly.Utils.ClampVolume(nil), 100, "default")
        end
    },
    {
        name = "Lua texts follow Config.Locale with English fallback",
        run = function()
            H.reset()
            H.eq(FiveFly.T("panel.key_description", "FiveFly"), "Open FiveFly", "english")

            Config.Locale = "pt-BR"
            H.eq(FiveFly.T("panel.key_description", "CaliFY"), "Abrir o CaliFY", "portuguese")
            H.eq(FiveFly.T("log.framework", "qbx"), "framework: qbx", "formatted")

            Config.Locale = "pt"
            H.eq(FiveFly.GetLocale(), "pt-BR", "pt alias")

            Config.Locale = "de"
            H.eq(FiveFly.GetLocale(), "en", "unknown locale")
            H.eq(FiveFly.T("missing.key"), "missing.key", "unknown key")
        end
    }
}
