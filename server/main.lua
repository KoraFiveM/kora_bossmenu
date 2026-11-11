local RESOURCE = GetCurrentResourceName()
local ready = false

local function decode(value, fallback)
    if type(value) ~= 'string' then return fallback end
    local ok, decoded = pcall(json.decode, value)
    return ok and type(decoded) == 'table' and decoded or fallback
end

local function roleDefinition(roleType, name)
    local role = type(name) == 'string' and Kora.shared.get(roleType == 'gang' and 'gangs' or 'jobs', name) or nil
    if not role or (roleType == 'gang' and name == 'none') or (roleType ~= 'gang' and name == 'unemployed') then return nil end
    return role
end

local function actorRole(src, roleType)
    local data = exports.kora_core:getPlayerData(src)
    return data and data[roleType] or nil
end

local function isBoss(src, roleType, expectedRole)
    local role = actorRole(src, roleType)
    if not role or role.name ~= expectedRole then return false end
    local definition = roleDefinition(roleType, role.name)
    local grade = definition and definition.grades and definition.grades[role.grade and role.grade.level]
    return grade and grade.isboss == true
end

local function requireBoss(src, roleType, roleName)
    if not ready then return nil, 'Boss menu storage is still starting.' end
    if not roleDefinition(roleType, roleName) then return nil, 'Unknown organization.' end
    if not isBoss(src, roleType, roleName) then return nil, 'You are not a boss for this organization.' end
    return true
end

local function ensureRole(roleType, roleName)
    local key = roleType == 'gang' and ('gang:' .. roleName) or roleName
    local row, err = Kora.sql.single('SELECT * FROM `kora_bossmenu_jobs` WHERE `job` = ?', { key })
    if err then return nil, 'Could not load boss-menu data.' end
    if not row then
        local questions = json.encode(Config.defaultQuestions[roleType])
        local inserted, insertErr = Kora.sql.insert('INSERT INTO `kora_bossmenu_jobs` (`job`,`questions`,`applicants`,`logs`) VALUES (?, ?, ?, ?)', {
            key, questions, '[]', '[]',
        })
        if not inserted then return nil, insertErr or 'Could not create job data.' end
        row = { job = key, questions = questions, applicants = '[]', logs = '[]' }
    end
    row.roleType, row.roleName = roleType, roleName
    row.questions = decode(row.questions, {})
    row.applicants = decode(row.applicants, {})
    row.logs = decode(row.logs, {})
    return row
end

local function save(row, column)
    local _, err = Kora.sql.update(('UPDATE `kora_bossmenu_jobs` SET `%s` = ? WHERE `job` = ?'):format(column), {
        json.encode(row[column]), row.job,
    })
    return not err, err
end

local function addLog(row, message)
    row.logs[#row.logs + 1] = { date = os.date('!%Y-%m-%dT%H:%M:%SZ'), message = message }
    while #row.logs > Config.maxLogs do table.remove(row.logs, 1) end
    return save(row, 'logs')
end

local function jobEmployees(jobName)
    local rows, err = exports.kora_multijob:getEmployees(jobName)
    if not rows then return nil, err or 'Could not load employee roster.' end
    local definition = roleDefinition('job', jobName)
    local result = {}
    for _, row in ipairs(rows) do
        local gradeNumber = tonumber(row.level)
        local grade = gradeNumber and definition.grades[gradeNumber]
        if grade then
            local online = exports.kora_core:getPlayerByCitizenId(row.citizenid) ~= nil
            result[#result + 1] = {
                citizenid = row.citizenid, name = row.name,
                jobName = jobName, jobLabel = definition.label or jobName,
                level = gradeNumber, gradeName = grade.name, pay = grade.payment or 0, online = online,
            }
        end
    end
    return result
end

local function gangEmployees(gangName)
    local rows, err = Kora.sql.query([[SELECT `citizenid`, `name`, `gang` FROM `players`
        WHERE `deleted_at` IS NULL AND JSON_UNQUOTE(JSON_EXTRACT(`gang`, '$.name')) = ?]], { gangName })
    if err then return nil, 'Could not load gang roster.' end
    local definition, result = roleDefinition('gang', gangName), {}
    for _, row in ipairs(rows or {}) do
        local gang = decode(row.gang, {})
        local level = tonumber(gang.grade and gang.grade.level)
        local grade = level and definition.grades[level]
        if grade then
            result[#result + 1] = {
                citizenid = row.citizenid, name = row.name, jobName = gangName,
                jobLabel = definition.label or gangName, level = level, gradeName = grade.name,
                online = exports.kora_core:getPlayerByCitizenId(row.citizenid) ~= nil,
            }
        end
    end
    table.sort(result, function(a, b) return a.name < b.name end)
    return result
end

local function employeeRows(roleType, roleName)
    if roleType == 'gang' then return gangEmployees(roleName) end
    return jobEmployees(roleName)
end

local function isEmployee(citizenid, roleType, roleName)
    for _, employee in ipairs(employeeRows(roleType, roleName) or {}) do
        if employee.citizenid == citizenid then return true end
    end
    return false
end

local function updateRoster(citizenid, roleType, roleName, grade)
    if roleType ~= 'gang' then
        if grade then return exports.kora_multijob:setEmployeeJob(citizenid, roleName, grade) end
        return exports.kora_multijob:removeEmployeeJob(citizenid, roleName)
    end
    local target = exports.kora_core:getPlayerByCitizenId(citizenid)
    if target then return exports.kora_core:setGang(target.source, grade and roleName or 'none', grade or 1) end
    return exports.kora_core:setOfflineGang(citizenid, grade and roleName or 'none', grade or 1)
end

local function nameFor(citizenid)
    local online = exports.kora_core:getPlayerByCitizenId(citizenid)
    if online then return online.name or citizenid end
    local row = Kora.sql.single('SELECT `name`,`charinfo` FROM `players` WHERE `citizenid` = ? AND `deleted_at` IS NULL', { citizenid })
    if not row then return citizenid end
    if row.name and row.name ~= 'unknown' then return row.name end
    local charinfo = decode(row.charinfo, {})
    return ((charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')):gsub('^%s*(.-)%s*$', '%1')
end

CreateThread(function()
    local available = Kora.sql.ready(60000)
    if not available then return print('^1[kora_bossmenu]^7 kora_sql was not ready; resource disabled.') end
    local reports, err = Kora.sql.ensureTables(KoraBossmenuSchema)
    if err then return print(('^1[kora_bossmenu]^7 schema setup failed: %s'):format(err)) end
    for _, report in ipairs(reports or {}) do
        for _, warning in ipairs(report.warnings or {}) do
            print(('^3[kora_bossmenu]^7 schema warning: %s'):format(tostring(warning)))
        end
    end
    ready = true
end)

local function actorIsBoss(src, roleType)
    local role = actorRole(src, roleType)
    return ready and role and isBoss(src, roleType, role.name) or false
end

Kora.callback.register('kora_bossmenu:server:isJobBoss', function(src)
    return actorIsBoss(src, 'job')
end)

Kora.callback.register('kora_bossmenu:server:isGangBoss', function(src)
    return actorIsBoss(src, 'gang')
end)

Kora.callback.register('kora_bossmenu:server:getJobData', function(src, requestedRoleType)
    local roleType = requestedRoleType == 'gang' and 'gang' or 'job'
    local role = actorRole(src, roleType)
    if roleType == 'job' and (not role or not isBoss(src, roleType, role.name)) then roleType, role = 'gang', actorRole(src, 'gang') end
    if not role then return nil, 'Character not loaded.' end
    local ok, err = requireBoss(src, roleType, role.name)
    if not ok then return nil, err end
    local row, rowErr = ensureRole(roleType, role.name)
    if not row then return nil, rowErr end
    local definition = roleDefinition(roleType, role.name)
    local grades, employees = {}, employeeRows(roleType, role.name)
    for level, grade in ipairs(definition.grades) do grades[#grades + 1] = { name = grade.name, grade = level, pay = roleType == 'job' and grade.payment or nil } end
    return {
        jobGrades = grades, employees = employees or {}, applicants = row.applicants,
        questions = row.questions, logs = row.logs, jobName = role.name,
        jobLabel = definition.label or role.name, roleType = roleType,
        accountBalance = exports.kora_banking:GetAccountBalance(role.name),
    }
end)

Kora.callback.register('kora_bossmenu:server:getApplication', function(_, jobName, roleType)
    roleType = roleType == 'gang' and 'gang' or 'job'
    local definition = roleDefinition(roleType, jobName)
    if not definition then return nil, 'Unknown organization.' end
    local row, err = ensureRole(roleType, jobName)
    return row and { label = definition.label or jobName, questions = row.questions, roleType = roleType } or nil, err
end, { rateLimit = { max = 5, window = 10000 } })

Kora.callback.register('kora_bossmenu:server:submitApplication', function(src, jobName, answers, roleType)
    if not ready or type(answers) ~= 'table' then return false, 'Invalid application.' end
    roleType = roleType == 'gang' and 'gang' or 'job'
    if not roleDefinition(roleType, jobName) then return false, 'Unknown organization.' end
    local row, err = ensureRole(roleType, jobName)
    if not row then return false, err end
    local player = exports.kora_core:getPlayerData(src)
    if not player or not player.citizenid then return false, 'Character not loaded.' end
    for _, applicant in ipairs(row.applicants) do if applicant.citizenid == player.citizenid then return false, 'You already applied for this job.' end end
    local questions = {}
    for i, question in ipairs(row.questions) do
        local answer = answers[tostring(i)]
        if answer == nil or tostring(answer):match('^%s*$') then return false, 'Every question must be answered.' end
        questions[#questions + 1] = { question = question.question, answer = tostring(answer):sub(1, 1000) }
    end
    row.applicants[#row.applicants + 1] = { citizenid = player.citizenid, name = player.name or player.citizenid, questions = questions }
    return save(row, 'applicants')
end, { rateLimit = { max = 2, window = 60000 } })

local function managed(src, data)
    local roleName = type(data) == 'table' and (data.jobName or data.job)
    local roleType = data and data.roleType == 'gang' and 'gang' or 'job'
    local ok, err = requireBoss(src, roleType, roleName)
    if not ok then return nil, err end
    return ensureRole(roleType, roleName)
end

Kora.callback.register('kora_bossmenu:server:acceptApplicant', function(src, data)
    local row, err = managed(src, data); if not row then return false, err end
    local applicant
    for i, entry in ipairs(row.applicants) do if entry.citizenid == data.citizenid then applicant = entry; table.remove(row.applicants, i); break end end
    if not applicant then return false, 'Application not found.' end
    local ok, writeErr = updateRoster(applicant.citizenid, row.roleType, row.roleName, 1)
    if not ok then return false, writeErr end
    save(row, 'applicants'); addLog(row, ('%s was hired.'):format(applicant.name))
    return true
end)

Kora.callback.register('kora_bossmenu:server:denyApplicant', function(src, data)
    local row, err = managed(src, data); if not row then return false, err end
    for i, entry in ipairs(row.applicants) do if entry.citizenid == data.citizenid then table.remove(row.applicants, i); save(row, 'applicants'); addLog(row, ('Application from %s was denied.'):format(entry.name)); return true end end
    return false, 'Application not found.'
end)

Kora.callback.register('kora_bossmenu:server:addQuestion', function(src, data)
    local row, err = managed(src, data); if not row then return false, err end
    local question = data.new
    -- A blank question would add an empty, unanswerable field to every application.
    if #row.questions >= Config.maxQuestions or type(question) ~= 'table' or type(question.question) ~= 'string' or not question.question:find('%S') or not ({ short = true, long = true, number = true, yesno = true })[question.type] then return false, 'Invalid question.' end
    row.questions[#row.questions + 1] = { question = question.question:sub(1, 250), type = question.type }
    return save(row, 'questions')
end)

Kora.callback.register('kora_bossmenu:server:editQuestion', function(src, data)
    local row, err = managed(src, data); if not row then return false, err end
    local updated = data.updatedQuestion
    if type(updated) ~= 'table' or type(updated.question) ~= 'string' or not updated.question:find('%S') or not ({ short = true, long = true, number = true, yesno = true })[updated.type] then return false, 'Invalid question.' end
    for i, question in ipairs(row.questions) do if question.question == data.originalQuestion then row.questions[i] = { question = updated.question:sub(1, 250), type = updated.type }; return save(row, 'questions') end end
    return false, 'Question not found.'
end)

Kora.callback.register('kora_bossmenu:server:removeQuestion', function(src, data)
    local row, err = managed(src, data); if not row then return false, err end
    for i, question in ipairs(row.questions) do if question.question == data.question then table.remove(row.questions, i); return save(row, 'questions') end end
    return false, 'Question not found.'
end)

Kora.callback.register('kora_bossmenu:server:setRank', function(src, data)
    local row, err = managed(src, data); if not row then return false, err end
    local grade = math.floor(tonumber(data.grade) or 0)
    if not roleDefinition(row.roleType, row.roleName).grades[grade] or type(data.citizenid) ~= 'string' then return false, 'Invalid employee rank.' end
    local actorRow = actorRole(src, row.roleType)
    local actorGrade = actorRow and actorRow.grade and actorRow.grade.level
    if not actorGrade then return false, 'Your role changed; reopen the boss menu.' end
    if grade >= actorGrade then return false, 'You cannot assign your rank or a higher rank.' end
    local roster = employeeRows(row.roleType, row.roleName) or {}
    for _, employee in ipairs(roster) do
        if employee.citizenid == data.citizenid and employee.level >= actorGrade then return false, 'You cannot manage an equal or higher-ranked employee.' end
    end
    local ok, writeErr = updateRoster(data.citizenid, row.roleType, row.roleName, grade); if not ok then return false, writeErr end
    addLog(row, ('%s was set to %s.'):format(nameFor(data.citizenid), roleDefinition(row.roleType, row.roleName).grades[grade].name))
    return true
end)

Kora.callback.register('kora_bossmenu:server:fireEmployee', function(src, data)
    local row, err = managed(src, data); if not row then return false, err end
    if type(data.employee) ~= 'string' then return false, 'Invalid employee.' end
    local actorRow = actorRole(src, row.roleType)
    local actorGrade = actorRow and actorRow.grade and actorRow.grade.level
    if not actorGrade then return false, 'Your role changed; reopen the boss menu.' end
    for _, employee in ipairs(employeeRows(row.roleType, row.roleName) or {}) do
        if employee.citizenid == data.employee and employee.level >= actorGrade then return false, 'You cannot manage an equal or higher-ranked employee.' end
    end
    local ok, writeErr = updateRoster(data.employee, row.roleType, row.roleName, nil); if not ok then return false, writeErr end
    addLog(row, ('%s was fired.'):format(nameFor(data.employee)))
    return true
end)

Kora.callback.register('kora_bossmenu:server:openStash', function(src, roleType)
    roleType = roleType == 'gang' and 'gang' or 'job'
    local role = actorRole(src, roleType)
    if not role then return false, 'You are not a boss.' end
    local ok, err = requireBoss(src, roleType, role.name)
    if not ok then return false, err end
    local id = ('kora_bossmenu:%s:%s'):format(roleType, role.name)
    exports.kora_inventory:RegisterStash(id, (roleDefinition(roleType, role.name).label or role.name) .. ' Boss Stash', Config.stash.slots, Config.stash.maxWeight, false, { [role.name] = 1 })
    -- `stashOpen`, not `openInventory`: kora_inventory's server realm exports
    -- `OpenInventory`/`stashOpen`, and the lowercase `openInventory` is a
    -- CLIENT-realm export.
    return exports.kora_inventory:stashOpen(src, id)
end)

Kora.callback.register('kora_bossmenu:server:giveBonus', function(src, data)
    local row, err = managed(src, data); if not row then return false, err end
    local amount = math.floor(tonumber(data.amount) or 0)
    if amount <= 0 or type(data.citizenid) ~= 'string' then return false, 'Invalid bonus amount.' end
    if not isEmployee(data.citizenid, row.roleType, row.roleName) then return false, 'That person is not an employee.' end
    if not exports.kora_banking:RemoveMoney(row.roleName, amount, 'boss-menu-bonus') then
        return false, 'The society does not have enough funds.'
    end

    local target = exports.kora_core:getPlayerByCitizenId(data.citizenid)
    local paid, payErr
    if target then
        paid, payErr = exports.kora_core:addMoney(target.source, 'bank', amount, 'boss-menu-bonus')
    else
        paid, payErr = exports.kora_core:addOfflineMoney(data.citizenid, 'bank', amount)
    end
    if not paid then
        if not exports.kora_banking:AddMoney(row.roleName, amount, 'boss-menu-bonus-refund') then
            print(('^1[kora_bossmenu]^7 bonus credit failed and society refund failed for %s'):format(row.roleName))
        end
        return false, payErr or 'Could not pay bonus.'
    end

    addLog(row, ('%s received a $%d bonus.'):format(nameFor(data.citizenid), amount))
    return true
end, { rateLimit = { max = 5, window = 10000 } })

local function credit(roleType, name, amount, reason)
    if not ready or not roleDefinition(roleType, name) then return false, 'unknown job' end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false, 'amount must be positive' end
    local row, err = ensureRole(roleType, name)
    if not row then return false, err end
    if not exports.kora_banking:AddMoney(name, amount, reason or 'boss-menu-business-credit') then return false, 'could not credit society' end
    addLog(row, ('Business received $%d%s.'):format(amount, reason and (' (' .. tostring(reason):sub(1, 100) .. ')') or ''))
    return true
end

local function debit(roleType, name, amount, reason)
    if not ready or not roleDefinition(roleType, name) then return false, 'unknown job' end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false, 'amount must be positive' end
    local row, err = ensureRole(roleType, name)
    if not row then return false, err end
    if not exports.kora_banking:RemoveMoney(name, amount, reason or 'boss-menu-business-debit') then return false, 'insufficient business funds' end
    addLog(row, ('Business paid out $%d%s.'):format(amount, reason and (' (' .. tostring(reason):sub(1, 100) .. ')') or ''))
    return true
end

local function balance(roleType, name)
    if not roleDefinition(roleType, name) then return nil, 'unknown job' end
    return exports.kora_banking:GetAccountBalance(name)
end

exports('addBusinessMoney', function(jobName, amount, reason) return credit('job', jobName, amount, reason) end)
exports('removeBusinessMoney', function(jobName, amount, reason) return debit('job', jobName, amount, reason) end)
exports('getBusinessBalance', function(jobName) return balance('job', jobName) end)

exports('AddMoney', function(name, amount) return (credit('job', name, amount, 'qb-management')) end)
exports('RemoveMoney', function(name, amount) return (debit('job', name, amount, 'qb-management')) end)
exports('AddGangMoney', function(name, amount) return (credit('gang', name, amount, 'qb-management')) end)
exports('RemoveGangMoney', function(name, amount) return (debit('gang', name, amount, 'qb-management')) end)
exports('GetAccount', function(name) return tonumber((balance('job', name))) or 0 end)
exports('GetGangAccount', function(name) return tonumber((balance('gang', name))) or 0 end)
