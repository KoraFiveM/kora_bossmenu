local root = debug.getinfo(1, 'S').source:sub(2):match('(.*/)') .. '../'
local registered, callbacks, accounts, logs = {}, {}, { police = 500, ballas = 200 }, {}
local assertions = 0

local function equal(actual, expected, message)
    assertions = assertions + 1
    if actual ~= expected then
        error(('%s: expected %s, got %s'):format(message, tostring(expected), tostring(actual)), 2)
    end
end

local roles = {
    jobs = { police = { label = 'Police', grades = {} }, unemployed = { grades = {} } },
    gangs = { ballas = { label = 'Ballas', grades = {} }, none = { grades = {} } },
}
local rows = {}

_G.GetCurrentResourceName = function() return 'kora_bossmenu' end
_G.json = { encode = function() return '[]' end, decode = function() return {} end }
_G.CreateThread = function() end
_G.AddEventHandler = function() end
_G.RegisterCommand = function() end
_G.vector3 = function(x, y, z) return { x = x, y = y, z = z } end
_G.exports = setmetatable({
    kora_banking = {
        AddMoney = function(_, name, amount) if not accounts[name] then return false end accounts[name] = accounts[name] + amount return true end,
        RemoveMoney = function(_, name, amount)
            if not accounts[name] or accounts[name] < amount then return false end
            accounts[name] = accounts[name] - amount
            return true
        end,
        GetAccountBalance = function(_, name) return accounts[name] or 0 end,
    },
}, { __call = function(_, name, fn) registered[name] = fn end })
_G.Kora = {
    shared = { get = function(name, key) return roles[name] and roles[name][key] end },
    callback = { register = function(name, fn) callbacks[name] = fn end },
    sql = {
        single = function(_, params) return rows[params[1]] end,
        insert = function() return 1 end,
        update = function(_, params) logs[#logs + 1] = params[2] return 1 end,
        execute = function() return 0 end,
        available = function() return true end,
    },
}
setmetatable(_G.Kora.sql, { __index = function() return function() return nil end end })

assert(loadfile(root .. 'shared.lua'))()
local file = assert(io.open(root .. 'server/main.lua'))
local source = file:read('*a'):gsub('local ready = false', 'local ready = true', 1)
file:close()
assert(load(source, '@server/main.lua'))()

for _, name in ipairs({ 'AddMoney', 'RemoveMoney', 'AddGangMoney', 'RemoveGangMoney', 'GetAccount', 'GetGangAccount' }) do
    equal(type(registered[name]), 'function', name .. ' export is registered')
end

equal(registered.GetAccount('police'), 500, 'GetAccount returns a number')
equal(registered.GetGangAccount('ballas'), 200, 'GetGangAccount returns a number')
equal(registered.GetAccount('nope'), 0, 'unknown account reads as 0')
equal(registered.GetAccount('unemployed'), 0, 'unemployed is not an account')
equal(registered.GetGangAccount('none'), 0, 'gang none is not an account')
equal(registered.AddMoney('police', 100), true, 'AddMoney credits')
equal(accounts.police, 600, 'AddMoney delegates to banking')
equal(registered.RemoveMoney('police', 700), false, 'RemoveMoney refuses overdraft')
equal(registered.RemoveMoney('police', 50), true, 'RemoveMoney debits')
equal(accounts.police, 550, 'RemoveMoney delegates to banking')
equal(registered.AddMoney('police', -5), false, 'negative amount refused')
equal(registered.AddMoney('police', 'x'), false, 'non-numeric amount refused')
equal(registered.AddMoney('ballas', 10), false, 'job export does not touch a gang account')
equal(accounts.ballas, 200, 'gang balance unchanged by job export')
equal(registered.AddGangMoney('ballas', 25), true, 'AddGangMoney credits')
equal(registered.RemoveGangMoney('ballas', 25), true, 'RemoveGangMoney debits')
equal(accounts.ballas, 200, 'gang balance round-trips')
equal(registered.AddGangMoney('police', 10), false, 'gang export does not touch a job account')
equal(select('#', registered.AddMoney('police', 1)), 1, 'legacy exports return a single value')

print(('qbbossmenu server: %d assertions passed'):format(assertions))
