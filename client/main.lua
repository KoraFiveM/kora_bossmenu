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
    Kora.notify.send({ title = Kora.lang('bossmenu.title'), message = message, type = type_ or 'info' })
end

local function applicationFields(questions)
    local fields = {}
    for index, question in ipairs(questions) do
        local kind = question.type == 'long' and 'textarea' or question.type == 'number' and 'number'
            or question.type == 'yesno' and 'select' or 'text'
        fields[#fields + 1] = {
            id = tostring(index), label = question.question, type = kind, required = true,
            rows = kind == 'textarea' and 4 or nil, maxLength = kind == 'textarea' and 1000 or 250,
            options = kind == 'select' and { { value = Kora.lang('bossmenu.application.yes'), label = Kora.lang('bossmenu.application.yes') }, { value = Kora.lang('bossmenu.application.no'), label = Kora.lang('bossmenu.application.no') } } or nil,
        }
    end
    return fields
end

local function openApplication(jobName, roleType)
    local job, err = Kora.callback.trigger('kora_bossmenu:server:getApplication', jobName, roleType)
    if not job then return notify(err or Kora.lang('bossmenu.notify.application_unavailable'), 'error') end
    local result = Kora.nui.openInputDialog(applicationFields(job.questions), Kora.lang('bossmenu.application.apply', job.label), Kora.lang('bossmenu.application.instructions'))
    if not result or result.cancelled then return end
    local ok, submitErr = Kora.callback.trigger('kora_bossmenu:server:submitApplication', jobName, result.values, roleType)
    notify(ok and Kora.lang('bossmenu.notify.application_submitted') or (submitErr or Kora.lang('bossmenu.notify.application_failed')), ok and 'success' or 'error')
end

local function money(value)
    return ('$%d'):format(math.floor(tonumber(value) or 0))
end

local questionTypes = {
    { value = 'short', label = Kora.lang('bossmenu.application.short') }, { value = 'long', label = Kora.lang('bossmenu.application.long') },
    { value = 'number', label = Kora.lang('bossmenu.application.number') }, { value = 'yesno', label = Kora.lang('bossmenu.application.yesno') },
}

local function appDefinition()
    local data = currentData or { employees = {}, applicants = {}, questions = {}, logs = {}, jobGrades = {} }
    local gradeOptions = {}
    for _, grade in ipairs(data.jobGrades or {}) do
        gradeOptions[#gradeOptions + 1] = { value = tostring(grade.grade), label = data.roleType == 'gang' and grade.name or Kora.lang('bossmenu.employee.grade_description', grade.name, money(grade.pay)) }
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
            metadata = { { label = Kora.lang('bossmenu.employee.answers'), value = #answers } },
            actions = {
                { id = 'boss:accept', label = Kora.lang('bossmenu.employee.hire'), icon = 'check', variant = 'primary' },
                { id = 'boss:deny', label = Kora.lang('bossmenu.employee.deny'), icon = 'x', variant = 'destructive', confirm = Kora.lang('bossmenu.employee.deny_confirm') },
            },
        }
    end

    local employees = {}
    for _, employee in ipairs(data.employees or {}) do employees[#employees + 1] = {
        id = employee.citizenid, label = employee.name or employee.citizenid,
        description = Kora.lang('bossmenu.employee.role_description', employee.jobLabel, employee.gradeName), icon = 'contact', badge = employee.online and Kora.lang('bossmenu.employee.online') or Kora.lang('bossmenu.employee.offline'),
        tone = employee.online and 'success' or 'neutral',
        metadata = data.roleType == 'gang' and { { label = Kora.lang('bossmenu.employee.rank'), value = employee.level } }
            or { { label = Kora.lang('bossmenu.employee.grade'), value = employee.level }, { label = Kora.lang('bossmenu.employee.pay'), value = money(employee.pay) } },
        actions = {
            { id = 'boss:rank', label = Kora.lang('bossmenu.employee.set_rank'), icon = 'chevrons-up', fields = {
                { id = 'grade', label = Kora.lang('bossmenu.employee.rank'), type = 'select', options = gradeOptions, default = tostring(employee.level), required = true },
            } },
            { id = 'boss:bonus', label = Kora.lang('bossmenu.employee.bonus'), icon = 'dollar-sign', fields = {
                { id = 'amount', label = Kora.lang('bossmenu.employee.bonus_amount'), type = 'number', min = 1,
                    required = true, presets = { { value = 100 }, { value = 250 }, { value = 500 }, { value = 1000 } } },
            } },
            { id = 'boss:fire', label = data.roleType == 'gang' and Kora.lang('bossmenu.employee.kick') or Kora.lang('bossmenu.employee.fire'), icon = 'user-x', variant = 'destructive', confirm = data.roleType == 'gang' and Kora.lang('bossmenu.employee.kick_confirm') or Kora.lang('bossmenu.employee.fire_confirm') },
        },
    } end

    local questions = {}
    for index, question in ipairs(data.questions or {}) do questions[#questions + 1] = {
        id = tostring(index), label = question.question, description = Kora.lang('bossmenu.application.' .. question.type), icon = 'help-circle',
        actions = {
            { id = 'boss:edit-question', label = Kora.lang('bossmenu.question.edit'), icon = 'pencil', fields = {
                { id = 'question', label = Kora.lang('bossmenu.question.title'), type = 'text', default = question.question, required = true, maxLength = 250 },
                { id = 'type', label = Kora.lang('bossmenu.question.answer_type'), type = 'select', options = questionTypes, default = question.type, required = true },
            } },
            { id = 'boss:remove-question', label = Kora.lang('bossmenu.question.remove'), icon = 'trash-2', variant = 'destructive', confirm = Kora.lang('bossmenu.question.remove_confirm') },
        },
    } end

    local activity = {}
    for index = #(data.logs or {}), 1, -1 do
        local entry = data.logs[index]
        activity[#activity + 1] = {
            id = tostring(index), title = entry.message or Kora.lang('bossmenu.ui.management_action'), timestamp = entry.date,
            icon = 'history', tone = 'neutral',
        }
    end

    local roleKey = data.roleType == 'gang' and 'gang' or 'job'
    local overviewActions = { { id = 'boss:stash', label = Kora.lang('bossmenu.ui.open_stash'), icon = 'package-open', variant = 'primary', closeBeforeAction = true } }
    for _, extra in ipairs(extraActions(roleKey)) do overviewActions[#overviewActions + 1] = extra end

    return {
        id = APP_ID, title = Kora.lang('bossmenu.ui.management'), description = data.jobLabel or data.jobName or Kora.lang('bossmenu.ui.boss_menu'), icon = 'briefcase-business',
        width = 1180, height = 780,
        navigation = {
            { id = 'overview', label = Kora.lang('bossmenu.ui.overview'), icon = 'layout-dashboard', content = {
                title = Kora.lang('bossmenu.ui.business_overview'), description = Kora.lang('bossmenu.ui.overview_description'),
                actions = overviewActions,
                blocks = { { type = 'stats', items = {
                    { label = Kora.lang('bossmenu.ui.employees'), value = #(data.employees or {}), icon = 'users' },
                    { label = Kora.lang('bossmenu.ui.applicants'), value = #(data.applicants or {}), icon = 'user-plus', tone = #applicants > 0 and 'warning' or 'neutral' },
                    { label = Kora.lang('bossmenu.ui.application_questions'), value = #(data.questions or {}), icon = 'help-circle' },
                } } },
            } },
            { id = 'applicants', label = Kora.lang('bossmenu.ui.applicants'), icon = 'user-plus', badge = #applicants, content = {
                title = Kora.lang('bossmenu.ui.applicants'), description = Kora.lang('bossmenu.ui.review_applications'),
                blocks = { { type = 'list', id = 'applicants', layout = 'cards', searchable = true, pageSize = 6,
                    items = applicants, empty = Kora.lang('bossmenu.ui.no_applications') } },
            } },
            { id = 'employees', label = Kora.lang('bossmenu.ui.employees'), icon = 'users', badge = #employees, content = {
                title = data.roleType == 'gang' and Kora.lang('bossmenu.ui.gang_roster') or Kora.lang('bossmenu.ui.employee_roster'), description = Kora.lang('bossmenu.ui.funds_description'),
                blocks = {
                    { type = 'stats', items = { { label = Kora.lang('bossmenu.ui.balance'), value = money(data.accountBalance), icon = 'landmark', tone = 'primary' } } },
                    { type = 'list', id = 'employees', layout = 'cards', searchable = true, pageSize = 8,
                    items = employees, empty = Kora.lang('bossmenu.ui.no_employees') },
                },
            } },
            { id = 'questions', label = Kora.lang('bossmenu.ui.questions_page'), icon = 'help-circle', badge = #questions, content = {
                title = Kora.lang('bossmenu.ui.application_questions'),
                actions = { { id = 'boss:add-question', label = Kora.lang('bossmenu.question.add'), icon = 'plus', variant = 'primary', fields = {
                    { id = 'question', label = Kora.lang('bossmenu.question.title'), type = 'text', required = true, maxLength = 250 },
                    { id = 'type', label = Kora.lang('bossmenu.question.answer_type'), type = 'select', options = questionTypes, default = 'short', required = true },
                } } },
                blocks = { { type = 'list', id = 'questions', items = questions, empty = Kora.lang('bossmenu.ui.no_questions') } },
            } },
            { id = 'activity', label = Kora.lang('bossmenu.ui.activity'), icon = 'history', badge = #activity, content = {
                title = Kora.lang('bossmenu.ui.management_activity'), blocks = { { type = 'timeline', title = Kora.lang('bossmenu.ui.audit_trail'), items = activity, empty = Kora.lang('bossmenu.ui.no_activity') } },
            } },
        },
        footer = Kora.lang('bossmenu.ui.footer'),
        onAction = function(actionId, context)
            local values = type(context and context.value) == 'table' and context.value or {}
            local itemId = context and context.itemId
            local latest = currentData or data
            local payload = { jobName = latest.jobName, roleType = latest.roleType }
            local endpoint
            if actionId == 'boss:stash' then
                local ok, err = Kora.callback.trigger('kora_bossmenu:server:openStash', latest.roleType)
                if not ok then return { notice = { tone = 'destructive', message = err or Kora.lang('bossmenu.notify.stash_failed') } } end
                return { notice = { tone = 'success', message = Kora.lang('bossmenu.notify.stash_opened') } }
            elseif actionId:sub(1, #EXTRA_PREFIX) == EXTRA_PREFIX then
                if not runExtraAction(latest.roleType == 'gang' and 'gang' or 'job', actionId) then
                    error(Kora.lang('bossmenu.notify.action_unavailable'))
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
                if not question then error(Kora.lang('bossmenu.notify.question_unavailable')) end
                if actionId == 'boss:edit-question' then
                    endpoint = 'editQuestion'
                    payload.originalQuestion = question.question
                    payload.updatedQuestion = { question = values.question, type = values.type }
                else
                    endpoint = 'removeQuestion'
                    payload.question = question.question
                end
            else error(Kora.lang('bossmenu.notify.action_unavailable')) end

            local ok, err = Kora.callback.trigger('kora_bossmenu:server:' .. endpoint, payload)
            if not ok then return { notice = { tone = 'destructive', message = err or Kora.lang('bossmenu.notify.action_declined') } } end
            local refreshed, refreshErr = Kora.callback.trigger('kora_bossmenu:server:getJobData', latest.roleType)
            if not refreshed then return { notice = { tone = 'warning', message = refreshErr or Kora.lang('bossmenu.notify.refresh_failed') } } end
            currentData = refreshed
            local updated = appDefinition()
            return { update = { navigation = updated.navigation, description = updated.description },
                notice = { tone = 'success', message = Kora.lang('bossmenu.notify.changes_saved') } }
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
                notify(loadError or Kora.lang('bossmenu.notify.menu_unavailable'), 'error')
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
            notify(Kora.lang('bossmenu.notify.menu_failed'), 'error')
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
                            label = Kora.lang('bossmenu.target.open_menu'),
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
                            label = Kora.lang('bossmenu.target.apply'),
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
