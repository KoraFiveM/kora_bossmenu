---
title: "Installation"
sidebar_position: 2
---


# Installation

Kora Bossmenu is a management console for jobs and gangs: a boss reviews applications, hires, promotes and fires, pays bonuses from the society account, edits the application questions, reads an activity log and opens a boss stash. It stores almost nothing itself. Jobs come from Kora Multijob, money from Kora Banking, and the player's job or gang from Kora Core.

## Install Kora Bossmenu

1. **Add the folder** — Place `kora_bossmenu` in your resources directory (on the Kora recipe it is `resources/[kora]/kora_bossmenu`). Keep the folder name: other resources call `exports.kora_bossmenu`.

2. **Make sure the dependencies exist** — The manifest declares `kora_lib`, `kora_sql`, `kora_core`, `kora_inventory`, `kora_multijob` and `kora_banking` as dependencies. In addition, `client/main.lua` calls `exports.kora_target:addBoxZone` to create the in-world boss and apply points, but `kora_target` is NOT declared in the manifest. Start it too, or the box zones are not created (the client calls it unguarded, so a missing resource would raise an error there; not tested).

3. **Start it after its dependencies** — Start it last of the group. The resource has no startup ordering of its own beyond the `dependency` lines.

   ```bash title="server.cfg"
   ensure kora_lib
   ensure kora_sql
   ensure kora_core
   ensure kora_inventory
   ensure kora_multijob
   ensure kora_banking
   ensure kora_target
   ensure kora_bossmenu
   ```

4. **Check the manifest** — The shared scripts load the Kora Lib and Kora Core loaders before `shared.lua`; the Kora SQL loader is a server script loaded before `server/schema.lua`. The manifest also `provide`s `qb-management` so legacy callers that use `exports['qb-management']` resolve to this resource.

   ```lua title="fxmanifest.lua"
   fx_version 'cerulean'
   game 'gta5'
   lua54 'yes'

   name 'kora_bossmenu'
   -- Legacy qb-management exports (AddMoney, GetAccount, Add/RemoveBossMenuItem, ...).
   provide 'qb-management'
   author 'qbcore2'
   version '0.2.0'
   description 'Job management, applications, employee roster, stash and bonuses for kora_core'

   dependency 'kora_lib'
   dependency 'kora_sql'
   dependency 'kora_core'
   dependency 'kora_inventory'
   dependency 'kora_multijob'
   dependency 'kora_banking'

   shared_scripts {
       '@kora_lib/init.lua',
       '@kora_core/init.lua',
       'shared.lua',
   }

   server_scripts { '@kora_sql/init.lua', 'server/schema.lua', 'server/main.lua' }
   client_script 'client/main.lua'

   files {
       'types.lua',
   }

   -- kora_qa: Gherkin test scenarios (converted legacy tests), see [kora]/kora_qa/README.md
   qa_feature 'tests/*.feature'
   ```

5. **Tables are created for you** — On start the server script waits up to 60 seconds for Kora SQL, then calls `Kora.sql.ensureTables(KoraBossmenuSchema)` to create `kora_bossmenu_jobs`. There is no SQL file to import. Until this finishes the menu refuses every action with `Boss menu storage is still starting.`

6. **Define the jobs, boss grades and bank accounts** — A player only qualifies if their grade has `isboss = true` in the shared job (or gang) definition read through `Kora.shared.get('jobs' | 'gangs', name)`. Kora Bossmenu does not define jobs. Business money lives in a Kora Banking account named exactly like the job. Kora Banking creates a missing job or gang account (balance 0) when a boss character's data is processed by its `ensureOrganizationAccounts`; until the account exists the balance reads `0` and credits or debits return `false`.

7. **Set the map points** — Edit `Config.Menus` in `shared.lua` (see Configuration) to place boss and apply points. A job without an entry still works through the exports; it just has no in-world point.

## Start order and startup behavior

- The server script sets an internal `ready` flag only after `Kora.sql.ready(60000)` succeeds and `Kora.sql.ensureTables` returns without error. If Kora SQL is not ready within 60 seconds it prints `kora_sql was not ready; resource disabled.` and `ready` stays `false`. If schema setup fails it prints `schema setup failed: <error>`. In both cases every callback and export that checks `ready` fails until the resource is restarted.
- Schema warnings from `ensureTables` are printed as `schema warning: <text>` and do not block startup.
- Callbacks and exports are registered at load time, before `ready` becomes true. Calls made during that window return a failure value, they do not queue.
- `getBusinessBalance` and the `GetAccount` family do not check `ready`; they only read Kora Banking.

## Things that surprise people

- The bundled `README.md` says `/openbossmenu` and `/jobapply <job>` exist. They do not: `client/main.lua` and `server/main.lua` register no command at all (the README has since been corrected). Access is through the target zones, the two client events, or the client exports.
- Hiring an applicant adds them to the job roster at grade 1 through Kora Multijob. It changes their active job only if their active job is already that job (see How to use).
- Job pay is not paid by this resource. It only displays `grade.payment`.
- The `web/` folder (React source and build) is left over for parity review. The manifest does not load it and the resource does not use it.

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

Also used but **not** declared as a manifest dependency: [kora_target](https://github.com/KoraFiveM/kora_target), whose `addBoxZone` export creates the boss and apply points.

No inventory items are required. The resource has no dependency on ox_lib, oxmysql, community bridges or legacy QBCore.

## Related pages

- [Configuration](./api/configuration.md) - every option in `shared.lua`.
- [Data and storage](./api/data.md) - the `kora_bossmenu_jobs` table and the tables it reads.
- [Compatibility](./compatibility.md) - the `qb-management` replacement surface.
- [Troubleshooting](./troubleshooting.md) - common startup and permission problems.
