---
title: "Server exports"
sidebar_position: 2
---


# Server exports

Public server exports for business (society) money. They are thin wrappers over Kora Banking that add an input check and an activity-log entry. The same names are reachable as `exports['qb-management']` (the manifest `provide`s that name) and natively as `exports.kora_bossmenu`.

Namespace: `exports.kora_bossmenu` · Source: `server/main.lua (exports at the bottom of the file), types.lua`

## How it works

All credit/debit exports share two private functions, `credit` and `debit`, which require the resource to be ready, check that the name is a defined job (or gang), floor the amount, ensure a `kora_bossmenu_jobs` row exists, call Kora Banking, and then append a log line to that row. If Kora Banking succeeds but the log write fails, the money has still moved and the export still returns true. These exports are server-only and carry no permission check: any server resource may call them, so never wire them to an unchecked net event.

## Functions

`types.lua` declares the first three plus the qb-management names for LuaLS. Multiple return values (`boolean, string?`) are the form the source produces. Only the first value is guaranteed to reach a caller in every runtime; check the second when you need the reason.

### `exports.kora_bossmenu:addBusinessMoney(jobName, amount, reason?) -> boolean, string?`

Adds money to a JOB's society account in Kora Banking and writes a log line to the job's boss-menu activity log. Public server export. Declared in `types.lua`.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `jobName` | string | Required. A job that exists in `Kora.shared.get('jobs', jobName)` and is not `unemployed`. Gang names are not accepted by this export (use `AddGangMoney`). |
| `amount` | number | Required. Converted with `math.floor(tonumber(amount) or 0)`; must end up above 0. There is no upper limit here, but Kora Banking refuses amounts above 1,000,000,000. |
| `reason?` | string | Optional. Passed to Kora Banking as the statement reason (default `boss-menu-business-credit`). The log line shows it truncated to 100 characters. |

**Returns**

- **true** — the society account was credited and the log written.
- **false, errorString** — failure. Messages: `unknown job` (also returned while the resource is not ready), `amount must be positive`, `could not credit society` (Kora Banking has no account of that name, or its update failed), or a database message from loading the row.

**Example**

```lua
-- server script of a shop resource
local function payTax(jobName, total)
    local ok, err = exports.kora_bossmenu:addBusinessMoney(jobName, total, 'shop sale')
    if not ok then
        print(('could not credit %s: %s'):format(jobName, tostring(err)))
    end
    return ok
end

payTax('police', 250)
```

**Representative console output**

```text
-- success: no output, society +250, log: Business received $250 (shop sale).
-- failure: could not credit police: could not credit society
```

### `exports.kora_bossmenu:removeBusinessMoney(jobName, amount, reason?) -> boolean, string?`

Takes money out of a JOB's society account and logs it. Succeeds only if the account balance covers the amount. Public server export.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `jobName` | string | Required. Existing job, not `unemployed`. |
| `amount` | number | Required. Floored, must be above 0. |
| `reason?` | string | Optional. Statement reason (default `boss-menu-business-debit`); log text truncated to 100 characters. |

**Returns**

- **true** — the money was removed and the log written.
- **false, errorString** — `unknown job`, `amount must be positive`, `insufficient business funds` (no account, balance too low or update failed), or a database message.

**Example**

```lua
local ok, err = exports.kora_bossmenu:removeBusinessMoney('police', 500, 'equipment order')
if not ok then
    return Kora.notify.send(src, { title = 'Orders', message = 'The department cannot afford this.', type = 'error' })
end
```

**Representative console output**

```text
-- success: society -500, log: Business paid out $500 (equipment order).
-- failure: false, 'insufficient business funds'
```

### `exports.kora_bossmenu:getBusinessBalance(jobName) -> number?, string?`

Returns the society balance of a job by reading Kora Banking. It does not check the ready flag and writes no log.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `jobName` | string | Required. Existing job, not `unemployed`. |

**Returns**

- **number** — the account balance (0 when Kora Banking has no account of that name).
- **nil, `unknown job`** — the name is not a defined job.

**Example**

```lua
local balance, err = exports.kora_bossmenu:getBusinessBalance('police')
if not balance then return print('balance unavailable:', err) end
print(('police society holds $%d'):format(balance))
```

**Representative console output**

```text
police society holds $12500
```

### `exports.kora_bossmenu:AddMoney(jobName, amount) -> boolean`

qb-management compatible credit for a job. Calls the same internal credit routine as `addBusinessMoney` with the reason `qb-management`. Returns only the boolean.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `jobName` | string | Required. Existing job. |
| `amount` | number | Required. Floored, above 0. |

**Returns**

true when credited, false on any failure (the error string is dropped).

**Example**

```lua
if exports['qb-management']:AddMoney('police', 100) then
    print('credited')
end
```

**Representative console output**

```text
credited
```

### `exports.kora_bossmenu:RemoveMoney(jobName, amount) -> boolean`

qb-management compatible debit for a job (reason `qb-management`). Fails when the balance is too low.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `jobName` | string | Required. Existing job. |
| `amount` | number | Required. Floored, above 0. |

**Returns**

true when debited, false on any failure.

**Example**

```lua
local ok = exports['qb-management']:RemoveMoney('police', 100)
```

**Representative console output**

```text
-- ok == false when the account holds less than 100
```

### `exports.kora_bossmenu:AddGangMoney(gangName, amount) -> boolean`

Credit for a GANG. Same as `AddMoney` but the name is validated against the shared gang definitions (`none` is rejected). The Kora Banking account is looked up by the same name.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `gangName` | string | Required. Existing gang. |
| `amount` | number | Required. Floored, above 0. |

**Returns**

true when credited, false on any failure.

**Example**

```lua
exports.kora_bossmenu:AddGangMoney('ballas', 2000)
```

**Representative console output**

```text
-- society of 'ballas' +2000, log line written to the gang row
```

### `exports.kora_bossmenu:RemoveGangMoney(gangName, amount) -> boolean`

Debit for a gang account. Fails when the balance is too low.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `gangName` | string | Required. Existing gang. |
| `amount` | number | Required. Floored, above 0. |

**Returns**

true when debited, false on any failure.

**Example**

```lua
local ok = exports.kora_bossmenu:RemoveGangMoney('ballas', 500)
```

**Representative console output**

```text
-- ok == false when the gang account holds less than 500
```

### `exports.kora_bossmenu:GetAccount(jobName) -> number`

qb-management compatible balance read for a job.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `jobName` | string | Required. |

**Returns**

number — the balance, or 0 for an unknown job or missing account.

**Example**

```lua
local money = exports['qb-management']:GetAccount('police')
```

**Representative console output**

```text
-- money == 12500
```

### `exports.kora_bossmenu:GetGangAccount(gangName) -> number`

qb-management compatible balance read for a gang.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `gangName` | string | Required. |

**Returns**

number — the balance, or 0 for an unknown gang or missing account.

**Example**

```lua
local money = exports.kora_bossmenu:GetGangAccount('ballas')
```

**Representative console output**

```text
-- money == 0 when the gang has no Kora Banking account
```

## Limits and related APIs

There is no export to set a balance, transfer between accounts or create an account. Account creation belongs to Kora Banking. Names are not case-normalized.

## Legacy qb-management exports

| Export | Returns | Behaviour |
| --- | --- | --- |
| `AddMoney(jobName, amount)` | boolean | Job credit, reason `qb-management`. |
| `RemoveMoney(jobName, amount)` | boolean | Job debit, reason `qb-management`. |
| `AddGangMoney(gangName, amount)` | boolean | Gang credit, reason `qb-management`. |
| `RemoveGangMoney(gangName, amount)` | boolean | Gang debit, reason `qb-management`. |
| `GetAccount(jobName)` | number | Job balance, `0` if unknown. |
| `GetGangAccount(gangName)` | number | Gang balance, `0` if unknown. |

These return only the boolean/number (no error string). All server money exports delegate to [kora_banking](https://github.com/KoraFiveM/kora_banking): the society account is the kora_banking account whose name equals the job or gang name. Successful credits and debits are written to the organization's [activity log](../management-menu.md#activity). The contract is also declared for LuaLS in [`types.lua`](https://github.com/KoraFiveM/kora_bossmenu/blob/dev/types.lua) (`KoraBossMenuServerExports`). See [Compatibility](../compatibility.md).

## Related guides

- [Data and storage](./data.md)
- [Compatibility](../compatibility.md)
