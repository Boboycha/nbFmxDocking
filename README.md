# nbFMXDocking

РЇР·С‹РєРё: [Р СѓСЃСЃРєРёР№](README.md) | [English](README.en.md) | [O'zbekcha](README.uz.md)

`nbFMXDocking` вЂ” РЅР°Р±РѕСЂ Delphi FireMonkey-РєРѕРјРїРѕРЅРµРЅС‚РѕРІ РґР»СЏ tabbed docking UI:
РІРєР»Р°РґРєРё, split-РїР°РЅРµР»Рё, РїРµСЂРµС‚Р°СЃРєРёРІР°РЅРёРµ pane-Р·Р°РіРѕР»РѕРІРєРѕРІ, header actions Рё
design-time СЃР±РѕСЂРєР° layout'Р° РїСЂСЏРјРѕ РІ IDE.

РџСЂРѕС‰Рµ РіРѕРІРѕСЂСЏ: СЌС‚Рѕ FMX-РѕСЃРЅРѕРІР° РґР»СЏ РёРЅС‚РµСЂС„РµР№СЃРѕРІ РІ СЃС‚РёР»Рµ IDE, Termius, iTerm2,
VS Code panels РёР»Рё tmux, РіРґРµ РїСЂРёР»РѕР¶РµРЅРёРµ СЃР°РјРѕ РїРѕСЃС‚Р°РІР»СЏРµС‚ СЃРѕРґРµСЂР¶РёРјРѕРµ РїР°РЅРµР»РµР№:
С‚РµСЂРјРёРЅР°Р», SFTP-Р±СЂР°СѓР·РµСЂ, Р»РѕРі, СЂРµРґР°РєС‚РѕСЂ, РјРѕРЅРёС‚РѕСЂРёРЅРі Рё С‚Р°Рє РґР°Р»РµРµ.

## РЎС‚Р°С‚СѓСЃ

РЈР¶Рµ СЂР°Р±РѕС‚Р°РµС‚:

- `TnbDockingPaneHost` вЂ” РѕРґРёРЅ docking-host СЃ РґРµСЂРµРІРѕРј split-РїР°РЅРµР»РµР№.
- `TnbDockingTabHost` вЂ” РІРєР»Р°РґРєРё, РєР°Р¶РґР°СЏ РІРєР»Р°РґРєР° СЃРѕРґРµСЂР¶РёС‚ СЃРІРѕР№ `PaneHost`.
- `TnbDockingPaneContent` вЂ” Р±Р°Р·РѕРІР°СЏ РєР°СЂС‚РѕС‡РєР° СЃРѕРґРµСЂР¶РёРјРѕРіРѕ СЃ Р·Р°РіРѕР»РѕРІРєРѕРј,
  СЂР°РјРєРѕР№, inline rename Рё action-РєРЅРѕРїРєР°РјРё.
- Р“РѕСЂРёР·РѕРЅС‚Р°Р»СЊРЅС‹Рµ Рё РІРµСЂС‚РёРєР°Р»СЊРЅС‹Рµ split'С‹.
- Design-time СЃРѕР·РґР°РЅРёРµ pane'РѕРІ Рё split'РѕРІ С‡РµСЂРµР· РєРѕРЅС‚РµРєСЃС‚РЅРѕРµ РјРµРЅСЋ IDE.
- Header actions С‡РµСЂРµР· Object Inspector.
- РџРµСЂРµС‚Р°СЃРєРёРІР°РЅРёРµ РІРєР»Р°РґРѕРє РІРЅСѓС‚СЂРё tab bar.
- РџРµСЂРµС‚Р°СЃРєРёРІР°РЅРёРµ РѕРґРёРЅРѕС‡РЅРѕР№ РІРєР»Р°РґРєРё РІ pane-zone РґСЂСѓРіРѕР№ РІРєР»Р°РґРєРё.
- РџРµСЂРµС‚Р°СЃРєРёРІР°РЅРёРµ pane-Р·Р°РіРѕР»РѕРІРєР° РІ tab bar РёР»Рё split-zone.
- VS Code-style drop preview.
- Focus mode РІРЅСѓС‚СЂРё `TnbDockingPaneHost`.
- Demo-РїСЂРѕРµРєС‚ `DockingTest`.

РџРѕРєР° РЅРµ СЂРµР°Р»РёР·РѕРІР°РЅРѕ:

- РѕС‚РґРµР»СЊРЅС‹Р№ shell-РєРѕРјРїРѕРЅРµРЅС‚ `sidebar | main | bottom`;
- floating windows;
- JSON persistence layout'Р°.

## Р’Р°Р¶РЅС‹Р№ РќСЋР°РЅСЃ РџСЂРѕ РџР°РєРµС‚

РЎРµР№С‡Р°СЃ `src\nbFMXDocking.dpk` СЃРѕР±СЂР°РЅ РєР°Рє design-time package:

```pascal
{$DESIGNONLY}
```

РћРЅ РЅСѓР¶РµРЅ РґР»СЏ СѓСЃС‚Р°РЅРѕРІРєРё РєРѕРјРїРѕРЅРµРЅС‚РѕРІ РІ IDE Рё СЃРѕРґРµСЂР¶РёС‚ СЂРµРіРёСЃС‚СЂР°С†РёСЋ
`Reg_nbFMXDocking`.

Р”Р»СЏ РїСЂРёР»РѕР¶РµРЅРёР№ РІ С‚РµРєСѓС‰РµРј workspace runtime units РѕР±С‹С‡РЅРѕ РїРѕРґРєР»СЋС‡Р°СЋС‚СЃСЏ С‡РµСЂРµР·
`Unit Search Path`, РЅР°РїСЂРёРјРµСЂ:

```text
Z:\Repos\Devops\nbFmxDocking\src
```

Р•СЃР»Рё РїРѕРЅР°РґРѕР±РёС‚СЃСЏ СЂР°СЃРїСЂРѕСЃС‚СЂР°РЅСЏС‚СЊ РєРѕРјРїРѕРЅРµРЅС‚ РєР°Рє РїРѕР»РЅРѕС†РµРЅРЅС‹Р№ runtime BPL, РїР°РєРµС‚
РЅР°РґРѕ Р±СѓРґРµС‚ СЂР°Р·РґРµР»РёС‚СЊ РЅР° РґРІР°:

- runtime package Р±РµР· `DesignIDE`, `Reg_*`, design editors;
- design-time package, РєРѕС‚РѕСЂС‹Р№ requires runtime package.

## РљРѕРјРїРѕРЅРµРЅС‚С‹

| РљРѕРјРїРѕРЅРµРЅС‚ | Р“РґРµ РёСЃРїРѕР»СЊР·РѕРІР°С‚СЊ | Р§С‚Рѕ РґРµР»Р°РµС‚ |
| --- | --- | --- |
| `TnbDockingPaneContent` | РєР°Рє Р±Р°Р·РѕРІС‹Р№ РєР»Р°СЃСЃ РёР»Рё design-time pane | РљР°СЂС‚РѕС‡РєР° СЃРѕРґРµСЂР¶РёРјРѕРіРѕ: header, caption, СЂР°РјРєР°, actions, activation |
| `TnbDockingPaneHost` | С„РѕСЂРјР°, layout, sub-layout | РћРґРёРЅ docking layout Р±РµР· РІРєР»Р°РґРѕРє |
| `TnbDockingTabHost` | РіР»Р°РІРЅС‹Р№ РєРѕРЅС‚РµР№РЅРµСЂ РїСЂРёР»РѕР¶РµРЅРёСЏ | Tab bar + РЅР°Р±РѕСЂ `TnbDockingPaneHost` |
| `TnbDockingDemoPane` | demo/debug | РџСЂРѕСЃС‚Р°СЏ С‚РµСЃС‚РѕРІР°СЏ pane, СЂРµРіРёСЃС‚СЂРёСЂСѓРµС‚СЃСЏ С‚РѕР»СЊРєРѕ РІ DEBUG |

РџР°Р»РёС‚СЂР° IDE:

```text
nb FMX Docking
```

## РЈСЃС‚Р°РЅРѕРІРєР° Р’ IDE

1. РћС‚РєСЂРѕР№С‚Рµ `ProjectGroup1.groupproj` РёР»Рё `src\nbFMXDocking.dproj`.
2. РЎРѕР±РµСЂРёС‚Рµ package РїРѕРґ Win32 РёР»Рё Win64, РІ Р·Р°РІРёСЃРёРјРѕСЃС‚Рё РѕС‚ IDE.
3. РЈСЃС‚Р°РЅРѕРІРёС‚Рµ BPL С‡РµСЂРµР· IDE.

РР· Developer Command Prompt:

```powershell
msbuild src\nbFMXDocking.dproj /t:Build /p:Config=Debug /p:Platform=Win64
```

РџРѕС‚РѕРј РІ RAD Studio:

```text
Component -> Install Packages -> Add...
```

Р’С‹Р±РµСЂРёС‚Рµ СЃРѕР±СЂР°РЅРЅС‹Р№ `.bpl` РёР· output-РїР°РїРєРё РїСЂРѕРµРєС‚Р°.

Р”Р»СЏ РїСЂРёР»РѕР¶РµРЅРёР№ РґРѕР±Р°РІСЊС‚Рµ `src` РІ Unit Search Path РїСЂРѕРµРєС‚Р°.

## Р‘С‹СЃС‚СЂС‹Р№ РЎС‚Р°СЂС‚: Design-Time

РЎР°РјС‹Р№ РїСЂРѕСЃС‚РѕР№ СЃС†РµРЅР°СЂРёР№ вЂ” СЃРѕР±СЂР°С‚СЊ layout РїСЂСЏРјРѕ РІ РґРёР·Р°Р№РЅРµСЂРµ С„РѕСЂРјС‹.

1. РџРѕР»РѕР¶РёС‚Рµ `TnbDockingPaneHost` РЅР° С„РѕСЂРјСѓ.
2. РЈСЃС‚Р°РЅРѕРІРёС‚Рµ `Align = Client`.
3. Р©С‘Р»РєРЅРёС‚Рµ РїСЂР°РІРѕР№ РєРЅРѕРїРєРѕР№ РїРѕ host -> `Add Pane Content`.
4. Р’С‹РґРµР»РёС‚Рµ СЃРѕР·РґР°РЅРЅС‹Р№ `TnbDockingPaneContent`.
5. Р©С‘Р»РєРЅРёС‚Рµ РїСЂР°РІРѕР№ РєРЅРѕРїРєРѕР№ РїРѕ pane -> `Split Pane Right` РёР»Рё `Split Pane Below`.
6. РџРѕРјРµС‰Р°Р№С‚Рµ РѕР±С‹С‡РЅС‹Рµ FMX-РєРѕРЅС‚СЂРѕР»С‹ РІРЅСѓС‚СЂСЊ РЅСѓР¶РЅРѕРіРѕ `TnbDockingPaneContent`.

РќР°РїСЂРёРјРµСЂ:

```text
Form1
  nbDockingPaneHost1
    nbDockingPaneContent1
      Memo1
    nbDockingPaneContent2
      Layout1
      Button1
```

Р”Р»СЏ РЅРµСЃРєРѕР»СЊРєРёС… pane'РѕРІ РѕРґРёРЅР°РєРѕРІРѕР№ РѕСЂРёРµРЅС‚Р°С†РёРё РёСЃРїРѕР»СЊР·СѓР№С‚Рµ:

```text
TnbDockingPaneHost.DesignChildrenOrientation = poHorizontal
```

РёР»Рё:

```text
poVertical
```

`AutoBuildDesignChildren = True` РѕР·РЅР°С‡Р°РµС‚: host СЃР°Рј СЃРѕР±РёСЂР°РµС‚ docking-tree РёР·
РїСЂСЏРјС‹С… РґРѕС‡РµСЂРЅРёС… `TnbDockingPaneContent` РїСЂРё Р·Р°РіСЂСѓР·РєРµ С„РѕСЂРјС‹.

### РљР°Рє РљР»Р°СЃС‚СЊ РљРѕРЅС‚СЂРѕР»С‹ Р’ Pane

`TnbDockingPaneContent` вЂ” СЌС‚Рѕ РѕР±С‹С‡РЅС‹Р№ FMX-РєРѕРЅС‚РµР№РЅРµСЂ. Р’РЅСѓС‚СЂСЊ РјРѕР¶РЅРѕ РєР»Р°СЃС‚СЊ:

- `TLayout`
- `TRectangle`
- `TMemo`
- `TListBox`
- СЃРѕР±СЃС‚РІРµРЅРЅС‹Рµ FMX-РєРѕРЅС‚СЂРѕР»С‹
- Р»СЋР±С‹Рµ РІРёР·СѓР°Р»СЊРЅС‹Рµ РєРѕРјРїРѕРЅРµРЅС‚С‹, РєРѕС‚РѕСЂС‹Рµ РЅРѕСЂРјР°Р»СЊРЅРѕ Р¶РёРІСѓС‚ РІРЅСѓС‚СЂРё FMX parent

РќРµ СЃР»РµРґСѓРµС‚ РІСЂСѓС‡РЅСѓСЋ РєР»Р°СЃС‚СЊ `TnbDockingPaneContent` РІРЅСѓС‚СЂСЊ РґСЂСѓРіРѕРіРѕ
`TnbDockingPaneContent`. Р”Р»СЏ split'РѕРІ РёСЃРїРѕР»СЊР·СѓР№С‚Рµ РєРѕРЅС‚РµРєСЃС‚РЅРѕРµ РјРµРЅСЋ:

```text
Split Pane Right
Split Pane Below
```

РўР°Рє РґРёР·Р°Р№РЅРµСЂ СЃРѕР·РґР°СЃС‚ РїСЂР°РІРёР»СЊРЅСѓСЋ СЃС‚СЂСѓРєС‚СѓСЂСѓ Рё splitters.

## Р‘С‹СЃС‚СЂС‹Р№ РЎС‚Р°СЂС‚: Runtime РЎ TabHost

РћР±С‹С‡РЅРѕ РїСЂРёР»РѕР¶РµРЅРёРµ СЃРѕР·РґР°С‘С‚ СЃРѕР±СЃС‚РІРµРЅРЅС‹Р№ РїРѕС‚РѕРјРѕРє `TnbDockingPaneContent`.

РњРёРЅРёРјР°Р»СЊРЅС‹Р№ РїСЂРёРјРµСЂ:

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

  AddHeaderAction('clear', 'delete', HandleClear, 'Clear log');
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

Р¤РѕСЂРјР° СЃ `TnbDockingTabHost`:

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

`AddTab` РІС‹Р·С‹РІР°РµС‚ `OnContentNeeded`. Р•СЃР»Рё РЅР°РґРѕ РґРѕР±Р°РІРёС‚СЊ СѓР¶Рµ РіРѕС‚РѕРІСѓСЋ pane:

```pascal
FTabHost.AddTabWithContent('Server 1', TLogPane.Create(Self));
```

## Runtime Р‘РµР· Р’РєР»Р°РґРѕРє: PaneHost

Р•СЃР»Рё РІРєР»Р°РґРєРё РЅРµ РЅСѓР¶РЅС‹, РјРѕР¶РЅРѕ РёСЃРїРѕР»СЊР·РѕРІР°С‚СЊ `TnbDockingPaneHost` РЅР°РїСЂСЏРјСѓСЋ.

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

`SplitActive` РїСЂРёРЅРёРјР°РµС‚ РЅР°РїСЂР°РІР»РµРЅРёРµ:

```pascal
sdLeft
sdRight
sdAbove
sdBelow
```

Р•СЃР»Рё РІС‚РѕСЂРѕР№ РїР°СЂР°РјРµС‚СЂ `nil`, host Р·Р°РїСЂРѕСЃРёС‚ РЅРѕРІСѓСЋ pane С‡РµСЂРµР· `OnContentNeeded`.

## Header Actions

РЈ `TnbDockingPaneContent` РµСЃС‚СЊ РєРѕР»Р»РµРєС†РёСЏ:

```pascal
HeaderActions: TDockingPaneHeaderActions
```

РљР°Р¶РґС‹Р№ action СЃРѕРґРµСЂР¶РёС‚:

| РЎРІРѕР№СЃС‚РІРѕ | РќР°Р·РЅР°С‡РµРЅРёРµ |
| --- | --- |
| `Id` | СЃС‚Р°Р±РёР»СЊРЅС‹Р№ РёРґРµРЅС‚РёС„РёРєР°С‚РѕСЂ РєРЅРѕРїРєРё |
| `Glyph` | СЃРёРјРІРѕР» РёР»Рё alias |
| `Hint` | tooltip |
| `OnExecute` | РѕР±СЂР°Р±РѕС‚С‡РёРє РєР»РёРєР° |

РџСЂРёРјРµСЂ runtime:

```pascal
AddHeaderAction('refresh', 'refresh', HandleRefresh, 'Refresh');
AddHeaderAction('theme', 'theme', HandleTheme, 'Theme');
AddDefaultCloseAction;
```

`AddDefaultCloseAction` Р»СѓС‡С€Рµ РІС‹Р·С‹РІР°С‚СЊ РїРѕСЃР»РµРґРЅРёРј, С‡С‚РѕР±С‹ close-РєРЅРѕРїРєР° Р±С‹Р»Р°
РєСЂР°Р№РЅРµР№ СЃРїСЂР°РІР°.

### Glyph

`Glyph` РїРѕРЅРёРјР°РµС‚ РЅРµСЃРєРѕР»СЊРєРѕ СѓРґРѕР±РЅС‹С… alias'РѕРІ:

| Р—РЅР°С‡РµРЅРёРµ | Р РµР·СѓР»СЊС‚Р°С‚ |
| --- | --- |
| `add`, `plus`, `+` | РїР»СЋСЃ |
| `close`, `x` | Р·Р°РєСЂС‹С‚СЊ |
| `broadcast`, `B` | broadcast |
| `sftp`, `folder`, `S` | РїР°РїРєР° |
| `theme`, `T` | С‚РµРјР° |

Р’ Object Inspector Сѓ `Glyph` РµСЃС‚СЊ СЂРµРґР°РєС‚РѕСЂ СЃ РєРЅРѕРїРєРѕР№ `...`: РјРѕР¶РЅРѕ РёСЃРєР°С‚СЊ Рё
РІС‹Р±РёСЂР°С‚СЊ vector aliases РІСЃРёР·СѓР°Р»СЊРЅРѕ.

Р•СЃР»Рё `Glyph` РЅРµ СЂР°СЃРїРѕР·РЅР°РЅ РєР°Рє vector alias, РѕРЅ СЂРёСЃСѓРµС‚СЃСЏ РєР°Рє РѕР±С‹С‡РЅС‹Р№
С‚РµРєСЃС‚.

## Р’Р°Р¶РЅС‹Рµ РЎРІРѕР№СЃС‚РІР°

### TnbDockingPaneContent

| РЎРІРѕР№СЃС‚РІРѕ | Р§С‚Рѕ РґРµР»Р°РµС‚ |
| --- | --- |
| `Caption` | Р·Р°РіРѕР»РѕРІРѕРє pane |
| `HeaderVisible` | РїРѕРєР°Р·С‹РІР°РµС‚ РёР»Рё СЃРєСЂС‹РІР°РµС‚ header |
| `HeaderDragEnabled` | СЂР°Р·СЂРµС€Р°РµС‚ drag pane-Р·Р°РіРѕР»РѕРІРєР° |
| `AlwaysShowActive` | РґРµСЂР¶РёС‚ Р°РєС‚РёРІРЅСѓСЋ СЂР°РјРєСѓ РґР°Р¶Рµ Р±РµР· С„РѕРєСѓСЃР° |
| `HeaderBgColor` | С†РІРµС‚ С„РѕРЅР° РєР°СЂС‚РѕС‡РєРё/header theme |
| `HeaderTextColor` | С†РІРµС‚ С‚РµРєСЃС‚Р° Рё glyph'РѕРІ |
| `HeaderActions` | РєРѕР»Р»РµРєС†РёСЏ РєРЅРѕРїРѕРє РІ Р·Р°РіРѕР»РѕРІРєРµ |

РЎРѕР±С‹С‚РёСЏ:

| РЎРѕР±С‹С‚РёРµ | РљРѕРіРґР° РІС‹Р·С‹РІР°РµС‚СЃСЏ |
| --- | --- |
| `OnCloseRequest` | pane РїСЂРѕСЃРёС‚ Р·Р°РєСЂС‹С‚СЊСЃСЏ |
| `OnActivateRequest` | pane РїСЂРѕСЃРёС‚ СЃС‚Р°С‚СЊ Р°РєС‚РёРІРЅРѕР№ |
| `OnRenamed` | РїРѕР»СЊР·РѕРІР°С‚РµР»СЊ РїРµСЂРµРёРјРµРЅРѕРІР°Р» pane |
| `OnHeaderChanged` | РёР·РјРµРЅРёР»РёСЃСЊ caption/colors/actions |

### TnbDockingPaneHost

| РЎРІРѕР№СЃС‚РІРѕ | Р§С‚Рѕ РґРµР»Р°РµС‚ |
| --- | --- |
| `BackgroundColor` | С„РѕРЅ host'Р° |
| `AutoMatchBg` | РїРѕРґСЃС‚СЂР°РёРІР°РµС‚ С„РѕРЅ host'Р° РїРѕРґ Р°РєС‚РёРІРЅСѓСЋ pane |
| `SplitterSize` | СЂР°Р·РјРµСЂ splitters |
| `SplitterColor` | С†РІРµС‚ splitters |
| `AutoBuildDesignChildren` | СЃС‚СЂРѕРёС‚ РґРµСЂРµРІРѕ РёР· design-time pane-РґРµС‚РµР№ |
| `DesignChildrenOrientation` | РѕСЂРёРµРЅС‚Р°С†РёСЏ design-time pane-РґРµС‚РµР№ |
| `FocusMode` | РІСЂРµРјРµРЅРЅРѕ РїРѕРєР°Р·С‹РІР°РµС‚ Р°РєС‚РёРІРЅСѓСЋ pane РєСЂСѓРїРЅРѕ + СЃРїРёСЃРѕРє СЃР»РµРІР° |

РЎРѕР±С‹С‚РёСЏ:

| РЎРѕР±С‹С‚РёРµ | РќР°Р·РЅР°С‡РµРЅРёРµ |
| --- | --- |
| `OnContentNeeded` | host РїСЂРѕСЃРёС‚ СЃРѕР·РґР°С‚СЊ РЅРѕРІСѓСЋ pane |
| `OnActiveLeafChanged` | РёР·РјРµРЅРёР»СЃСЏ Р°РєС‚РёРІРЅС‹Р№ leaf |
| `OnContentHeaderChanged` | content РїРѕРјРµРЅСЏР» header |
| `OnHeaderDrag` | pane-Р·Р°РіРѕР»РѕРІРѕРє С‚Р°С‰Р°С‚ РјС‹С€СЊСЋ |

### TnbDockingTabHost

| РЎРІРѕР№СЃС‚РІРѕ | Р§С‚Рѕ РґРµР»Р°РµС‚ |
| --- | --- |
| `TabBarColor` | С„РѕРЅ tab bar |
| `TabActiveColor` | С†РІРµС‚ Р°РєС‚РёРІРЅРѕР№ РІРєР»Р°РґРєРё |
| `TabInactiveColor` | С†РІРµС‚ РЅРµР°РєС‚РёРІРЅРѕР№ РІРєР»Р°РґРєРё |
| `TabHoverColor` | hover С†РІРµС‚ |
| `TabTextColor` | С†РІРµС‚ С‚РµРєСЃС‚Р° РІРєР»Р°РґРѕРє |
| `AccentColor` | Р°РєС†РµРЅС‚ drop/selection |
| `TabAddVisible` | РїРѕРєР°Р·С‹РІР°РµС‚ РєРЅРѕРїРєСѓ `+` |
| `TabBarActionText` | С‚РµРєСЃС‚ РїСЂР°РІРѕР№ action-РєРЅРѕРїРєРё tab bar |
| `TabBarActionVisible` | РїРѕРєР°Р·С‹РІР°РµС‚ РїСЂР°РІСѓСЋ action-РєРЅРѕРїРєСѓ |
| `PaneHostAutoMatchBg` | РїСЂРѕРєРёРґС‹РІР°РµС‚СЃСЏ РІРѕ РІРЅСѓС‚СЂРµРЅРЅРёРµ hosts |

РЎРѕР±С‹С‚РёСЏ:

| РЎРѕР±С‹С‚РёРµ | РќР°Р·РЅР°С‡РµРЅРёРµ |
| --- | --- |
| `OnContentNeeded` | РЅСѓР¶РЅР° РЅРѕРІР°СЏ pane РґР»СЏ РЅРѕРІРѕР№ РІРєР»Р°РґРєРё/split |
| `OnTabAdded` | РІРєР»Р°РґРєР° РґРѕР±Р°РІР»РµРЅР° |
| `OnTabClick` | РєР»РёРє РїРѕ РІРєР»Р°РґРєРµ |
| `OnTabClosing` | РјРѕР¶РЅРѕ РѕС‚РјРµРЅРёС‚СЊ Р·Р°РєСЂС‹С‚РёРµ |
| `OnTabClosed` | РІРєР»Р°РґРєР° Р·Р°РєСЂС‹С‚Р° |
| `OnActiveTabChanged` | Р°РєС‚РёРІРЅР°СЏ РІРєР»Р°РґРєР° РёР·РјРµРЅРёР»Р°СЃСЊ |
| `OnTabBarActionClick` | РєР»РёРє РїРѕ РїСЂР°РІРѕР№ action-РєРЅРѕРїРєРµ tab bar |

## РљР°Рє Р Р°Р±РѕС‚Р°РµС‚ Drag & Drop

РџРѕРґРґРµСЂР¶РёРІР°СЋС‚СЃСЏ РґРІР° drag-СЃС†РµРЅР°СЂРёСЏ.

### Р’РєР»Р°РґРєР°

- РџРµСЂРµС‚Р°С‰РёС‚СЊ РІРєР»Р°РґРєСѓ РІРЅСѓС‚СЂРё tab bar вЂ” reorder.
- РџРµСЂРµС‚Р°С‰РёС‚СЊ РѕРґРёРЅРѕС‡РЅСѓСЋ РІРєР»Р°РґРєСѓ РІ РѕР±Р»Р°СЃС‚СЊ pane вЂ” split РІ РІС‹Р±СЂР°РЅРЅСѓСЋ СЃС‚РѕСЂРѕРЅСѓ.
- Р’РєР»Р°РґРєСѓ СЃ РЅРµСЃРєРѕР»СЊРєРёРјРё pane'Р°РјРё РЅРµР»СЊР·СЏ С‚Р°С‰РёС‚СЊ РєР°Рє split-source, РїРѕС‚РѕРјСѓ С‡С‚Рѕ
  РѕРЅР° СѓР¶Рµ РїСЂРµРґСЃС‚Р°РІР»СЏРµС‚ РіСЂСѓРїРїСѓ.

### Pane Header

- РџРµСЂРµС‚Р°С‰РёС‚СЊ Р·Р°РіРѕР»РѕРІРѕРє pane РІ tab bar вЂ” pane СЃС‚Р°РЅРµС‚ РЅРѕРІРѕР№ РІРєР»Р°РґРєРѕР№.
- РџРµСЂРµС‚Р°С‰РёС‚СЊ Р·Р°РіРѕР»РѕРІРѕРє pane РІ РґСЂСѓРіСѓСЋ pane-zone вЂ” pane РїРµСЂРµРµРґРµС‚ РєР°Рє split.

Р’Рѕ РІСЂРµРјСЏ drag РїРѕРєР°Р·С‹РІР°РµС‚СЃСЏ drop preview.

## Focus Mode

`TnbDockingPaneHost.FocusMode` РЅРµ РјРµРЅСЏРµС‚ РґРµСЂРµРІРѕ layout'Р°. РћРЅ РІСЂРµРјРµРЅРЅРѕ
РїРµСЂРµСЃС‚СЂР°РёРІР°РµС‚ РІРёР·СѓР°Р»СЊРЅС‹Р№ РІРёРґ:

- СЃР»РµРІР° СЃРїРёСЃРѕРє РІСЃРµС… leaf'РѕРІ;
- СЃРїСЂР°РІР° Р°РєС‚РёРІРЅР°СЏ pane РЅР° РІСЃС‘ РѕСЃС‚Р°РІС€РµРµСЃСЏ РїСЂРѕСЃС‚СЂР°РЅСЃС‚РІРѕ.

Р’С‹С…РѕРґ РёР· focus mode РІРѕР·РІСЂР°С‰Р°РµС‚ РёСЃС…РѕРґРЅС‹Рµ split-РїСЂРѕРїРѕСЂС†РёРё.

```pascal
Host.EnterFocusMode;
Host.ExitFocusMode;
Host.ToggleFocusMode;
```

## Р–РёР·РЅРµРЅРЅС‹Р№ Р¦РёРєР» Р Ownership

Р’Р°Р¶РЅР°СЏ РёРґРµСЏ: `TPaneTree` С…СЂР°РЅРёС‚ СЃСЃС‹Р»РєРё РЅР° `TnbDockingPaneContent`, РЅРѕ РЅРµ
РІР»Р°РґРµРµС‚ РёРјРё РєР°Рє owner.

РџСЂР°РєС‚РёС‡РµСЃРєРёРµ РїСЂР°РІРёР»Р°:

- РќРµ РѕСЃРІРѕР±РѕР¶РґР°Р№С‚Рµ pane РІСЂСѓС‡РЅСѓСЋ, РµСЃР»Рё РѕРЅР° СѓР¶Рµ РїРµСЂРµРґР°РЅР° host'Сѓ.
- Р”Р»СЏ Р·Р°РєСЂС‹С‚РёСЏ РёСЃРїРѕР»СЊР·СѓР№С‚Рµ `CloseActive`, close action РёР»Рё `RequestClose`.
- Р”Р»СЏ РїРµСЂРµРЅРѕСЃР° РјРµР¶РґСѓ host'Р°РјРё РёСЃРїРѕР»СЊР·СѓРµС‚СЃСЏ `TakeActiveContent` /
  `TakeLeafContent`: content РІС‹РЅРёРјР°РµС‚СЃСЏ РёР· РґРµСЂРµРІР°, РЅРѕ РЅРµ СѓРЅРёС‡С‚РѕР¶Р°РµС‚СЃСЏ.
- РќРµ РёРјРїРѕСЂС‚РёСЂСѓР№С‚Рµ `nbDocking.PaneHost` РёР»Рё `nbDocking.TabHost` РІ unit Р±Р°Р·РѕРІРѕРіРѕ
  content-РєР»Р°СЃСЃР°. Content РѕР±С‰Р°РµС‚СЃСЏ СЃРЅР°СЂСѓР¶Рё С‡РµСЂРµР· СЃРѕР±С‹С‚РёСЏ.
- Р•СЃР»Рё close РїСЂРѕРёСЃС…РѕРґРёС‚ РёР· click handler'Р° РІРЅСѓС‚СЂРё Р·Р°РєСЂС‹РІР°РµРјРѕР№ pane, free
  РґРѕР»Р¶РµРЅ Р±С‹С‚СЊ РѕС‚Р»РѕР¶РµРЅ РЅР° СЃР»РµРґСѓСЋС‰РёР№ tick. Р’ РєРѕРјРїРѕРЅРµРЅС‚Рµ СЌС‚Рѕ СѓР¶Рµ СЃРґРµР»Р°РЅРѕ.

## Build

РўСЂРµР±СѓРµС‚СЃСЏ RAD Studio / Delphi СЃ FireMonkey.

РџСЂРѕРІРµСЂСЏР»РѕСЃСЊ РЅР° Delphi 13.x.

```powershell
msbuild src\nbFMXDocking.dproj /t:Build /p:Config=Debug /p:Platform=Win64
msbuild demo\DockingTest.dproj /t:Build /p:Config=Debug /p:Platform=Win64
```

Р”Р»СЏ Win32:

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

РџР»Р°РЅРёСЂСѓРµРјС‹Рµ СЃР»РµРґСѓСЋС‰РёРµ СЃР»РѕРё:

1. `nbDocking.Shell` вЂ” layout РёР· РЅРµСЃРєРѕР»СЊРєРёС… Р·РѕРЅ: sidebar, main, bottom.
2. `nbDocking.FloatWindow` вЂ” РѕС‚СЃС‚С‹РєРѕРІРєР° pane РІ РѕС‚РґРµР»СЊРЅСѓСЋ С„РѕСЂРјСѓ.
3. `nbDocking.Persistence` вЂ” СЃРѕС…СЂР°РЅРµРЅРёРµ/РІРѕСЃСЃС‚Р°РЅРѕРІР»РµРЅРёРµ layout'Р°.

## Р”РѕРєСѓРјРµРЅС‚Р°С†РёСЏ РїСЂРѕРµРєС‚Р°

- [РћС‚С‡РµС‚ Рѕ СЂР°Р·СЂР°Р±РѕС‚РєРµ](docs/DEVELOPMENT_REPORT.md)
- [Р СѓРєРѕРІРѕРґСЃС‚РІРѕ СЂР°Р·СЂР°Р±РѕС‚С‡РёРєР°](docs/DEVELOPER_GUIDE.md)
