KoraBossmenuSchema = {
    {
        name = 'kora_bossmenu_jobs',
        collate = 'utf8mb4_unicode_ci',
        columns = {
            { name = 'job', type = 'varchar(64)' },
            { name = 'questions', type = 'longtext' },
            { name = 'applicants', type = 'longtext' },
            { name = 'logs', type = 'longtext' },
            { name = 'updated_at', type = 'timestamp', default = { raw = 'CURRENT_TIMESTAMP' }, on_update = 'CURRENT_TIMESTAMP' },
        },
        primary = { 'job' },
    },
}
