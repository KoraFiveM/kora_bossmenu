---
title: Management menu
sidebar_position: 3
---

# Management menu

The management console is a kora_lib AppShell app with the id `kora_bossmenu:management` (title "Management", subtitle = job or gang label). All data, permission checks and mutations are owned by the kora_bossmenu server; the client only renders the data and forwards actions.

## Opening the menu

The menu can be opened by:

- the **Open Boss Menu** kora_target option at a configured `bossmenu` point (see [Configuration](./configuration.md#menu-locations---configmenus)),
- the client export `exports.kora_bossmenu:openBossMenu(roleType)` (see [Exports](./exports.md)),
- the legacy client events `qb-bossmenu:client:OpenMenu` and `qb-gangmenu:client:OpenMenu` (see [Events](./events.md)).

There is no chat command for opening the menu.

### Who is a boss

A player is a boss when the grade of their **current** job (or gang) in the kora_core shared definitions has `isboss = true`. The `unemployed` job and the `none` gang never count. The check is done on the server for loading the menu and repeated for every action, so a player who loses the boss grade while the menu is open gets an error on the next action.

### Job or gang

- Opening with `roleType = 'gang'` loads the player's current gang.
- Opening without a role type (or with `'job'`) loads the player's current job. If the player is **not** a boss of their job, the server falls back to their gang, so a gang boss who is not a job boss gets the gang menu.

If the menu cannot be loaded the player sees one of these notifications: "Boss menu storage is still starting.", "Unknown organization.", "You are not a boss for this organization.", "Character not loaded." or "You cannot open this boss menu.". Opening is ignored while a previous open request is still in progress.

## Pages

### Overview

- Stats: number of employees, pending applicants (highlighted when greater than 0) and application questions.
- **Open boss stash** - see [Boss stash](#boss-stash).
- Any extra actions registered by other resources with `AddBossMenuItem` (job menu) or `AddGangMenuItem` (gang menu). See [Exports](./exports.md#extra-overview-actions).

### Applicants

Searchable card list (6 per page). Each card shows the applicant name, citizen ID and every question with its answer.

| Action | Effect | Log entry |
| --- | --- | --- |
| **Hire** | Removes the application and gives the applicant the job/gang at grade `1`. | `<name> was hired.` |
| **Deny** (confirmation) | Removes the application. | `Application from <name> was denied.` |

Hiring a job applicant calls `kora_multijob:setEmployeeJob(citizenid, job, 1)`. Hiring a gang applicant calls `kora_core:setGang` for online players or `kora_core:setOfflineGang` for offline ones.

### Employees

Shows the current society **Business balance** (`kora_banking:GetAccountBalance(<name>)`) and a searchable card list (8 per page) of the roster. Each card shows the name, organization label and grade name, an Online/Offline badge, and:

- jobs: grade number and pay (`payment` of the grade),
- gangs: rank number only (gangs have no pay).

Roster sources:

- **Jobs** - `kora_multijob:getEmployees(job)`. Entries whose level is not a defined grade of the job are hidden.
- **Gangs** - characters in the `players` table (not soft-deleted) whose stored `gang.name` matches, sorted by name. Entries with an undefined grade are hidden.

| Action | Fields | Effect | Log entry |
| --- | --- | --- | --- |
| **Set rank** | Rank (select of all grades; job options also show pay) | Sets the member's grade. | `<name> was set to <grade name>.` |
| **Give bonus** | Bonus amount (number, minimum 1, presets 100 / 250 / 500 / 1000) | Pays a bonus from the society account. | `<name> received a $<amount> bonus.` |
| **Fire** (jobs) / **Kick** (gangs), confirmation | - | Removes the member from the job or gang. | `<name> was fired.` |

Rank rules enforced by the server:

- The new grade must exist in the job/gang definition.
- The new grade must be **lower** than the boss's own grade ("You cannot assign your rank or a higher rank.").
- Members at the boss's grade or higher cannot be re-ranked or removed ("You cannot manage an equal or higher-ranked employee.").

Rank changes and removals work for online and offline characters:

- Jobs: `kora_multijob:setEmployeeJob` / `kora_multijob:removeEmployeeJob`.
- Gangs: `kora_core:setGang` (online) or `kora_core:setOfflineGang` (offline); removal sets the gang to `none`.

#### Bonuses

1. The amount is rounded down to a whole number and must be greater than 0.
2. The target must be on the current roster ("That person is not an employee.").
3. The amount is withdrawn from the kora_banking account named after the job or gang (`RemoveMoney(<name>, amount, 'boss-menu-bonus')`). If that fails: "The society does not have enough funds."
4. The amount is added to the member's **bank** money: `kora_core:addMoney(source, 'bank', amount, 'boss-menu-bonus')` when online, `kora_core:addOfflineMoney(citizenid, 'bank', amount)` when offline.
5. If the payout fails, the society is refunded (`AddMoney(<name>, amount, 'boss-menu-bonus-refund')`) and the action is refused.

Bonus requests are rate-limited to 5 per 10 seconds per player.

### Questions

Lists the application questions with their answer type.

| Action | Fields | Effect |
| --- | --- | --- |
| **Add question** | Question (max 250 chars), Answer type | Appends a question. Refused once `Config.maxQuestions` is reached. |
| **Edit** | Question, Answer type | Replaces the question (matched by its current text). |
| **Remove** (confirmation) | - | Deletes the question (matched by its text). |

Question text must not be blank and is cut to 250 characters; the type must be `short`, `long`, `number` or `yesno`. Question changes are not written to the activity log. Removing or editing a question does not change answers already stored with pending applications. See [Applications](./applications.md).

### Activity

A timeline of the stored log entries, newest first. Entries are stored with a UTC ISO 8601 timestamp; only the last `Config.maxLogs` entries are kept. Besides the menu actions above, business credits and debits made through the [money exports](./exports.md#server-exports) are logged as `Business received $<amount> (<reason>).` and `Business paid out $<amount> (<reason>).`.

## Boss stash

**Open boss stash** closes the AppShell and opens a kora_inventory stash:

| Property | Value |
| --- | --- |
| Stash id | `kora_bossmenu:job:<job>` or `kora_bossmenu:gang:<gang>` |
| Label | `<organization label> Boss Stash` |
| Slots / max weight | `Config.stash.slots` / `Config.stash.maxWeight` |
| Owner | none (shared) |
| Groups | `{ [<job or gang name>] = 1 }` |

The stash is registered and opened (`kora_inventory:stashOpen`) on the server only after the boss check passes.

## After each action

After a successful action the client reloads the menu data from the server and shows "Management changes saved.". Failed actions show the server's error message and change nothing.
