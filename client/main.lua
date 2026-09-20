local APP_ID = 'qbbossmenu:management'
local currentData
local appActive = false

local function notify(message, type_)
    QB.notify.send({ title = 'Boss Menu', message = message, type = type_ or 'info' })
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

local function openApplication(jobName)
    local job, err = QB.callback.trigger('qbbossmenu:server:getApplication', jobName)
    if not job then return notify(err or 'That job is not accepting applications.', 'error') end
    local result = QB.nui.openInputDialog(applicationFields(job.questions), ('Apply: %s'):format(job.label), 'Complete every question to submit your application.')
    if not result or result.cancelled then return end
    local ok, submitErr = QB.callback.trigger('qbbossmenu:server:submitApplication', jobName, result.values)
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
        gradeOptions[#gradeOptions + 1] = { value = tostring(grade.grade), label = ('%s · %s'):format(grade.name, money(grade.pay)) }
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
        metadata = { { label = 'Grade', value = employee.level }, { label = 'Pay', value = money(employee.pay) } },
        actions = {
            { id = 'boss:rank', label = 'Set rank', icon = 'chevrons-up', fields = {
                { id = 'grade', label = 'Rank', type = 'select', options = gradeOptions, default = tostring(employee.level), required = true },
            } },
            { id = 'boss:bonus', label = 'Give bonus', icon = 'dollar-sign', fields = {
                { id = 'amount', label = 'Bonus amount', type = 'number', min = 1,
                    required = true, presets = { { value = 100 }, { value = 250 }, { value = 500 }, { value = 1000 } } },
            } },
            { id = 'boss:fire', label = 'Fire', icon = 'user-x', variant = 'destructive', confirm = 'Remove this employee from the job roster?' },
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

    return {
        id = APP_ID, title = 'Management', description = data.jobLabel or data.jobName or 'Boss menu', icon = 'briefcase-business',
        width = 1180, height = 780,
        navigation = {
            { id = 'overview', label = 'Overview', icon = 'layout-dashboard', content = {
                title = 'Business overview', description = 'Live staffing and recruitment summary.',
                actions = { { id = 'boss:stash', label = 'Open boss stash', icon = 'package-open', variant = 'primary', closeBeforeAction = true } },
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
                title = 'Employee roster', description = 'Current business funds are available for bonuses.',
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
            local payload = { jobName = latest.jobName }
            local endpoint
            if actionId == 'boss:stash' then
                local ok, err = QB.callback.trigger('qbbossmenu:server:openStash')
                if not ok then return { notice = { tone = 'destructive', message = err or 'Could not open the stash.' } } end
                return { notice = { tone = 'success', message = 'Boss stash opened.' } }
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

            local ok, err = QB.callback.trigger('qbbossmenu:server:' .. endpoint, payload)
            if not ok then return { notice = { tone = 'destructive', message = err or 'The management action was declined.' } } end
            local refreshed, refreshErr = QB.callback.trigger('qbbossmenu:server:getJobData')
            if not refreshed then return { notice = { tone = 'warning', message = refreshErr or 'Saved, but the view could not refresh.' } } end
            currentData = refreshed
            local updated = appDefinition()
            return { update = { navigation = updated.navigation, description = updated.description },
                notice = { tone = 'success', message = 'Management changes saved.' } }
        end,
    }
end

local function openBossMenu()
    if appActive then return end
    appActive = true

    CreateThread(function()
        local ok, err = pcall(function()
            local data, loadError = QB.callback.trigger('qbbossmenu:server:getJobData')
            if not data then
                notify(loadError or 'You cannot open this boss menu.', 'error')
                return
            end

            currentData = data
            QB.nui.registerApp(appDefinition())
            QB.nui.openApp(APP_ID)
        end)

        currentData = nil
        appActive = false

        if not ok then
            print(('^1[qbbossmenu]^7 Could not open the management menu: %s'):format(tostring(err)))
            notify('The management menu could not be opened.', 'error')
        end
    end)
end

RegisterCommand(Config.command, openBossMenu, false)
RegisterCommand(Config.applicationCommand, function(_, args)
    if not args[1] then return notify(('Usage: /%s [job]'):format(Config.applicationCommand), 'error') end
    openApplication(args[1])
end, false)

exports('openBossMenu', openBossMenu)
exports('openApplication', openApplication)
