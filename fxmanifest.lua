fx_version "cerulean"
game "gta5"
lua54 "yes"

name "fivefy"
author "Mezmerize"
description "FiveFY: music player for FiveM with lb-phone app, desktop panel, playlists and spatial audio."
version "1.0.0"
repository "https://github.com/OWNER/fivefy"

ui_page "ui/dist/engine.html"

shared_scripts {
    "config.lua",
    "shared/utils.lua"
}

server_scripts {
    "@oxmysql/lib/MySQL.lua",
    "bridge/server/init.lua",
    "bridge/server/standalone.lua",
    "bridge/server/qbx.lua",
    "bridge/server/qb.lua",
    "bridge/server/esx.lua",
    "bridge/server/vrp.lua",
    "server/migrations.lua",
    "server/services/rate_limit.lua",
    "server/services/permissions.lua",
    "server/services/identity.lua",
    "server/repositories/tracks.lua",
    "server/repositories/playlists.lua",
    "server/repositories/profiles.lua",
    "server/services/media.lua",
    "server/services/search/parser.lua",
    "server/services/search/init.lua",
    "server/services/library.lua",
    "server/services/sync.lua",
    "server/services/sessions.lua",
    "server/main.lua",
    "server/actions/music.lua",
    "server/actions/library.lua",
    "server/actions/social.lua",
    "server/actions/playback.lua"
}

client_scripts {
    "client/main.lua",
    "client/nui_bridge.lua",
    "client/audio_engine.lua",
    "client/prop.lua",
    "client/vehicle.lua",
    "client/bluetooth.lua",
    "client/sync.lua",
    "client/app_register.lua",
    "client/panel.lua"
}

files {
    "ui/dist/**/*"
}

dependencies {
    "oxmysql"
}
