---
title: Compatibility
sidebar_position: 8
---

# Compatibility

kora_bossmenu has no dependency on ox_lib, oxmysql, community bridges or legacy QBCore. It replaces `qb-management` for legacy callers.

## qb-management

The manifest declares `provide 'qb-management'`, so resources that list `qb-management` as a dependency are satisfied by kora_bossmenu.

| Legacy surface | Side | kora_bossmenu behaviour |
| --- | --- | --- |
| `AddMoney`, `RemoveMoney`, `AddGangMoney`, `RemoveGangMoney` | server export | Delegate to kora_banking, return a boolean, logged in the activity trail. |
| `GetAccount`, `GetGangAccount` | server export | kora_banking balance, `0` for unknown names. |
| `AddBossMenuItem`, `RemoveBossMenuItem`, `AddGangMenuItem`, `RemoveGangMenuItem` | client export | Add buttons to the Overview page. Only client-local events are supported; `isServer`, `isCommand`, header items and items without `params.event` are ignored. |
| `qb-bossmenu:client:OpenMenu`, `qb-gangmenu:client:OpenMenu` | client event | Open the job / gang menu after a server boss check. |

See [Exports](./api/server-exports.md) and [Events](./api/events.md) for details.

Differences from qb-management:

- Society money is not stored by the boss menu; kora_banking owns it. The `addBusinessMoney`, `removeBusinessMoney` and `getBusinessBalance` exports also delegate to kora_banking.
- The UI is a kora_lib AppShell app instead of qb-menu, so extra items appear as Overview buttons, not menu entries.
- There is no `/bossmenu`-style chat command.

## Legacy web UI

The `web/` folder contains an older React UI and build. It is not referenced by `fxmanifest.lua` (no `ui_page`) and is not loaded; the AppShell console replaces it.
