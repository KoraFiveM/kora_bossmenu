---
title: "Configuration"
sidebar_position: 5
---


# Configuration

All options live in the global `Config` table in `shared.lua`, loaded in both client and server (the last line passes it through `Kora.config.adopt(Config)` when that exists, which is Kora Lib's consumer-local config bridge; this resource does not document how overrides are supplied).

Namespace: `Config` · Source: `shared.lua`

## Config options (shared.lua)

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| Config.stash.slots | integer | 80 | Slot count passed to `RegisterStash` for the boss stash. |
| Config.stash.maxWeight | integer | 400000 | Maximum weight passed to `RegisterStash` (units defined by Kora Inventory). |
| Config.maxQuestions | integer | 20 | Maximum number of application questions per organization. `addQuestion` refuses more with `Invalid question.` |
| Config.maxLogs | integer | 100 | Activity entries kept per organization. Older entries are dropped when a new one is added. |
| Config.Menus.job | list of entries | one entry for `police` | Job points. See entry fields below. |
| Config.Menus.gang | list of entries | one entry for `ballas` | Gang points, same entry shape. |
| Config.defaultQuestions.job | list of `{ question, type }` | 3 questions | Questions inserted when a job row is created (first access). |
| Config.defaultQuestions.gang | list of `{ question, type }` | 4 questions | Questions inserted when a gang row is created. |

## How it works

The server reads `Config.stash`, `Config.maxQuestions`, `Config.maxLogs` and `Config.defaultQuestions`. The client reads `Config.Menus`. Changes require restarting the resource.

## Menu entry fields

Each entry of `Config.Menus.job` and `Config.Menus.gang` is a table with these fields. Targets are created by `initLocations` on the client with `exports.kora_target:addBoxZone` (size 1.0 x 1.0 x 2.6, interaction distance 2.5). A `?` after a name means the option is optional.

| Option | Type | Description |
| --- | --- | --- |
| `job` | string | Organization name. Used only for the `apply` points (passed to `openApplication`). The `bossmenu` points ignore it: they open the menu for the player's own active job or gang. |
| `bossmenu?` | vector3[] | Coordinates of `Open Boss Menu` points. The option is visible only if the local player's grade has `isboss`. |
| `apply?` | vector3[] | Coordinates of `Apply for Job` points. Visible to everyone (no `canInteract`). |

## Question types

Valid `type` values, enforced on the server for `addQuestion` and `editQuestion`: `short`, `long`, `number`, `yesno`. The default questions use `short` and `long`. `defaultQuestions` entries are not validated when inserted, so keep them to these types.

## Not configurable

Rate limits, the 250-character question cap, the 1000-character answer cap, the 100-character reason cap in logs, and the `ready` timeout of 60 seconds are constants in the source.

## Limits and related APIs

Adding a job to `Config.Menus` only adds map points. It does not create a job, a boss grade or a bank account.

## Menu locations and behaviour

Config points are standing-player positions (about 1 m above the floor); the target box is 2.6 m tall so it reaches the floor beneath the point. Boss permission itself is not configured here: it comes from the `isboss = true` flag on the player's current grade in the kora_core job or gang definition.

- The **Open Boss Menu** option is only shown when the player's current job (for `Config.Menus.job`) or gang (for `Config.Menus.gang`) grade has `isboss = true`. It opens the menu for the player's own current job or gang, so any job boss can use any job boss point.
- The **Apply for Job** option is shown to everyone and applies to the entry's `job` (as a gang application for entries in `Config.Menus.gang`).
- Rules for the stored questionnaire: `Config.defaultQuestions` is only copied when a row is created in `kora_bossmenu_jobs`. After that the questionnaire is edited from the Questions page of the [Management menu](../management-menu.md#questions); changing the defaults does not update existing organizations. See [Applications](../applications.md#question-types) for how each type is rendered.

## Default values (shared.lua)

```lua title="shared.lua"
Config = {
    stash = { slots = 80, maxWeight = 400000 },
    maxQuestions = 20,
    maxLogs = 100,
}

Config.Menus = {
    job = {
        {
            job = 'police',
            bossmenu = { vector3(447.96, -973.39, 30.69) },
            apply = {
                vector3(438.84, -981.15, 30.69),
                vector3(441.82, -981.13, 30.69)
            }
        }
    },
    gang = {
        {
            job = 'ballas',
            bossmenu = { vector3(322.25, -1005.72, 29.30) },
            apply = { vector3(318.96, -1005.61, 29.30) }
        }
    }
}

Config.defaultQuestions = {
    job = {
        { question = 'Why do you want to work here?', type = 'short' },
        { question = 'What relevant experience do you have?', type = 'long' },
        { question = 'How do you work in a team environment?', type = 'long' },
    },
    gang = {
        { question = 'Why do you want to join this gang?', type = 'short' },
        { question = 'What relevant experience do you have?', type = 'long' },
        { question = 'How do you work in a team environment?', type = 'long' },
        { question = 'What is your arrest record like?', type = 'long' }
    }
}
```

## Related guides

- [Data and storage](./data.md)
- [Applications](../applications.md)
