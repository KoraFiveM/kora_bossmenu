Config = {
    command = 'openbossmenu',
    applicationCommand = 'jobapply',
    stash = { slots = 80, maxWeight = 400000 },
    maxQuestions = 20,
    maxLogs = 100,
}

Config.Menus = {
    job = {
        {
            job = 'police',
            bossmenu = {
                vector3(447.96, -973.39, 30.69)
            },
            apply = {
                vector3(438.84, -981.15, 30.69),
                vector3(441.82, -981.13, 30.69)
            }
        }
    },
    gang = {
        {
            job = 'ballas',
            bossmenu = {
                vector3(322.25, -1005.72, 29.30)
            },
            apply = {
                vector3(318.96, -1005.61, 29.30)
            }
        }
    }
}
 
Config.defaultQuestions = {
    job = {
        { question = 'Why do you want to work here?', type = 'short' },
        { question = 'What relevant experience do you have?', type = 'long' },
        { question = 'How do you work in a team environment?', type = 'long' },
    },
    gang = {
        { question = 'Why do you want to join this gang?', type = 'short' },
        { question = 'What relevant experience do you have?', type = 'long' },
        { question = 'How do you work in a team environment?', type = 'long' },
        { question = 'What is your arrest record like?', type = 'long' }
    }
}

-- Registers this resource-owned configuration with qblib while preserving the
-- public Config table used by the client and server scripts.
if QB and QB.config and QB.config.adopt then Config = QB.config.adopt(Config) end
