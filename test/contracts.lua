local root = debug.getinfo(1, 'S').source:sub(2):match('(.*/)') .. '../'
local assertions = 0

local function check(value, message)
    assertions = assertions + 1
    if not value then error(message, 2) end
end

local function read(path)
    local file = assert(io.open(root .. path, 'r'), 'missing ' .. path)
    local source = file:read('*a')
    file:close()
    return source
end

local client = read('client/main.lua')
local server = read('server/main.lua')
local types = read('types.lua')
local schema = read('sql/001_bossmenu.sql')

for _, name in ipairs({ 'openBossMenu', 'openApplication' }) do
    check(client:find(("exports('%s'"):format(name), 1, true),
        ('client export %s is registered'):format(name))
    check(types:find(('---@field %s '):format(name), 1, true),
        ('client export %s is declared for LuaLS'):format(name))
end

for _, name in ipairs({ 'addBusinessMoney', 'removeBusinessMoney', 'getBusinessBalance' }) do
    check(server:find(("exports('%s'"):format(name), 1, true),
        ('server export %s is registered'):format(name))
    check(types:find(('---@field %s '):format(name), 1, true),
        ('server export %s is declared for LuaLS'):format(name))
end

-- kora_bossmenu owns its AppShell session state locally. This keeps opening the
-- menu independent of kora_lib's generated export lookup and catches the exact
-- broken call that previously reached production.
check(not client:find('Kora.nui.isAppOpen', 1, true),
    'boss menu does not call the removed cross-resource isAppOpen guard')

check(not server:find('row.balance', 1, true), 'boss menu does not maintain a balance on its job row')
check(client:find('data.accountBalance', 1, true), 'boss menu displays the qbbanking account balance on the employee page')
check(client:find("RegisterNetEvent('qb-bossmenu:client:OpenMenu'", 1, true), 'legacy job event is registered')
check(client:find("RegisterNetEvent('qb-gangmenu:client:OpenMenu'", 1, true), 'legacy gang event is registered')
check(server:find("Kora.callback.register('qbbossmenu:server:isJobBoss'", 1, true), 'job authorization callback is registered')
check(server:find("Kora.callback.register('qbbossmenu:server:isGangBoss'", 1, true), 'gang authorization callback is registered')
check(server:find('accountBalance = exports.kora_banking:GetAccountBalance(role.name)', 1, true),
    'authorized job data reads the current balance from qbbanking')
check(server:find("JSON_UNQUOTE(JSON_EXTRACT(`gang`, '$.name'))", 1, true),
    'gang rosters are read from the persisted players table')
check(server:find('exports.kora_core:setGang', 1, true), 'online gang rank changes use qbcore')
check(server:find('jobLabel = definition.label or jobName', 1, true),
    'employee labels come from the job definition, not the minimal roster row')
check(server:find("exports.kora_banking:AddMoney", 1, true), 'business credits delegate to qbbanking')
check(server:find("exports.kora_banking:RemoveMoney", 1, true), 'business debits delegate to qbbanking')
check(server:find("exports.kora_banking:GetAccountBalance", 1, true), 'business balance reads delegate to qbbanking')
check(server:find('DROP COLUMN IF EXISTS `balance`', 1, true), 'startup removes the obsolete balance column')
check(not schema:find('`balance`', 1, true), 'new installs do not create a boss-menu balance column')
check(server:find("acceptedChecksums = { 'a3aa4c49' }", 1, true),
    'the two existing servers accept the reviewed pre-removal migration checksum')

print(('qbbossmenu contracts: %d assertions passed'):format(assertions))
