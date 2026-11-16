Config = {}

--[[
    FiveFly configuration / Configuração do FiveFly

    EN: Secrets (YouTube Data API key, Fivemanage key) are NOT configured here. Set them as server
        convars in server.cfg, so they never reach clients.
    PT: Chaves (YouTube Data API, Fivemanage) NÃO ficam aqui. Defina-as como convars no server.cfg,
        assim elas nunca chegam aos clients.

        set fivefly_youtube_key "YOUR_YOUTUBE_DATA_API_V3_KEY"
        set fivefly_fivemanage_key "YOUR_FIVEMANAGE_IMAGE_KEY"
]]

-- EN: Language of the whole resource (UI, console messages, app and key binding texts): "en" or "pt-BR".
-- PT: Idioma de todo o resource (interface, mensagens do console, textos do app e da tecla): "en" ou "pt-BR".
Config.Locale = "en"

-- EN: Print detailed logs to the server/client console.
-- PT: Mostra logs detalhados no console do servidor e do client.
Config.Debug = false

-- EN: Framework used to identify players: "auto", "qbx", "qb", "esx", "vrp" or "standalone".
--     "auto" picks the first started framework in that order and falls back to standalone (Rockstar license).
--     A specific value never falls back: FiveFly waits for that framework to start.
-- PT: Framework usado para identificar os jogadores: "auto", "qbx", "qb", "esx", "vrp" ou "standalone".
--     "auto" usa o primeiro framework iniciado, nessa ordem, e por último o standalone (license da Rockstar).
--     Um valor específico nunca troca de framework: o FiveFly espera ele iniciar.
Config.Framework = "auto"

-- EN: Restrict the app to players with a permission.
--     vRP: vRP.hasPermission | QBCore: QBCore.Functions.HasPermission | ESX: player group | others: ACE.
-- PT: Restringe o app a jogadores com uma permissão.
--     vRP: vRP.hasPermission | QBCore: QBCore.Functions.HasPermission | ESX: grupo do jogador | outros: ACE.
Config.RequirePermission = false
Config.Permission = "fivefly.use"

---------------------------------------------------------------------------------------------------
-- EN: Phone app (lb-phone). Optional: without lb-phone, FiveFly runs through the panel only.
-- PT: App do celular (lb-phone). Opcional: sem o lb-phone, o FiveFly funciona só pelo painel.
---------------------------------------------------------------------------------------------------
Config.Phone = {
    Enabled = true,
    Resource = "lb-phone",
    Identifier = "fivefly",
    Name = "FiveFly",
    -- EN: nil = text from Config.Locale. Set a string to override it.
    -- PT: nil = texto do Config.Locale. Defina um texto para substituir.
    Description = nil,
    Developer = "FiveFly",
    DefaultApp = true,
    Size = 24500,
    -- EN: Stop music started from the phone when the player no longer has a phone item (lb-phone HasPhoneItem).
    -- PT: Para a música iniciada pelo celular quando o jogador não tem mais o item de celular (HasPhoneItem do lb-phone).
    StopWithoutPhoneItem = true
}

---------------------------------------------------------------------------------------------------
-- EN: Desktop panel: a larger player opened by command or key binding.
-- PT: Painel desktop: um player maior, aberto por comando ou tecla.
---------------------------------------------------------------------------------------------------
Config.Panel = {
    Enabled = true,
    Command = "fivefly",
    -- EN: Default key (players can change it in Settings > Key Bindings > FiveM). "" = no default key.
    -- PT: Tecla padrão (o jogador pode trocar em Configurações > Atalhos > FiveM). "" = sem tecla padrão.
    DefaultKey = "",
    -- EN: nil = text from Config.Locale. / PT: nil = texto do Config.Locale.
    KeyDescription = nil,
    -- EN: Client-side hook. Return false to block opening (e.g. while handcuffed).
    -- PT: Hook do client. Retorne false para bloquear a abertura (por exemplo, quando algemado).
    CanOpen = function()
        return not IsEntityDead(PlayerPedId())
    end
}

---------------------------------------------------------------------------------------------------
-- EN: Music search. / PT: Busca de músicas.
---------------------------------------------------------------------------------------------------
Config.Search = {
    -- EN: "auto": YouTube Data API when the fivefly_youtube_key convar is set, scraping otherwise.
    --     "youtube_api": official API only. "scrape": HTML scraping only (experimental, may break).
    -- PT: "auto": YouTube Data API quando a convar fivefly_youtube_key estiver definida, scraping caso contrário.
    --     "youtube_api": só a API oficial. "scrape": só scraping do HTML (experimental, pode quebrar).
    Provider = "auto",
    MinLength = 3,
    MaxLength = 100,
    MaxResults = 20,
    CacheTtlSeconds = 21600,
    CacheMaxEntries = 500,
    CooldownMs = 1500,
    -- EN: Region and language hints sent to YouTube. nil = from Config.Locale (en: US/en, pt-BR: BR/pt).
    -- PT: Região e idioma enviados ao YouTube. nil = conforme o Config.Locale (en: US/en, pt-BR: BR/pt).
    RegionCode = nil,
    Language = nil
}

Config.Playback = {
    MaxQueueSize = 50
}

-- EN: Minimum interval between requests of the same kind, per player (ms).
-- PT: Intervalo mínimo entre requisições do mesmo tipo, por jogador (ms).
Config.RateLimits = {
    LibraryReadMs = 750,
    LibraryWriteMs = 500,
    PlaybackMs = 250,
    SyncUpdateMs = 500
}

Config.Library = {
    MaxPlaylistNameLength = 48,
    MaxPlaylists = 50,
    MaxTracksPerPlaylist = 200,
    MaxHistoryRowsPerUser = 300,
    HistoryPruneIntervalSeconds = 600
}

---------------------------------------------------------------------------------------------------
-- EN: Images (avatars and playlist covers). / PT: Imagens (avatares e capas de playlist).
---------------------------------------------------------------------------------------------------
Config.Media = {
    -- EN: Re-upload images from temporary hosts (e.g. Discord CDN links expire) to Fivemanage.
    -- PT: Reenvia ao Fivemanage imagens de hosts temporários (links do CDN do Discord expiram, por exemplo).
    ReuploadExternal = true,
    RequireReuploadForTemporaryHosts = true,
    -- EN: When the fivefly_fivemanage_key convar is empty, read the Image key from lb-phone's server/apiKeys.lua.
    -- PT: Se a convar fivefly_fivemanage_key estiver vazia, usa a chave Image do server/apiKeys.lua do lb-phone.
    UseLbPhoneApiKey = true,
    MaxDownloadBytes = 8 * 1024 * 1024,
    -- EN: When lb-phone is started, its own whitelist/blacklist settings take precedence over these.
    -- PT: Com o lb-phone iniciado, as whitelists/blacklists dele têm prioridade sobre estas.
    ExternalWhitelistedHostnames = {
        "cdn.discordapp.com",
        "media.discordapp.net"
    },
    ExternalWhitelistedDomains = {
        "discordapp.com",
        "discord.com"
    },
    UploadWhitelistedHostnames = {
        "*.users.cfx.re"
    },
    UploadWhitelistedDomains = {
        "fivemanage.com",
        "fmfile.com",
        "cfx.re"
    },
    ExternalBlacklistedHostnames = {},
    ExternalBlacklistedDomains = {},
    ReuploadHostnames = {
        "cdn.discordapp.com",
        "media.discordapp.net"
    }
}

---------------------------------------------------------------------------------------------------
-- EN: Audio outputs. / PT: Saídas de áudio.
---------------------------------------------------------------------------------------------------
Config.Outputs = {
    Default = "private",
    Allowed = {
        private = true, -- EN: only the player hears it / PT: só o jogador escuta
        prop = true,    -- EN: portable speaker carried by the player / PT: caixa de som portátil na mão
        vehicle = true, -- EN: current/last vehicle (or a sound-system trailer) / PT: veículo atual/último (ou carreta de som)
        off = true
    }
}

-- EN: Integration with an external volume mixer (optional).
-- PT: Integração com um mixer de volume externo (opcional).
Config.MasterVolume = {
    -- EN: Resource and export read when the audio engine starts, e.g. Resource = "my_mixer", Export = "GetVolume".
    --     The export receives the resource name and must return 0-100.
    -- PT: Resource e export lidos quando o engine de áudio inicia, ex.: Resource = "meu_mixer", Export = "GetVolume".
    --     O export recebe o nome do resource e deve retornar 0-100.
    Resource = nil,
    Export = "GetVolume",
    -- EN: Extra export names that set FiveFly's master volume (0-100), for mixers that push volume.
    --     FiveFly always exposes exports.fivefly:SetMasterVolume(volume).
    -- PT: Nomes extras de export que definem o volume geral do FiveFly (0-100), para mixers que enviam o volume.
    --     O FiveFly sempre expõe exports.fivefly:SetMasterVolume(volume).
    ExportAliases = {}
}

-- EN: Radio stations shown in the app. Each station needs at least one track with a streamUrl (or a YouTube videoId).
--     Only these stream URLs are accepted from clients.
-- PT: Rádios exibidas no app. Cada rádio precisa de ao menos uma faixa com streamUrl (ou um videoId do YouTube).
--     Só essas URLs de stream são aceitas vindas dos clients.
Config.Stations = {
    -- {
    --     id = "my-radio",
    --     name = "My Radio",
    --     description = "24/7 live stream.",
    --     cover = "https://example.com/cover.jpg",
    --     tracks = {
    --         {
    --             videoId = "my-radio-stream",
    --             streamUrl = "https://example.com/stream.mp3",
    --             title = "My Radio",
    --             author = "Live",
    --             duration = "0:00",
    --             thumbnail = "https://example.com/cover.jpg"
    --         }
    --     }
    -- }
}

---------------------------------------------------------------------------------------------------
-- EN: Portable speaker prop. Base-game model by default; point Model to your own streamed prop if you have one.
-- PT: Prop da caixa de som. Modelo do jogo base por padrão; aponte Model para o seu prop, se tiver um.
---------------------------------------------------------------------------------------------------
Config.Prop = {
    Model = "prop_boombox_01",
    Bone = 57005,
    Attach = {
        x = 0.30,
        y = 0.0,
        z = 0.0,
        rx = 0.0,
        ry = 260.0,
        rz = 60.0
    }
}

---------------------------------------------------------------------------------------------------
-- EN: Spatial audio ranges (meters) and volumes (0-100). The server caps every reported range to the
--     largest range configured here.
-- PT: Alcance (metros) e volume (0-100) do áudio espacial. O servidor limita qualquer alcance informado
--     ao maior alcance configurado aqui.
---------------------------------------------------------------------------------------------------
Config.Range = {
    prop = {
        range = 16.0,
        volume = 78.0
    },
    vehicle = {
        -- EN: Playback stops when the owner gets farther than this from the connected vehicle.
        -- PT: A música para quando o dono se afasta mais que isso do veículo conectado.
        ownerMaxDistance = 80.0,
        default = {
            range = 24.0,
            volume = 82.0
        },
        -- EN: Per vehicle class (GetVehicleClass). / PT: Por classe de veículo (GetVehicleClass).
        classProfiles = {
            [0] = { range = 18.0, volume = 68.0 },
            [1] = { range = 22.0, volume = 78.0 },
            [2] = { range = 26.0, volume = 86.0 },
            [3] = { range = 23.0, volume = 80.0 },
            [4] = { range = 28.0, volume = 88.0 },
            [5] = { range = 26.0, volume = 84.0 },
            [6] = { range = 27.0, volume = 86.0 },
            [7] = { range = 28.0, volume = 88.0 },
            [8] = { range = 16.0, volume = 62.0 },
            [9] = { range = 29.0, volume = 88.0 },
            [10] = { range = 34.0, volume = 92.0 },
            [11] = { range = 31.0, volume = 90.0 },
            [12] = { range = 34.0, volume = 94.0 },
            [17] = { range = 32.0, volume = 90.0 },
            [18] = { range = 32.0, volume = 90.0 },
            [20] = { range = 36.0, volume = 94.0 }
        },
        -- EN: Sound-system vehicles (party buses, speaker trailers). A hitched trailer matching this profile
        --     becomes the audio source instead of the towing vehicle.
        -- PT: Veículos de som (ônibus de festa, carretas de som). Uma carreta engatada que bata com este perfil
        --     passa a ser a origem do áudio no lugar do veículo que a puxa.
        soundSystem = {
            range = 58.0,
            volume = 100.0,
            models = {
                pbus2 = true
            },
            classes = {},
            -- EN: Case-insensitive substrings of the vehicle display name.
            -- PT: Trechos do nome do veículo, sem diferenciar maiúsculas.
            namePatterns = {
                "sound",
                "speaker"
            }
        }
    }
}

Config.LocalAudio = {
    -- EN: Volume multiplier for the "private" output. / PT: Multiplicador de volume da saída "privado".
    privateVolumeMultiplier = 0.35
}

Config.Attenuation = {
    nearRadius = 1.25,
    fadeStartRatio = 0.18,
    curve = 1.65,
    verticalScale = 1.25,
    smoothingFactor = 0.24
}

Config.Sync = {
    PositionIntervalMs = 500,
    PositionThreshold = 1.0,
    VolumeIntervalMs = 100,
    ListenerRefreshMs = 1000,
    -- EN: Max distance (meters) between a player and the speaker position they report.
    -- PT: Distância máxima (metros) entre o jogador e a posição da caixa de som que ele informa.
    MaxSourceDistance = 120.0
}
