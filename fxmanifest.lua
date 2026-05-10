fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Distortionz'
description 'Distortionz Shot Spotter — premium gunshot detection + dispatch HUD for police, with smart clustering, fuzzed locations, weapon classification, and optional Discord audit logging.'
version '1.1.8'
repository 'https://github.com/Distortionzz/Distortionz_ShotSpotter'

ui_page 'html/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client.lua',
}

server_scripts {
    'server.lua',
    'version_check.lua',
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies {
    'ox_lib',
}
