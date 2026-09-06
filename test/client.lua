local root = debug.getinfo(1, 'S').source:sub(2):match('(.*/)') .. '../'
local callbacks, commands, handlers, registered = {}, {}, {}, {}
local messages, focus, serverCalls = {}, {}, {}

_G.GetCurrentResourceName = function() return 'qbbossmenu' end
_G.RegisterNUICallback = function(name, fn) callbacks[name] = fn end
_G.RegisterCommand = function(name, fn) commands[name] = fn end
_G.AddEventHandler = function(name, fn) handlers[name] = fn end
_G.SetNuiFocus = function(keyboard, mouse) focus[#focus + 1] = { keyboard, mouse } end
_G.SendNUIMessage = function(message) messages[#messages + 1] = message end
_G.exports = setmetatable({}, { __call = function(_, name, fn) registered[name] = fn end })
_G.Citizen = { Await = function() end }
_G.QBTheme = { refresh = function() return {} end }

local menuData = { jobName = 'police', employees = {}, applicants = {}, questions = {}, logs = {}, bank = 0, jobGrades = {} }
_G.QB = {
    nui = setmetatable({}, { __index = function(_, name) error('QB.nui.' .. name .. ' must not be used', 2) end }),
    notify = { send = function() end },
    callback = {
        trigger = function(name, ...)
            serverCalls[#serverCalls + 1] = { name = name, ... }
            local values = name == 'qbbossmenu:server:getJobData' and table.pack(menuData) or table.pack(true)
            return { qblibCallbackResults = values }
        end,
    },
}

dofile(root .. 'shared.lua')
dofile(root .. 'client/main.lua')

local function equal(actual, expected, message)
    if actual ~= expected then error(('%s: expected %s, got %s'):format(message, tostring(expected), tostring(actual)), 2) end
end

assert(callbacks['qbbossmenu:ready'], 'raw ready callback registered')
assert(callbacks.acceptApplicant, 'raw mutation callback registered')
assert(callbacks.hideUI, 'raw close callback registered')
assert(callbacks.openStash, 'raw stash callback registered')

commands[Config.command]()
equal(focus[#focus][1], true, 'opening takes focus')
equal(#messages, 0, 'open waits for browser readiness')
callbacks['qbbossmenu:ready']({}, function() end)
equal(messages[#messages].action, 'openBossMenu', 'ready flushes pending open')
equal(messages[#messages].data, menuData, 'open payload is unchanged')

local mutationResult
callbacks.acceptApplicant({ citizenid = 'ABC', jobName = 'police' }, function(value) mutationResult = value end)
equal(mutationResult, true, 'mutation result reaches browser')
equal(serverCalls[#serverCalls].name, 'qbbossmenu:server:acceptApplicant', 'server callback name unchanged')

callbacks.hideUI({}, function() end)
equal(focus[#focus][1], false, 'hide releases focus')
callbacks.openStash({}, function() end)
equal(serverCalls[#serverCalls].name, 'qbbossmenu:server:openStash', 'stash callback name unchanged')
equal(focus[#focus][1], false, 'stash releases boss-menu focus before handoff')

print('qbbossmenu client: 13 assertions passed')
