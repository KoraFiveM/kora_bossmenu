---
title: Database
sidebar_position: 7
---

# Database

No SQL file needs to be imported. On start the server waits up to 60 seconds for kora_sql and then calls `Kora.sql.ensureTables` with the schema in [`server/schema.lua`](https://github.com/KoraFiveM/kora_bossmenu/blob/dev/server/schema.lua). If kora_sql is not ready or schema setup fails, an error is printed and the resource stays disabled (menus report "Boss menu storage is still starting."). Schema warnings are printed to the console.

## kora_bossmenu_jobs

One row per job or gang, created on first use with the configured default questions. Collation `utf8mb4_unicode_ci`.

| Column | Type | Description |
| --- | --- | --- |
| `job` | `varchar(64)`, primary key | Job name for jobs, `gang:<name>` for gangs. |
| `questions` | `longtext` (JSON) | Array of `{ question, type }`. |
| `applicants` | `longtext` (JSON) | Array of pending applications `{ citizenid, name, questions }`, where `questions` is an array of `{ question, answer }`. |
| `logs` | `longtext` (JSON) | Array of `{ date, message }`; `date` is UTC ISO 8601. Trimmed to `Config.maxLogs` entries. |
| `updated_at` | `timestamp` | Defaults to `CURRENT_TIMESTAMP`, updated on every change. |

Example `questions` value:

```json
[
  { "question": "Why do you want to work here?", "type": "short" },
  { "question": "What relevant experience do you have?", "type": "long" }
]
```

The table has **no balance column**. Society balances live in [kora_banking](https://github.com/KoraFiveM/kora_banking).

## Tables read

| Table | Columns | Used for |
| --- | --- | --- |
| `players` (kora_core) | `citizenid`, `name`, `gang` (JSON, `$.name`, `grade.level`), `charinfo` (JSON), `deleted_at` | Gang rosters and member names for log entries. Rows with `deleted_at` set are ignored. |

Job rosters, grades, money and stashes are accessed only through the exports of kora_multijob, kora_core, kora_banking and kora_inventory.
