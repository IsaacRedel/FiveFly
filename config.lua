Config = {}

--[[
    FiveFY configuration.

    Secrets (YouTube Data API key, Fivemanage key) are NOT configured here.
    Set them as server convars in server.cfg, so they never reach clients:

        set fivefy_youtube_key "YOUR_YOUTUBE_DATA_API_V3_KEY"
        set fivefy_fivemanage_key "YOUR_FIVEMANAGE_IMAGE_KEY"
]]

-- UI language: "en" or "pt-BR".
Config.Locale = "en"

-- Print detailed logs to the server/client console.
Config.Debug = false

-- Framework used to identify players: "auto", "qbx", "qb", "esx", "vrp" or "standalone".
-- "auto" picks the first started framework in that order and falls back to standalone (Rockstar license).
Config.Framework = "auto"

-- Restrict the app to players with a permission.
-- vRP: vRP.hasPermission | QBCore: QBCore.Functions.HasPermission | ESX: player group | others: ACE.
Config.RequirePermission = false
Config.Permission = "fivefy.use"

---------------------------------------------------------------------------------------------------
-- Phone app (lb-phone). Optional: without lb-phone, FiveFY runs through the panel only.
---------------------------------------------------------------------------------------------------
Config.Phone = {
    Enabled = true,
    Resource = "lb-phone",
    Identifier = "fivefy",
    Name = "FiveFY",
    Description = "Music for your city.",
    Developer = "FiveFY",
    DefaultApp = true,
    Size = 24500,
    -- Stop playback when the player no longer has a phone item (lb-phone HasPhoneItem).
    StopWithoutPhoneItem = true
}

---------------------------------------------------------------------------------------------------
-- Desktop panel: a larger player opened by command or key binding.
---------------------------------------------------------------------------------------------------
Config.Panel = {
    Enabled = true,
    Command = "fivefy",
    -- Default key binding (players can change it in Settings > Key Bindings > FiveM). "" = no default key.
    DefaultKey = "",
    KeyDescription = "Open FiveFY",
    -- Client-side hook. Return false to block opening (e.g. while handcuffed).
    CanOpen = function()
        return not IsEntityDead(PlayerPedId())
    end
}

---------------------------------------------------------------------------------------------------
-- Music search.
---------------------------------------------------------------------------------------------------
Config.Search = {
    -- "auto": YouTube Data API when the fivefy_youtube_key convar is set, scraping otherwise.
    -- "youtube_api": official API only. "scrape": HTML scraping only (experimental, may break).
    Provider = "auto",
    MinLength = 3,
    MaxLength = 100,
    MaxResults = 20,
    CacheTtlSeconds = 21600,
    CacheMaxEntries = 500,
    CooldownMs = 1500,
    -- Region and language hints sent to YouTube.
    RegionCode = "US",
    Language = "en"
}

Config.Playback = {
    MaxQueueSize = 50
}

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
-- Images (avatars and playlist covers).
---------------------------------------------------------------------------------------------------
Config.Media = {
    -- Re-upload images from temporary hosts (e.g. Discord CDN links expire) to Fivemanage.
    ReuploadExternal = true,
    RequireReuploadForTemporaryHosts = true,
    -- When the fivefy_fivemanage_key convar is empty, read the Image key from lb-phone's server/apiKeys.lua.
    UseLbPhoneApiKey = true,
    MaxDownloadBytes = 8 * 1024 * 1024,
    -- When lb-phone is started, its own whitelist/blacklist settings take precedence over these.
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
-- Audio outputs.
---------------------------------------------------------------------------------------------------
Config.Outputs = {
    Default = "private",
    Allowed = {
        private = true, -- only the player hears it
        prop = true,    -- portable speaker carried by the player
        vehicle = true, -- current/last vehicle (or a sound-system trailer)
        off = true
    }
}

-- Integration with an external volume mixer (optional).
Config.MasterVolume = {
    -- Resource and export read once when the audio engine starts, e.g. Resource = "my_mixer", Export = "GetVolume".
    -- The export receives the resource name and must return 0-100.
    Resource = nil,
    Export = "GetVolume",
    -- Extra export names that set FiveFY's master volume (0-100), for mixers that push volume.
    -- FiveFY always exposes exports.fivefy:SetMasterVolume(volume).
    ExportAliases = {}
}

-- Radio stations shown in the app. Each station needs at least one track with a streamUrl (or a YouTube videoId).
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
-- Portable speaker prop. Uses a base-game model by default; point Model to your own streamed prop if you have one.
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
-- Spatial audio ranges (meters) and volumes (0-100).
-- The server caps every reported range to the largest range configured here.
---------------------------------------------------------------------------------------------------
Config.Range = {
    prop = {
        range = 16.0,
        volume = 78.0
    },
    vehicle = {
        -- Playback stops when the owner gets farther than this from the connected vehicle.
        ownerMaxDistance = 80.0,
        default = {
            range = 24.0,
            volume = 82.0
        },
        -- Per vehicle class (GetVehicleClass).
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
        -- Sound-system vehicles (party buses, speaker trailers). A hitched trailer matching this profile
        -- becomes the audio source instead of the towing vehicle.
        soundSystem = {
            range = 58.0,
            volume = 100.0,
            models = {
                pbus2 = true
            },
            classes = {},
            -- Case-insensitive substrings of the vehicle display name.
            namePatterns = {
                "sound",
                "speaker"
            }
        }
    }
}

Config.LocalAudio = {
    -- Volume multiplier for the "private" output (only the player hears it).
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
    -- Max distance (meters) between a player and the audio source position they report.
    MaxSourceDistance = 120.0
}
