# kora_bossmenu agent guide

kora_bossmenu is the Kora job/gang management console (applications, roster, ranks, bonuses, boss stash, activity log) built on kora_lib AppShell, with society money delegated to kora_banking and a `qb-management` compatibility surface. Layout: `fxmanifest.lua`, `shared.lua` (Config), `types.lua` (LuaLS export contract), `server/schema.lua` + `server/main.lua` (storage, permission checks, callbacks, exports), `client/main.lua` (AppShell app, application form, target points, client exports), `test/` and `tests/*.feature` (contracts and QA scenarios), `web/` (legacy UI, not loaded).

## Documentation

User-facing documentation lives in `docs/` (Markdown, published via the Kora Docusaurus site, kora_docs_next). Read `docs/index.md` first (hub with a documentation map). Layout: `index.md` (overview and map), `installation.md`, `how-to-use.md`, `commands.md` (no commands exist), `management-menu.md`, `applications.md`, `compatibility.md`, `troubleshooting.md`, and `api/` (`server-exports.md`, `client-exports.md`, `events.md` incl. internal callbacks, `configuration.md` for `shared.lua`, `data.md` for `kora_bossmenu_jobs`). Update the page that matches the change.

When you add, change, or remove a feature, config option, command, export, event, item, permission, or database table/column, update the matching page in `docs/` in the same change. Keep docs accurate to the code; do not document behaviour that does not exist.

Docs rules: plain Markdown with `title`/`sidebar_position` front matter (no `id`/`slug`), relative links only between docs pages, assets inside `docs/`, fenced code blocks with a language, and no raw `<`, `>`, `{`, `}` outside code (pages are parsed as MDX). The release version comes from `fxmanifest.lua`'s `version` field.

## Shared contribution standards

Read [CONTRIBUTING.md](CONTRIBUTING.md) before editing. Humans and agents follow
the same Kora standards and self-contained local Lua checks. Preserve the domain
constraints above and in module guides; record policy conflicts explicitly.
