# AGENTS.md

Handover doc for agentic coding tools (Codex, Cursor, Aider, etc.).

The full architecture guide and coding conventions live in
[CLAUDE.md](CLAUDE.md) — read that first. This file captures the
*current state* of the work and what comes next, so a fresh agent
can pick up where the previous one stopped.

## Where we are

Completed and verified manually via the `DockingTest` demo:

- `nbDocking.Types` — `TDockingPaneContent` base + events + enums.
- `nbDocking.PaneTree` — pure n-ary data model (split/close/sizes).
- `nbDocking.PaneHost` — visual rendering, leaf frames with header,
  drag of pane header, deferred destruction of clicked-on content.
- `nbDocking.DropOverlay` — VS Code-style half-pane preview.
- `nbDocking.TabHost` — tab shell with:
  - tab- and pane-header drag-drop into split zones and into the tab bar;
  - hover effect on tabs, ✕ button, and `+` button;
  - inline rename (double-click) with single/group caption policy
    centralised in `SyncTabCaptions`;
  - manual child layout inside `TTabButton` (no FMX `Align`),
    `Ceil`-ed widths, fallback text-width estimate.
- `nbDocking.Demo` — `TDockingDemoPane` stub (DEBUG-only).
- `Reg_nbFMXDocking` — IDE component registration.

The recent commits have stripped restate-the-code comments from every
unit. What remains documents non-obvious *why* — FMX quirks, ownership
invariants, deferred Free, etc. Do not re-add tutorial comments.

## Latest Codex Handoff (Commit 52b865d)

Last pushed commit:

```text
52b865d Add pane header actions and focus mode
```

Use it as the current baseline when checking what Cloud or another agent
changed after Codex:

```powershell
git fetch
git diff 52b865deecb4c6ebf31597c53253e9bf2c0c609b..origin/main
```

What changed in that commit:

- `TDockingPaneContent` now owns header actions:
  `AddHeaderAction`, `RemoveHeaderAction`, `ClearHeaderActions`,
  `FindHeaderAction`, and `ExecuteHeaderAction`.
- `TPaneLeafFrame` renders content-provided header actions in the pane
  title bar. The layout is manual, not FMX `Align`, so button order stays
  stable after caption/action changes.
- Built-in pane header buttons now include custom content actions,
  focus toggle (`F`), and close (`x`).
- `TDockingPaneHost.FocusMode` was added. It does not mutate
  `TPaneTree`; it only rebuilds the visual tree as a left sidebar with
  all leaves plus the active leaf full-size on the right.
- Clicking an item in the focus sidebar activates that leaf and rebuilds
  the focus view. Toggling focus mode off restores the original split
  layout because the underlying tree was untouched.
- `DockingTest` demo content adds two sample header actions: `+`
  appends `*` to the content caption, and `D` removes that demo action
  via `RemoveHeaderAction`.

Manual verification done:

- `demo\DockingTest.dproj` builds successfully for Debug/Win32.
- In `DockingTest`, custom header actions work.
- Button order stays stable before and after action/caption changes.
- Focus mode works: split layout -> focused active pane with sidebar ->
  selecting another sidebar item -> returning to original split layout.

Known implementation notes:

- Focus mode currently lives inside one `TDockingPaneHost`; it is not yet
  a shell-level workspace focus across multiple tab hosts/zones.
- The focus sidebar subtitle is placeholder text (`content`). Real apps
  should provide richer metadata later, probably via content properties or
  an event.
- The focus button glyph is plain text `F`; replace with an icon later
  when the project has a real icon/style layer.

## Next iterations (in priority order)

1. **`nbDocking.Shell`** — three-zone layout (sidebar | main | bottom),
   each zone hosting its own `TDockingTabHost`. Two `TSplitter`s between
   zones; sidebar should be collapsible. Hook the existing per-host
   `OnContentNeeded` upward to a single shell-level factory.

2. **`nbDocking.FloatWindow`** — detached panes. Hook into
   `TDockingTabHost.PaneHeader_End`: if the drop point falls outside the
   host's screen bounds, take the leaf content via `TakeLeafContent` and
   spawn a new `TForm` with one `TDockingTabHost` showing that content.
   Mirror the same logic for `TabButton_DropOnPane` (tab drag-out).

3. **`nbDocking.Persistence`** — JSON save/restore of layout.
   - Tree shape (split orientations + child sizes + leaves), tab list,
     active tab/leaf, optional float-window positions.
   - Content identity must round-trip via an opaque string payload
     supplied by the consumer (host stays content-agnostic).
   - Recommend `System.JSON` with a visitor over `TPaneTree`.

## Open questions / known minor issues

- **Single → split caption loss.** When the user renames a single-leaf
  tab, the new name is stored on `Content.Caption` and `Tab.Caption` is
  re-read from it. After a split, `IsSingle = False` and
  `SyncTabCaptions` overwrites the tab caption to `"Group N"` because
  `Tab.CustomGroupCaption = False`. Decide whether rename should carry
  over to the group; if yes, set `CustomGroupCaption := True` on the
  single-tab rename path too.

- **`TTabButton.DesiredWidth` allocates** a `TTextLayout` on every call.
  Called per-tab on every TabBar resize. Worth caching on the button
  and invalidating on Caption/Dirty/IsSingle change.

- **Hover during drag.** A tab button being reordered still receives
  `OnMouseEnter`/`OnMouseLeave` from neighbours, causing fill-color
  flicker under `Opacity = 0.6`. Cosmetic. Gate the hover handler on
  `FDragState = dsIdle`.

- **Tab auto-numbering.** `HandleAddButtonClick` uses
  `'New tab ' + (FTabs.Count + 1).ToString` — if the user closes a
  middle tab, the next add will re-use a number. If unique numbering
  matters, replace with a monotonic counter field.

## Load-bearing invariants (repeated from CLAUDE.md)

These caused real bugs before; do not "fix" them.

1. **`TPaneLeaf.Destroy` does NOT free its `Content`.** Owner of every
   content is the `TDockingPaneHost` (`TComponent.Owner`), so FMX
   cascade handles cleanup. The tree only holds references.
2. **`RebuildVisualTree` calls `DetachAllContents` first** — setting
   `Parent := nil` on every live content so FMX doesn't cascade them.
3. **Destruction of a clicked-on object is deferred to the next
   message-loop tick** — `TThread.Queue` for content (in
   `CloseActive`), `FDeferTimer` for tabs (in `ScheduleDeferredCloseTab`).
   Synchronous Free inside an FMX click handler is AV.
4. **`FActiveLeaf := nil` before `FTree.CloseLeaf(ToClose)`** in both
   `CloseActive` and `TakeActiveContent`. Otherwise `RebuildVisualTree`
   → `InternalSetActive` reads through a dangling pointer.
5. **`TPaneLeafFrame` field order in constructor**: `FActionsLayout`
   (Align=Right) is created **before** `FTitleLabel` (Align=Client).
   Reversed order makes Client steal Right's space.
6. **`BuildSplit` wraps its loop in `BeginUpdate/EndUpdate`.** Without
   it, intermediate `AlignObjects` passes sort already-placed splitters
   by `Position`, and new children (Position=0) get inserted in front.
7. **`TTabButton` is added to `FTabBar` with a temp `Align := Right`**
   immediately reverted to `Left` — works around an FMX quirk where
   `Parent :=` with `Align = Left` doesn't append to `Children`.
8. **Content → host communication is event-only.** Content never holds
   a reference to its host. Do not import `nbDocking.PaneHost` or
   `nbDocking.TabHost` from `nbDocking.Types`.

## Style (strict)

- Russian comments, `(* ... *)` only. Never `{ ... }` for human comments
  (only for compiler directives).
- Default to no comment. Only write one when the *why* is non-obvious.
  Do not restate what the next line of code does.
- No ternary; use `if/then/else` or `IfThen` from `System.Math` /
  `System.StrUtils`.
- `Min`/`Max`/`Ceil`/`EnsureRange` → `System.Math`.
- `Ceil` widths/heights where subpixel layout matters.
- Preserve `{$IFDEF DEBUG}` blocks around `TDockingDemoPane`
  registration — they're load-bearing.

## Build / run

```powershell
msbuild src\nbFMXDocking.dproj /t:Build /p:Config=Debug /p:Platform=Win32
msbuild demo\DockingTest.dproj  /t:Build /p:Config=Debug /p:Platform=Win32
```

No automated tests. Verify changes manually by running `DockingTest`
and exercising: add tabs, split panes, drag tabs/headers, rename,
close to empty, etc.
