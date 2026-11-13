fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kora_bossmenu'
-- Legacy qb-management exports (AddMoney, GetAccount, Add/RemoveBossMenuItem, ...).
provide 'qb-management'
author 'Kora'
version '0.2.1'
description 'Job management, applications, employee roster, stash and bonuses for kora_core'

dependency 'kora_lib'
dependency 'kora_sql'
dependency 'kora_core'
dependency 'kora_inventory'
dependency 'kora_multijob'
dependency 'kora_banking'

shared_scripts {
    '@kora_lib/init.lua',
    '@kora_core/init.lua',
    'shared.lua',
}

server_scripts { '@kora_sql/init.lua', 'server/schema.lua', 'server/main.lua' }
client_script 'client/main.lua'

files {
    'types.lua',
    'locales/*.lua',
}

-- kora_qa: Gherkin test scenarios (converted legacy tests), see [kora]/kora_qa/README.md
qa_feature 'tests/*.feature'
