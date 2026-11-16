--- Maps framework identifiers ("qb:ABC123", "vrp:42", "license:...") to internal numeric user ids.
--- Internal ids are what the database and the UI use, so framework identifiers never reach other players.
FiveFY.Identity = {}

local Identity = FiveFY.Identity
local idByIdentifier = {}

---@param identifier string
---@return integer|nil
local function resolveIdentifier(identifier)
    local cached = idByIdentifier[identifier]

    if cached then
        return cached
    end

    MySQL.insert.await("INSERT IGNORE INTO fivefy_users (identifier) VALUES (?)", { identifier })

    local rows = MySQL.query.await("SELECT id FROM fivefy_users WHERE identifier = ? LIMIT 1", { identifier }) or {}
    local userId = tonumber(rows[1] and rows[1].id)

    if userId then
        idByIdentifier[identifier] = userId
    end

    return userId
end

--- Returns the internal user id for a connected player, or nil while the framework has no character loaded.
--- The identifier is read on every call, so character switches (multicharacter) are picked up automatically.
---@param source integer
---@return integer|nil
function Identity.GetUserId(source)
    local identifier = FiveFY.Bridge.GetIdentifier(source)

    if not identifier then
        return nil
    end

    return resolveIdentifier(identifier)
end
