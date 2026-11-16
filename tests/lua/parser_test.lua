local H = require("helpers")

local function load()
    H.reset()
    dofile("server/services/search/parser.lua")
    return FiveFly.SearchParser
end

return {
    {
        name = "FormatIsoDuration converts ISO 8601 durations",
        run = function()
            local parser = load()

            H.eq(parser.FormatIsoDuration("PT3M45S"), "3:45", "minutes and seconds")
            H.eq(parser.FormatIsoDuration("PT1H2M3S"), "1:02:03", "hours")
            H.eq(parser.FormatIsoDuration("PT45S"), "0:45", "seconds only")
            H.eq(parser.FormatIsoDuration("P1DT1H"), "25:00:00", "days")
            H.eq(parser.FormatIsoDuration("P0D"), "LIVE", "live stream")
            H.eq(parser.FormatIsoDuration("garbage"), "--:--", "invalid")
        end
    },
    {
        name = "DecodeHtmlEntities decodes named and numeric entities",
        run = function()
            local parser = load()

            H.eq(parser.DecodeHtmlEntities("Rock &amp; Roll &quot;Live&quot; &#39;99"), "Rock & Roll \"Live\" '99", "entities")
            H.eq(parser.DecodeHtmlEntities("Caf&#233;"), "Café", "numeric unicode")
        end
    },
    {
        name = "UrlEncode escapes reserved characters and spaces",
        run = function()
            local parser = load()
            H.eq(parser.UrlEncode("a b&c=d/é"), "a+b%26c%3Dd%2F%C3%A9", "encoded")
        end
    },
    {
        name = "ParseApiResults builds tracks with durations and limits results",
        run = function()
            local parser = load()
            local search = {
                items = {
                    { id = { videoId = "v1" }, snippet = { title = "One &amp; Two", channelTitle = "Band", thumbnails = { high = { url = "https://i.ytimg.com/v1.jpg" } } } },
                    { id = { kind = "youtube#channel" }, snippet = { title = "skip me" } },
                    { id = { videoId = "v2" }, snippet = { title = "Second", channelTitle = "Band", thumbnails = {} } },
                    { id = { videoId = "v3" }, snippet = { title = "Third" } }
                }
            }
            local videos = { items = { { id = "v1", contentDetails = { duration = "PT4M2S" } } } }
            local results = parser.ParseApiResults(search, videos, 2)

            H.eq(#results, 2, "limited to 2")
            H.eq(results[1].title, "One & Two", "decoded title")
            H.eq(results[1].duration, "4:02", "duration from videos.list")
            H.eq(results[2].duration, "--:--", "missing duration")
            H.eq(results[2].thumbnail, "https://i.ytimg.com/vi/v2/mqdefault.jpg", "fallback thumbnail")
            H.eq(#parser.ParseApiResults(nil, nil, 5), 0, "nil response")
        end
    },
    {
        name = "ExtractBalancedJson handles nested braces and braces inside strings",
        run = function()
            local parser = load()
            local html = [[<script>var ytInitialData = {"a":{"b":"}{"},"c":[1,{"d":2}]};</script>]]

            H.eq(parser.ExtractBalancedJson(html, "ytInitialData"), [[{"a":{"b":"}{"},"c":[1,{"d":2}]}]], "balanced object")
            H.eq(parser.ExtractBalancedJson("no marker here", "ytInitialData"), nil, "missing marker")
        end
    },
    {
        name = "ParseScrapedPage collects unique video renderers",
        run = function()
            local parser = load()
            local renderer = function(id, title)
                return {
                    videoRenderer = {
                        videoId = id,
                        title = { runs = { { text = title } } },
                        ownerText = { runs = { { text = "Owner" } } },
                        lengthText = { simpleText = "3:10" },
                        thumbnail = { thumbnails = { { url = "small" }, { url = "https://big/" .. id } } }
                    }
                }
            end
            local data = { contents = { renderer("a", "First"), { nested = { renderer("b", "Second"), renderer("a", "Duplicate") } } } }
            local results = parser.ParseScrapedPage("var ytInitialData = {};", 10, function() return data end)

            H.eq(#results, 2, "duplicates removed")
            H.eq(results[1].videoId == "a" and results[1].title or results[2].title, "First", "title from runs")
            H.eq(results[1].duration, "3:10", "duration")
            H.eq(parser.ParseScrapedPage("<html></html>", 10, function() return data end), nil, "page without data")
            H.eq(parser.ParseScrapedPage("ytInitialData = {}", 10, function() error("bad json") end), nil, "decoder failure")
        end
    }
}
