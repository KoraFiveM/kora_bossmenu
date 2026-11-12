---
title: Applications
sidebar_position: 7
---

# Applications

Any player can apply to a job or gang that exists in the kora_core shared definitions (except `unemployed` and the `none` gang). Applications are stored per organization and reviewed by bosses on the [Applicants page](./management-menu.md#applicants).

## Opening the form

- The **Apply for Job** kora_target option at a configured `apply` point (see [Configuration](./api/configuration.md#menu-entry-fields)). Points under `Config.Menus.gang` open a gang application.
- The client export `exports.kora_bossmenu:openApplication(jobName)` (job applications only; see [Exports](./api/client-exports.md)).

There is no chat command for applying.

The form is a kora_lib input dialog titled `Apply: <label>` with the description "Complete every question to submit your application.". It is generated from the organization's stored questions. If the organization does not exist the player is notified "Unknown organization.".

## Question types

| Type | Shown as | Limit |
| --- | --- | --- |
| `short` | Single-line text field | 250 characters |
| `long` | Text area (4 rows) | 1000 characters |
| `number` | Number field | 250 characters |
| `yesno` | Select with `Yes` / `No` | - |

Every field is required.

## Submission rules

The server validates every submission:

- Every question must have a non-blank answer ("Every question must be answered.").
- Each answer is stored as text, cut to 1000 characters, together with the question text at the time of submission.
- A character can have only one pending application per organization ("You already applied for this job."). After the application is hired or denied, the character can apply again.
- The character must be loaded ("Character not loaded.").

Requests are rate-limited: loading the form 5 times per 10 seconds, submitting 2 times per 60 seconds per player.

On success the player is notified "Your application was submitted.". Pending applications are not logged in the activity timeline; hiring and denying are.

## Questionnaire storage

The first time an organization is used (form opened, menu opened, or money export called) a row is created in `kora_bossmenu_jobs` with a copy of `Config.defaultQuestions.job` or `Config.defaultQuestions.gang`. Bosses then manage the questionnaire from the [Questions page](./management-menu.md#questions). See [Database](./api/data.md).
