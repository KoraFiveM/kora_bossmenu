---
title: Events
sidebar_position: 6
---

# Events

## Client events (public)

These are the legacy qb-bossmenu / qb-gangmenu open events. They are registered as net events, so they can be triggered from the server (`TriggerClientEvent`) or locally on the client (`TriggerEvent`).

| Event | Side | Payload | Effect |
| --- | --- | --- | --- |
| `qb-bossmenu:client:OpenMenu` | client | none | Asks the server whether the player is a boss of their current job (`kora_bossmenu:server:isJobBoss`) and, if so, opens the job [management menu](./management-menu.md). |
| `qb-gangmenu:client:OpenMenu` | client | none | Same for the current gang (`kora_bossmenu:server:isGangBoss`), opening the gang menu. |

```lua
-- server side
TriggerClientEvent('qb-bossmenu:client:OpenMenu', source)
-- client side
TriggerEvent('qb-gangmenu:client:OpenMenu')
```

New code should prefer the `openBossMenu` [export](./exports.md#openbossmenu).

## Server callbacks (internal)

The resource registers no server net events. The client talks to the server through kora_lib callbacks (`Kora.callback`). They are **internal**: each management callback re-checks the caller's boss grade, and other resources should use the [exports](./exports.md) instead of calling them.

| Callback | Purpose | Guard |
| --- | --- | --- |
| `kora_bossmenu:server:isJobBoss` | Is the caller a boss of their current job | - |
| `kora_bossmenu:server:isGangBoss` | Is the caller a boss of their current gang | - |
| `kora_bossmenu:server:getJobData` | Load menu data (grades, roster, applicants, questions, logs, balance) | Boss |
| `kora_bossmenu:server:getApplication` | Load an organization's questionnaire | Rate limit 5 / 10 s |
| `kora_bossmenu:server:submitApplication` | Submit an application | Rate limit 2 / 60 s |
| `kora_bossmenu:server:acceptApplicant` | Hire an applicant | Boss |
| `kora_bossmenu:server:denyApplicant` | Deny an applicant | Boss |
| `kora_bossmenu:server:addQuestion` | Add a question | Boss |
| `kora_bossmenu:server:editQuestion` | Edit a question | Boss |
| `kora_bossmenu:server:removeQuestion` | Remove a question | Boss |
| `kora_bossmenu:server:setRank` | Change a member's grade | Boss, rank rules |
| `kora_bossmenu:server:fireEmployee` | Remove a member | Boss, rank rules |
| `kora_bossmenu:server:openStash` | Open the boss stash | Boss |
| `kora_bossmenu:server:giveBonus` | Pay a bonus | Boss, roster check, rate limit 5 / 10 s |
