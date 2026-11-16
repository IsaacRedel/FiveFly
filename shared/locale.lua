--- Lua-side texts (console messages, lb-phone app description, key binding description).
--- The UI has its own dictionaries in ui/src/i18n. Both follow Config.Locale ("en" or "pt-BR").
FiveFly = FiveFly or {}

local LOCALES <const> = {
    en = {
        ["app.description"] = "Music for your city.",
        ["panel.key_description"] = "Open FiveFly",

        ["log.framework"] = "framework: %s",
        ["log.framework_late"] = "framework: %s (started after fivefly)",
        ["log.framework_late_standalone"] = "framework: %s (started after fivefly; players who used FiveFly meanwhile were saved under their license)",
        ["log.adapter_failed"] = "framework adapter '%s' failed to initialize: %s",
        ["log.unknown_framework"] = "Config.Framework = '%s' is not a known adapter",
        ["log.waiting_framework"] = "waiting for framework '%s': ensure it before fivefly in server.cfg",
        ["log.vrp_utils_failed"] = "could not run vrp/lib/utils.lua, using built-in helpers: %s",
        ["log.action_failed"] = "action '%s' failed: %s",
        ["log.migration_applying"] = "applying database migration %d (%s)",
        ["log.migration_failed"] = "database migration failed, FiveFly will not accept requests: %s",
        ["log.youtube_api_failed"] = "YouTube Data API search failed with HTTP %s",
        ["log.scrape_parse_failed"] = "could not parse the YouTube results page; set the fivefly_youtube_key convar to use the official API",
        ["log.scrape_provider"] = "search provider: scrape (experimental). Set the fivefly_youtube_key convar for the official YouTube Data API.",
        ["log.phone_register_failed"] = "failed to register the phone app: %s"
    },
    ["pt-BR"] = {
        ["app.description"] = "Músicas da sua cidade.",
        ["panel.key_description"] = "Abrir o FiveFly",

        ["log.framework"] = "framework: %s",
        ["log.framework_late"] = "framework: %s (iniciado depois do fivefly)",
        ["log.framework_late_standalone"] = "framework: %s (iniciado depois do fivefly; quem usou o FiveFly nesse intervalo ficou salvo pela license)",
        ["log.adapter_failed"] = "o adaptador do framework '%s' falhou ao iniciar: %s",
        ["log.unknown_framework"] = "Config.Framework = '%s' não é um adaptador conhecido",
        ["log.waiting_framework"] = "aguardando o framework '%s': dê ensure nele antes do fivefly no server.cfg",
        ["log.vrp_utils_failed"] = "não foi possível executar vrp/lib/utils.lua, usando funções internas: %s",
        ["log.action_failed"] = "a ação '%s' falhou: %s",
        ["log.migration_applying"] = "aplicando a migração %d do banco (%s)",
        ["log.migration_failed"] = "a migração do banco falhou, o FiveFly não vai aceitar requisições: %s",
        ["log.youtube_api_failed"] = "a busca pela YouTube Data API falhou com HTTP %s",
        ["log.scrape_parse_failed"] = "não foi possível ler a página de resultados do YouTube; defina a convar fivefly_youtube_key para usar a API oficial",
        ["log.scrape_provider"] = "provider de busca: scrape (experimental). Defina a convar fivefly_youtube_key para usar a YouTube Data API oficial.",
        ["log.phone_register_failed"] = "falha ao registrar o app no celular: %s"
    }
}

function FiveFly.GetLocale()
    local wanted = tostring(Config and Config.Locale or "en")
    return LOCALES[wanted] and wanted or (wanted:lower():sub(1, 2) == "pt" and "pt-BR" or "en")
end

--- Translates `key` with string.format arguments, falling back to English and then to the key itself.
function FiveFly.T(key, ...)
    local template = LOCALES[FiveFly.GetLocale()][key] or LOCALES.en[key] or key

    if select("#", ...) > 0 then
        return template:format(...)
    end

    return template
end
