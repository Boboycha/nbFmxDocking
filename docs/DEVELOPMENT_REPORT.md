# Development Report: nbFMXDocking

Date: 2026-06-01

## Summary

`nbFMXDocking` provides the docking foundation for the DevOps FMX workspace. It supplies tab hosts, pane hosts, split tree nodes, pane content containers, header actions, and focus/restore behavior.

## Completed

- `TnbDockingTabHost` with closeable and reorderable tabs.
- `TnbDockingPaneHost` with split tree layout.
- `TnbDockingPaneContent` with header, caption, action buttons, activation, and theming hooks.
- Drag/drop support for tabs and panes.
- Focus mode inside pane hosts.
- Design-time component registration.
- Docking tree restore API used by `nbFleet` workspace persistence.

## Current Consumers

- `nbFleet` uses docking for terminals, SFTP, server manager, key manager, script manager, settings, and remote file editor panes.

## Known Risks

- Icon rendering currently leans on text glyphs and Windows-centric fonts in consumers.
- Design-time and runtime packaging should remain simple until distribution requirements are clear.
- More examples are needed for layout persistence and custom pane content.

## Validation

- Repository is clean and synced with `origin/main` before this documentation pass.
- The latest known consumer, `nbFleet`, builds on Windows x64 with the current docking API.

## Recommended Next Steps

1. Add a small persistence demo project.
2. Document pane tree traversal with a complete example.
3. Review icon strategy for Linux/macOS consumers.
4. Keep API changes backward compatible for `nbFleet`.
