# nbFMXDocking

Tillar: [Р СѓСЃСЃРєРёР№](README.md) | [English](README.en.md) | [O'zbekcha](README.uz.md)

`nbFMXDocking` - Delphi FireMonkey uchun tabbed docking UI komponentlari
to'plami. U tablar, split-panellar, pane sarlavhasini sudrab ko'chirish,
header actions va layout'ni IDE ichida design-time yig'ishni beradi.

Amalda bu IDE, Termius, iTerm2, VS Code panels yoki tmux uslubidagi FMX
interfeyslar uchun asos. Ilova pane ichidagi kontentni o'zi beradi: terminal,
SFTP brauzer, log ko'ruvchi, editor, monitoring oynasi va hokazo.

## Holat

Ishlaydigan qismlar:

- `TnbDockingPaneHost` - split-panellar daraxtiga ega bitta docking host.
- `TnbDockingTabHost` - tablar, har bir tab o'z `PaneHost`iga ega.
- `TnbDockingPaneContent` - sarlavha, caption, ramka, inline rename va action
  tugmalari bor asosiy content kartasi.
- Gorizontal va vertikal split'lar.
- IDE context menu orqali design-time pane va split yaratish.
- Object Inspector orqali header actions.
- Tab bar ichida tablarni sudrab tartiblash.
- Bitta pane'li tabni boshqa tab pane-zone'iga sudrab split qilish.
- Pane sarlavhasini tab bar yoki split-zone ichiga sudrash.
- VS Code uslubidagi drop preview.
- `TnbDockingPaneHost` ichida focus mode.
- `DockingTest` demo loyihasi.

Hali qilinmagan:

- `sidebar | main | bottom` uchun alohida shell komponent;
- floating windows;
- layout'ni JSON ko'rinishida saqlash va tiklash.

## Paket Haqida Muhim Izoh

Hozir `src\nbFMXDocking.dpk` design-time package sifatida yig'iladi:

```pascal
{$DESIGNONLY}
```

Bu paket komponentlarni IDE palitrasiga o'rnatish uchun kerak va
`Reg_nbFMXDocking` unit'ini o'z ichiga oladi.

Joriy workspace ichidagi ilovalarda runtime unit'lar odatda loyiha
`Unit Search Path` orqali ulanadi, masalan:

```text
Z:\Repos\Devops\nbFmxDocking\src
```

Keyinchalik komponentni to'liq runtime BPL sifatida tarqatish kerak bo'lsa,
paketni ikkiga ajratish maqsadga muvofiq:

- `DesignIDE`, `Reg_*` va design editor'larsiz runtime package;
- runtime package'ni requires qiladigan design-time package.

## Komponentlar

| Komponent | Qayerda ishlatiladi | Vazifasi |
| --- | --- | --- |
| `TnbDockingPaneContent` | base class yoki design-time pane | Content kartasi: header, caption, ramka, actions, activation |
| `TnbDockingPaneHost` | forma, layout, sub-layout | Tabsiz bitta docking layout |
| `TnbDockingTabHost` | ilovaning asosiy konteyneri | Tab bar va bir nechta `TnbDockingPaneHost` |
| `TnbDockingDemoPane` | demo/debug | Oddiy test pane, faqat DEBUG rejimida ro'yxatdan o'tadi |

IDE palitrasi:

```text
nb FMX Docking
```

## IDE'ga O'rnatish

1. `ProjectGroup1.groupproj` yoki `src\nbFMXDocking.dproj` ni oching.
2. IDE turiga qarab package'ni Win32 yoki Win64 uchun yig'ing.
3. BPL'ni IDE orqali o'rnating.

Developer Command Prompt ichidan:

```powershell
msbuild src\nbFMXDocking.dproj /t:Build /p:Config=Debug /p:Platform=Win64
```

Keyin RAD Studio ichida:

```text
Component -> Install Packages -> Add...
```

Loyiha output papkasidan yig'ilgan `.bpl` faylini tanlang.

Ilovalar uchun `src` papkasini loyiha `Unit Search Path`iga qo'shing.

## Tez Boshlash: Design-Time

Eng oddiy yo'l - layout'ni to'g'ridan-to'g'ri form designer ichida yig'ish.

1. Formaga `TnbDockingPaneHost` qo'ying.
2. `Align = Client` qiling.
3. Host ustida o'ng tugma bilan bosing -> `Add Pane Content`.
4. Yaratilgan `TnbDockingPaneContent` ni tanlang.
5. Pane ustida o'ng tugma bilan bosing -> `Split Pane Right` yoki
   `Split Pane Below`.
6. Kerakli `TnbDockingPaneContent` ichiga oddiy FMX control'larni joylashtiring.

Misol struktura:

```text
Form1
  nbDockingPaneHost1
    nbDockingPaneContent1
      Memo1
    nbDockingPaneContent2
      Layout1
      Button1
```

Bir xil yo'nalishdagi bir nechta pane uchun:

```text
TnbDockingPaneHost.DesignChildrenOrientation = poHorizontal
```

yoki:

```text
poVertical
```

`AutoBuildDesignChildren = True` bo'lsa, forma yuklanganda host to'g'ridan-
to'g'ri child bo'lgan design-time `TnbDockingPaneContent`lardan docking tree
yig'adi.

### Pane Ichiga Control Qo'yish

`TnbDockingPaneContent` oddiy FMX konteyner. Ichiga quyidagilarni qo'yish
mumkin:

- `TLayout`
- `TRectangle`
- `TMemo`
- `TListBox`
- custom FMX control'lar
- normal FMX parent/child qoidalari bilan ishlaydigan har qanday visual control

`TnbDockingPaneContent` ni qo'lda boshqa `TnbDockingPaneContent` ichiga
joylashtirmang. Split uchun context menu'dan foydalaning:

```text
Split Pane Right
Split Pane Below
```

Designer to'g'ri strukturani va splitter'larni o'zi yaratadi.

## Tez Boshlash: Runtime TabHost Bilan

Odatda ilova `TnbDockingPaneContent` dan o'z descendant class'ini yaratadi.

Minimal content misoli:

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

`TnbDockingTabHost` ishlatilgan forma:

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

`AddTab` `OnContentNeeded` ni chaqiradi. Agar tayyor pane instance bo'lsa:

```pascal
FTabHost.AddTabWithContent('Server 1', TLogPane.Create(Self));
```

## Runtime Tabsiz: PaneHost

Tablar kerak bo'lmasa, `TnbDockingPaneHost` dan to'g'ridan-to'g'ri
foydalaning.

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

`SplitActive` quyidagi yo'nalishlarni qabul qiladi:

```pascal
sdLeft
sdRight
sdAbove
sdBelow
```

Ikkinchi parametr `nil` bo'lsa, host yangi pane'ni `OnContentNeeded` orqali
so'raydi.

## Header Actions

`TnbDockingPaneContent` da quyidagi collection bor:

```pascal
HeaderActions: TDockingPaneHeaderActions
```

Har bir action quyidagilardan iborat:

| Property | Vazifasi |
| --- | --- |
| `Id` | barqaror tugma identifikatori |
| `Glyph` | symbol yoki alias |
| `Hint` | tooltip |
| `OnExecute` | click handler |

Runtime misol:

```pascal
AddHeaderAction('refresh', 'refresh', HandleRefresh, 'Refresh');
AddHeaderAction('theme', 'theme', HandleTheme, 'Theme');
AddDefaultCloseAction;
```

Close tugmasi eng o'ngda bo'lishi uchun `AddDefaultCloseAction` ni oxirida
chaqiring.

### Glyph

`Glyph` bir nechta alias'larni tushunadi:

| Qiymat | Natija |
| --- | --- |
| `add`, `plus`, `+` | plus |
| `close`, `x` | close |
| `broadcast`, `B` | broadcast |
| `sftp`, `folder`, `S` | folder |
| `theme`, `T` | theme |

Object Inspector ichida `Glyph` uchun `...` tugmali editor bor. U vector
alias'larni vizual qidirish va tanlash imkonini beradi.

`Glyph` vector alias sifatida tanilmasa, oddiy text sifatida
chiziladi.

## Muhim Property'lar

### TnbDockingPaneContent

| Property | Vazifasi |
| --- | --- |
| `Caption` | pane sarlavhasi |
| `HeaderVisible` | header'ni ko'rsatadi yoki yashiradi |
| `HeaderDragEnabled` | pane header dragging'ni yoqadi |
| `AlwaysShowActive` | focus bo'lmasa ham active border'ni saqlaydi |
| `HeaderBgColor` | card/header theme background |
| `HeaderTextColor` | text va glyph rangi |
| `HeaderActions` | header tugmalari collection'i |

Events:

| Event | Qachon chaqiriladi |
| --- | --- |
| `OnCloseRequest` | pane yopilishni so'raydi |
| `OnActivateRequest` | pane active bo'lishni so'raydi |
| `OnRenamed` | foydalanuvchi pane nomini o'zgartirdi |
| `OnHeaderChanged` | caption/colors/actions o'zgardi |

### TnbDockingPaneHost

| Property | Vazifasi |
| --- | --- |
| `BackgroundColor` | host background |
| `AutoMatchBg` | host background'ini active pane'ga moslaydi |
| `SplitterSize` | splitter o'lchami |
| `SplitterColor` | splitter rangi |
| `AutoBuildDesignChildren` | design-time pane child'lardan tree yig'adi |
| `DesignChildrenOrientation` | design-time pane child'lar yo'nalishi |
| `FocusMode` | active pane'ni katta qilib, chapda ro'yxat ko'rsatadi |

Events:

| Event | Vazifasi |
| --- | --- |
| `OnContentNeeded` | host yangi pane so'raydi |
| `OnActiveLeafChanged` | active leaf o'zgardi |
| `OnContentHeaderChanged` | content o'z header'ini o'zgartirdi |
| `OnHeaderDrag` | pane header sudralmoqda |

### TnbDockingTabHost

| Property | Vazifasi |
| --- | --- |
| `TabBarColor` | tab bar background |
| `TabActiveColor` | active tab rangi |
| `TabInactiveColor` | inactive tab rangi |
| `TabHoverColor` | hover rangi |
| `TabTextColor` | tab text rangi |
| `AccentColor` | drop/selection accent |
| `TabAddVisible` | `+` tugmasini ko'rsatadi |
| `TabBarActionText` | o'ng tab-bar action tugmasi text'i |
| `TabBarActionVisible` | o'ng tab-bar action tugmasini ko'rsatadi |
| `PaneHostAutoMatchBg` | ichki host'larga uzatiladi |

Events:

| Event | Vazifasi |
| --- | --- |
| `OnContentNeeded` | yangi tab yoki split uchun pane kerak |
| `OnTabAdded` | tab qo'shildi |
| `OnTabClick` | tab bosildi |
| `OnTabClosing` | yopishni bekor qilish mumkin |
| `OnTabClosed` | tab yopildi |
| `OnActiveTabChanged` | active tab o'zgardi |
| `OnTabBarActionClick` | o'ng tab-bar action tugmasi bosildi |

## Drag & Drop Qanday Ishlaydi

Ikki drag ssenariy qo'llab-quvvatlanadi.

### Tab

- Tab bar ichida tab'ni sudrang - tartibi o'zgaradi.
- Bitta pane'li tab'ni pane maydoniga sudrang - tanlangan tomonga split bo'ladi.
- Bir nechta pane'li tab split source bo'la olmaydi, chunki u allaqachon group.

### Pane Header

- Pane header'ni tab bar'ga sudrang - pane yangi tab bo'ladi.
- Pane header'ni boshqa pane-zone'ga sudrang - pane split sifatida ko'chadi.

Drag vaqtida drop preview ko'rsatiladi.

## Focus Mode

`TnbDockingPaneHost.FocusMode` layout daraxtini o'zgartirmaydi. U faqat visual
ko'rinishni vaqtincha qayta yig'adi:

- chapda barcha leaf'lar ro'yxati;
- o'ngda active pane qolgan joyning hammasini egallaydi.

Focus mode'dan chiqilganda asl split proporsiyalari tiklanadi.

```pascal
Host.EnterFocusMode;
Host.ExitFocusMode;
Host.ToggleFocusMode;
```

## Lifetime Va Ownership

Asosiy fikr: `TPaneTree` `TnbDockingPaneContent` ga reference saqlaydi, lekin
ularning owner'i emas.

Amaliy qoidalar:

- Pane host'ga berilgandan keyin uni qo'lda free qilmang.
- Yopish uchun `CloseActive`, close action yoki `RequestClose` dan foydalaning.
- Content'ni host'lar orasida ko'chirish uchun `TakeActiveContent` /
  `TakeLeafContent` ishlatiladi. Content tree'dan olinadi, lekin yo'q
  qilinmaydi.
- Base content class unit'iga `nbDocking.PaneHost` yoki `nbDocking.TabHost`
  import qilmang. Content tashqariga events orqali murojaat qiladi.
- Agar yopish yopilayotgan pane ichidagi click handler'dan boshlangan bo'lsa,
  free keyingi tick'ka qoldirilishi kerak. Komponent buni allaqachon qiladi.

## Build

FireMonkey o'rnatilgan RAD Studio / Delphi kerak.

Delphi 13.x da tekshirilgan.

```powershell
msbuild src\nbFMXDocking.dproj /t:Build /p:Config=Debug /p:Platform=Win64
msbuild demo\DockingTest.dproj /t:Build /p:Config=Debug /p:Platform=Win64
```

Win32 uchun:

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

Keyingi rejalashtirilgan qatlamlar:

1. `nbDocking.Shell` - ko'p zonali layout: sidebar, main, bottom.
2. `nbDocking.FloatWindow` - pane'ni alohida formaga ajratish.
3. `nbDocking.Persistence` - layout'larni saqlash va tiklash.

## Loyiha hujjatlari

- [Development Report](docs/DEVELOPMENT_REPORT.md)
- [Developer Guide](docs/DEVELOPER_GUIDE.md)
