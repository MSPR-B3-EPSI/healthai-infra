# Documentation Checklist

Use this checklist to document what is required when changing the MSPR local infrastructure.

## Required Documents In This Folder

1. 00-url-cheat-sheet.md

- Keep host and container URLs current.
- Update ports and route paths when they change.

2. 01-getting-started.md

- Keep prerequisites and startup commands current.
- Document required .env values for image mode and dev hot reload mode.

3. 02-how-it-works.md

- Keep architecture, routing, auth boundaries, and profile composition current.
- Keep observability flow current (Promtail -> Loki -> Grafana).

4. 03-operations-guide.md

- Keep routine run, stop, logs, reset, and profile commands current.
- Keep environment variable reference current.

5. 04-troubleshooting.md

- Keep known failure cases and verification commands current.
- Include checks for gateway, auth, metrics, logs, and startup ordering.

6. README.md (this folder)

- Keep document index and reading order current.
- Link any new docs added in this folder.

## Change-To-Doc Mapping

When you change compose files:

- Update 01-getting-started.md and 03-operations-guide.md.
- Update 00-url-cheat-sheet.md if routes, ports, or profile composition changed.

When you change monitoring:

- Update 02-how-it-works.md monitoring model section.
- Update 04-troubleshooting.md with new diagnosis commands.
- Update 00-url-cheat-sheet.md for new internal observability endpoints.

When you change scripts:

- Update 01-getting-started.md and 03-operations-guide.md command examples.

When you change auth/issuer/audience behavior:

- Update 02-how-it-works.md auth boundary and runtime assumptions.
- Update 04-troubleshooting.md auth mismatch sections.

## Definition Of Done For Documentation

A change is documented only when all checks below pass:

1. Commands in docs are executable as written.
2. File paths referenced in docs exist.
3. Profile and service names match compose definitions.
4. URLs and ports match .env defaults.
5. Troubleshooting steps include at least one verification command.
