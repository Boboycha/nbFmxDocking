# nbFmxDocking Agent Guidelines

## Role

This public repository owns reusable Delphi FMX docking, tab, pane-tree, split-layout and workspace presentation components.

## Boundaries

- Keep pane-tree state independent from application business models.
- Hosts provide pane content and persistence payloads; the package owns docking interactions and layout structure.
- Avoid host-specific pane kinds, captions, commands and credentials.
- Preserve public APIs used by existing consumers unless a coordinated migration is provided.
- Do not include private product or infrastructure details.

## Invariants

- A content object appears once in the pane tree.
- Closing a tab or pane removes the correct node without corrupting siblings.
- Restore produces the same split orientation, ordering and active pane.
- Focus mode is a projection and must not duplicate or reparent content.
- Drag/drop and title-bar hit testing must work on Windows and Linux.
- Teardown must not access released pane content or actions.

## Verification

Build `src/nbFMXDocking.dproj` through RAD Studio `rsvars.bat` and MSBuild. Use the demos under `demo` for tab, split, drag/drop and native title-bar checks.

Layout or lifetime changes require validation in at least one real consumer in addition to package compilation.

## Git

Active workspace development currently uses `workspace-model`. Keep public and mirror remotes synchronized only when explicitly requested. After pushing, update the parent workspace submodule pointer.
