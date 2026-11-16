FiveFly.Repo = FiveFly.Repo or {}
FiveFly.Repo.Profiles = {}

local Profiles = FiveFly.Repo.Profiles
local Utils = FiveFly.Utils

---@class Profile
---@field userId integer
---@field name string
---@field bio string
---@field avatar string
---@field isPublic boolean
---@field showActivity boolean
---@field following boolean
---@field followerCount integer
---@field followingCount integer
---@field publicPlaylists table[]

-- Selects a profile with its follower counts and whether the viewer (first parameter) follows it.
local PROFILE_COLUMNS <const> = [[
    p.user_id, p.display_name, p.bio, p.avatar, p.is_public, p.show_activity,
    (SELECT COUNT(*) FROM fivefly_follows f1 WHERE f1.target_user_id = p.user_id) AS follower_count,
    (SELECT COUNT(*) FROM fivefly_follows f2 WHERE f2.follower_user_id = p.user_id) AS following_count,
    EXISTS(SELECT 1 FROM fivefly_follows f3 WHERE f3.follower_user_id = ? AND f3.target_user_id = p.user_id) AS is_following
]]

local function normalizeDisplayName(value)
    local name = Utils.Trim(value):sub(1, 64)
    return name ~= "" and name or "Player"
end

local function isTrue(value, default)
    if value == nil then
        return default
    end

    return value == true or tonumber(value) == 1
end

---@return Profile
function Profiles.Map(row)
    return {
        userId = tonumber(row.user_id) or 0,
        name = normalizeDisplayName(row.display_name),
        bio = tostring(row.bio or ""),
        avatar = tostring(row.avatar or ""),
        isPublic = isTrue(row.is_public, true),
        showActivity = isTrue(row.show_activity, true),
        following = isTrue(row.is_following, false),
        followerCount = tonumber(row.follower_count) or 0,
        followingCount = tonumber(row.following_count) or 0,
        publicPlaylists = {}
    }
end

--- Creates the profile on first use and keeps the display name in sync with the character name.
function Profiles.Ensure(userId, displayName)
    MySQL.insert.await([[
        INSERT INTO fivefly_profiles (user_id, display_name)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE display_name = VALUES(display_name)
    ]], { userId, normalizeDisplayName(displayName) })
end

---@return Profile|nil
function Profiles.Get(userId, viewerUserId)
    local rows = MySQL.query.await(([[
        SELECT %s
        FROM fivefly_profiles p
        WHERE p.user_id = ?
        LIMIT 1
    ]]):format(PROFILE_COLUMNS), { viewerUserId or 0, userId }) or {}

    return rows[1] and Profiles.Map(rows[1]) or nil
end

function Profiles.Update(userId, fields)
    MySQL.update.await([[
        UPDATE fivefly_profiles
        SET bio = ?, avatar = ?, is_public = ?, show_activity = ?
        WHERE user_id = ?
    ]], {
        Utils.Trim(fields.bio):sub(1, 140),
        Utils.NormalizeHttpUrl(fields.avatar),
        fields.isPublic and 1 or 0,
        fields.showActivity and 1 or 0,
        userId
    })
end

function Profiles.CanShowActivity(userId)
    local rows = MySQL.query.await([[
        SELECT is_public, show_activity FROM fivefly_profiles WHERE user_id = ? LIMIT 1
    ]], { userId }) or {}

    local row = rows[1]
    return row ~= nil and isTrue(row.is_public, true) and isTrue(row.show_activity, true)
end

---@return Profile[]
function Profiles.GetFollowing(userId)
    local rows = MySQL.query.await(([[
        SELECT %s
        FROM fivefly_follows f
        INNER JOIN fivefly_profiles p ON p.user_id = f.target_user_id
        WHERE f.follower_user_id = ? AND p.is_public = 1
        ORDER BY p.display_name ASC
        LIMIT 30
    ]]):format(PROFILE_COLUMNS), { userId, userId }) or {}

    local profiles = {}

    for _, row in ipairs(rows) do
        profiles[#profiles + 1] = Profiles.Map(row)
    end

    return profiles
end

--- Returns the subset of `userIds` followed by `followerUserId`, as a set.
---@param followerUserId integer
---@param userIds integer[]
---@return table<integer, boolean>
function Profiles.GetFollowedSet(followerUserId, userIds)
    local followed = {}

    if #userIds == 0 then
        return followed
    end

    local placeholders = string.rep("?", #userIds, ",")
    local params = { followerUserId }

    for _, id in ipairs(userIds) do
        params[#params + 1] = id
    end

    local rows = MySQL.query.await(([[
        SELECT target_user_id FROM fivefly_follows
        WHERE follower_user_id = ? AND target_user_id IN (%s)
    ]]):format(placeholders), params) or {}

    for _, row in ipairs(rows) do
        followed[tonumber(row.target_user_id)] = true
    end

    return followed
end

---@return boolean|nil following, string|nil error
function Profiles.ToggleFollow(followerUserId, targetUserId)
    local target = tonumber(targetUserId)

    if not target or target <= 0 or target == followerUserId then
        return nil, "invalid_profile"
    end

    local exists = MySQL.query.await("SELECT 1 FROM fivefly_profiles WHERE user_id = ? LIMIT 1", { target }) or {}

    if not exists[1] then
        return nil, "profile_not_found"
    end

    local removed = MySQL.update.await([[
        DELETE FROM fivefly_follows WHERE follower_user_id = ? AND target_user_id = ?
    ]], { followerUserId, target })

    if removed and removed > 0 then
        return false, nil
    end

    MySQL.insert.await([[
        INSERT IGNORE INTO fivefly_follows (follower_user_id, target_user_id) VALUES (?, ?)
    ]], { followerUserId, target })

    return true, nil
end

---@return Profile[]
function Profiles.Search(viewerUserId, query)
    local pattern = "%" .. query .. "%"
    local rows = MySQL.query.await(([[
        SELECT %s
        FROM fivefly_profiles p
        WHERE p.is_public = 1 AND (p.display_name LIKE ? OR p.bio LIKE ? OR p.user_id = ?)
        ORDER BY p.display_name ASC
        LIMIT 10
    ]]):format(PROFILE_COLUMNS), { viewerUserId, pattern, pattern, tonumber(query) or -1 }) or {}

    local profiles = {}

    for _, row in ipairs(rows) do
        profiles[#profiles + 1] = Profiles.Map(row)
    end

    return profiles
end
