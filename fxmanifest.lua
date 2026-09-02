fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'qbbossmenu'
author 'qbcore2'
version '2.0.0'
description 'Job management, applications, employee roster, stash and bonuses for qbcore'

dependency 'qblib'
dependency 'qbsql'
dependency 'qbcore'
dependency 'qbinventory'
dependency 'qbmultijob'

ui_page 'web/build/index.html'

shared_scripts {
    '@qblib/init.lua',
    '@qbsql/init.lua',
    '@qbcore/init.lua',
    'shared.lua',
}

server_scripts { 'server/main.lua' }
client_scripts { 'client/main.lua' }

files {
    'sql/001_bossmenu.sql',
    'web/build/index.html',
    'web/build/**/*',
}
