fx_version 'cerulean'
game 'rdr3'

rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

lua54 'yes'

author 'NODE7 Development Studios'
description 'NODE7 Charselect - optimized RedEMRP-style character selector with direct spawn'
version '8.0.0'

shared_script 'config.lua'

client_script 'client/main.lua'
server_script 'server/main.lua'

ui_page 'html/ui.html'

files {
    'html/ui.html',
    'html/style.css',
    'html/bg.png',
    'html/circle.gif',
    'html/rdr21.png',
    'html/rdr22.png',
    'html/rdr23.png',
    'html/js/listener.js'
}

dependencies {
    'node7-core',
    'node7-players'
}
