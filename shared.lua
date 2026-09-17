Config = {
    command = 'openbossmenu',
    applicationCommand = 'jobapply',
    stash = { slots = 80, maxWeight = 400000 },
    maxQuestions = 20,
    maxLogs = 100,
}

Config.defaultQuestions = {
    { question = 'Why do you want to work here?', type = 'short' },
    { question = 'What relevant experience do you have?', type = 'long' },
    { question = 'How do you work in a team environment?', type = 'long' },
}

-- Registers this resource-owned configuration with qblib while preserving the
-- public Config table used by the client and server scripts.
if QB and QB.config and QB.config.adopt then Config = QB.config.adopt(Config) end
