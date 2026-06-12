# nbFMXDocking

Languages: [Русский](README.md) | [English](README.en.md) | [O'zbekcha](README.uz.md)

`nbFMXDocking` is a Delphi FireMonkey component set for docking-style
interfaces: split layouts, tabbed groups, pane dragging, header actions, and
design-time layout assembly directly in RAD Studio.

The current recommended model is simple: place one `TnbDockingPaneHost` on the
form. The host manages panes, groups, tabs, and drop previews by itself. You do
not need to place lower-level docking components on the form manually.

## Status

Implemented and usable:

- `TnbDockingPaneHost` as the primary IDE palette component.
- Design-time pane creation through the host context menu.
- Design-time split right / split below through the pane context menu.
- Runtime split layout with horizontal and vertical splitters.
- Runtime tabs inside `TnbDockingPaneHost`.
- The `+` button on the tab bar creates a new tab with a new pane.
- A tab with one pane is captioned with that pane caption.
- A tab with multiple panes is captioned as `Group`.
- Pane header drag into split zones.
- Pane header drag onto the tab bar to make a new tab.
- Dragging a single-pane tab from the tab bar back into the active group.
- Tab bar position: top, bottom, left, right.
- Tab text direction: auto, horizontal, vertical.
- Header actions through Object Inspector.
- Inline pane title rename.
- Close button shown by default.
- Focus mode inside the host.

Not implemented yet:

- floating windows;
- JSON layout save/restore;
- full design-time tab collection;
- dragging a whole multi-pane tab group back as a nested group. For now, only single-pane tabs can be dragged back.

## Components

### `TnbDockingPaneHost`

The main component. Place it on a form and usually set `Align = Client`.

Responsible for:

- the split-pane tree;
- tab bar and group tabs;
- runtime drag/drop;
- drop overlay;
- content creation through `OnContentNeeded`;
- design-time layout from child `TnbDockingPaneContent` controls.

Important properties:

| Property | Purpose |
| --- | --- |
| `VisibleTabs` | Shows or hides the tab bar. |
| `ShowAddButton` | Shows the `+` button on the tab bar. |
| `TabPosition` | `dtpTop`, `dtpBottom`, `dtpLeft`, `dtpRight`. |
| `TabTextDirection` | `ttdAuto`, `ttdHorizontal`, `ttdVertical`. |
| `DesignChildrenOrientation` | Direction of the initial design-time layout. |
| `DesignChildrenLayoutMode` | Split layout or align layout for design-time children. |
| `SplitterSize` | Splitter thickness. |
| `SplitterColor` | Splitter/cover color. |
| `AutoMatchBg` | Matches the host background to the active pane. |

Events:

| Event | Purpose |
| --- | --- |
| `OnContentNeeded` | Fired when the host needs a new pane. |
| `OnActiveLeafChanged` | Active pane changed. |
| `OnContentHeaderChanged` | A pane caption/header changed. |
| `OnHeaderDrag` | External notification for pane header drag. |

### `TnbDockingPaneContent`

The pane card. It is usually created by the design-time editor or by application code.

Responsible for:

- header;
- caption;
- inline rename;
- close button;
- action buttons;
- active pane frame;
- client area for regular FMX controls.

Important properties:

| Property | Purpose |
| --- | --- |
| `Caption` | Pane title and single-pane tab caption. |
| `HeaderVisible` | Shows the pane header. |
| `HeaderDragEnabled` | Enables header drag. At runtime the host enables drag for its panes. |
| `CanClosePane` | Allows the pane to be closed. |
| `ShowCloseButton` | Shows the close button. Default is `True`. |
| `HeaderActions` | Collection of action buttons on the right side of the header. |
| `AllowResize` | Which resize directions are allowed. |
| `MinPaneWidth`, `MinPaneHeight` | Minimum pane size. |

### `TnbDockingDemoPane`

A development test pane. It is registered on the palette only in `DEBUG`.

## IDE Palette

After installing the package, the `nb FMX Docking` palette contains the primary component:

```text
TnbDockingPaneHost
```

`TnbDockingPaneContent` is created through host and pane design-time commands,
not as the primary palette component.

## Quick Start In The Designer

1. Place `TnbDockingPaneHost` on the form.
2. Set `Align = Client`.
3. If tabs are needed, set `VisibleTabs = True`.
4. Right-click the host -> `Add Pane Content`.
5. Select the created pane.
6. Right-click the pane -> `Split Pane Right` or `Split Pane Below`.
7. Put regular FMX controls inside the desired `TnbDockingPaneContent`.

Example structure:

```text
Form1
  nbDockingPaneHost1
    nbDockingPaneContent1
      Memo1
    nbDockingPaneContent2
      Layout1
      Button1
```

At runtime, the user can:

- drag a pane header into split zones;
- drag a pane header onto the tab bar to create a new tab;
- press `+` to create a new tab;
- drag a single-pane tab back into the active group.

## Creating Panes In Code

If you need a custom pane when the user presses `+` or requests a split, handle
`OnContentNeeded`.

```pascal
procedure TForm1.DockHostContentNeeded(Sender: TObject;
  var AContent: TnbDockingPaneContent);
begin
  AContent := TnbDockingPaneContent.Create(Self);
  AContent.Caption := 'Terminal';

  // Any FMX controls can be placed inside AContent:
  // Memo1.Parent := AContent;
  // Memo1.Align := TAlignLayout.Client;
end;
```

If no handler is assigned, `TnbDockingPaneHost` creates a simple default pane.

## Header Actions

`TnbDockingPaneContent` has a `HeaderActions` collection. It can be configured
in Object Inspector or in code.

```pascal
var
  Action: TDockingPaneHeaderAction;
begin
  Action := Pane.HeaderActions.Add as TDockingPaneHeaderAction;
  Action.Id := 'refresh';
  Action.Glyph := 'refresh';
  Action.Hint := 'Refresh';
  Action.OnExecute := PaneActionExecute;
end;
```

The close button is created automatically. It is controlled by:

- `ShowCloseButton`;
- `CanClosePane`.

## Build And Install

The package project is:

```text
src\nbFMXDocking.dproj
```

Build from a Developer Command Prompt:

```powershell
msbuild src\nbFMXDocking.dproj /t:Build /p:Config=Debug /p:Platform=Win32
```

The IDE needs the Win32 design-time BPL. After building, install the `.bpl` via:

```text
Component -> Install Packages -> Add...
```

For applications, add `src` to the project `Unit Search Path`, for example:

```text
Z:\Repos\Devops\nbFmxDocking\src
```

## Important Package Note

The current package is a design-time package:

```pascal
{$DESIGNONLY}
```

It contains the registration unit and design editors. For a full runtime BPL
distribution later, split the project into two packages:

- a runtime package without `DesignIDE`, `Reg_*`, and design editors;
- a design-time package that depends on the runtime package.

## Project Files

```text
src\nbDocking.PaneHost.pas       main host, split tree, tab bar, drag/drop
src\nbDocking.Types.pas          TnbDockingPaneContent and header actions
src\nbDocking.PaneTree.pas       split-pane tree
src\nbDocking.DropOverlay.pas    drop zone preview
src\nbDocking.DesignEditors.pas  design-time context menu and property editors
src\Reg_nbFMXDocking.pas         IDE component registration
demo\DockingDesignTest.dproj     test project
```

## Current Limitations

- Host tabs are runtime-only for now; there is no full published tab collection in Object Inspector.
- Dragging back from the tab bar is supported for single-pane tabs. A tab group is not yet dragged back as one nested group.
- `TnbDockingTabHost` remains in the source tree as a legacy/compatibility unit, but the recommended path is `TnbDockingPaneHost`.
- Layout persistence should currently be implemented by application code.

## Pre-Publish Check

Minimum build check:

```powershell
msbuild src\nbFMXDocking.dproj /t:Build /p:Config=Debug /p:Platform=Win32
msbuild src\nbFMXDocking.dproj /t:Build /p:Config=Debug /p:Platform=Win64
msbuild demo\DockingDesignTest.dproj /t:Build /p:Config=Debug /p:Platform=Win64
```

Recommended runtime smoke-test:

1. Create a few panes at design time.
2. Run the application.
3. Drag a pane into a split zone.
4. Drag a pane onto the tab bar.
5. Switch between tabs.
6. Press `+`.
7. Drag a single-pane tab back into the active group.
