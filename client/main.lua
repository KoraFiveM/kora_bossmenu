local APP_ID = 'kora_bossmenu:management'
local currentData
local appActive = false

local extraItems = { job = {}, gang = {} }
local EXTRA_PREFIX = 'boss:extra:'

local function copyValue(value)
    if type(value) ~= 'table' then return value end
    local copy = {}
    for key, entry in pairs(value) do copy[key] = copyValue(entry) end
    return copy
end

local function addExtraItem(roleType, data, id)
    local items = extraItems[roleType]
    local key = id or (#items + 1)
    items[key] = copyValue(data)
    return key
end

local function sortedExtraItems(roleType)
    local keys = {}
    for key, entry in pairs(extraItems[roleType]) do
        local params = type(entry) == 'table' and entry.params
        if type(params) == 'table' and type(params.event) == 'string' and not params.isServer
            and not params.isCommand and not entry.isMenuHeader then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys, function(a, b)
        if type(a) == type(b) then return a < b end
        return type(a) == 'number'
    end)
    return keys
end

local function extraActions(roleType)
    local actions = {}
    for _, key in ipairs(sortedExtraItems(roleType)) do
        local entry = extraItems[roleType][key]
        actions[#actions + 1] = {
            id = EXTRA_PREFIX .. tostring(key), label = tostring(entry.header or entry.params.event),
            icon = 'puzzle', closeBeforeAction = true,
        }
    end
    return actions
end

local function runExtraAction(roleType, actionId)
    local wanted = actionId:sub(#EXTRA_PREFIX + 1)
    for _, key in ipairs(sortedExtraItems(roleType)) do
        if tostring(key) == wanted then
            local params = extraItems[roleType][key].params
            TriggerEvent(params.event, params.args)
            return true
        end
    end
    return false
end

local function notify(message, type_)
    Kora.notify.send({ title = 'Boss Menu', message = message, type = type_ or 'info' })
end

local function applicationFields(questions)
    local fields = {}
    for index, question in ipairs(questions) do
        local kind = question.type == 'long' and 'textarea' or question.type == 'number' and 'number'
            or question.type == 'yesno' and 'select' or 'text'
        fields[#fields + 1] = {
            id = tostring(index), label = question.question, type = kind, required = true,
            rows = kind == 'textarea' and 4 or nil, maxLength = kind == 'textarea' and 1000 or 250,
            options = kind == 'select' and { { value = 'Yes', label = 'Yes' }, { value = 'No', label = 'No' } } or nil,
        }
    end
    return fields
end

local function openApplication(jobName, roleType)
    local job, err = Kora.callback.trigger('kora_bossmenu:server:getApplication', jobName, roleType)
    if not job then return notify(err or 'That job is not accepting applications.', 'error') end
    local result = Kora.nui.openInputDialog(applicationFields(job.questions), ('Apply: %s'):format(job.label), 'Complete every question to submit your application.')
    if not result or result.cancelled then return end
    local ok, submitErr = Kora.callback.trigger('kora_bossmenu:server:submitApplication', jobName, result.values, roleType)
    notify(ok and 'Your application was submitted.' or (submitErr or 'Could not submit application.'), ok and 'success' or 'error')
end

local function money(value)
    return ('$%d'):format(math.floor(tonumber(value) or 0))
end

local questionTypes = {
    { value = 'short', label = 'Short answer' }, { value = 'long', label = 'Long answer' },
    { value = 'number', label = 'Number' }, { value = 'yesno', label = 'Yes / No' },
}

local function appDefinition()
    local data = currentData or { employees = {}, applicants = {}, questions = {}, logs = {}, jobGrades = {} }
    local gradeOptions = {}
    for _, grade in ipairs(data.jobGrades or {}) do
        gradeOptions[#gradeOptions + 1] = { value = tostring(grade.grade), label = data.roleType == 'gang' and grade.name or ('%s · %s'):format(grade.name, money(grade.pay)) }
    end

    local applicants = {}
    for _, applicant in ipairs(data.applicants or {}) do
        local answers = {}
        for index, answer in ipairs(applicant.questions or {}) do answers[#answers + 1] = {
            id = applicant.citizenid .. ':' .. index, label = answer.question, description = answer.answer, icon = 'message-square',
        } end
        applicants[#applicants + 1] = {
            id = applicant.citizenid, label = applicant.name or applicant.citizenid,
            description = applicant.citizenid, icon = 'user-plus', children = answers,
            metadata = { { label = 'Answers', value = #answers } },
            actions = {
                { id = 'boss:accept', label = 'Hire', icon = 'check', variant = 'primary' },
                { id = 'boss:deny', label = 'Deny', icon = 'x', variant = 'destructive', confirm = 'Deny this application?' },
            },
        }
    end

    local employees = {}
    for _, employee in ipairs(data.employees or {}) do employees[#employees + 1] = {
        id = employee.citizenid, label = employee.name or employee.citizenid,
        description = ('%s · %s'):format(employee.jobLabel, employee.gradeName), icon = 'contact', badge = employee.online and 'Online' or 'Offline',
        tone = employee.online and 'success' or 'neutral',
        metadata = data.roleType == 'gang' and { { label = 'Rank', value = employee.level } }
            or { { label = 'Grade', value = employee.level }, { label = 'Pay', value = money(employee.pay) } },
        actions = {
            { id = 'boss:rank', label = 'Set rank', icon = 'chevrons-up', fields = {
                { id = 'grade', label = 'Rank', type = 'select', options = gradeOptions, default = tostring(employee.level), required = true },
            } },
            { id = 'boss:bonus', label = 'Give bonus', icon = 'dollar-sign', fields = {
                { id = 'amount', label = 'Bonus amount', type = 'number', min = 1,
                    required = true, presets = { { value = 100 }, { value = 250 }, { value = 500 }, { value = 1000 } } },
            } },
            { id = 'boss:fire', label = data.roleType == 'gang' and 'Kick' or 'Fire', icon = 'user-x', variant = 'destructive', confirm = data.roleType == 'gang' and 'Remove this member from the gang?' or 'Remove this employee from the job roster?' },
        },
    } end

    local questions = {}
    for index, question in ipairs(data.questions or {}) do questions[#questions + 1] = {
        id = tostring(index), label = question.question, description = question.type, icon = 'help-circle',
        actions = {
            { id = 'boss:edit-question', label = 'Edit', icon = 'pencil', fields = {
                { id = 'question', label = 'Question', type = 'text', default = question.question, required = true, maxLength = 250 },
                { id = 'type', label = 'Answer type', type = 'select', options = questionTypes, default = question.type, required = true },
            } },
            { id = 'boss:remove-question', label = 'Remove', icon = 'trash-2', variant = 'destructive', confirm = 'Remove this application question?' },
        },
    } end

    local activity = {}
    for index = #(data.logs or {}), 1, -1 do
        local entry = data.logs[index]
        activity[#activity + 1] = {
            id = tostring(index), title = entry.message or 'Management action', timestamp = entry.date,
            icon = 'history', tone = 'neutral',
        }
    end

    local roleKey = data.roleType == 'gang' and 'gang' or 'job'
    local overviewActions = { { id = 'boss:stash', label = 'Open boss stash', icon = 'package-open', variant = 'primary', closeBeforeAction = true } }
    for _, extra in ipairs(extraActions(roleKey)) do overviewActions[#overviewActions + 1] = extra end

    return {
        id = APP_ID, title = 'Management', description = data.jobLabel or data.jobName or 'Boss menu', icon = 'briefcase-business',
        width = 1180, height = 780,
        navigation = {
            { id = 'overview', label = 'Overview', icon = 'layout-dashboard', content = {
                title = 'Business overview', description = 'Live staffing and recruitment summary.',
                actions = overviewActions,
                blocks = { { type = 'stats', items = {
                    { label = 'Employees', value = #(data.employees or {}), icon = 'users' },
                    { label = 'Applicants', value = #(data.applicants or {}), icon = 'user-plus', tone = #applicants > 0 and 'warning' or 'neutral' },
                    { label = 'Application questions', value = #(data.questions or {}), icon = 'help-circle' },
                } } },
            } },
            { id = 'applicants', label = 'Applicants', icon = 'user-plus', badge = #applicants, content = {
                title = 'Applicants', description = 'Review answers and decide each application.',
                blocks = { { type = 'list', id = 'applicants', layout = 'cards', searchable = true, pageSize = 6,
                    items = applicants, empty = 'There are no pending applications.' } },
            } },
            { id = 'employees', label = 'Employees', icon = 'users', badge = #employees, content = {
                title = data.roleType == 'gang' and 'Gang roster' or 'Employee roster', description = 'Current business funds are available for bonuses.',
                blocks = {
                    { type = 'stats', items = { { label = 'Business balance', value = money(data.accountBalance), icon = 'landmark', tone = 'primary' } } },
                    { type = 'list', id = 'employees', layout = 'cards', searchable = true, pageSize = 8,
                    items = employees, empty = 'No employees were found.' },
                },
            } },
            { id = 'questions', label = 'Questions', icon = 'help-circle', badge = #questions, content = {
                title = 'Application questions',
                actions = { { id = 'boss:add-question', label = 'Add question', icon = 'plus', variant = 'primary', fields = {
                    { id = 'question', label = 'Question', type = 'text', required = true, maxLength = 250 },
                    { id = 'type', label = 'Answer type', type = 'select', options = questionTypes, default = 'short', required = true },
                } } },
                blocks = { { type = 'list', id = 'questions', items = questions, empty = 'No application questions are configured.' } },
            } },
            { id = 'activity', label = 'Activity', icon = 'history', badge = #activity, content = {
                title = 'Management activity', blocks = { { type = 'timeline', title = 'Audit trail', items = activity, empty = 'No management activity yet.' } },
            } },
        },
        footer = 'Every management action is checked against your current boss grade.',
        onAction = function(actionId, context)
            local values = type(context and context.value) == 'table' and context.value or {}
            local itemId = context and context.itemId
            local latest = currentData or data
            local payload = { jobName = latest.jobName, roleType = latest.roleType }
            local endpoint
            if actionId == 'boss:stash' then
                local ok, err = Kora.callback.trigger('kora_bossmenu:server:openStash', latest.roleType)
                if not ok then return { notice = { tone = 'destructive', message = err or 'Could not open the stash.' } } end
                return { notice = { tone = 'success', message = 'Boss stash opened.' } }
            elseif actionId:sub(1, #EXTRA_PREFIX) == EXTRA_PREFIX then
                if not runExtraAction(latest.roleType == 'gang' and 'gang' or 'job', actionId) then
                    error('That management action is no longer available.')
                end
                return
            elseif actionId == 'boss:accept' then endpoint = 'acceptApplicant'; payload.citizenid = itemId
            elseif actionId == 'boss:deny' then endpoint = 'denyApplicant'; payload.citizenid = itemId
            elseif actionId == 'boss:rank' then endpoint = 'setRank'; payload.citizenid = itemId; payload.grade = values.grade
            elseif actionId == 'boss:bonus' then endpoint = 'giveBonus'; payload.citizenid = itemId; payload.amount = values.amount
            elseif actionId == 'boss:fire' then endpoint = 'fireEmployee'; payload.employee = itemId
            elseif actionId == 'boss:add-question' then endpoint = 'addQuestion'; payload.new = { question = values.question, type = values.type }
            elseif actionId == 'boss:edit-question' or actionId == 'boss:remove-question' then
                local question = latest.questions and latest.questions[math.floor(tonumber(itemId) or 0)]
                if not question then error('That application question is no longer available.') end
                if actionId == 'boss:edit-question' then
                    endpoint = 'editQuestion'
                    payload.originalQuestion = question.question
                    payload.updatedQuestion = { question = values.question, type = values.type }
                else
                    endpoint = 'removeQuestion'
                    payload.question = question.question
                end
            else error('That management action is no longer available.') end

            local ok, err = Kora.callback.trigger('kora_bossmenu:server:' .. endpoint, payload)
            if not ok then return { notice = { tone = 'destructive', message = err or 'The management action was declined.' } } end
            local refreshed, refreshErr = Kora.callback.trigger('kora_bossmenu:server:getJobData', latest.roleType)
            if not refreshed then return { notice = { tone = 'warning', message = refreshErr or 'Saved, but the view could not refresh.' } } end
            currentData = refreshed
            local updated = appDefinition()
            return { update = { navigation = updated.navigation, description = updated.description },
                notice = { tone = 'success', message = 'Management changes saved.' } }
        end,
    }
end

local function openBossMenu(roleType)
    if appActive then return end
    appActive = true

    CreateThread(function()
        local ok, err = pcall(function()
            local data, loadError = Kora.callback.trigger('kora_bossmenu:server:getJobData', roleType)
            if not data then
                notify(loadError or 'You cannot open this boss menu.', 'error')
                return
            end

            currentData = data
            Kora.nui.registerApp(appDefinition())
            Kora.nui.openApp(APP_ID)
        end)

        currentData = nil
        appActive = false

        if not ok then
            print(('^1[kora_bossmenu]^7 Could not open the management menu: %s'):format(tostring(err)))
            notify('The management menu could not be opened.', 'error')
        end
    end)
end

RegisterNetEvent('qb-bossmenu:client:OpenMenu', function()
    if Kora.callback.trigger('kora_bossmenu:server:isJobBoss') then openBossMenu() end
end)

RegisterNetEvent('qb-gangmenu:client:OpenMenu', function()
    if Kora.callback.trigger('kora_bossmenu:server:isGangBoss') then openBossMenu('gang') end
end)

exports('openBossMenu', openBossMenu)
exports('openApplication', openApplication)
exports('AddBossMenuItem', function(data, id) return addExtraItem('job', data, id) end)
exports('RemoveBossMenuItem', function(id) extraItems.job[id] = nil end)
exports('AddGangMenuItem', function(data, id) return addExtraItem('gang', data, id) end)
exports('RemoveGangMenuItem', function(id) extraItems.gang[id] = nil end)

-- Config points are standing-player positions (about 1 m above the floor).
-- kora_target matches the point the camera ray hits, so a 1 m cube there held
-- no surface to aim at; 2.6 m tall reaches the floor under the point.
local POINT_SIZE = vector3(1.0, 1.0, 2.6)

local function initLocations(data, Type)
    local roleType = Type == 'gang' and 'gang' or 'job'
    for _, job in ipairs(data) do
        if job.bossmenu then
            for _, location in ipairs(job.bossmenu) do
                exports.kora_target:addBoxZone({
                    coords = location,
                    size = POINT_SIZE,
                    options = {
                        {
                            icon = "fas fa-briefcase",
                            label = "Open Boss Menu",
                            onSelect = function()
                                openBossMenu(Type)
                            end,
                            canInteract = function()
                                local role = exports.kora_core:getPlayerData({ roleType })
                                if not role or role.name == (roleType == 'gang' and 'none' or 'unemployed') then return false end
                                local definition = Kora.shared.get(roleType == 'gang' and 'gangs' or 'jobs', role.name)
                                local grade = definition and definition.grades and definition.grades[role.grade and role.grade.level]
                                return grade and grade.isboss == true or false
                            end
                        },
                    },
                    distance = 2.5,
                })
            end
        end
        if job.apply then
            for _, location in ipairs(job.apply) do
                exports.kora_target:addBoxZone({
                    coords = location,
                    size = POINT_SIZE,
                    options = {
                        {
                            icon = "fas fa-briefcase",
                            label = "Apply for Job",
                            onSelect = function()
                                openApplication(job.job, Type)
                            end,
                        },
                    },
                    distance = 2.5,
                })
            end
        end
    end
end
initLocations(Config.Menus.job)
initLocations(Config.Menus.gang, 'gang')
