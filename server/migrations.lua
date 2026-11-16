FiveFY.Database = {
    ready = false
}

--- Each migration runs once, in order, and is recorded in fivefy_schema.
--- Only use SQL supported by both MySQL 8 and MariaDB 10.x.
local MIGRATIONS <const> = {
    {
        version = 1,
        name = "initial schema",
        statements = {
            [[
            CREATE TABLE IF NOT EXISTS fivefy_users (
                id INT NOT NULL AUTO_INCREMENT,
                identifier VARCHAR(64) NOT NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                UNIQUE KEY uq_fivefy_users_identifier (identifier)
            ) DEFAULT CHARSET = utf8mb4
            ]],
            [[
            CREATE TABLE IF NOT EXISTS fivefy_profiles (
                user_id INT NOT NULL,
                display_name VARCHAR(64) NOT NULL DEFAULT '',
                bio VARCHAR(140) NULL,
                avatar TEXT NULL,
                is_public TINYINT(1) NOT NULL DEFAULT 1,
                show_activity TINYINT(1) NOT NULL DEFAULT 1,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (user_id),
                KEY idx_fivefy_profiles_public_name (is_public, display_name)
            ) DEFAULT CHARSET = utf8mb4
            ]],
            [[
            CREATE TABLE IF NOT EXISTS fivefy_follows (
                follower_user_id INT NOT NULL,
                target_user_id INT NOT NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (follower_user_id, target_user_id),
                KEY idx_fivefy_follows_target (target_user_id)
            ) DEFAULT CHARSET = utf8mb4
            ]],
            [[
            CREATE TABLE IF NOT EXISTS fivefy_favorites (
                user_id INT NOT NULL,
                video_id VARCHAR(32) NOT NULL,
                title VARCHAR(255) NOT NULL,
                thumbnail TEXT NULL,
                duration VARCHAR(24) NULL,
                author VARCHAR(128) NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (user_id, video_id),
                KEY idx_fivefy_favorites_video (video_id)
            ) DEFAULT CHARSET = utf8mb4
            ]],
            [[
            CREATE TABLE IF NOT EXISTS fivefy_playlists (
                id INT NOT NULL AUTO_INCREMENT,
                user_id INT NOT NULL,
                name VARCHAR(48) NOT NULL,
                cover TEXT NULL,
                share_code VARCHAR(12) NULL,
                visibility VARCHAR(16) NOT NULL DEFAULT 'private',
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                UNIQUE KEY uq_fivefy_playlists_share_code (share_code),
                KEY idx_fivefy_playlists_user (user_id),
                KEY idx_fivefy_playlists_visibility (visibility)
            ) DEFAULT CHARSET = utf8mb4
            ]],
            [[
            CREATE TABLE IF NOT EXISTS fivefy_playlist_tracks (
                playlist_id INT NOT NULL,
                video_id VARCHAR(32) NOT NULL,
                title VARCHAR(255) NOT NULL,
                thumbnail TEXT NULL,
                duration VARCHAR(24) NULL,
                author VARCHAR(128) NULL,
                position INT NOT NULL DEFAULT 0,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (playlist_id, video_id),
                KEY idx_fivefy_playlist_tracks_playlist (playlist_id, position)
            ) DEFAULT CHARSET = utf8mb4
            ]],
            [[
            CREATE TABLE IF NOT EXISTS fivefy_history (
                id BIGINT NOT NULL AUTO_INCREMENT,
                user_id INT NOT NULL,
                video_id VARCHAR(32) NOT NULL,
                title VARCHAR(255) NOT NULL,
                thumbnail TEXT NULL,
                duration VARCHAR(24) NULL,
                author VARCHAR(128) NULL,
                played_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                KEY idx_fivefy_history_user_time (user_id, played_at)
            ) DEFAULT CHARSET = utf8mb4
            ]],
            [[
            CREATE TABLE IF NOT EXISTS fivefy_track_stats (
                user_id INT NOT NULL,
                video_id VARCHAR(32) NOT NULL,
                title VARCHAR(255) NOT NULL,
                thumbnail TEXT NULL,
                duration VARCHAR(24) NULL,
                author VARCHAR(128) NULL,
                play_count INT NOT NULL DEFAULT 0,
                skip_count INT NOT NULL DEFAULT 0,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (user_id, video_id),
                KEY idx_fivefy_track_stats_user_play (user_id, play_count),
                KEY idx_fivefy_track_stats_user_skip (user_id, skip_count)
            ) DEFAULT CHARSET = utf8mb4
            ]]
        }
    }
}

FiveFY.Database.LatestVersion = MIGRATIONS[#MIGRATIONS].version

local function getCurrentVersion()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS fivefy_schema (
            version INT NOT NULL,
            applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (version)
        )
    ]])

    local rows = MySQL.query.await("SELECT MAX(version) AS version FROM fivefy_schema") or {}
    return tonumber(rows[1] and rows[1].version) or 0
end

local function runMigrations()
    local current = getCurrentVersion()

    for _, migration in ipairs(MIGRATIONS) do
        if migration.version > current then
            FiveFY.Log("info", "applying database migration %d (%s)", migration.version, migration.name)

            for _, statement in ipairs(migration.statements) do
                MySQL.query.await(statement)
            end

            MySQL.insert.await("INSERT INTO fivefy_schema (version) VALUES (?)", { migration.version })
        end
    end
end

MySQL.ready(function()
    local ok, err = pcall(runMigrations)

    if not ok then
        FiveFY.Log("error", "database migration failed, FiveFY will not accept requests: %s", tostring(err))
        return
    end

    FiveFY.Database.ready = true
    FiveFY.Log("debug", "database schema at version %d", FiveFY.Database.LatestVersion)
end)
