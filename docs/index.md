---
title: kora_bossmenu
sidebar_position: 1
---

# kora_bossmenu

`kora_bossmenu` is the job and gang management console for the Kora stack. Bosses (players whose current job or gang grade has `isboss = true`) open a kora_lib AppShell window where they review job applications, hire or deny applicants, manage the application questionnaire, change ranks, fire or kick members, pay bonuses from the society account, open a shared boss stash and read an activity log. Players apply through a generated kora_lib input form. Society money is owned by [kora_banking](https://github.com/KoraFiveM/kora_banking); kora_bossmenu only delegates to it and keeps the legacy `qb-management` export surface alive.

## Features

- **Management console** - a kora_lib AppShell app (`kora_bossmenu:management`) with Overview, Applicants, Employees, Questions and Activity pages. See [Management menu](./management-menu.md).
- **Job and gang support** - every feature works for the active job and for the active gang. Gang rosters show ranks but no pay, and use **Kick** instead of **Fire**.
- **Boss check on every action** - the server re-checks the caller's current boss grade before reading data or performing any mutation.
- **Applications** - per-organization questionnaires (short text, long text, number, yes/no). Players submit one application per organization; bosses hire (grade 1) or deny. See [Applications](./applications.md).
- **Rank management** - bosses can set ranks strictly below their own grade and cannot manage equal or higher-ranked members. Works for online and offline characters.
- **Bonuses** - pays an employee's bank account from the society account in kora_banking, with automatic refund if the payout fails.
- **Boss stash** - a shared kora_inventory stash per job or gang.
- **Activity log** - hires, denials, rank changes, firings, bonuses and business credits/debits are recorded per organization (capped by `Config.maxLogs`).
- **World interaction points** - kora_target boxes for "Open Boss Menu" and "Apply for Job" at configured coordinates.
- **Business money exports** - `addBusinessMoney`, `removeBusinessMoney`, `getBusinessBalance` and the legacy `qb-management` exports, all delegating to kora_banking. See [Exports](./exports.md).
- **Extra menu actions** - other resources can add client-side actions to the overview page with `AddBossMenuItem` / `AddGangMenuItem`.

The resource registers **no chat commands**. Menus are opened through the target points, the `openBossMenu` / `openApplication` client exports, or the legacy client events listed in [Events](./events.md).

## Requirements

Declared in `fxmanifest.lua`:

| Resource | Used for |
| --- | --- |
| [kora_lib](https://github.com/KoraFiveM/kora_lib) | Callbacks, notifications, AppShell (`Kora.nui.registerApp` / `openApp`), input dialogs, config registration |
| [kora_sql](https://github.com/KoraFiveM/kora_sql) | `Kora.sql` queries and `ensureTables` schema creation |
| [kora_core](https://github.com/KoraFiveM/kora_core) | Player data, job/gang definitions (`Kora.shared`), `setGang` / `setOfflineGang`, `addMoney` / `addOfflineMoney` |
| [kora_inventory](https://github.com/KoraFiveM/kora_inventory) | Boss stash (`RegisterStash`, `stashOpen`) |
| [kora_multijob](https://github.com/KoraFiveM/kora_multijob) | Job rosters (`getEmployees`, `setEmployeeJob`, `removeEmployeeJob`) |
| [kora_banking](https://github.com/KoraFiveM/kora_banking) | Society account balance, debits and credits |

Also used but **not** declared as a manifest dependency:

- [kora_target](https://github.com/KoraFiveM/kora_target) - the client calls `exports.kora_target:addBoxZone` at start for every configured boss/apply point. Start it before kora_bossmenu.

The resource `provide`s `qb-management`, so resources that depend on `qb-management` resolve to it. See [Compatibility](./compatibility.md).

## Installation

1. Place the resource in your resources folder.
2. Make sure the dependencies start first, for example:

   ```cfg
   ensure kora_lib
   ensure kora_sql
   ensure kora_core
   ensure kora_inventory
   ensure kora_multijob
   ensure kora_banking
   ensure kora_target
   ensure kora_bossmenu
   ```

3. No manual SQL import is needed. On start the server waits for kora_sql (up to 60 seconds) and creates the `kora_bossmenu_jobs` table through `Kora.sql.ensureTables`. See [Database](./database.md).
4. No inventory items are required.
5. Mark boss grades with `isboss = true` in your kora_core job and gang definitions, and adjust the boss/apply locations in `shared.lua`. See [Configuration](./configuration.md).

## Pages

- [Configuration](./configuration.md) - every option in `shared.lua`.
- [Management menu](./management-menu.md) - the boss console, permissions and each action.
- [Applications](./applications.md) - applying for a job or gang and the question types.
- [Exports](./exports.md) - client and server exports.
- [Events](./events.md) - legacy open events and internal callbacks.
- [Database](./database.md) - `kora_bossmenu_jobs` and the tables it reads.
- [Compatibility](./compatibility.md) - `qb-management` replacement surface.
- [Troubleshooting](./troubleshooting.md) - common problems.
