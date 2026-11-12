---
title: "How to use"
sidebar_position: 3
---


# How to use

A boss opens the management window at a target zone (or through an export or event), and every button in it becomes a server callback that re-checks the boss grade. Applicants fill a question form and wait in a list until a boss hires or denies them.

## Who counts as a boss

Qualification is decided on the server by the private function `isBoss` in `server/main.lua`, always against the player's live data from `exports.kora_core:getPlayerData(src)`:

- The player's active `job` (or `gang`) name must equal the organization being managed.
- The organization must exist in `Kora.shared.get('jobs'|'gangs', name)`. The names `unemployed` (job) and `none` (gang) are rejected as `Unknown organization.`
- The player's current grade (`role.grade.level`) must have `isboss == true` in the definition's `grades` table.
- There is no ACE, command permission or job-name allow-list. Any job or gang with a boss grade works, even if it is not in `Config.Menus`.

> **Note:** Only the ACTIVE job counts. With Kora Multijob a player may hold several jobs, but they must switch to the job whose boss grade they hold before the menu opens.

## Ways to open the menu

All three end in the same private client function `openBossMenu(roleType)`. It ignores a second call while a menu is already opening or open (`appActive`).

```lua title="client.lua"
-- client script of another resource: open the boss menu from your own interaction.
-- Opens the active JOB menu; if the player is not a job boss it falls back to the gang menu.
exports.kora_bossmenu:openBossMenu()

-- Force the gang menu
exports.kora_bossmenu:openBossMenu('gang')

-- Open the application form of a job
exports.kora_bossmenu:openApplication('police')
```

- Target zones: `initLocations` creates a box zone for every `bossmenu` coordinate in `Config.Menus` with the option `Open Boss Menu`. The option is visible only when the local player's job/gang grade has `isboss` (client-side convenience check). The zone does not look at the `job` field of its entry; the menu always opens for the player's own active job or gang.
- Client exports: `exports.kora_bossmenu:openBossMenu(roleType?)` (used by Kora Jobcreator's business menu).
- Legacy events: `qb-bossmenu:client:OpenMenu` and `qb-gangmenu:client:OpenMenu` first ask the server whether the player is a job/gang boss and then open the menu.

## The management window

The UI is a single Kora Lib AppShell app with the id `kora_bossmenu:management`, registered with `Kora.nui.registerApp` and opened with `Kora.nui.openApp`. There is no custom HTML in this resource. It has five pages:

- Overview: counts of employees, applicants and questions, an `Open boss stash` button, and any extra buttons added through `AddBossMenuItem` / `AddGangMenuItem`.
- Applicants: one card per pending application with the questions and answers, and Hire / Deny buttons.
- Employees: the `Business balance` (read from Kora Banking when the data was loaded), and a card per employee with Online/Offline badge, grade and pay, and the actions Set rank, Give bonus and Fire (labelled Kick for gangs).
- Questions: add, edit and remove application questions.
- Activity: the stored log, newest first.

> **Note:** After a successful action the client calls `kora_bossmenu:server:getJobData` again and swaps the new navigation into the open window. If only the refresh fails the user sees `Saved, but the view could not refresh.`

## Hiring: applications

A player applies at an `apply` point (option `Apply for Job`) or through `exports.kora_bossmenu:openApplication(job)`. The client loads the questions with `kora_bossmenu:server:getApplication`, shows them in `Kora.nui.openInputDialog` (every field required) and submits the answers with `kora_bossmenu:server:submitApplication`.

- Question types map to inputs: `short` is a text field (max 250 chars), `long` a 4-row textarea (max 1000), `number` a number field, `yesno` a Yes/No select. Any unknown type falls back to a text field.
- The server stores every answer as text truncated to 1000 characters. Each application records `citizenid`, `name` and the question/answer pairs.
- A character can have only one pending application per organization (`You already applied for this job.`). There is no cooldown and no check that the applicant is not already an employee.
- Hire (`acceptApplicant`) removes the application, calls the roster updater with grade `1`, then saves the applicants list and writes the log line `<name> was hired.`.
- Deny (`denyApplicant`) removes the application and logs `Application from <name> was denied.`.
- Applications are stored per job/gang row, never per branch or location.

## How a job or gang change is actually applied

Kora Bossmenu never edits the `players` table for jobs itself. The private function `updateRoster` in `server/main.lua` delegates:

- Jobs, set or hire: `exports.kora_multijob:setEmployeeJob(citizenid, jobName, grade)`. Kora Multijob validates the job and grade with `Kora.shared.get('jobs', name)`, updates its own roster table `kora_multijob_jobs` and, ONLY if the character's active job already equals that job, also calls `exports.kora_core:setJob` (online) or `setOfflineJob` (offline) with the new grade.
- Jobs, fire: `exports.kora_multijob:removeEmployeeJob(citizenid, jobName)`. It removes the job from the roster and, if that was the active job, moves the character to `unemployed` grade 1. It fails with `employee does not have that job` if the roster has no such job.
- Gangs, set or hire: `exports.kora_core:setGang(source, gangName, grade)` for an online player, `exports.kora_core:setOfflineGang(citizenid, gangName, grade)` for an offline one. This updates the gang in the player data (and the `players` row for offline targets). There is no gang roster table: the member list is read from the `players` table.
- Gangs, kick: the same two calls with `none` and grade `1`.

> **Note:** Consequence for jobs: a newly hired applicant is on the roster at grade 1, but their active job changes only when they select that job through Kora Multijob (or already had it active). The boss menu does not force a switch.

## Grades, rank changes and salary

- Grades are 1-based indexes into the job definition's `grades` table. The list shown in the Set rank form comes from `ipairs(definition.grades)`.
- The submitted grade is floored (`math.floor(tonumber(...) or 0)`) and must exist for the organization, otherwise `Invalid employee rank.`
- A boss cannot assign a grade equal to or higher than their own (`You cannot assign your rank or a higher rank.`) and cannot change an employee whose current grade is equal to or higher than theirs (`You cannot manage an equal or higher-ranked employee.`). The same rule protects firing, which also means a boss cannot fire themselves.
- Salary is not editable here. Job pay is the `payment` value of each grade in the shared job definition. The roster and the Set rank form only display it (`grade.payment or 0`). Gang grades have no pay shown.
- Hiring always uses grade 1. To start someone higher, hire them and then use Set rank.

## Society funds and bonuses

The society balance is a Kora Banking account whose `account_name` equals the job or gang name. Kora Bossmenu keeps no balance of its own (new installs have no balance column). It reads, credits and debits through `exports.kora_banking:GetAccountBalance`, `AddMoney` and `RemoveMoney`.

- Give bonus (`giveBonus`): the amount is floored and must be above 0; the target must be an employee (job roster or gang member list). The society is debited first (`boss-menu-bonus`), then the employee's `bank` money is credited with `exports.kora_core:addMoney` (online) or `addOfflineMoney` (offline).
- If the employee credit fails the society is refunded with the reason `boss-menu-bonus-refund`. If the refund also fails, the console prints `bonus credit failed and society refund failed for <name>` and the money is lost from the account.
- Bonuses use the account named after the job or gang. A job with no Kora Banking account has balance 0, so any bonus fails with `The society does not have enough funds.`
- Other resources add and remove society money through the exports `addBusinessMoney`, `removeBusinessMoney`, `getBusinessBalance` and the `qb-management` style exports. Every such credit or debit is also written to the activity log.

> **Note:** Kora Banking rejects amounts that are not finite, are 0 or below, or exceed 1,000,000,000. Debits succeed only if the balance covers the amount (`account_balance >= amount` in the SQL).

## The boss stash

The Open boss stash button calls `kora_bossmenu:server:openStash`. After the boss check, the server registers the stash `kora_bossmenu:<job|gang>:<name>` with `exports.kora_inventory:RegisterStash(id, '<Label> Boss Stash', Config.stash.slots, Config.stash.maxWeight, false, { [name] = 1 })` and opens it for the player with `exports.kora_inventory:stashOpen(src, id)`. The last argument is the group restriction for kora_inventory (`{ [roleName] = 1 }`). The window closes before the stash opens. The stash contents are owned by Kora Inventory, not by this resource. The meaning of the `false` argument is defined by Kora Inventory's `RegisterStash` and was not verified here.

## Architecture

- Client (`client/main.lua`): builds the AppShell definition from the last data loaded by `getJobData`, forwards each action to a server callback, and creates the target zones. It holds no authority: the data it shows is a copy returned by the server.
- Server (`server/main.lua`): registers 14 callbacks and 9 exports. All writes happen here. Each mutating callback runs the same `managed` helper: it rebuilds the organization name from the payload, calls `requireBoss` against live Kora Core data, then loads or creates the row.
- Storage: one table, `kora_bossmenu_jobs`, with JSON columns for the application questions, pending applicants and activity logs. Employees, jobs and money live in other resources.
- Callbacks use `Kora.callback.register` on the server and `Kora.callback.trigger` on the client. Failure is returned as `false`/`nil` plus a message string, not raised.
- Public surface: server exports, client exports and the two legacy client events. Everything else in both files is a local function.

## A worked flow

```text title="client/main.lua (simplified)"
-- What happens when a boss presses "Set rank" (all from client/main.lua onAction):
local ok, err = Kora.callback.trigger('kora_bossmenu:server:setRank', {
    jobName = 'police', roleType = 'job', citizenid = 'ABC12345', grade = '2',
})
-- server: requireBoss -> grade must exist -> grade < actor grade -> target below actor
--         -> exports.kora_multijob:setEmployeeJob(citizenid, 'police', 2) -> log line
-- then the client calls kora_bossmenu:server:getJobData again and updates the open window.
```

## Related pages

- [Management menu](./management-menu.md) - every page and action of the console, with the exact messages and log entries.
- [Applications](./applications.md) - the application form, question types and submission rules.
- [API reference](./api/index.md) - exports, events, configuration and storage.
- [Troubleshooting](./troubleshooting.md) - symptoms and fixes.
