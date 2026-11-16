--- Validates image URLs against whitelists and re-uploads images from temporary hosts to Fivemanage.
FiveFly.Media = {}

local trim = FiveFly.Utils.Trim

local BASE64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local CONTENT_TYPE_EXTENSIONS = {
    ["image/jpeg"] = "jpg",
    ["image/jpg"] = "jpg",
    ["image/png"] = "png",
    ["image/webp"] = "webp",
    ["image/gif"] = "gif"
}
local lbPhoneApiKeyLoaded = false
local lbPhoneImageApiKey = nil

local function getPhoneResource()
    return Config.Phone and Config.Phone.Resource or "lb-phone"
end

--- Lowercase hostname of an http(s) URL, or nil when the authority contains anything other than a plain host
--- (credentials, backslashes or unusual characters could make the host checked differ from the one requested).
function FiveFly.Media.GetHostname(url)
    local authority = trim(url):lower():match("^https?://([^/%?#]+)")

    if not authority then
        return nil
    end

    local host = authority:gsub(":%d+$", "")

    if host == "" or host:find("[^%w%.%-]") or host:find("%.%.") then
        return nil
    end

    return host
end

local getHostname = FiveFly.Media.GetHostname

local function escapePattern(value)
    return (value:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

local function getHostnamePattern(entry)
    local parts = {}

    for segment in tostring(entry or ""):lower():gmatch("[^%.]+") do
        parts[#parts + 1] = segment == "*" and "[^.]+" or escapePattern(segment)
    end

    return "^" .. table.concat(parts, "%.") .. "$"
end

local function getDomainPatterns(entry)
    local escaped = escapePattern(tostring(entry or ""):lower())
    return "^" .. escaped .. "$", "^.+%." .. escaped .. "$"
end

local function addHostnamePatterns(target, entries)
    if type(entries) ~= "table" then return end

    for i = 1, #entries do
        target[#target + 1] = getHostnamePattern(entries[i])
    end
end

local function addDomainPatterns(target, entries)
    if type(entries) ~= "table" then return end

    for i = 1, #entries do
        local exact, subdomain = getDomainPatterns(entries[i])
        target[#target + 1] = exact
        target[#target + 1] = subdomain
    end
end

local function matchesAny(hostname, patterns)
    for i = 1, #patterns do
        if hostname:find(patterns[i]) then
            return true
        end
    end

    return false
end

local function getLbPhoneConfig()
    local resource = getPhoneResource()

    if GetResourceState(resource) ~= "started" then
        return nil
    end

    local ok, lbConfig = pcall(function()
        return exports[resource]:GetConfig()
    end)

    if ok and type(lbConfig) == "table" then
        return lbConfig
    end

    return nil
end

local function getMediaConfig(name)
    local mediaConfig = Config.Media or {}
    local lbConfig = getLbPhoneConfig()

    if lbConfig and lbConfig[name] ~= nil then
        return lbConfig[name]
    end

    return mediaConfig[name]
end

local function buildRules()
    local allowedPatterns = {}
    local blockedPatterns = {}

    addHostnamePatterns(allowedPatterns, getMediaConfig("ExternalWhitelistedHostnames"))
    addDomainPatterns(allowedPatterns, getMediaConfig("ExternalWhitelistedDomains"))
    addHostnamePatterns(allowedPatterns, getMediaConfig("UploadWhitelistedHostnames"))
    addDomainPatterns(allowedPatterns, getMediaConfig("UploadWhitelistedDomains"))
    addHostnamePatterns(blockedPatterns, getMediaConfig("ExternalBlacklistedHostnames"))
    addDomainPatterns(blockedPatterns, getMediaConfig("ExternalBlacklistedDomains"))

    return allowedPatterns, blockedPatterns
end

function FiveFly.Media.IsAllowed(url)
    local hostname = getHostname(url)

    if not hostname or not hostname:find("%.") then
        return false
    end

    local allowedPatterns, blockedPatterns = buildRules()

    if matchesAny(hostname, blockedPatterns) then
        return false
    end

    if #allowedPatterns == 0 then
        return true
    end

    return matchesAny(hostname, allowedPatterns)
end

local function shouldReupload(url)
    local hostname = getHostname(url)

    if not hostname then
        return false
    end

    local reuploadHostnames = Config.Media and Config.Media.ReuploadHostnames or {}

    for i = 1, #reuploadHostnames do
        local pattern = getHostnamePattern(reuploadHostnames[i])

        if hostname:find(pattern) then
            return true
        end
    end

    return false
end

local function awaitHttp(url, method, data, headers)
    local request = promise.new()

    PerformHttpRequest(url, function(status, body, responseHeaders)
        request:resolve({
            status = status,
            body = body,
            headers = responseHeaders or {}
        })
    end, method or "GET", data or "", headers or {})

    return Citizen.Await(request)
end

local function getHeader(headers, name)
    local target = name:lower()

    for key, value in pairs(headers or {}) do
        if tostring(key):lower() == target then
            return tostring(value)
        end
    end

    return nil
end

local BASE64_LOOKUP = {}

for index = 1, #BASE64_CHARS do
    BASE64_LOOKUP[index - 1] = BASE64_CHARS:sub(index, index)
end

function FiveFly.Media.Base64Encode(data)
    local output = {}
    local length = #data

    for index = 1, length, 3 do
        local a, b, c = data:byte(index, index + 2)
        local chunk = (a << 16) | ((b or 0) << 8) | (c or 0)

        output[#output + 1] = BASE64_LOOKUP[(chunk >> 18) & 63]
            .. BASE64_LOOKUP[(chunk >> 12) & 63]
            .. (b and BASE64_LOOKUP[(chunk >> 6) & 63] or "=")
            .. (c and BASE64_LOOKUP[chunk & 63] or "=")
    end

    return table.concat(output)
end

local base64Encode = FiveFly.Media.Base64Encode

local function extensionFromContentType(contentType)
    return CONTENT_TYPE_EXTENSIONS[tostring(contentType or ""):lower()]
end

local function extensionFromUrl(url)
    return tostring(url or ""):lower():match("%.([a-z0-9]+)%??[^/]*$") or "webp"
end

--- Reads the Image key from lb-phone's server/apiKeys.lua (cached after the first attempt).
local function getLbPhoneImageApiKey()
    if lbPhoneApiKeyLoaded then
        return lbPhoneImageApiKey
    end

    lbPhoneApiKeyLoaded = true

    local resource = getPhoneResource()
    local apiKeysFile = LoadResourceFile(resource, "server/apiKeys.lua")

    if type(apiKeysFile) ~= "string" or apiKeysFile == "" then
        return nil
    end

    local env = setmetatable({
        GetCurrentResourceName = function()
            return resource
        end
    }, { __index = _G })
    local chunk = load(apiKeysFile, ("@%s/server/apiKeys.lua"):format(resource), "t", env)

    if not chunk or not pcall(chunk) or type(env.API_KEYS) ~= "table" then
        return nil
    end

    local imageKey = env.API_KEYS.Image

    if type(imageKey) == "string" and imageKey ~= "" and imageKey ~= "API_KEY_HERE" then
        lbPhoneImageApiKey = imageKey
    end

    return lbPhoneImageApiKey
end

local function getFivemanageApiKey()
    local apiKey = GetConvar("fivefly_fivemanage_key", "")

    if apiKey ~= "" then
        return apiKey
    end

    if Config.Media and Config.Media.UseLbPhoneApiKey then
        return getLbPhoneImageApiKey()
    end

    return nil
end

local function reuploadToFivemanage(sourceUrl)
    local apiKey = getFivemanageApiKey()

    if not apiKey then
        return nil, "media_reupload_not_configured"
    end

    local download = awaitHttp(sourceUrl, "GET")

    if not download or download.status ~= 200 or type(download.body) ~= "string" then
        return nil, "media_download_failed"
    end

    local maxBytes = Config.Media and tonumber(Config.Media.MaxDownloadBytes) or 8388608

    if maxBytes and maxBytes > 0 and #download.body > maxBytes then
        return nil, "media_too_large"
    end

    local contentType = getHeader(download.headers, "content-type") or "image/webp"

    if not contentType:lower():match("^image/") then
        return nil, "media_not_image"
    end

    local extension = extensionFromContentType(contentType) or extensionFromUrl(sourceUrl)
    local filename = ("fivefly-%d.%s"):format(os.time(), extension)
    local payload = json.encode({
        base64 = ("data:%s;base64,%s"):format(contentType, base64Encode(download.body)),
        filename = filename,
        retentionExempt = true,
        metadata = json.encode({
            source = "fivefly-external-reupload",
            originalUrl = sourceUrl
        })
    })

    local upload = awaitHttp("https://api.fivemanage.com/api/v3/file/base64", "POST", payload, {
        ["Content-Type"] = "application/json",
        ["Authorization"] = apiKey
    })

    if not upload or (upload.status ~= 200 and upload.status ~= 201) then
        return nil, "media_upload_failed"
    end

    local ok, decoded = pcall(json.decode, upload.body or "")

    if not ok or type(decoded) ~= "table" then
        return nil, "media_upload_failed"
    end

    local uploadedUrl = decoded.url or (decoded.data and decoded.data.url)

    if type(uploadedUrl) ~= "string" or uploadedUrl == "" then
        return nil, "media_upload_failed"
    end

    return uploadedUrl, nil
end

function FiveFly.Media.ResolveImageUrl(url)
    local safeUrl = trim(url):sub(1, 512)

    if safeUrl == "" then
        return "", nil
    end

    if not safeUrl:match("^https?://") or not FiveFly.Media.IsAllowed(safeUrl) then
        return nil, "media_not_allowed"
    end

    if Config.Media and Config.Media.ReuploadExternal == true and shouldReupload(safeUrl) then
        local uploadedUrl, uploadError = reuploadToFivemanage(safeUrl)

        if not uploadedUrl then
            if Config.Media.RequireReuploadForTemporaryHosts == true then
                return nil, uploadError
            end

            return safeUrl, nil
        end

        if not FiveFly.Media.IsAllowed(uploadedUrl) then
            return nil, "media_not_allowed"
        end

        return uploadedUrl:sub(1, 512), nil
    end

    return safeUrl, nil
end
