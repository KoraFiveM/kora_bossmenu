local root = debug.getinfo(1, 'S').source:sub(2):match('(.*/)') .. '../'
local commands, registeredExports, serverCalls = {}, {}, {}
local appDefinitions, openedApps, inputDialogs, notifications = {}, {}, {}, {}
local rawCallbacks, directMessages, focusChanges, directCloses = 0, 0, 0, 0
local assertions = 0

local function check(value, message)
    assertions = assertions + 1
    if not value then error(message, 2) end
end

local function equal(actual, expected, message)
    assertions = assertions + 1
    if actual ~= expected then
        error(('%s: expected %s, got %s'):format(message, tostring(expected), tostring(actual)), 2)
    end
end

local function copyMenu(overrides)
    local data = {
        jobName = 'police', jobLabel = 'Police',
        employees = {
            { citizenid = 'EMP-1', name = 'Alex Officer', jobName = 'police', jobLabel = 'Police', level = 1, gradeName = 'Officer', pay = 100, online = true },
        },
        applicants = {
            { citizenid = 'APP-1', name = 'Sam Applicant', questions = {
                { question = 'Why?', answer = 'To help.' },
            } },
        },
        questions = {
            { question = 'Why do you want to work here?', type = 'short' },
            { question = 'What experience do you have?', type = 'long' },
        },
        logs = { { date = '2026-09-07T00:00:00Z', message = 'Menu opened.' } },
        jobGrades = {
            { grade = 1, name = 'Officer', pay = 100 },
            { grade = 2, name = 'Sergeant', pay = 200 },
        },
    }
    for key, value in pairs(overrides or {}) do data[key] = value end
    return data
end

local menuData = copyMenu()
local applicationData = { label = 'Police', questions = menuData.questions }
local defaultApplicationData = applicationData
local applicationError
local dialogResult = { cancelled = true }

_G.GetCurrentResourceName = function() return 'qbbossmenu' end
_G.RegisterCommand = function(name, fn) commands[name] = fn end
_G.RegisterNUICallback = function() rawCallbacks = rawCallbacks + 1 end
_G.SetNuiFocus = function() focusChanges = focusChanges + 1 end
_G.SendNUIMessage = function() directMessages = directMessages + 1 end
_G.CreateThread = function(fn) fn() end
_G.exports = setmetatable({}, { __call = function(_, name, fn) registeredExports[name] = fn end })

local function responseFor(name)
    if name == 'qbbossmenu:server:getJobData' then return table.pack(menuData) end
    if name == 'qbbossmenu:server:getApplication' then return table.pack(applicationData, applicationError) end
    return table.pack(true)
end

_G.QB = {
    nui = {
        registerApp = function(definition)
            appDefinitions[definition.id] = definition
            return definition.id
        end,
        openApp = function(id)
            openedApps[#openedApps + 1] = id
            return { closed = true }
        end,
        closeApp = function()
            directCloses = directCloses + 1
            return true
        end,
        openInputDialog = function(fields, title, description)
            inputDialogs[#inputDialogs + 1] = { fields = fields, title = title, description = description }
            return dialogResult
        end,
    },
    notify = { send = function(message) notifications[#notifications + 1] = message end },
    callback = {
        trigger = function(name, ...)
            serverCalls[#serverCalls + 1] = { name = name, args = table.pack(...) }
            local response = responseFor(name)
            return table.unpack(response, 1, response.n)
        end,
    },
}

dofile(root .. 'shared.lua')
dofile(root .. 'client/main.lua')

local function view(definition, id)
    for _, candidate in ipairs(definition.navigation or {}) do
        if candidate.id == id then return candidate end
    end
end

local function item(block, id)
    for _, candidate in ipairs(block.items or {}) do
        if candidate.id == id then return candidate end
    end
end

local function action(actions, id)
    for _, candidate in ipairs(actions or {}) do
        if candidate.id == id then return candidate end
    end
end

local function lastServerCall(name)
    for index = #serverCalls, 1, -1 do
        if serverCalls[index].name == name then return serverCalls[index] end
    end
end

local function exercise(definition, actionId, context, endpoint)
    local result = definition.onAction(actionId, context or {})
    local call = lastServerCall('qbbossmenu:server:' .. endpoint)
    check(call, actionId .. ' routes through its server callback')
    check(type(result.update) == 'table' and type(result.update.navigation) == 'table', actionId .. ' refreshes AppShell data')
    equal(result.notice.tone, 'success', actionId .. ' returns a success notice')
    return call.args[1], result
end

check(commands[Config.command], 'boss-menu command is registered')
check(commands[Config.applicationCommand], 'application command is registered')
check(registeredExports.openBossMenu, 'boss-menu export is registered')
check(registeredExports.openApplication, 'application export is registered')

commands[Config.command]()
local definition = appDefinitions['qbbossmenu:management']
check(definition, 'boss menu registers an AppShell definition')
equal(openedApps[#openedApps], 'qbbossmenu:management', 'boss menu opens the registered AppShell')
equal(definition.title, 'Management', 'AppShell title is retained')
equal(#definition.navigation, 5, 'all management workspaces are present')
check(view(definition, 'overview'), 'overview workspace is present')
check(view(definition, 'applicants'), 'applicant workspace is present')
check(view(definition, 'employees'), 'employee workspace is present')
check(view(definition, 'questions'), 'question workspace is present')
check(view(definition, 'activity'), 'activity workspace is present')

local overview = view(definition, 'overview')
local stash = action(overview.content.actions, 'boss:stash')
check(stash and stash.closeBeforeAction == true, 'stash releases AppShell before inventory opens')
equal(directCloses, 0, 'consumer does not manually close the AppShell')
for _, stat in ipairs(overview.content.blocks[1].items) do
    check(stat.label ~= 'Business balance', 'overview does not display a business balance')
end

local applicants = view(definition, 'applicants').content.blocks[1]
equal(applicants.layout, 'cards', 'applicants use card layout')
equal(applicants.searchable, true, 'applicants are searchable')
local applicant = item(applicants, 'APP-1')
equal(applicant.children[1].description, 'To help.', 'application answers are nested under their applicant')
check(action(applicant.actions, 'boss:accept'), 'applicant hire action is available')
check(action(applicant.actions, 'boss:deny'), 'applicant deny action is available')

local employees = view(definition, 'employees').content.blocks[1]
equal(employees.layout, 'cards', 'employees use card layout')
equal(employees.searchable, true, 'employees are searchable')
local employee = item(employees, 'EMP-1')
equal(employee.description, 'Police · Officer', 'employees display the server-provided job label')
equal(employee.metadata[1].value, 1, 'employees display the flattened job level')
equal(employee.metadata[2].value, '$100', 'employees display the flattened job pay')
check(action(employee.actions, 'boss:rank').fields, 'rank uses an AppShell action form')
local bonus = action(employee.actions, 'boss:bonus')
check(bonus.fields, 'bonus uses an AppShell action form')
equal(bonus.disabled, nil, 'bonus availability is decided by qbbanking on the server')
equal(bonus.fields[1].max, nil, 'bonus form does not cache a business balance as its maximum')
equal(bonus.fields[1].description, nil, 'bonus form does not display a business balance')
check(action(employee.actions, 'boss:fire').confirm, 'firing uses AppShell confirmation')

local questions = view(definition, 'questions')
check(action(questions.content.actions, 'boss:add-question').fields, 'question creation uses a header action form')
check(item(questions.content.blocks[1], '1'), 'existing questions are listed')
equal(view(definition, 'activity').content.blocks[1].type, 'timeline', 'management logs use the shared timeline')

-- Action forms replace context.value with submitted fields. Resolve a question
-- through its stable list item id, not through the overwritten item data.
local refreshed = copyMenu({ questions = {
    { question = 'Latest first question', type = 'yesno' },
    { question = 'Latest second question', type = 'number' },
} })
menuData = refreshed
local editPayload = exercise(definition, 'boss:edit-question', {
    itemId = '2', value = { question = 'Updated experience?', type = 'short' },
}, 'editQuestion')
equal(editPayload.jobName, 'police', 'question edit includes the managed job')
equal(editPayload.originalQuestion, 'What experience do you have?', 'first edit resolves the original definition item by id')
equal(editPayload.updatedQuestion.question, 'Updated experience?', 'question edit forwards submitted fields')

local removePayload = exercise(definition, 'boss:remove-question', { itemId = '1' }, 'removeQuestion')
equal(removePayload.question, 'Latest first question', 'later question actions use the refreshed question set')

local acceptPayload = exercise(definition, 'boss:accept', { itemId = 'APP-1' }, 'acceptApplicant')
equal(acceptPayload.citizenid, 'APP-1', 'hire forwards the applicant id')
local denyPayload = exercise(definition, 'boss:deny', { itemId = 'APP-1' }, 'denyApplicant')
equal(denyPayload.citizenid, 'APP-1', 'deny forwards the applicant id')
local rankPayload = exercise(definition, 'boss:rank', { itemId = 'EMP-1', value = { grade = '2' } }, 'setRank')
equal(rankPayload.citizenid, 'EMP-1', 'rank forwards the employee id')
equal(rankPayload.grade, '2', 'rank forwards the selected grade')
local bonusPayload = exercise(definition, 'boss:bonus', { itemId = 'EMP-1', value = { amount = 500 } }, 'giveBonus')
equal(bonusPayload.citizenid, 'EMP-1', 'bonus forwards the employee id')
equal(bonusPayload.amount, 500, 'bonus forwards the submitted amount')
local firePayload = exercise(definition, 'boss:fire', { itemId = 'EMP-1' }, 'fireEmployee')
equal(firePayload.employee, 'EMP-1', 'fire forwards the employee id')
local addPayload = exercise(definition, 'boss:add-question', { value = { question = 'New question?', type = 'long' } }, 'addQuestion')
equal(addPayload.new.question, 'New question?', 'question creation forwards its text')
equal(addPayload.new.type, 'long', 'question creation forwards its answer type')

local stashResult = definition.onAction('boss:stash', {})
equal(lastServerCall('qbbossmenu:server:openStash').name, 'qbbossmenu:server:openStash', 'stash routes through the server')
equal(stashResult.notice.tone, 'success', 'stash returns a shell-owned success notice')
equal(directCloses, 0, 'stash relies on closeBeforeAction instead of closing directly')

applicationData, applicationError = nil, 'Applications are closed.'
commands[Config.applicationCommand](nil, { 'police' })
equal(notifications[#notifications].message, 'Applications are closed.',
    'application errors returned after a nil result reach the notification')

applicationData, applicationError = defaultApplicationData, nil
dialogResult = { values = { ['1'] = 'An answer', ['2'] = 'A longer answer' } }
commands[Config.applicationCommand](nil, { 'police' })
local dialog = inputDialogs[#inputDialogs]
equal(dialog.title, 'Apply: Police', 'application uses the shared input dialog')
equal(#dialog.fields, 2, 'application creates one field per configured question')
equal(dialog.fields[2].type, 'textarea', 'long application answers use a textarea')
equal(dialog.fields[2].maxLength, 1000, 'long application answers retain the server limit')
local submit = lastServerCall('qbbossmenu:server:submitApplication')
equal(submit.args[1], 'police', 'application submission includes the job')
equal(submit.args[2]['1'], 'An answer', 'application submission forwards dialog values')

equal(rawCallbacks, 0, 'migration registers no private NUI callbacks')
equal(directMessages, 0, 'migration sends no private browser messages')
equal(focusChanges, 0, 'migration delegates focus ownership to qblib')

local manifestFile = assert(io.open(root .. 'fxmanifest.lua', 'r'))
local manifest = manifestFile:read('*a')
manifestFile:close()
check(not manifest:find('ui_page', 1, true), 'private browser page is no longer loaded')
check(not manifest:find('@qbtheme/client/bridge.lua', 1, true), 'obsolete private theme bridge is no longer loaded')
check(not manifest:find("dependency 'qbtheme'", 1, true), 'obsolete direct qbtheme dependency is removed')
check(manifest:find("client_script 'client/main.lua'", 1, true), 'AppShell client remains in the manifest')

print(('qbbossmenu client: %d assertions passed'):format(assertions))
