FiveFY.RateLimit = {}

local buckets = {}

--- Allows one call per `cooldownMs` for each player and key.
---@param source integer
---@param key string
---@param cooldownMs integer
---@return boolean allowed, integer remainingMs
function FiveFY.RateLimit.Allow(source, key, cooldownMs)
    local now = GetGameTimer()
    local playerBuckets = buckets[source]

    if not playerBuckets then
        playerBuckets = {}
        buckets[source] = playerBuckets
    end

    local last = playerBuckets[key] or 0

    if now - last < cooldownMs then
        return false, cooldownMs - (now - last)
    end

    playerBuckets[key] = now
    return true, 0
end

function FiveFY.RateLimit.Clear(source)
    buckets[source] = nil
end

AddEventHandler("playerDropped", function()
    FiveFY.RateLimit.Clear(source)
end)
