---
title: "Client exports"
sidebar_position: 3
---


# Client exports

Client exports to open the management window or application form from another resource, and to add extra buttons to the overview page. Authority stays on the server: the window only opens if the server agrees the player is a boss.

Namespace: `exports.kora_bossmenu` · Source: `client/main.lua`

## How it works

`openBossMenu` and `openApplication` are the same local functions the target zones use. The extra-item exports store a deep copy of your table in a client-local table. An extra item is shown only if `data.params.event` is a string, `params.isServer` and `params.isCommand` are falsy, and `data.isMenuHeader` is falsy. Pressing the button closes the window first, then runs `TriggerEvent(params.event, params.args)` on the client. Nothing is sent to the server.

## Functions

All of these run on the client only. Extra items are not persisted: they vanish when this resource restarts, so register them again when `onClientResourceStart` fires for `kora_bossmenu`.

### `exports.kora_bossmenu:openBossMenu(roleType?)`

Loads the management data from the server and opens the AppShell window. Does nothing if a menu is already opening or open. Shows an error notification `You cannot open this boss menu.` (or the server's message) if the server refuses.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `roleType?` | string | Optional. `'gang'` opens the gang menu. Anything else, including nil, means `'job'`. Note the server fallback: when `'job'` is requested but the player's active job is not a boss grade, the server answers with the player's gang data if that is a boss grade. |

**Returns**

No value.

**Example**

```lua
-- open from your own target option
exports.kora_target:addBoxZone({
    coords = vector3(120.0, -750.0, 45.0),
    size = vector3(1, 1, 1),
    options = { {
        label = 'Open Management',
        onSelect = function() exports.kora_bossmenu:openBossMenu() end,
    } },
    distance = 2.5,
})
```

**Representative console output**

```text
-- no console output; the Management window opens or a red notification explains why not
```

### `exports.kora_bossmenu:openApplication(jobName, roleType?)`

Fetches the application questions of a job or gang from the server, shows them in an input dialog, and submits the answers. Notifies `Your application was submitted.` on success.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `jobName` | string | Required. The job (or gang) name. Unknown names produce the notification `Unknown organization.` |
| `roleType?` | string | Optional. `'gang'` for a gang application, otherwise `'job'`. `types.lua` declares only `jobName`, but the function accepts this second parameter and the zones pass it. |

**Returns**

No value.

**Example**

```lua
exports.kora_bossmenu:openApplication('police')
exports.kora_bossmenu:openApplication('ballas', 'gang')
```

**Representative console output**

```text
-- player sees the Apply: <label> dialog; after submit: 'Your application was submitted.'
```

### `exports.kora_bossmenu:AddBossMenuItem(data, id?) -> string|integer`

Adds an extra button to the Overview page of the JOB boss menu (qb-management compatible).

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `data` | table | Required. `data.params.event` (string, required) is the client event triggered; `data.params.args` is passed as its argument; `data.header` is the button label (defaults to the event name). Items with `params.isServer`, `params.isCommand`, `isMenuHeader`, or without a string event are ignored. |
| `id?` | string \| integer | Optional key. Reusing a key replaces the earlier item. Default is `#items + 1`. |

**Returns**

The key under which the item was stored.

**Example**

```lua
local key = exports.kora_bossmenu:AddBossMenuItem({
    header = 'Open Evidence',
    params = { event = 'my_police:client:openEvidence', args = { room = 1 } },
}, 'evidence')
```

**Representative console output**

```text
-- key == 'evidence'
```

### `exports.kora_bossmenu:RemoveBossMenuItem(id)`

Removes a job menu item previously added with `AddBossMenuItem`.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `id` | string \| integer | Required. The key returned by `AddBossMenuItem`. |

**Returns**

No value.

**Example**

```lua
exports.kora_bossmenu:RemoveBossMenuItem('evidence')
```

**Representative console output**

```text
-- the button no longer appears the next time the menu opens
```

### `exports.kora_bossmenu:AddGangMenuItem(data, id?) -> string|integer`

Same as `AddBossMenuItem` but for the gang menu.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `data` | table | Required. Same shape as `AddBossMenuItem`. |
| `id?` | string \| integer | Optional key. |

**Returns**

The stored key.

**Example**

```lua
exports.kora_bossmenu:AddGangMenuItem({
    header = 'Stash House',
    params = { event = 'my_gang:client:stashHouse' },
})
```

**Representative console output**

```text
-- returns 1 when it is the first item with an automatic key
```

### `exports.kora_bossmenu:RemoveGangMenuItem(id)`

Removes a gang menu item.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `id` | string \| integer | Required. The key returned by `AddGangMenuItem`. |

**Returns**

No value.

**Example**

```lua
exports.kora_bossmenu:RemoveGangMenuItem(1)
```

**Representative console output**

```text
-- item removed
```

## Limits and related APIs

The extra-item keys are sorted numbers first, then strings; mixing key types is allowed. `#items + 1` is the automatic key, so removing a middle numeric item and adding another can reuse or collide with an existing key (the later one replaces the earlier). The button is shown only after the server has authorized the menu, but the event itself is a plain client-local event, so the target resource must not treat it as proof of boss rights.

## Extra overview actions - details

`AddBossMenuItem` / `AddGangMenuItem` add buttons to the Overview page of the job / gang menu; `RemoveBossMenuItem` / `RemoveGangMenuItem` remove them. These mirror the `qb-management` client exports. The data table is deep-copied.

| Field of `data` | Type | Description |
| --- | --- | --- |
| `header` | string | Button label. Falls back to `params.event`. |
| `params.event` | string | **Required.** Client event fired with `TriggerEvent(params.event, params.args)` when the button is clicked. |
| `params.args` | any | Passed to the event. |

Items are listed with integer keys first, then string keys, each sorted ascending. Items are only visible to players who passed the server boss check for that menu, and the menu is closed before the event fires. Actions only fire local client events, so they grant no server authority; validate anything sensitive in your own server code.

The export contract is also declared for LuaLS in [`types.lua`](https://github.com/KoraFiveM/kora_bossmenu/blob/dev/types.lua) (`KoraBossMenuClientExports`). See [Management menu](../management-menu.md) and [Applications](../applications.md) for what the opened windows do.

## Related guides

- [Events](./events.md)
- [Compatibility](../compatibility.md)
