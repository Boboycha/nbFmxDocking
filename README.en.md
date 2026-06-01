# nbFMXDocking

Languages: [Русский](README.md) | [English](README.en.md) | [O'zbekcha](README.uz.md)

`nbFMXDocking` is a Delphi FireMonkey component set for tabbed docking UI:
tabs, split panes, pane header dragging, header actions, and design-time layout
assembly directly in the IDE.

In practice, it is an FMX foundation for IDE-like, Termius-like, iTerm2-like,
VS Code panel, or tmux-style interfaces where the application provides its own
pane content: terminal, SFTP browser, log viewer, editor, monitoring view, and
so on.

## Status

Implemented and usable:

- `TnbDockingPaneHost` - one docking host with a split-pane tree.
- `TnbDockingTabHost` - tabs, each tab containing its own `PaneHost`.
- `TnbDockingPaneContent` - base content card with header, caption, border,
  inline rename, and action buttons.
- Horizontal and vertical splits.
- Design-time pane and split creation through IDE context menus.
- Header actions through Object Inspector.
- Tab reordering inside the tab bar.
- Dragging a single-pane tab into another tab's pane zone.
- Dragging a pane header into the tab bar or into a split zone.
- VS Code-style drop preview.
- Focus mode inside `TnbDockingPaneHost`.
- Demo project: `DockingTest`.

Not implemented yet:

- a separate shell component for `sidebar | main | bottom`;
- floating windows;
- JSON layout persistence.

## Important Package Note

At the moment `src\nbFMXDocking.dpk` is a design-time package:

```pascal
{$DESIGNONLY}
```

It is used to install components into the IDE and contains
`Reg_nbFMXDocking`.

For applications in the current workspace, runtime units are usually consumed
through the project's `Unit Search Path`, for example:

```text
Z:\Repos\Devops\nbFmxDocking\src
```

If the component needs to be distributed as a full runtime BPL later, the
package should be split into two packages:

- a runtime package without `DesignIDE`, `Reg_*`, and design editors;
- a design-time package that requires the runtime package.

## Components

| Component | Where to use it | Purpose |
| --- | --- | --- |
| `TnbDockingPaneContent` | as a base class or design-time pane | Content card: header, caption, border, actions, activation |
| `TnbDockingPaneHost` | form, layout, sub-layout | One docking layout without tabs |
| `TnbDockingTabHost` | main application container | Tab bar plus a set of `TnbDockingPaneHost` instances |
| `TnbDockingDemoPane` | demo/debug | Simple test pane, registered only in DEBUG |

IDE palette:

```text
nb FMX Docking
```

## IDE Installation

1. Open `ProjectGroup1.groupproj` or `src\nbFMXDocking.dproj`.
2. Build the package for Win32 or Win64, depending on your IDE.
3. Install the BPL in the IDE.

From a Developer Command Prompt:

```powershell
msbuild src\nbFMXDocking.dproj /t:Build /p:Config=Debug /p:Platform=Win64
```

Then in RAD Studio:

```text
Component -> Install Packages -> Add...
```

Select the built `.bpl` from the project output directory.

For applications, add `src` to the project's Unit Search Path.

## Quick Start: Design-Time

The simplest scenario is to build the layout directly in the form designer.

1. Place `TnbDockingPaneHost` on the form.
2. Set `Align = Client`.
3. Right-click the host -> `Add Pane Content`.
4. Select the created `TnbDockingPaneContent`.
5. Right-click the pane -> `Split Pane Right` or `Split Pane Below`.
6. Place regular FMX controls inside the required `TnbDockingPaneContent`.

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

For several panes with the same orientation, use:

```text
TnbDockingPaneHost.DesignChildrenOrientation = poHorizontal
```

or:

```text
poVertical
```

`AutoBuildDesignChildren = True` means that the host builds the docking tree
from direct design-time `TnbDockingPaneContent` children when the form is
loaded.

### Putting Controls Into A Pane

`TnbDockingPaneContent` is a regular FMX container. You can place inside it:

- `TLayout`
- `TRectangle`
- `TMemo`
- `TListBox`
- custom FMX controls
- any visual controls that work with normal FMX parent/child rules

Do not manually place `TnbDockingPaneContent` inside another
`TnbDockingPaneContent`. For splits, use the context menu:

```text
Split Pane Right
Split Pane Below
```

The designer will create the correct structure and splitters.

## Quick Start: Runtime With TabHost

Usually an application creates its own descendant of `TnbDockingPaneContent`.

Minimal content example:

```pascal
unit Demo.LogPane;

interface

uses
  System.Classes,
  FMX.Types, FMX.Controls, FMX.Layouts, FMX.Memo,
  nbDocking.Types;

type
  TLogPane = class(TnbDockingPaneContent)
  private
    FMemo: TMemo;
    procedure HandleClear(Sender: TnbDockingPaneContent;
      const AActionId: string);
  protected
    procedure DoPaneActivate; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure AppendLine(const AText: string);
  end;

implementation

constructor TLogPane.Create(AOwner: TComponent);
begin
  inherited;
  Caption := 'Log';
  HeaderBgColor := $FF1C2330;
  HeaderTextColor := $FFE6EDF3;

  AddHeaderAction('clear', 'MDL2:E74D', HandleClear, 'Clear log');
  AddDefaultCloseAction;

  FMemo := TMemo.Create(Self);
  FMemo.Parent := Self;
  FMemo.Align := TAlignLayout.Client;
  FMemo.Lines.Text := 'Ready';
end;

procedure TLogPane.AppendLine(const AText: string);
begin
  FMemo.Lines.Add(AText);
end;

procedure TLogPane.DoPaneActivate;
begin
  inherited;
  if FMemo.CanFocus then
    FMemo.SetFocus;
end;

procedure TLogPane.HandleClear(Sender: TnbDockingPaneContent;
  const AActionId: string);
begin
  FMemo.Lines.Clear;
end;

end.
```

Form with `TnbDockingTabHost`:

```pascal
unit Unit1;

interface

uses
  System.Classes,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Layouts,
  nbDocking.Types, nbDocking.TabHost,
  Demo.LogPane;

type
  TForm1 = class(TForm)
    procedure FormCreate(Sender: TObject);
  private
    FTabHost: TnbDockingTabHost;
    procedure HandleContentNeeded(Sender: TObject;
      var AContent: TnbDockingPaneContent);
  end;

implementation

procedure TForm1.FormCreate(Sender: TObject);
begin
  FTabHost := TnbDockingTabHost.Create(Self);
  FTabHost.Parent := Self;
  FTabHost.Align := TAlignLayout.Client;
  FTabHost.OnContentNeeded := HandleContentNeeded;

  FTabHost.AddTab('Logs');
end;

procedure TForm1.HandleContentNeeded(Sender: TObject;
  var AContent: TnbDockingPaneContent);
begin
  AContent := TLogPane.Create(Self);
end;

end.
```

`AddTab` calls `OnContentNeeded`. If you already have a pane instance:

```pascal
FTabHost.AddTabWithContent('Server 1', TLogPane.Create(Self));
```

## Runtime Without Tabs: PaneHost

If tabs are not needed, use `TnbDockingPaneHost` directly.

```pascal
uses
  FMX.Layouts,
  nbDocking.Types,
  nbDocking.PaneHost,
  Demo.LogPane;

procedure TForm1.FormCreate(Sender: TObject);
var
  Host: TnbDockingPaneHost;
begin
  Host := TnbDockingPaneHost.Create(Self);
  Host.Parent := Self;
  Host.Align := TAlignLayout.Client;

  Host.SetInitialContent(TLogPane.Create(Host));
  Host.SplitActive(sdRight, TLogPane.Create(Host));
  Host.SplitActive(sdBelow, TLogPane.Create(Host));
end;
```

`SplitActive` accepts these directions:

```pascal
sdLeft
sdRight
sdAbove
sdBelow
```

If the second parameter is `nil`, the host asks for a new pane through
`OnContentNeeded`.

## Header Actions

`TnbDockingPaneContent` has a collection:

```pascal
HeaderActions: TDockingPaneHeaderActions
```

Each action contains:

| Property | Purpose |
| --- | --- |
| `Id` | stable button identifier |
| `Glyph` | symbol or alias |
| `Hint` | tooltip |
| `OnExecute` | click handler |

Runtime example:

```pascal
AddHeaderAction('refresh', 'MDL2:E72C', HandleRefresh, 'Refresh');
AddHeaderAction('theme', 'theme', HandleTheme, 'Theme');
AddDefaultCloseAction;
```

Call `AddDefaultCloseAction` last if you want the close button to be the
rightmost button.

### Glyph

`Glyph` supports several aliases:

| Value | Result |
| --- | --- |
| `add`, `plus`, `+` | plus |
| `close`, `x` | close |
| `broadcast`, `B` | broadcast |
| `sftp`, `folder`, `S` | folder |
| `theme`, `T` | theme |
| `MDL2:E712` | exact Segoe MDL2 Assets glyph |

In Object Inspector, `Glyph` has an editor with a `...` button. It allows you
to search and select MDL2 symbols visually.

If `Glyph` is not recognized as an alias or MDL2 code, it is rendered as
regular text.

## Important Properties

### TnbDockingPaneContent

| Property | Purpose |
| --- | --- |
| `Caption` | pane title |
| `HeaderVisible` | show or hide the header |
| `HeaderDragEnabled` | allow pane header dragging |
| `AlwaysShowActive` | keep active border even without focus |
| `HeaderBgColor` | card/header theme background |
| `HeaderTextColor` | text and glyph color |
| `HeaderActions` | header button collection |

Events:

| Event | When it fires |
| --- | --- |
| `OnCloseRequest` | the pane requests closing |
| `OnActivateRequest` | the pane requests activation |
| `OnRenamed` | the user renamed the pane |
| `OnHeaderChanged` | caption/colors/actions changed |

### TnbDockingPaneHost

| Property | Purpose |
| --- | --- |
| `BackgroundColor` | host background |
| `AutoMatchBg` | adapts the host background to the active pane |
| `SplitterSize` | splitter size |
| `SplitterColor` | splitter color |
| `AutoBuildDesignChildren` | builds tree from design-time pane children |
| `DesignChildrenOrientation` | orientation of design-time pane children |
| `FocusMode` | temporarily shows active pane large plus a list on the left |

Events:

| Event | Purpose |
| --- | --- |
| `OnContentNeeded` | host asks for a new pane |
| `OnActiveLeafChanged` | active leaf changed |
| `OnContentHeaderChanged` | content changed its header |
| `OnHeaderDrag` | pane header is being dragged |

### TnbDockingTabHost

| Property | Purpose |
| --- | --- |
| `TabBarColor` | tab bar background |
| `TabActiveColor` | active tab color |
| `TabInactiveColor` | inactive tab color |
| `TabHoverColor` | hover color |
| `TabTextColor` | tab text color |
| `AccentColor` | drop/selection accent |
| `TabAddVisible` | shows the `+` button |
| `TabBarActionText` | text of the right tab-bar action button |
| `TabBarActionVisible` | shows the right tab-bar action button |
| `PaneHostAutoMatchBg` | forwarded to internal hosts |

Events:

| Event | Purpose |
| --- | --- |
| `OnContentNeeded` | new pane is needed for a new tab or split |
| `OnTabAdded` | tab was added |
| `OnTabClick` | tab was clicked |
| `OnTabClosing` | closing can be cancelled |
| `OnTabClosed` | tab was closed |
| `OnActiveTabChanged` | active tab changed |
| `OnTabBarActionClick` | right tab-bar action button was clicked |

## Drag & Drop Behavior

Two drag scenarios are supported.

### Tab

- Drag a tab inside the tab bar to reorder it.
- Drag a single-pane tab into a pane area to split it into the chosen side.
- A tab that already contains several panes cannot be dragged as a split
  source, because it already represents a group.

### Pane Header

- Drag a pane header into the tab bar to turn the pane into a new tab.
- Drag a pane header into another pane zone to move it as a split.

A drop preview is shown during dragging.

## Focus Mode

`TnbDockingPaneHost.FocusMode` does not change the layout tree. It temporarily
rebuilds the visual view:

- left side: list of all leaves;
- right side: active pane using all remaining space.

Leaving focus mode restores the original split proportions.

```pascal
Host.EnterFocusMode;
Host.ExitFocusMode;
Host.ToggleFocusMode;
```

## Lifetime And Ownership

Key idea: `TPaneTree` stores references to `TnbDockingPaneContent`, but it is
not their owner.

Practical rules:

- Do not free a pane manually after it has been passed to a host.
- To close a pane, use `CloseActive`, close action, or `RequestClose`.
- To move content between hosts, use `TakeActiveContent` / `TakeLeafContent`.
  The content is removed from the tree but is not destroyed.
- Do not import `nbDocking.PaneHost` or `nbDocking.TabHost` into the unit of
  your base content class. Content communicates outward through events.
- If closing is triggered from a click handler inside the pane being closed,
  freeing must be deferred to the next tick. The component already does this.

## Build

Requires RAD Studio / Delphi with FireMonkey.

Verified on Delphi 13.x.

```powershell
msbuild src\nbFMXDocking.dproj /t:Build /p:Config=Debug /p:Platform=Win64
msbuild demo\DockingTest.dproj /t:Build /p:Config=Debug /p:Platform=Win64
```

For Win32:

```powershell
msbuild src\nbFMXDocking.dproj /t:Build /p:Config=Debug /p:Platform=Win32
msbuild demo\DockingTest.dproj /t:Build /p:Config=Debug /p:Platform=Win32
```

Demo executable:

```text
bin\demo\<Platform>\<Config>\DockingTest.exe
```

## Source Layout

```text
src/
  nbDocking.Types.pas          base content class, actions, shared enums
  nbDocking.PaneTree.pas       pure docking tree model
  nbDocking.PaneHost.pas       visual host for one tree
  nbDocking.DropOverlay.pas    drop preview
  nbDocking.TabHost.pas        tab shell and drag/drop routing
  nbDocking.DesignEditors.pas  IDE context menu and glyph editor
  nbDocking.Demo.pas           DEBUG-only demo pane
  Reg_nbFMXDocking.pas         IDE registration
  nbFMXDocking.dpk             design-time package

demo/
  DockingTest.dproj
  Unit1.pas
  Unit1.fmx
```

## Roadmap

Planned next layers:

1. `nbDocking.Shell` - multi-zone layout: sidebar, main, bottom.
2. `nbDocking.FloatWindow` - undock a pane into a separate form.
3. `nbDocking.Persistence` - save and restore layouts.

## Project Documentation

- [Development Report](docs/DEVELOPMENT_REPORT.md)
- [Developer Guide](docs/DEVELOPER_GUIDE.md)

