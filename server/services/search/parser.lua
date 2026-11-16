--- Pure parsing helpers for the search providers (no FiveM natives, covered by tests/lua).
FiveFY.SearchParser = {}

local Parser = FiveFY.SearchParser

local HTML_ENTITIES <const> = {
    ["&amp;"] = "&",
    ["&lt;"] = "<",
    ["&gt;"] = ">",
    ["&quot;"] = "\"",
    ["&#39;"] = "'",
    ["&apos;"] = "'"
}

function Parser.DecodeHtmlEntities(value)
    local text = tostring(value or "")

    text = text:gsub("&#(%d+);", function(code)
        local number = tonumber(code)
        return number and number < 0x110000 and utf8.char(number) or ""
    end)

    return (text:gsub("&%a+;", HTML_ENTITIES))
end

--- Converts an ISO 8601 duration (PT1H2M3S) into "1:02:03" / "2:03". Live streams (P0D) return "LIVE".
function Parser.FormatIsoDuration(value)
    local text = tostring(value or "")

    if text == "P0D" then
        return "LIVE"
    end

    local days = tonumber(text:match("(%d+)D")) or 0
    local hours = (tonumber(text:match("(%d+)H")) or 0) + days * 24
    local minutes = tonumber(text:match("(%d+)M")) or 0
    local seconds = tonumber(text:match("(%d+)S")) or 0

    if not text:match("^P") then
        return "--:--"
    end

    if hours > 0 then
        return ("%d:%02d:%02d"):format(hours, minutes, seconds)
    end

    return ("%d:%02d"):format(minutes, seconds)
end

function Parser.UrlEncode(value)
    local text = tostring(value or ""):gsub("\n", "\r\n")

    text = text:gsub("([^%w%-_%.~ ])", function(char)
        return ("%%%02X"):format(char:byte())
    end)

    return (text:gsub(" ", "+"))
end

---------------------------------------------------------------------------------------------------
-- YouTube Data API v3
---------------------------------------------------------------------------------------------------

--- Builds tracks from a search.list response, with durations from a videos.list response (optional).
function Parser.ParseApiResults(searchResponse, videosResponse, maxResults)
    local durations = {}

    for _, item in ipairs(type(videosResponse) == "table" and videosResponse.items or {}) do
        if type(item) == "table" and item.id and type(item.contentDetails) == "table" then
            durations[item.id] = Parser.FormatIsoDuration(item.contentDetails.duration)
        end
    end

    local results = {}

    for _, item in ipairs(type(searchResponse) == "table" and searchResponse.items or {}) do
        local videoId = type(item) == "table" and type(item.id) == "table" and item.id.videoId
        local snippet = type(item) == "table" and item.snippet

        if type(videoId) == "string" and videoId ~= "" and type(snippet) == "table" then
            local thumbnails = type(snippet.thumbnails) == "table" and snippet.thumbnails or {}
            local thumbnail = (thumbnails.high or thumbnails.medium or thumbnails.default or {}).url

            results[#results + 1] = {
                videoId = videoId,
                title = Parser.DecodeHtmlEntities(snippet.title),
                thumbnail = type(thumbnail) == "string" and thumbnail or ("https://i.ytimg.com/vi/" .. videoId .. "/mqdefault.jpg"),
                duration = durations[videoId] or "--:--",
                author = Parser.DecodeHtmlEntities(snippet.channelTitle)
            }

            if #results >= maxResults then
                break
            end
        end
    end

    return results
end

---------------------------------------------------------------------------------------------------
-- HTML scraping (experimental: depends on YouTube's page structure)
---------------------------------------------------------------------------------------------------

local function rendererText(renderer)
    if type(renderer) ~= "table" then
        return ""
    end

    if type(renderer.simpleText) == "string" then
        return renderer.simpleText
    end

    local parts = {}

    for _, run in ipairs(type(renderer.runs) == "table" and renderer.runs or {}) do
        if type(run) == "table" and type(run.text) == "string" then
            parts[#parts + 1] = run.text
        end
    end

    return table.concat(parts)
end

local function collectVideoRenderers(node, results, seen, maxResults, depth)
    if #results >= maxResults or type(node) ~= "table" or depth > 40 then
        return
    end

    local renderer = node.videoRenderer

    if type(renderer) == "table" then
        local videoId = tostring(renderer.videoId or "")

        if videoId ~= "" and not seen[videoId] then
            seen[videoId] = true

            local thumbnails = type(renderer.thumbnail) == "table" and renderer.thumbnail.thumbnails
            local last = type(thumbnails) == "table" and thumbnails[#thumbnails]
            local thumbnail = type(last) == "table" and tostring(last.url or "") or ""

            results[#results + 1] = {
                videoId = videoId,
                title = rendererText(renderer.title),
                thumbnail = thumbnail ~= "" and thumbnail or ("https://i.ytimg.com/vi/" .. videoId .. "/mqdefault.jpg"),
                duration = rendererText(renderer.lengthText),
                author = rendererText(renderer.ownerText)
            }
        end
    end

    for _, child in pairs(node) do
        collectVideoRenderers(child, results, seen, maxResults, depth + 1)
    end
end

--- Extracts the JSON object that follows `marker` in `content`, honoring nested braces and strings.
function Parser.ExtractBalancedJson(content, marker)
    local markerStart = content:find(marker, 1, true)
    local jsonStart = markerStart and content:find("{", markerStart, true)

    if not jsonStart then
        return nil
    end

    local depth = 0
    local inString = false
    local escaped = false

    for index = jsonStart, #content do
        local char = content:sub(index, index)

        if inString then
            if escaped then
                escaped = false
            elseif char == "\\" then
                escaped = true
            elseif char == "\"" then
                inString = false
            end
        elseif char == "\"" then
            inString = true
        elseif char == "{" then
            depth = depth + 1
        elseif char == "}" then
            depth = depth - 1

            if depth == 0 then
                return content:sub(jsonStart, index)
            end
        end
    end

    return nil
end

--- Parses a YouTube results page. `decodeJson` is injected so tests can run outside FiveM.
---@return table[]|nil results nil when the page could not be parsed
function Parser.ParseScrapedPage(html, maxResults, decodeJson)
    if type(html) ~= "string" then
        return nil
    end

    local jsonText = Parser.ExtractBalancedJson(html, "ytInitialData")

    if not jsonText then
        return nil
    end

    local ok, data = pcall(decodeJson, jsonText)

    if not ok or type(data) ~= "table" then
        return nil
    end

    local results = {}
    collectVideoRenderers(data, results, {}, maxResults, 0)

    return results
end
