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
