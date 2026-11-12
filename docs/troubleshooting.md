---
title: Troubleshooting
sidebar_position: 9
---

# Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| "Boss menu storage is still starting." | kora_sql was not ready within 60 seconds or `ensureTables` failed. Check the server console for `[kora_bossmenu]` errors and make sure kora_sql starts first. |
| "You are not a boss for this organization." / "You cannot open this boss menu." | The player's current grade lacks `isboss = true` in the kora_core job/gang definition. |
| Job boss gets the gang menu | Opening without `'gang'` falls back to the gang when the player is not a boss of their current job. Check the job grade's `isboss`. |
| No "Open Boss Menu" target | The option is only shown to bosses of their current job (job points) or gang (gang points). Also ensure kora_target is started before kora_bossmenu - it is not a declared dependency. |
| Employee missing from the roster | Job rosters come from kora_multijob; members whose level is not a defined grade are hidden. Gang members must have the gang stored in the `players.gang` JSON. |
| "The society does not have enough funds." | The kora_banking account named after the job/gang has too little money for the bonus. |
| "You cannot assign your rank or a higher rank." | Bosses can only assign grades below their own. |
| Changed `Config.defaultQuestions` has no effect | Defaults are copied only when an organization's row is first created. Edit questions from the Questions page instead. |
