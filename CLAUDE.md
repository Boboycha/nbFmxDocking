# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`nbFMXDocking` is a Delphi **FireMonkey (FMX)** design-time package that provides a generic tab/split/dock UI (Termius/iTerm2/tmux-style). It is consumed by other apps (e.g. `nbDevOpsCockpit`) which subclass `TnbDockingPaneContent` to plug in terminals, SFTP browsers, log viewers, etc. The repo itself ships a `DockingTest` demo and a `TnbDockingDemoPane` (DEBUG-only) stub for verifying the engine without real content plugins.

Code comments are written in **Russian** — preserve language and tone when adding or modifying them.

## Build / run

Toolchain: RAD Studio (Delphi). Two projects, driven by `ProjectGroup1.groupproj`:

| Project | File | Purpose |
| --- | --- | --- |
| `nbFMXDocking` | `src/nbFMXDocking.dproj` (`.dpk`) | Design-time package (`{$DESIGNONLY}`, requires `rtl`, `fmx`, `DesignIDE`). Installs components into the IDE palette under `nb FMX Docking`. |
| `DockingTest`  | `demo/DockingTest.dproj` | FMX host app that exercises `TnbDockingTabHost`. |

Note: `ProjectGroup1.groupproj` also references `Z:\pr\TerminalTest\src\Project1.dproj` (a sibling repo, not in this tree). Don't expect it to exist locally.

Build from a Developer Command Prompt:

```powershell
msbuild src\nbFMXDocking.dproj /t:Build /p:Config=Debug /p:Platform=Win32
msbuild demo\DockingTest.dproj  /t:Build /p:Config=Debug /p:Platform=Win32
```

Output paths (relative to project file): package DCUs → `..\bin\dpk\$(Platform)\$(Config)`, demo binary → `..\bin\demo\$(Platform)\$(Config)`. Supported platforms declared in the dproj: Win32, Win64, Linux64, OSX64/ARM64, iOS, Android64.

There are no automated tests — verification is manual via the `DockingTest` demo.

## Architecture

The package is layered. The lower layers know nothing about the upper layers, and `TnbDockingPaneContent` (the unit consumers subclass) knows nothing about its host.

```
nbDocking.TabHost      ── multi-tab shell wrapping N × PaneHost (+ tab and header drag-drop)
nbDocking.PaneHost     ── FMX rendering of a single tree (TLayout/TSplitter/TPaneLeafFrame)
nbDocking.DropOverlay  ── VS Code-style preview of where the dropped pane will land
nbDocking.PaneTree     ── pure data model: n-ary tree of TPaneSplit / TPaneLeaf
nbDocking.Types        ── TnbDockingPaneContent (base for plugin content) + enums + event types
nbDocking.Demo         ── TnbDockingDemoPane stub (DEBUG only, registered via {$IFDEF})
Reg_nbFMXDocking       ── IDE component registration
```

### Three non-obvious invariants

1. **Content ownership lives in the visual layer, not the tree.** `TPaneTree` holds *references* only — `TPaneLeaf.Destroy` explicitly does NOT free its `Content`. The owning `TComponent` of each `TnbDockingPaneContent` is the `TnbDockingPaneHost`, so FMX cascade-destruction handles cleanup. Before `TnbDockingPaneHost.RebuildVisualTree` tears down old wrappers, `DetachAllContents` walks the tree and sets `Parent := nil` on every live content to prevent FMX from cascading them. **Only `TnbDockingPaneHost.CloseActive` (destructive) and `TakeActiveContent`/`TakeLeafContent` (non-destructive snip-out, used by drag-drop) remove a leaf from the tree.** Only the first frees the content.

2. **Content → host communication is event-only.** `TnbDockingPaneContent` emits `RequestSplit / RequestClose / RequestActivate / HeaderChanged`; `PaneHost` subscribes during `WireContent`. Content never references its host. This is what lets the package live without knowledge of terminals/SFTP/etc.

3. **Destruction of a clicked-on object is always deferred to the next message-loop tick.** Both `TnbDockingPaneHost.CloseActive` (wraps `Content.Free` in `TThread.Queue`) and `TnbDockingTabHost` (enqueues onto `FPendingCloseTabs`, drained by a 1 ms `TTimer`) follow the same rule: the close request typically originates from a click handler *inside* the doomed object (the ✕ button on a header, the ✕ on a tab, etc.). Synchronous Free yanks the button out from under the FMX framework as it walks back up the call stack — AV. Any new code path that frees panes/tabs in response to a click must defer the same way.

### Tree algorithms (in `nbDocking.PaneTree`)

- **Split**: if the leaf's parent split already has the requested orientation, insert the new leaf as a sibling there. Otherwise wrap the leaf in a new split node. Keeps the tree minimally nested.
- **Close**: remove leaf; if its parent split is left with one child, *collapse* the split into that survivor — cascading upward. Closing the last leaf empties the tree (`Root := nil`).
- **Sizes** are normalized fractions summing to 1.0, clamped to `[0.05, 0.95]`. `InsertChild` scales existing siblings down by `1 - newSize`; `RemoveChild` redistributes the released fraction proportionally.

### Drag-and-drop

Two independent drag sources, both feeding the same `TDockingDropOverlay`:

- **Tab-button drag** (`TTabButton` inside `TabHost`). Inside `TabBar` → reorder. Dragged below `TAB_BAR_HEIGHT` → mode flips to `dsDraggingToPane`, overlay appears over the target `PaneHost`. Only single-leaf tabs (`TDockingTab.IsSingle`, signalled by a `▦` group glyph when **not** single) are eligible drop *sources* into a split; multi-leaf tabs are reorder-only.
- **Pane-header drag** (`TPaneLeafFrame` inside any `PaneHost`). The title bar emits `OnHeaderDrag(phdStart/Move/End)` from its `PaneHost`; `TabHost.HandlePaneHostHeaderDrag` routes it. Drop over `TabBar` → `AddTabWithContent` creates a new tab from the snipped content. Drop over a pane → ordinary split in the hit direction.

Both flows extract the source via `TakeLeafContent`/`TakeActiveContent`, which is `CloseActive` minus the `Free` — the snipped `TnbDockingPaneContent` survives so the caller can re-parent it.

`TDockingDropOverlay` shows one half-pane preview (VS Code style), not four bands. Hit-test still has four edge "corridors" excluding the centre and the four corners; outside any corridor → `HasZone = False` and the preview hides.

### Header visibility (Termius rule)

`RebuildVisualTree` toggles every `TPaneLeafFrame.Header` based on `Tree.LeafCount`: hidden when 1, visible when ≥ 2. With a single pane the tab caption already names it, so the title bar is redundant. The moment a split appears, every leaf in the tab grows a title bar.

`TPaneLeafFrame.ActionsLayout` is the right-side slot in the header for action buttons (only `✕` currently); it's visible only on the active leaf. New header buttons (reload, maximize, …) belong here.

### Three timing/FMX quirks worth knowing

- `TSplitter` in FMX has no `OnMoved` event, so `TnbDockingPaneHost` recomputes proportions on `OnMouseUp` (the splitter captures the mouse during drag).
- `BuildSplit` wraps its child-creation loop in `BeginUpdate/EndUpdate`. Without it, intermediate `AlignObjects` passes sort already-placed splitters by `Position.Top/Left`, and each new child (with `Position = 0`) gets inserted *before* them — splitters end up at the bottom and the order falls apart. One final realign inside `EndUpdate` keeps insertion order correct.
- Tab-button `OnMouseDown` does **not** activate the tab. Activating eagerly would mark a non-active tab as the drag source the moment the user grabs it, breaking drop-into-self detection. Activation is deferred to `OnMouseUp` in the `dsArmed` branch (i.e. only if no drag occurred).

### Iteration plan (from the .dpk comment block)

Done (iterations 1-2): Types / PaneTree / PaneHost / Demo / TabHost (+ tab- and header-drag-drop, drop overlay). Pending: `nbDocking.Shell` (sidebar | main | bottom layout), `nbDocking.FloatWindow` (detached panes), `nbDocking.Persistence` (JSON layout save/restore).

## Extending the package

To add a real content plugin (terminal, log viewer, etc.):
1. Subclass `TnbDockingPaneContent` (in `nbDocking.Types`).
2. Override `DoActivate`/`DoDeactivate`/`CanClose` as needed; set `Caption`, `Glyph`, `HeaderBgColor`, `HeaderTextColor` so the host title bar matches your content's theme. Setters propagate to the visible header via `HeaderChanged`.
3. Call `RequestSplit`/`RequestClose`/`RequestActivate` from inside your UI — do not touch the host directly.
4. Provide instances via the consuming form's `OnContentNeeded` event on `TnbDockingPaneHost` (or `TnbDockingTabHost`, which forwards to its internal hosts).
5. Optional: park extra header buttons (reload, maximize, …) inside `TPaneLeafFrame.ActionsLayout` (`Align = Right`, visible only on the active leaf).

## Coding conventions (strict)

These rules are non-negotiable for this codebase. Violations require explicit user approval.

### Comments
- Human comments use `(* ... *)` ONLY, never `{ ... }`.
- `{$IFDEF}`, `{$DESIGNONLY}`, `{$R *.res}` etc. are **compiler directives, not comments** — leave them as-is.
- Existing Russian-language comments stay in Russian; new comments — also Russian, matching surrounding tone.

### Language features
- **No ternary operator** — Delphi doesn't have one. Use `if ... then ... else ...` or `IfThen()` from `System.StrUtils` / `System.Math`.
- Prefer `case` over chained `if-else if` when matching against enums or small integer ranges.
- Inline variables (`var x: Integer := ...;`) are allowed (Delphi 10.3+), but keep style consistent with the surrounding unit.

### Required uses
- `EnsureRange`, `Min`, `Max`, `InRange` → `System.Math`
- `TStringDynArray` → `System.Types` (always add this when using `TDirectory.GetFiles` or returning string arrays)
- `TDirectory`, `TPath`, `TFile` → `System.IOUtils`
- FMX core: `FMX.Types`, `FMX.Controls`, `FMX.Layouts`, `FMX.StdCtrls`

### Memory & ownership (project-specific — see Architecture above)
- `TPaneLeaf.Destroy` does NOT free its `Content`. Don't "fix" this — it's intentional.
- Before tearing down visual wrappers in `RebuildVisualTree`, always `Parent := nil` on live content to break FMX cascade.
- Only `TnbDockingPaneHost.CloseActive` and `Tree.CloseLeaf`-paired logic actually free content. New code that closes panes must follow the same pattern.

### Editing rules for the agent
- When unsure about ownership or FMX cascade behavior, ASK before changing memory management code.
- Never replace `(* *)` comments with `{ }`, and never the reverse.
- Preserve `{$IFDEF DEBUG}` blocks around `TnbDockingDemoPane` registration — they're load-bearing.
- Keep the layering invariant: lower layers never reference upper layers. `TnbDockingPaneContent` never imports `nbDocking.PaneHost` or `nbDocking.TabHost`.

### Output format for code changes
- Show full method bodies, not partial snippets (user has explicitly requested this style).
- Russian or Uzbek explanations are fine; English code identifiers stay English.