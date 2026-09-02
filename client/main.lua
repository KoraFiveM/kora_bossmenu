local RESOURCE = GetCurrentResourceName()

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
    SendNUIMessage({ action = 'openBossMenu', data = data })
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

QB.nui.registerCallback('hideUI', function()
    SetNuiFocus(false, false)
    return true
end)

for _, action in ipairs({ 'acceptApplicant', 'denyApplicant', 'addQuestion', 'editQuestion', 'removeQuestion', 'fireEmployee', 'setRank', 'giveBonus' }) do
    QB.nui.registerCallback(action, function(data)
        local ok, err = callback('qbbossmenu:server:' .. action, data)
        if not ok and err then notify(err, 'error') end
        return ok == true
    end)
end

QB.nui.registerCallback('openStash', function()
    local ok, err = callback('qbbossmenu:server:openStash')
    if not ok then notify(err or 'Could not open the stash.', 'error') end
    return ok == true
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == RESOURCE then SetNuiFocus(false, false) end
end)
