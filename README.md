# qbbossmenu

Native boss menu for the qbcore2 stack. It uses `qblib`, `qbsql`, `qbcore`,
`qbinventory`, and `qbmultijob`; it has no ox_lib, oxmysql, community bridge,
or legacy QBCore dependency.

- `/openbossmenu` opens the active job's boss menu for an `isboss` grade.
- `/jobapply <job>` opens a qblib input form generated from that job's questions.
- `exports.qbbossmenu:openBossMenu()` and `exports.qbbossmenu:openApplication(job)`
  are available to attach the flows to another resource's interaction.

The resource migrates `qbbossmenu_jobs` on start. Job balances are new,
resource-owned balances; a trusted revenue resource can credit one through
`exports.qbbossmenu:addBusinessMoney(job, amount, reason)`. Read a balance with
`exports.qbbossmenu:getBusinessBalance(job)`.
