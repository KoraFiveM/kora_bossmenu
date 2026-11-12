---
title: "Events"
sidebar_position: 4
---


# Events

Kora Bossmenu registers two client network events for legacy compatibility. It registers no server events and triggers none of its own.

Namespace: `qb-bossmenu:* · qb-gangmenu:*` · Source: `client/main.lua`

## How it works

Both events call `Kora.callback.trigger('kora_bossmenu:server:isJobBoss')` or `...:isGangBoss` first and open the menu only if the answer is true. Because they are registered with `RegisterNetEvent`, the server (or any resource on the client) can trigger them.

## Functions

Trigger them from the client with `TriggerEvent`, or from the server with `TriggerClientEvent`. They take no arguments.

### `RegisterNetEvent('qb-bossmenu:client:OpenMenu', function() end)`

Opens the JOB boss menu if the server says the player is a job boss.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `(none)` | - | No arguments. |

**Returns**

No value. Nothing happens when the player is not a job boss (no notification).

**Example**

```lua
-- server side, for example from a legacy resource
TriggerClientEvent('qb-bossmenu:client:OpenMenu', src)

-- client side
TriggerEvent('qb-bossmenu:client:OpenMenu')
```

**Representative console output**

```text
-- the Management window opens for a job boss; silent otherwise
```

### `RegisterNetEvent('qb-gangmenu:client:OpenMenu', function() end)`

Opens the GANG boss menu if the server says the player is a gang boss.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `(none)` | - | No arguments. |

**Returns**

No value. Silent when not a gang boss.

**Example**

```lua
TriggerClientEvent('qb-gangmenu:client:OpenMenu', src)
```

**Representative console output**

```text
-- the gang Management window opens for a gang boss; silent otherwise
```

## Server callbacks (internal)

The resource registers no server net events. The client talks to the server through kora_lib callbacks (`Kora.callback`). They are **internal**: each management callback re-checks the caller's boss grade, and other resources should use the [exports](./server-exports.md) instead of calling them. New code should prefer the `openBossMenu` [export](./client-exports.md).

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

## Limits and related APIs

Anyone can run `TriggerEvent` on their own client, but the server still decides in `isJobBoss`/`isGangBoss` and again in `getJobData`, so triggering the event as a non-boss opens nothing.

## Related guides

- [Management menu](../management-menu.md)
- [Compatibility](../compatibility.md)
