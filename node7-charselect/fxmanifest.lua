fx_version 'cerulean'
game 'rdr3'

rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

lua54 'yes'

author 'NODE7 Development Studios'
description 'NODE7 Charselect - RedEMRP format/assets with NODE7 players persistence and spawnselector support'
version '3.0.0'

shared_script 'config.lua'

client_script 'client/main.lua'
server_script 'server/main.lua'

ui_page 'html/ui.html'

files {
    'html/ui.html',
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/bg.png',
    'html/circle.gif',
    'html/rdr21.png',
    'html/rdr22.png',
    'html/rdr23.png',
    'html/js/jquery-1.4.1.min.js',
    'html/js/jquery.jcarousel.pack.js',
    'html/js/jquery-func.js',
    'html/js/listener.js'
}

dependencies {
    'node7-core',
    'node7-players'
}
