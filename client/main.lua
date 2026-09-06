local RESOURCE = GetCurrentResourceName()
local nuiReady = false
local pendingMenu

local function notify(message, type_)
    QB.notify.send({ title = 'Boss Menu', message = message, type = type_ or 'info' })
end

local function callback(name, ...)
    local args = table.pack(...)
    local ok, results = pcall(function()
        local pending = QB.callback.trigger(name, table.unpack(args, 1, args.n))
        Citizen.Await(pending)
        return pending.qblibCallbackResults
    end)
    if not ok then return false, tostring(results) end
    if not results then return false, 'The server did not answer.' end
    return table.unpack(results, 1, results.n)
end

local function openBossMenu()
    local data, err = callback('qbbossmenu:server:getJobData')
    if not data then return notify(err or 'You cannot open this boss menu.', 'error') end
    SetNuiFocus(true, true)
    if nuiReady then
        SendNUIMessage({ action = 'openBossMenu', data = data })
    else
        pendingMenu = data
    end
end

local function applicationFields(questions)
    local fields = {}
    for index, question in ipairs(questions) do
        local kind = question.type == 'long' and 'textarea'
            or question.type == 'number' and 'number'
            or question.type == 'yesno' and 'select'
            or 'text'
        fields[#fields + 1] = {
            id = tostring(index), label = question.question, type = kind, required = true,
            rows = kind == 'textarea' and 4 or nil,
            options = kind == 'select' and {
                { value = 'Yes', label = 'Yes' }, { value = 'No', label = 'No' },
            } or nil,
        }
    end
    return fields
end

local function openApplication(jobName)
    local job, err = callback('qbbossmenu:server:getApplication', jobName)
    if not job then return notify(err or 'That job is not accepting applications.', 'error') end
    local result = QB.nui.openInputDialog(applicationFields(job.questions), ('Apply: %s'):format(job.label), 'Complete every question to submit your application.')
    if not result or result.cancelled then return end
    local ok, submitErr = callback('qbbossmenu:server:submitApplication', jobName, result.values)
    notify(ok and 'Your application was submitted.' or (submitErr or 'Could not submit application.'), ok and 'success' or 'error')
end

RegisterCommand(Config.command, openBossMenu, false)
RegisterCommand(Config.applicationCommand, function(_, args)
    if not args[1] then return notify(('Usage: /%s [job]'):format(Config.applicationCommand), 'error') end
    openApplication(args[1])
end, false)

exports('openBossMenu', openBossMenu)
exports('openApplication', openApplication)

-- This resource owns its NUI frame. Registering through QB.nui would create
-- callbacks in qblib's VM and at the wrong https:// resource endpoint.
local function registerNuiCallback(name, handler)
    RegisterNUICallback(name, function(data, cb)
        local ok, result = pcall(handler, type(data) == 'table' and data or {})
        if not ok then
            notify('The boss menu action failed.', 'error')
            print(('[qbbossmenu] NUI callback %s failed: %s'):format(name, result))
            cb(false)
            return
        end
        cb(result == nil and true or result)
    end)
end

registerNuiCallback('qbbossmenu:ready', function()
    nuiReady = true
    QBTheme.refresh()
    if pendingMenu then
        SendNUIMessage({ action = 'openBossMenu', data = pendingMenu })
        pendingMenu = nil
    end
    return true
end)

registerNuiCallback('hideUI', function()
    pendingMenu = nil
    SetNuiFocus(false, false)
    return true
end)

for _, action in ipairs({ 'acceptApplicant', 'denyApplicant', 'addQuestion', 'editQuestion', 'removeQuestion', 'fireEmployee', 'setRank', 'giveBonus' }) do
    registerNuiCallback(action, function(data)
        local ok, err = callback('qbbossmenu:server:' .. action, data)
        if not ok and err then notify(err, 'error') end
        return ok == true
    end)
end

registerNuiCallback('openStash', function()
    SetNuiFocus(false, false)
    local ok, err = callback('qbbossmenu:server:openStash')
    if not ok then
        SetNuiFocus(true, true)
        notify(err or 'Could not open the stash.', 'error')
    end
    return ok == true
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == RESOURCE then SetNuiFocus(false, false) end
end)
