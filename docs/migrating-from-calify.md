# Migrating from CaliFY (`califyapp_*` tables)

For servers that ran `mzm_CaliFY`, the vRP-only predecessor of FiveFY. The script copies the data into the `fivefy_*` tables and leaves the old tables untouched, so you can roll back by starting the old resource again.

`mzm_CaliFY` stored the vRP `user_id` directly. FiveFY maps framework identifiers to internal ids in `fivefy_users`; the vRP adapter uses `vrp:<user_id>`, so the script creates those rows with the **same numeric ids** and no other column needs to change.

## Before you start

- Requires `Config.Framework = "vrp"` (or `"auto"` with vRP running). The ids are only valid for the vRP server that created them.
- Run it on a copy of the database first, then schedule a maintenance window for the live one.
- Stop the server (or at least `mzm_CaliFY`) so no new rows are written during the copy.

## Steps

1. Back up the old tables:

   ```sh
   mysqldump -u USER -p DATABASE califyapp_profiles califyapp_follows califyapp_favorites califyapp_playlists califyapp_playlist_tracks califyapp_history califyapp_track_stats > calify-backup.sql
   ```

2. Create the FiveFY tables: start FiveFY once on an empty `fivefy_*` schema (it migrates automatically) or import `sql/install.sql`. The `fivefy_*` tables must be **empty**.

3. Run the copy in a single session:

   ```sql
   START TRANSACTION;

   INSERT INTO fivefy_users (id, identifier)
   SELECT user_id, CONCAT('vrp:', user_id) FROM (
       SELECT user_id FROM califyapp_profiles
       UNION SELECT user_id FROM califyapp_favorites
       UNION SELECT user_id FROM califyapp_playlists
       UNION SELECT user_id FROM califyapp_history
       UNION SELECT user_id FROM califyapp_track_stats
       UNION SELECT follower_user_id FROM califyapp_follows
       UNION SELECT target_user_id FROM califyapp_follows
   ) AS ids
   WHERE user_id > 0;

   INSERT INTO fivefy_profiles (user_id, display_name, bio, avatar, is_public, show_activity, updated_at)
   SELECT user_id, display_name, bio, avatar, is_public, show_activity, updated_at
   FROM califyapp_profiles WHERE user_id > 0;

   INSERT INTO fivefy_follows (follower_user_id, target_user_id, created_at)
   SELECT follower_user_id, target_user_id, created_at
   FROM califyapp_follows WHERE follower_user_id > 0 AND target_user_id > 0;

   INSERT INTO fivefy_favorites (user_id, video_id, title, thumbnail, duration, author, created_at)
   SELECT user_id, video_id, title, thumbnail, duration, author, created_at
   FROM califyapp_favorites WHERE user_id > 0;

   INSERT INTO fivefy_playlists (id, user_id, name, cover, share_code, visibility, created_at)
   SELECT id, user_id, name, cover, share_code, visibility, created_at
   FROM califyapp_playlists WHERE user_id > 0;

   INSERT INTO fivefy_playlist_tracks (playlist_id, video_id, title, thumbnail, duration, author, position, created_at)
   SELECT t.playlist_id, t.video_id, t.title, t.thumbnail, t.duration, t.author, t.position, t.created_at
   FROM califyapp_playlist_tracks t
   INNER JOIN fivefy_playlists p ON p.id = t.playlist_id;

   INSERT INTO fivefy_history (user_id, video_id, title, thumbnail, duration, author, played_at)
   SELECT user_id, video_id, title, thumbnail, duration, author, played_at
   FROM califyapp_history WHERE user_id > 0
   ORDER BY played_at ASC;

   INSERT INTO fivefy_track_stats (user_id, video_id, title, thumbnail, duration, author, play_count, skip_count, updated_at)
   SELECT user_id, video_id, title, thumbnail, duration, author, play_count, skip_count, updated_at
   FROM califyapp_track_stats WHERE user_id > 0;

   COMMIT;
   ```

   Known limitation: when vRP did not return a user id, `mzm_CaliFY` stored the player's **server id** (`source`) instead. Those rows cannot be told apart from real vRP ids, so they are migrated as if they belonged to the vRP user with the same number. This only happened while vRP was not ready (e.g. during a resource restart); if your server ran vRP normally the impact is limited to a few history rows. Rows with `user_id = 0` are skipped.

4. Check the counts match:

   ```sql
   SELECT
       (SELECT COUNT(*) FROM califyapp_playlists WHERE user_id > 0) AS old_playlists,
       (SELECT COUNT(*) FROM fivefy_playlists) AS new_playlists,
       (SELECT COUNT(*) FROM califyapp_favorites WHERE user_id > 0) AS old_favorites,
       (SELECT COUNT(*) FROM fivefy_favorites) AS new_favorites;
   ```

5. Keep the app identity for players by setting, in `config.lua`:

   ```lua
   Config.Phone.Identifier = "calify"
   Config.Phone.Name = "CaliFY"
   ```

6. Start FiveFY and do not start `mzm_CaliFY` again. Keep the `califyapp_*` tables until you are confident the migration is complete.

## Rollback

Stop FiveFY and start `mzm_CaliFY` again: its tables were not modified. Data created in FiveFY after the migration is not copied back.
