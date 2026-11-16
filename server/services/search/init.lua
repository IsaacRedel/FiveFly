--- Music search with pluggable providers and a bounded in-memory cache.
FiveFly.Search = {}

local Search = FiveFly.Search
local Parser = FiveFly.SearchParser
local Utils = FiveFly.Utils

local cache = {}
local cacheSize = 0

local function httpGet(url, headers)
    local pending = promise.new()

    PerformHttpRequest(url, function(status, body)
        pending:resolve({ status = status, body = body or "" })
    end, "GET", "", headers or {})

    return Citizen.Await(pending)
end

local function decodeJson(text)
    local ok, decoded = pcall(json.decode, text)
    return ok and decoded or nil
end

local function getApiKey()
    return GetConvar("fivefly_youtube_key", "")
end

local function getRegion()
    return Config.Search.RegionCode or (FiveFly.GetLocale() == "pt-BR" and "BR" or "US")
end

local function getLanguage()
    return Config.Search.Language or (FiveFly.GetLocale() == "pt-BR" and "pt" or "en")
end

---@type table<string, fun(query: string): table[]|nil, string|nil>
local providers = {}

providers.youtube_api = function(query)
    local apiKey = getApiKey()

    if apiKey == "" then
        return nil, "search_not_configured"
    end

    local maxResults = math.min(50, Config.Search.MaxResults)
    local searchUrl = ("https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&videoEmbeddable=true&maxResults=%d&q=%s&regionCode=%s&relevanceLanguage=%s&key=%s")
        :format(maxResults, Parser.UrlEncode(query), Parser.UrlEncode(getRegion()),
            Parser.UrlEncode(getLanguage()), Parser.UrlEncode(apiKey))
    local searchResponse = httpGet(searchUrl)

    if searchResponse.status ~= 200 then
        FiveFly.Log("warn", FiveFly.T("log.youtube_api_failed", tostring(searchResponse.status)))
        return nil, "search_unavailable"
    end

    local searchData = decodeJson(searchResponse.body)

    if type(searchData) ~= "table" then
        return nil, "search_parse_failed"
    end

    local ids = {}

    for _, item in ipairs(searchData.items or {}) do
        if type(item) == "table" and type(item.id) == "table" and type(item.id.videoId) == "string" then
            ids[#ids + 1] = item.id.videoId
        end
    end

    local videosData = nil

    if #ids > 0 then
        -- videos.list costs 1 quota unit (search.list costs 100), so durations are cheap to add.
        local videosResponse = httpGet(("https://www.googleapis.com/youtube/v3/videos?part=contentDetails&id=%s&key=%s")
            :format(table.concat(ids, ","), Parser.UrlEncode(apiKey)))

        if videosResponse.status == 200 then
            videosData = decodeJson(videosResponse.body)
        end
    end

    return Parser.ParseApiResults(searchData, videosData, maxResults), nil
end

providers.scrape = function(query)
    local response = httpGet("https://www.youtube.com/results?search_query=" .. Parser.UrlEncode(query), {
        ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36",
        ["Accept-Language"] = ("%s,en;q=0.8"):format(getLanguage())
    })

    if response.status ~= 200 then
        return nil, "search_unavailable"
    end

    local results = Parser.ParseScrapedPage(response.body, Config.Search.MaxResults, json.decode)

    if not results then
        FiveFly.Log("warn", FiveFly.T("log.scrape_parse_failed"))
        return nil, "search_parse_failed"
    end

    return results, nil
end

local function getProviderName()
    local wanted = tostring(Config.Search.Provider or "auto")

    if wanted == "auto" then
        return getApiKey() ~= "" and "youtube_api" or "scrape"
    end

    return providers[wanted] and wanted or "scrape"
end

local function cacheGet(key)
    local entry = cache[key]

    if entry and os.time() - entry.createdAt < Config.Search.CacheTtlSeconds then
        return entry.results
    end

    return nil
end

local function cacheSet(key, results)
    if not cache[key] then
        if cacheSize >= (Config.Search.CacheMaxEntries or 500) then
            -- Simple bound: drop everything rather than tracking LRU order for a best-effort cache.
            cache = {}
            cacheSize = 0
        end

        cacheSize = cacheSize + 1
    end

    cache[key] = { createdAt = os.time(), results = results }
end

---@return boolean success, table[] results, string|nil error
function Search.SearchTracks(query)
    local normalized = Utils.Trim(query)

    if #normalized < Config.Search.MinLength then
        return true, {}, nil
    end

    normalized = normalized:sub(1, Config.Search.MaxLength)

    local providerName = getProviderName()
    local cacheKey = providerName .. ":" .. normalized:lower()
    local cached = cacheGet(cacheKey)

    if cached then
        return true, cached, nil
    end

    local results, searchError = providers[providerName](normalized)

    if not results then
        return false, {}, searchError
    end

    results = Utils.NormalizeTrackList(results, Config.Search.MaxResults)
    cacheSet(cacheKey, results)

    return true, results, nil
end

CreateThread(function()
    Wait(1000)

    if getProviderName() == "scrape" then
        FiveFly.Log("info", FiveFly.T("log.scrape_provider"))
    else
        FiveFly.Log("debug", "search provider: %s", getProviderName())
    end
end)
