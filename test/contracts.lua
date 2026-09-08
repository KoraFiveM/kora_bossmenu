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

-- qbbossmenu owns its AppShell session state locally. This keeps opening the
-- menu independent of qblib's generated export lookup and catches the exact
-- broken call that previously reached production.
check(not client:find('QB.nui.isAppOpen', 1, true),
    'boss menu does not call the removed cross-resource isAppOpen guard')

print(('qbbossmenu contracts: %d assertions passed'):format(assertions))
