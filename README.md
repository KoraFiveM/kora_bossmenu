# qbbossmenu

Native boss menu for the qbcore2 stack. It uses `qblib`, `qbsql`, `qbcore`,
`qbinventory`, and `qbmultijob`; it has no ox_lib, oxmysql, community bridge,
or legacy QBCore dependency.

- `/openbossmenu` opens the active job's boss menu for an `isboss` grade.
- `/jobapply <job>` opens a qblib input form generated from that job's questions.
- `exports.qbbossmenu:openBossMenu()` and `exports.qbbossmenu:openApplication(job)`
  are available to attach the flows to another resource's interaction.

The resource migrates `qbbossmenu_jobs` on start for applications and activity
only. Any obsolete boss-menu balance column is removed during startup. Job
society balances are owned by `qbbanking`; bonuses debit that account directly.
The legacy `addBusinessMoney`,
`removeBusinessMoney`, and `getBusinessBalance` exports remain as delegates to
qbbanking for existing business resources.

The management console uses qblib's AppShell for its overview, applicant
answers, employee cards, shared action forms, question management, and activity
timeline. qbbossmenu still owns all data, permission checks, and mutations. The
stash action closes AppShell before handing focus to qbinventory.

The old `web/` source and build are retained temporarily for parity review, but
they are no longer loaded by the resource manifest.
