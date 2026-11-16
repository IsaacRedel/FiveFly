# Migrando do CaliFY (tabelas `califyapp_*`)

> English: [docs/migrating-from-calify.md](../migrating-from-calify.md)

Para servidores que usavam o `mzm_CaliFY`, o antecessor do FiveFly que só funcionava com vRP. O script copia os dados para as tabelas `fivefly_*` e não mexe nas antigas, então dá para voltar atrás iniciando o resource antigo de novo.

O `mzm_CaliFY` gravava o `user_id` do vRP direto. O FiveFly mapeia os identificadores do framework para ids internos em `fivefly_users`; o adaptador do vRP usa `vrp:<user_id>`, então o script cria essas linhas com os **mesmos ids numéricos**, e nenhuma outra coluna precisa mudar.

## Antes de começar

- Exige `Config.Framework = "vrp"` (ou `"auto"` com o vRP rodando). Os ids só valem para o servidor vRP que os criou.
- Rode primeiro numa cópia do banco e depois agende uma janela de manutenção para o banco de produção.
- Pare o servidor (ou pelo menos o `mzm_CaliFY`) para que nenhuma linha nova seja gravada durante a cópia.

## Passos

1. Faça backup das tabelas antigas:

   ```sh
   mysqldump -u USER -p DATABASE califyapp_profiles califyapp_follows califyapp_favorites califyapp_playlists califyapp_playlist_tracks califyapp_history califyapp_track_stats > calify-backup.sql
   ```

2. Crie as tabelas do FiveFly: inicie o FiveFly uma vez com o schema `fivefly_*` vazio (ele migra sozinho) ou importe `sql/install.sql`. As tabelas `fivefly_*` precisam estar **vazias**.

3. Rode a cópia numa única sessão:

   ```sql
   START TRANSACTION;

   INSERT INTO fivefly_users (id, identifier)
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

   INSERT INTO fivefly_profiles (user_id, display_name, bio, avatar, is_public, show_activity, updated_at)
   SELECT user_id, display_name, bio, avatar, is_public, show_activity, updated_at
   FROM califyapp_profiles WHERE user_id > 0;

   INSERT INTO fivefly_follows (follower_user_id, target_user_id, created_at)
   SELECT follower_user_id, target_user_id, created_at
   FROM califyapp_follows WHERE follower_user_id > 0 AND target_user_id > 0;

   INSERT INTO fivefly_favorites (user_id, video_id, title, thumbnail, duration, author, created_at)
   SELECT user_id, video_id, title, thumbnail, duration, author, created_at
   FROM califyapp_favorites WHERE user_id > 0;

   INSERT INTO fivefly_playlists (id, user_id, name, cover, share_code, visibility, created_at)
   SELECT id, user_id, name, cover, share_code, visibility, created_at
   FROM califyapp_playlists WHERE user_id > 0;

   INSERT INTO fivefly_playlist_tracks (playlist_id, video_id, title, thumbnail, duration, author, position, created_at)
   SELECT t.playlist_id, t.video_id, t.title, t.thumbnail, t.duration, t.author, t.position, t.created_at
   FROM califyapp_playlist_tracks t
   INNER JOIN fivefly_playlists p ON p.id = t.playlist_id;

   INSERT INTO fivefly_history (user_id, video_id, title, thumbnail, duration, author, played_at)
   SELECT user_id, video_id, title, thumbnail, duration, author, played_at
   FROM califyapp_history WHERE user_id > 0
   ORDER BY played_at ASC;

   INSERT INTO fivefly_track_stats (user_id, video_id, title, thumbnail, duration, author, play_count, skip_count, updated_at)
   SELECT user_id, video_id, title, thumbnail, duration, author, play_count, skip_count, updated_at
   FROM califyapp_track_stats WHERE user_id > 0;

   COMMIT;
   ```

   Limitação conhecida: quando o vRP não retornava um user id, o `mzm_CaliFY` gravava o **id do servidor** do jogador (`source`). Essas linhas não podem ser diferenciadas de ids reais do vRP, então são migradas como se fossem do usuário vRP com o mesmo número. Isso só acontecia enquanto o vRP não estava pronto (por exemplo, durante um restart de resource); se o servidor rodava o vRP normalmente, o impacto se limita a poucas linhas de histórico. Linhas com `user_id = 0` são ignoradas.

4. Confira se as contagens batem:

   ```sql
   SELECT
       (SELECT COUNT(*) FROM califyapp_playlists WHERE user_id > 0) AS old_playlists,
       (SELECT COUNT(*) FROM fivefly_playlists) AS new_playlists,
       (SELECT COUNT(*) FROM califyapp_favorites WHERE user_id > 0) AS old_favorites,
       (SELECT COUNT(*) FROM fivefly_favorites) AS new_favorites;
   ```

5. Mantenha a identidade do app para os jogadores definindo no `config.lua`:

   ```lua
   Config.Phone.Identifier = "calify"
   Config.Phone.Name = "CaliFY"
   ```

6. Inicie o FiveFly e não inicie mais o `mzm_CaliFY`. Mantenha as tabelas `califyapp_*` até ter certeza de que a migração está completa.

## Como voltar atrás

Pare o FiveFly e inicie o `mzm_CaliFY` de novo: as tabelas dele não foram alteradas. Os dados criados no FiveFly depois da migração não são copiados de volta.
