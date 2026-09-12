local RESOURCE = GetCurrentResourceName()
local ready = false

local function decode(value, fallback)
    if type(value) ~= 'string' then return fallback end
    local ok, decoded = pcall(json.decode, value)
    return ok and type(decoded) == 'table' and decoded or fallback
end

local function jobDefinition(name)
    local job = type(name) == 'string' and QB.shared.get('jobs', name) or nil
    if not job or name == 'unemployed' then return nil end
    return job
end

local function actorJob(src)
    local data = exports.qbcore:getPlayerData(src)
    return data and data.job or nil
end

local function isBoss(src, expectedJob)
    local job = actorJob(src)
    if not job or job.name ~= expectedJob then return false end
    local definition = jobDefinition(job.name)
    local grade = definition and definition.grades and definition.grades[job.grade and job.grade.level]
    return grade and grade.isboss == true
end

local function requireBoss(src, job)
    if not ready then return nil, 'Boss menu storage is still starting.' end
    if not jobDefinition(job) then return nil, 'Unknown job.' end
    if not isBoss(src, job) then return nil, 'You are not a boss for this job.' end
    return true
end

local function ensureJob(job)
    local row, err = QB.sql.single('SELECT * FROM `qbbossmenu_jobs` WHERE `job` = ?', { job })
    if err then return nil, 'Could not load boss-menu data.' end
    if not row then
        local inserted, insertErr = QB.sql.insert('INSERT INTO `qbbossmenu_jobs` (`job`,`questions`,`applicants`,`logs`) VALUES (?, ?, ?, ?)', {
            job, json.encode(Config.defaultQuestions), '[]', '[]',
        })
        if not inserted then return nil, insertErr or 'Could not create job data.' end
        row = { job = job, questions = json.encode(Config.defaultQuestions), applicants = '[]', logs = '[]', balance = 0 }
    end
    row.questions = decode(row.questions, {})
    row.applicants = decode(row.applicants, {})
    row.logs = decode(row.logs, {})
    row.balance = tonumber(row.balance) or 0
    return row
end

local function save(row, column)
    local _, err = QB.sql.update(('UPDATE `qbbossmenu_jobs` SET `%s` = ? WHERE `job` = ?'):format(column), {
        json.encode(row[column]), row.job,
    })
    return not err, err
end

local function addLog(row, message)
    row.logs[#row.logs + 1] = { date = os.date('!%Y-%m-%dT%H:%M:%SZ'), message = message }
    while #row.logs > Config.maxLogs do table.remove(row.logs, 1) end
    return save(row, 'logs')
end

local function employeeRows(jobName)
    local rows, err = exports.qbmultijob:getEmployees(jobName)
    if not rows then return nil, err or 'Could not load employee roster.' end
    local definition = jobDefinition(jobName)
    local result = {}
    for _, row in ipairs(rows) do
        local gradeNumber = tonumber(row.level)
        local grade = gradeNumber and definition.grades[gradeNumber]
        if grade then
            local online = exports.qbcore:getPlayerByCitizenId(row.citizenid) ~= nil
            result[#result + 1] = {
                citizenid = row.citizenid, name = row.name,
                jobName = row.jobName, jobLabel = row.jobLabel,
                level = gradeNumber, gradeName = grade.name, pay = tonumber(row.pay) or 0, online = online,
            }
        end
    end
    return result
end

local function isEmployee(citizenid, jobName)
    for _, employee in ipairs(employeeRows(jobName) or {}) do
        if employee.citizenid == citizenid then return true end
    end
    return false
end

local function updateRoster(citizenid, jobName, grade)
    if grade then return exports.qbmultijob:setEmployeeJob(citizenid, jobName, grade) end
    return exports.qbmultijob:removeEmployeeJob(citizenid, jobName)
end

local function nameFor(citizenid)
    local online = exports.qbcore:getPlayerByCitizenId(citizenid)
    if online then return online.name or citizenid end
    local row = QB.sql.single('SELECT `name`,`charinfo` FROM `players` WHERE `citizenid` = ? AND `deleted_at` IS NULL', { citizenid })
    if not row then return citizenid end
    if row.name and row.name ~= 'unknown' then return row.name end
    local charinfo = decode(row.charinfo, {})
    return ((charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')):gsub('^%s*(.-)%s*$', '%1')
end

CreateThread(function()
    local available = QB.sql.ready(60000)
    if not available then return print('^1[qbbossmenu]^7 qbsql was not ready; resource disabled.') end
    local _, err = QB.sql.migrateFiles(RESOURCE, {
        { version = 1, name = 'bossmenu', file = 'sql/001_bossmenu.sql' },
    })
    if err then return print(('^1[qbbossmenu]^7 migration failed: %s'):format(err)) end
    ready = true
end)

QB.callback.register('qbbossmenu:server:getJobData', function(src)
    local job = actorJob(src)
    if not job then return nil, 'Character not loaded.' end
    local ok, err = requireBoss(src, job.name)
    if not ok then return nil, err end
    local row, rowErr = ensureJob(job.name)
    if not row then return nil, rowErr end
    local definition = jobDefinition(job.name)
    local grades, employees = {}, employeeRows(job.name)
    for level, grade in ipairs(definition.grades) do grades[#grades + 1] = { name = grade.name, grade = level, pay = grade.payment or 0 } end
    return { jobGrades = grades, employees = employees or {}, applicants = row.applicants, questions = row.questions, bank = exports.qbbanking:GetAccountBalance(job.name), logs = row.logs, jobName = job.name, jobLabel = definition.label or job.name }
end)

QB.callback.register('qbbossmenu:server:getApplication', function(_, jobName)
    local definition = jobDefinition(jobName)
    if not definition then return nil, 'Unknown job.' end
    local row, err = ensureJob(jobName)
    return row and { label = definition.label or jobName, questions = row.questions } or nil, err
end, { rateLimit = { max = 5, window = 10000 } })

QB.callback.register('qbbossmenu:server:submitApplication', function(src, jobName, answers)
    if not ready or type(answers) ~= 'table' then return false, 'Invalid application.' end
    local row, err = ensureJob(jobName)
    if not row then return false, err end
    local player = exports.qbcore:getPlayerData(src)
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
    local job = type(data) == 'table' and (data.jobName or data.job)
    local ok, err = requireBoss(src, job)
    if not ok then return nil, err end
    return ensureJob(job)
end

QB.callback.register('qbbossmenu:server:acceptApplicant', function(src, data)
    local row, err = managed(src, data); if not row then return false, err end
    local applicant
    for i, entry in ipairs(row.applicants) do if entry.citizenid == data.citizenid then applicant = entry; table.remove(row.applicants, i); break end end
    if not applicant then return false, 'Application not found.' end
    local ok, writeErr = updateRoster(applicant.citizenid, row.job, 1)
    if not ok then return false, writeErr end
    save(row, 'applicants'); addLog(row, ('%s was hired.'):format(applicant.name))
    return true
end)

QB.callback.register('qbbossmenu:server:denyApplicant', function(src, data)
    local row, err = managed(src, data); if not row then return false, err end
    for i, entry in ipairs(row.applicants) do if entry.citizenid == data.citizenid then table.remove(row.applicants, i); save(row, 'applicants'); addLog(row, ('Application from %s was denied.'):format(entry.name)); return true end end
    return false, 'Application not found.'
end)

QB.callback.register('qbbossmenu:server:addQuestion', function(src, data)
    local row, err = managed(src, data); if not row then return false, err end
    local question = data.new
    if #row.questions >= Config.maxQuestions or type(question) ~= 'table' or type(question.question) ~= 'string' or not ({ short = true, long = true, number = true, yesno = true })[question.type] then return false, 'Invalid question.' end
    row.questions[#row.questions + 1] = { question = question.question:sub(1, 250), type = question.type }
    return save(row, 'questions')
end)

QB.callback.register('qbbossmenu:server:editQuestion', function(src, data)
    local row, err = managed(src, data); if not row then return false, err end
    local updated = data.updatedQuestion
    if type(updated) ~= 'table' or type(updated.question) ~= 'string' or not ({ short = true, long = true, number = true, yesno = true })[updated.type] then return false, 'Invalid question.' end
    for i, question in ipairs(row.questions) do if question.question == data.originalQuestion then row.questions[i] = { question = updated.question:sub(1, 250), type = updated.type }; return save(row, 'questions') end end
    return false, 'Question not found.'
end)

QB.callback.register('qbbossmenu:server:removeQuestion', function(src, data)
    local row, err = managed(src, data); if not row then return false, err end
    for i, question in ipairs(row.questions) do if question.question == data.question then table.remove(row.questions, i); return save(row, 'questions') end end
    return false, 'Question not found.'
end)

QB.callback.register('qbbossmenu:server:setRank', function(src, data)
    local row, err = managed(src, data); if not row then return false, err end
    local grade = math.floor(tonumber(data.grade) or 0)
    if not jobDefinition(row.job).grades[grade] or type(data.citizenid) ~= 'string' then return false, 'Invalid employee rank.' end
    local actorGrade = actorJob(src).grade.level
    if grade >= actorGrade then return false, 'You cannot assign your rank or a higher rank.' end
    local roster = employeeRows(row.job) or {}
    for _, employee in ipairs(roster) do
        if employee.citizenid == data.citizenid and employee.level >= actorGrade then return false, 'You cannot manage an equal or higher-ranked employee.' end
    end
    local ok, writeErr = updateRoster(data.citizenid, row.job, grade); if not ok then return false, writeErr end
    addLog(row, ('%s was set to %s.'):format(nameFor(data.citizenid), jobDefinition(row.job).grades[grade].name))
    return true
end)

QB.callback.register('qbbossmenu:server:fireEmployee', function(src, data)
    local row, err = managed(src, data); if not row then return false, err end
    if type(data.employee) ~= 'string' then return false, 'Invalid employee.' end
    local actorGrade = actorJob(src).grade.level
    for _, employee in ipairs(employeeRows(row.job) or {}) do
        if employee.citizenid == data.employee and employee.level >= actorGrade then return false, 'You cannot manage an equal or higher-ranked employee.' end
    end
    local ok, writeErr = updateRoster(data.employee, row.job, nil); if not ok then return false, writeErr end
    addLog(row, ('%s was fired.'):format(nameFor(data.employee)))
    return true
end)

QB.callback.register('qbbossmenu:server:openStash', function(src)
    local job = actorJob(src)
    if not job then return false, 'You are not a boss.' end
    local ok, err = requireBoss(src, job.name)
    if not ok then return false, err end
    local id = ('qbbossmenu:%s'):format(job.name)
    exports.qbinventory:RegisterStash(id, (jobDefinition(job.name).label or job.name) .. ' Boss Stash', Config.stash.slots, Config.stash.maxWeight, false, { [job.name] = 1 })
    -- `stashOpen`, not `openInventory`: qbinventory's server realm exports
    -- `OpenInventory`/`stashOpen`, and the lowercase `openInventory` is a
    -- CLIENT-realm export, so this call was resolving to nothing at all.
    return exports.qbinventory:stashOpen(src, id)
end)

QB.callback.register('qbbossmenu:server:giveBonus', function(src, data)
    local row, err = managed(src, data); if not row then return false, err end
    local amount = math.floor(tonumber(data.amount) or 0)
    if amount <= 0 or type(data.citizenid) ~= 'string' then return false, 'Invalid bonus amount.' end
    if not isEmployee(data.citizenid, row.job) then return false, 'That person is not an employee.' end
    if not exports.qbbanking:RemoveMoney(row.job, amount, 'boss-menu-bonus') then
        return false, 'The society does not have enough funds.'
    end

    local target = exports.qbcore:getPlayerByCitizenId(data.citizenid)
    local paid, payErr
    if target then
        paid, payErr = exports.qbcore:addMoney(target.source, 'bank', amount, 'boss-menu-bonus')
    else
        -- A bonus is a bank credit even when the employee is offline. The
        -- compatibility object gives us Player.Functions.AddMoney/Save without
        -- issuing a separate player lookup for every roster entry.
        local offline = exports['qb-core']:GetOfflinePlayerByCitizenId(data.citizenid)
        if offline then
            paid = offline.Functions.AddMoney('bank', amount)
            if paid then paid = offline.Functions.Save() end
        end
        payErr = paid and nil or 'Could not save the offline player.'
    end
    if not paid then
        if not exports.qbbanking:AddMoney(row.job, amount, 'boss-menu-bonus-refund') then
            print(('^1[qbbossmenu]^7 bonus credit failed and society refund failed for %s'):format(row.job))
        end
        return false, payErr or 'Could not pay bonus.'
    end

    addLog(row, ('%s received a $%d bonus.'):format(nameFor(data.citizenid), amount))
    return true
end, { rateLimit = { max = 5, window = 10000 } })

---Compatibility aliases for resources that previously used qbbossmenu as the
---society ledger. qbbanking is now the only owner of that money.
exports('addBusinessMoney', function(jobName, amount, reason)
    if not ready or not jobDefinition(jobName) then return false, 'unknown job' end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false, 'amount must be positive' end
    local row, err = ensureJob(jobName)
    if not row then return false, err end
    if not exports.qbbanking:AddMoney(jobName, amount, reason or 'boss-menu-business-credit') then return false, 'could not credit society' end
    addLog(row, ('Business received $%d%s.'):format(amount, reason and (' (' .. tostring(reason):sub(1, 100) .. ')') or ''))
    return true
end)

exports('removeBusinessMoney', function(jobName, amount, reason)
    if not ready or not jobDefinition(jobName) then return false, 'unknown job' end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false, 'amount must be positive' end
    local row, err = ensureJob(jobName)
    if not row then return false, err end
    if not exports.qbbanking:RemoveMoney(jobName, amount, reason or 'boss-menu-business-debit') then return false, 'insufficient business funds' end
    addLog(row, ('Business paid out $%d%s.'):format(amount, reason and (' (' .. tostring(reason):sub(1, 100) .. ')') or ''))
    return true
end)

exports('getBusinessBalance', function(jobName)
    if not ready or not jobDefinition(jobName) then return nil, 'unknown job' end
    return exports.qbbanking:GetAccountBalance(jobName)
end)
