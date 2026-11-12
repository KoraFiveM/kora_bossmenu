---
title: Exports
sidebar_position: 5
---

# Exports

The export contract is also declared for LuaLS in [`types.lua`](https://github.com/KoraFiveM/kora_bossmenu/blob/dev/types.lua) (`KoraBossMenuClientExports`, `KoraBossMenuServerExports`).

## Client exports

### openBossMenu

```lua
exports.kora_bossmenu:openBossMenu(roleType)
```

| Param | Type | Description |
| --- | --- | --- |
| `roleType` | `'gang'` or nil | `'gang'` opens the current gang's menu. Anything else opens the current job's menu, falling back to the gang when the player is not a job boss. |

Returns nothing. Opens the [management menu](./management-menu.md) after the server boss check; otherwise shows an error notification. Calls made while an open request is in progress are ignored.

```lua
-- Open the boss menu from your own interaction
exports.kora_bossmenu:openBossMenu()
-- Open the gang menu
exports.kora_bossmenu:openBossMenu('gang')
```

### openApplication

```lua
exports.kora_bossmenu:openApplication(jobName)
```

| Param | Type | Description |
| --- | --- | --- |
| `jobName` | string | Job name as defined in kora_core. |

Returns nothing. Opens the [application form](./applications.md) for that job. The function also accepts a second `roleType` argument (`'gang'`) internally, which the gang apply points use, but the declared export contract only documents `jobName`.

```lua
exports.kora_bossmenu:openApplication('police')
```

### Extra overview actions

`AddBossMenuItem` / `AddGangMenuItem` add buttons to the Overview page of the job / gang menu; `RemoveBossMenuItem` / `RemoveGangMenuItem` remove them. These mirror the `qb-management` client exports.

```lua
local id = exports.kora_bossmenu:AddBossMenuItem(data, id)
exports.kora_bossmenu:RemoveBossMenuItem(id)
local id = exports.kora_bossmenu:AddGangMenuItem(data, id)
exports.kora_bossmenu:RemoveGangMenuItem(id)
```

| Param | Type | Description |
| --- | --- | --- |
| `data` | table | Menu item in the qb-menu style shape (see below). The table is deep-copied. |
| `id` | string or integer, optional | Key for the item. When omitted, the next integer key is used. An existing key is overwritten. |

Returns the key (`string` or `integer`) for `Add*`; nothing for `Remove*`.

Used fields of `data`:

| Field | Type | Description |
| --- | --- | --- |
| `header` | string | Button label. Falls back to `params.event`. |
| `params.event` | string | **Required.** Client event fired with `TriggerEvent(params.event, params.args)` when the button is clicked. |
| `params.args` | any | Passed to the event. |

Items are ignored (not shown) when `params.event` is missing, when `params.isServer` or `params.isCommand` is set, or when `isMenuHeader` is set. Actions only fire **local client** events, so they grant no server authority; validate anything sensitive in your own server code. The menu is closed before the event fires. Items are listed with integer keys first, then string keys, each sorted ascending. Items are only visible to players who passed the server boss check for that menu.

```lua
exports.kora_bossmenu:AddBossMenuItem({
    header = 'Order supplies',
    params = { event = 'my_resource:client:orderSupplies', args = { tier = 1 } },
}, 'my_resource:supplies')
```

## Server exports

All server money exports delegate to [kora_banking](https://github.com/KoraFiveM/kora_banking): the society account is the kora_banking account whose name equals the job or gang name. They fail when the name is not a defined job (or gang, for the gang variants), when the amount rounded down is not positive, or while boss-menu storage is still starting. Successful credits and debits are written to the organization's [activity log](./management-menu.md#activity).

### addBusinessMoney

```lua
local ok, err = exports.kora_bossmenu:addBusinessMoney(jobName, amount, reason)
```

| Param | Type | Description |
| --- | --- | --- |
| `jobName` | string | Job name. |
| `amount` | number | Amount; rounded down, must be greater than 0. |
| `reason` | string, optional | Passed to kora_banking and shown (first 100 chars) in the log. Default reason sent to kora_banking: `boss-menu-business-credit`. |

Returns `true` or `false, err`. Errors: `'unknown job'`, `'amount must be positive'`, `'could not credit society'`, or a storage error.

### removeBusinessMoney

```lua
local ok, err = exports.kora_bossmenu:removeBusinessMoney(jobName, amount, reason)
```

Same parameters as `addBusinessMoney`; default reason `boss-menu-business-debit`. Returns `true` or `false, err`. Errors: `'unknown job'`, `'amount must be positive'`, `'insufficient business funds'`, or a storage error.

### getBusinessBalance

```lua
local balance, err = exports.kora_bossmenu:getBusinessBalance(jobName)
```

Returns the kora_banking account balance (`GetAccountBalance`) for a defined job, or `nil, 'unknown job'`.

```lua
if exports.kora_bossmenu:removeBusinessMoney('mechanic', 250, 'parts order') then
    print(exports.kora_bossmenu:getBusinessBalance('mechanic'))
end
```

### Legacy qb-management exports

| Export | Returns | Behaviour |
| --- | --- | --- |
| `AddMoney(jobName, amount)` | boolean | Job credit, reason `qb-management`. |
| `RemoveMoney(jobName, amount)` | boolean | Job debit, reason `qb-management`. |
| `AddGangMoney(gangName, amount)` | boolean | Gang credit, reason `qb-management`. |
| `RemoveGangMoney(gangName, amount)` | boolean | Gang debit, reason `qb-management`. |
| `GetAccount(jobName)` | number | Job balance, `0` if unknown. |
| `GetGangAccount(gangName)` | number | Gang balance, `0` if unknown. |

These return only the boolean/number (no error string). See [Compatibility](./compatibility.md).

```lua
local ok = exports.kora_bossmenu:AddMoney('police', 500)
local balance = exports.kora_bossmenu:GetAccount('police')
```
