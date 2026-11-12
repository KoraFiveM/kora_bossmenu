---
title: "Data and storage"
sidebar_position: 6
---


# Data and storage

One table, created by `Kora.sql.ensureTables(KoraBossmenuSchema)`, holds applications, questions and logs. Everything else it shows or changes belongs to another resource.

Namespace: `kora_bossmenu_jobs` · Source: `server/schema.lua, server/main.lua (`ensureRole`, `save`, `addLog`, `gangEmployees`, `nameFor`)`

## Table kora_bossmenu_jobs

| Column | Type | Notes |
| --- | --- | --- |
| job | varchar(64), primary key | Organization key. Jobs use the plain name (`police`). Gangs use the prefix `gang:` (`gang:ballas`). So a gang and a job with the same name do not collide. |
| questions | longtext | JSON array of `{ question, type }`. |
| applicants | longtext | JSON array of `{ citizenid, name, questions = { { question, answer } } }`. |
| logs | longtext | JSON array of `{ date = 'YYYY-MM-DDTHH:MM:SSZ' (UTC), message }`, capped by `Config.maxLogs`. |
| updated_at | timestamp | Defaults to `CURRENT_TIMESTAMP` and updates on every change. |

## How it works

A row is created lazily by `ensureRole` the first time an organization is touched: by `getJobData`, `getApplication`, `submitApplication`, any mutating callback, and the credit/debit exports. It starts with `Config.defaultQuestions` and empty `applicants` and `logs`. Each change rewrites one whole JSON column: `UPDATE kora_bossmenu_jobs SET <column> = ? WHERE job = ?` (the column name is chosen from a fixed list in the code, never from client input). Reads are `SELECT * FROM kora_bossmenu_jobs WHERE job = ?`. JSON that fails to decode is treated as an empty list.

## Persisted vs temporary

Persisted: the three JSON columns above; the job roster (in Kora Multijob's `kora_multijob_jobs`); gang membership and the personal job/gang (in Kora Core's `players` data); society money (in Kora Banking's account); the stash contents (in Kora Inventory). Temporary, in memory only: the `ready` flag, the client's `currentData` and `appActive`, and the extra menu items added with the client exports.

## Employee lists

Job employees come from `exports.kora_multijob:getEmployees(job)`; rows whose grade does not exist in the current job definition are skipped. Gang members come from `SELECT citizenid, name, gang FROM players WHERE deleted_at IS NULL AND JSON_UNQUOTE(JSON_EXTRACT(gang, '$.name')) = ?`, sorted by name, again skipping unknown grades. The online badge is `exports.kora_core:getPlayerByCitizenId(citizenid) ~= nil`.

## Races and consistency

Each JSON column is read, modified in Lua and written back as a whole with no lock or transaction. Two bosses changing applicants or questions at the same moment can overwrite each other. Hiring changes the roster first and saves the applicant list afterwards; the result of that save and of the log write is not checked.

## Schema and example

The schema is declared in [`server/schema.lua`](https://github.com/KoraFiveM/kora_bossmenu/blob/dev/server/schema.lua) with collation `utf8mb4_unicode_ci`. No SQL file needs to be imported. If kora_sql is not ready within 60 seconds or schema setup fails, an error is printed and the resource stays disabled (menus report "Boss menu storage is still starting."). Schema warnings are printed to the console.

Example `questions` value:

```json
[
  { "question": "Why do you want to work here?", "type": "short" },
  { "question": "What relevant experience do you have?", "type": "long" }
]
```

The table has no balance column. Society balances live in [kora_banking](https://github.com/KoraFiveM/kora_banking).

## Tables read

| Table | Columns | Used for |
| --- | --- | --- |
| `players` (kora_core) | `citizenid`, `name`, `gang` (JSON, `$.name`, `grade.level`), `charinfo` (JSON), `deleted_at` | Gang rosters and member names for log entries. Rows with `deleted_at` set are ignored. |

Job rosters, grades, money and stashes are accessed only through the exports of kora_multijob, kora_core, kora_banking and kora_inventory.

## Limits and related APIs

There is no migration or cleanup. A removed job leaves its row behind. Logs and applicants keep citizen names as written when the event happened.
