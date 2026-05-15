# nbFMXDocking

`nbFMXDocking` is a Delphi FireMonkey package for building tabbed, split-pane docking interfaces in FMX applications.

It provides a generic tab/split/dock UI in the spirit of Termius, iTerm2, tmux, and VS Code pane splitting. The package owns the docking engine; consuming applications provide their own content by subclassing `TnbDockingPaneContent`.

## Features

- Multi-tab host component: `TnbDockingTabHost`
- Split-pane tree with horizontal and vertical splits
- Active pane tracking
- Tab reordering by drag and drop
- Drag a single-pane tab into another tab as a split
- Drag pane headers back into the tab bar to create a new tab
- VS Code-style drop preview overlay
- Design-time package registration under `nb FMX Docking`
- Demo FMX application for manual testing

## Projects

| Project | File | Purpose |
| --- | --- | --- |
| `nbFMXDocking` | `src/nbFMXDocking.dproj` | Design-time FMX package |
| `DockingTest` | `demo/DockingTest.dproj` | Demo application |

## Build

Use RAD Studio / Delphi with FireMonkey support.

From a RAD Studio Developer Command Prompt:

```powershell
msbuild src\nbFMXDocking.dproj /t:Build /p:Config=Debug /p:Platform=Win32
msbuild demo\DockingTest.dproj /t:Build /p:Config=Debug /p:Platform=Win32
```

The demo executable is written to:

```text
bin\demo\Win32\Debug\DockingTest.exe
```

## Quick Start

Create a host and provide content through `OnContentNeeded`:

```pascal
uses
  FMX.Layouts,
  nbDocking.Types,
  nbDocking.TabHost;

procedure TForm1.FormCreate(Sender: TObject);
var
  Host: TnbDockingTabHost;
begin
  Host := TnbDockingTabHost.Create(Self);
  Host.Parent := Self;
  Host.Align := TAlignLayout.Client;
  Host.OnContentNeeded := DoNeedContent;
end;

procedure TForm1.DoNeedContent(Sender: TObject;
  var AContent: TnbDockingPaneContent);
begin
  AContent := TMyDockingPaneContent.Create(TnbDockingTabHost(Sender));
end;
```

`TMyDockingPaneContent` should inherit from `TnbDockingPaneContent`. Content communicates with the host through events such as `RequestSplit`, `RequestClose`, and `RequestActivate`; it should not directly depend on `TnbDockingPaneHost` or `TnbDockingTabHost`.

## Source Layout

```text
src/
  nbDocking.Types.pas        Base content class and shared types
  nbDocking.PaneTree.pas     Pure pane tree model
  nbDocking.PaneHost.pas     FMX visual host for one pane tree
  nbDocking.DropOverlay.pas  Drop target preview overlay
  nbDocking.TabHost.pas      Multi-tab host and drag/drop routing
  nbDocking.Demo.pas         DEBUG-only demo pane
  Reg_nbFMXDocking.pas       IDE component registration

demo/
  DockingTest.dproj          Demo project
```

## Status

The core tab host, pane host, pane tree, split layout, and internal drag/drop flows are implemented.

Planned areas include:

- Shell layout component
- Detached floating windows
- Layout persistence
- Cross-host tab/pane moves

## Notes

The codebase currently uses Russian comments in implementation files. Keep new implementation comments consistent with the surrounding code.

