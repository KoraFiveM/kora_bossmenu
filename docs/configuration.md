---
title: Configuration
sidebar_position: 2
---

# Configuration

All options live in the global `Config` table in [`shared.lua`](https://github.com/KoraFiveM/kora_bossmenu/blob/dev/shared.lua), which is loaded on both client and server. At the end of the file the table is passed to `Kora.config.adopt(Config)` when kora_lib's config module is available, which registers it with kora_lib's config system (see the [kora_lib documentation](https://github.com/KoraFiveM/kora_lib) for server-local overrides).

Boss permission itself is **not** configured here: it comes from the `isboss = true` flag on the player's current grade in the kora_core job or gang definition.

## General

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `stash.slots` | number | `80` | Slot count of each boss stash. |
| `stash.maxWeight` | number | `400000` | Maximum weight of each boss stash. |
| `maxQuestions` | number | `20` | Maximum number of application questions per job/gang. Adding more is refused with "Invalid question.". |
| `maxLogs` | number | `100` | Number of activity log entries kept per job/gang; the oldest entries are dropped first. |

```lua
Config = {
    stash = { slots = 80, maxWeight = 400000 },
    maxQuestions = 20,
    maxLogs = 100,
}
```

## Menu locations - `Config.Menus`

`Config.Menus.job` and `Config.Menus.gang` are lists of location entries. For each entry the client creates kora_target box zones (1.0 x 1.0 x 2.6 m, interaction distance 2.5) at start.

| Key | Type | Description |
| --- | --- | --- |
| `job` | string | Job name (in `Config.Menus.job`) or gang name (in `Config.Menus.gang`). Used for the "Apply for Job" target. |
| `bossmenu` | list of `vector3` | Optional. Points with an **Open Boss Menu** option. |
| `apply` | list of `vector3` | Optional. Points with an **Apply for Job** option that opens the application form for `job`. |

Coordinates are standing-player positions (about 1 m above the floor); the target box is 2.6 m tall so it reaches the floor beneath the point.

Notes on behaviour:

- The **Open Boss Menu** option is only shown when the player's current job (for `Config.Menus.job`) or gang (for `Config.Menus.gang`) grade has `isboss = true`. It opens the menu for the player's **own current** job or gang - the `job` field of the entry is not checked, so any job boss can use any job boss point.
- The **Apply for Job** option is shown to everyone and applies to the entry's `job` (as a gang application for entries in `Config.Menus.gang`).

Default:

```lua
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
```

## Default questions - `Config.defaultQuestions`

| Key | Type | Description |
| --- | --- | --- |
| `job` | list of question | Questionnaire copied to a job the first time its boss-menu row is created. |
| `gang` | list of question | Questionnaire copied to a gang the first time its boss-menu row is created. |

Each question is `{ question = string, type = 'short' | 'long' | 'number' | 'yesno' }`. See [Applications](./applications.md#question-types) for how each type is rendered.

The defaults are only used when a row is created in `kora_bossmenu_jobs`. After that the stored questionnaire is edited from the [Questions page](./management-menu.md#questions); changing `Config.defaultQuestions` does not update existing organizations.

```lua
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
