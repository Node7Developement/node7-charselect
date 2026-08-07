fx_version 'cerulean'
game 'rdr3'

rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

lua54 'yes'

author 'NODE7 Development Studios'
description 'NODE7 keyboard-navigable nested side character selection with paged creation and no preview ped.'
version '5.3.0'

ui_page 'html/index.html'

shared_script 'config.lua'

client_script 'client/main.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/reset.css',
    'html/script.js',
    'html/profanity.js',
    'html/AD-Rsail.otf',
    'html/CHINESER.TTF',
    'html/assets/*.png'
}

dependencies {
    'oxmysql',
    'node7-core',
    'node7-appearance'
}
