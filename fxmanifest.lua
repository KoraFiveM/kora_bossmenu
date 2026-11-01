fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kora_bossmenu'
-- Keep the legacy resource name resolvable for exports['qbbossmenu'] callers.
provide 'qbbossmenu'
-- Legacy qb-management exports (AddMoney, GetAccount, Add/RemoveBossMenuItem, ...).
provide 'qb-management'
author 'qbcore2'
version '2.0.0'
description 'Job management, applications, employee roster, stash and bonuses for qbcore'

dependency 'kora_lib'
dependency 'kora_sql'
dependency 'kora_core'
dependency 'kora_inventory'
dependency 'kora_multijob'
dependency 'kora_banking'

shared_scripts {
    '@kora_lib/init.lua',
    '@kora_sql/init.lua',
    '@kora_core/init.lua',
    'shared.lua',
}

server_scripts { 'server/main.lua' }
client_script 'client/main.lua'

files {
    'sql/001_bossmenu.sql',
    'types.lua',
}
