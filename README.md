# kora_bossmenu

Native boss menu for the qbcore2 stack. It uses `kora_lib`, `kora_sql`, `kora_core`,
`kora_inventory`, and `kora_multijob`; it has no ox_lib, oxmysql, community bridge,
or legacy QBCore dependency.

- `/openbossmenu` opens the active job's boss menu for an `isboss` grade; use
  `/openbossmenu gang` for the active gang. Gang rosters are read from the
  persisted player records, have ranks but no pay, and use **Kick** to remove a
  member.
- `/jobapply <job>` opens a kora_lib input form generated from that job's questions.
- `exports.kora_bossmenu:openBossMenu()` and `exports.kora_bossmenu:openApplication(job)`
  are available to attach the flows to another resource's interaction.

The resource ensures `kora_bossmenu_jobs` (declared in `server/schema.lua`) on start for applications and activity
only. Boss-menu tables never had a balance column on new installs. Job
society balances are owned by `kora_banking`; bonuses debit that account directly.
The legacy `addBusinessMoney`,
`removeBusinessMoney`, and `getBusinessBalance` exports remain as delegates to
kora_banking for existing business resources.

The resource also `provide`s `qb-management` for legacy callers. Server-only
exports `AddMoney`, `RemoveMoney`, `AddGangMoney`, `RemoveGangMoney` (return a
boolean) and `GetAccount`, `GetGangAccount` (return a number, `0` if unknown)
delegate to kora_banking for real job/gang names and are logged to the activity
trail. Client exports `AddBossMenuItem`, `RemoveBossMenuItem`, `AddGangMenuItem`
and `RemoveGangMenuItem` add extra actions to the overview page of the boss/gang
menu (only shown to the boss who already passed the server check). An action only
runs the client-local `TriggerEvent(item.params.event, item.params.args)`; items
with `isServer`/`isCommand`, headers, or no event are ignored, so nothing gains
server authority.

The management console uses kora_lib's AppShell for its overview, applicant
answers, employee cards, shared action forms, question management, and activity
timeline. kora_bossmenu still owns all data, permission checks, and mutations. The
stash action closes AppShell before handing focus to kora_inventory.

The old `web/` source and build are retained temporarily for parity review, but
they are no longer loaded by the resource manifest.

Full documentation: see [docs/](docs/index.md).
