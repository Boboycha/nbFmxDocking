# Developer Guide: nbFMXDocking

## Purpose

Use `nbFMXDocking` when an FMX application needs IDE-style docking: tabs, split panes, pane headers, action buttons, focus mode, and layout restore.

## Build

```powershell
msbuild src\nbFMXDocking.dproj /t:Build /p:Config=Debug /p:Platform=Win64
```

Use the same platform bitness as the RAD Studio IDE when installing components.

## Main Types

- `TnbDockingTabHost`: owns tabs and tab-specific pane hosts.
- `TnbDockingPaneHost`: owns one split tree.
- `TnbDockingPaneContent`: visual content container.
- `TPaneLeaf`: tree leaf containing pane content.
- `TPaneSplit`: split node containing child nodes and sizes.

## Usage Pattern

```pascal
Pane := TnbDockingPaneContent.Create(Owner);
Pane.Caption := 'Terminal';
Pane.Parent := PaneHost;
PaneHost.SetRootContent(Pane);
```

For application-specific panes, either subclass `TnbDockingPaneContent` or create a normal FMX frame and set its parent to a pane content instance.

## Header Actions

Header actions are identified by string IDs. Consumers should handle action callbacks by ID rather than relying on button indexes.

## Layout Persistence

Persist logical tree structure, not component pointers:

- leaf content kind;
- split orientation;
- child order;
- split sizes;
- active leaf path.

On restore, recreate content by kind and rebuild the split tree.

## Design-Time Notes

Registration units should stay isolated from runtime code. If the package is split later, keep `DesignIDE` dependencies in the design-time package only.

## Compatibility Rules

- Avoid breaking public method names used by `nbFleet`.
- Keep pane content ownership explicit.
- Do not free consumer-owned controls from docking internals.
- Prefer adding new APIs over changing current semantics.
