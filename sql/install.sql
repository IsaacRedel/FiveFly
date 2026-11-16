-- FiveFly database schema (version 1).
--
-- You do NOT need to run this file: FiveFly creates and upgrades its tables automatically on start
-- (server/migrations.lua). Use it only if your database user cannot create tables at runtime.
-- Compatible with MySQL 8 and MariaDB 10.x.

CREATE TABLE IF NOT EXISTS fivefly_schema (
    version INT NOT NULL,
    applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (version)
);

CREATE TABLE IF NOT EXISTS fivefly_users (
    id INT NOT NULL AUTO_INCREMENT,
    identifier VARCHAR(64) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_fivefly_users_identifier (identifier)
) DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS fivefly_profiles (
    user_id INT NOT NULL,
    display_name VARCHAR(64) NOT NULL DEFAULT '',
    bio VARCHAR(140) NULL,
    avatar TEXT NULL,
    is_public TINYINT(1) NOT NULL DEFAULT 1,
    show_activity TINYINT(1) NOT NULL DEFAULT 1,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id),
    KEY idx_fivefly_profiles_public_name (is_public, display_name)
) DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS fivefly_follows (
    follower_user_id INT NOT NULL,
    target_user_id INT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (follower_user_id, target_user_id),
    KEY idx_fivefly_follows_target (target_user_id)
) DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS fivefly_favorites (
    user_id INT NOT NULL,
    video_id VARCHAR(32) NOT NULL,
    title VARCHAR(255) NOT NULL,
    thumbnail TEXT NULL,
    duration VARCHAR(24) NULL,
    author VARCHAR(128) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, video_id),
    KEY idx_fivefly_favorites_video (video_id)
) DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS fivefly_playlists (
    id INT NOT NULL AUTO_INCREMENT,
    user_id INT NOT NULL,
    name VARCHAR(48) NOT NULL,
    cover TEXT NULL,
    share_code VARCHAR(12) NULL,
    visibility VARCHAR(16) NOT NULL DEFAULT 'private',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_fivefly_playlists_share_code (share_code),
    KEY idx_fivefly_playlists_user (user_id),
    KEY idx_fivefly_playlists_visibility (visibility)
) DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS fivefly_playlist_tracks (
    playlist_id INT NOT NULL,
    video_id VARCHAR(32) NOT NULL,
    title VARCHAR(255) NOT NULL,
    thumbnail TEXT NULL,
    duration VARCHAR(24) NULL,
    author VARCHAR(128) NULL,
    position INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (playlist_id, video_id),
    KEY idx_fivefly_playlist_tracks_playlist (playlist_id, position)
) DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS fivefly_history (
    id BIGINT NOT NULL AUTO_INCREMENT,
    user_id INT NOT NULL,
    video_id VARCHAR(32) NOT NULL,
    title VARCHAR(255) NOT NULL,
    thumbnail TEXT NULL,
    duration VARCHAR(24) NULL,
    author VARCHAR(128) NULL,
    played_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_fivefly_history_user_time (user_id, played_at)
) DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS fivefly_track_stats (
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
    KEY idx_fivefly_track_stats_user_play (user_id, play_count),
    KEY idx_fivefly_track_stats_user_skip (user_id, skip_count)
) DEFAULT CHARSET = utf8mb4;

-- Mark version 1 as applied so the automatic migrations skip it.
INSERT IGNORE INTO fivefly_schema (version) VALUES (1);
