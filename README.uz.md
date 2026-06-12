# nbFMXDocking

Tillar: [Русский](README.md) | [English](README.en.md) | [O'zbekcha](README.uz.md)

`nbFMXDocking` - Delphi FireMonkey uchun docking uslubidagi interfeyslar
komponentlari to'plami: split-layout, guruh tablari, panellarni sudrash,
header actions va layout'ni RAD Studio ichida design-time yig'ish.

Hozir tavsiya qilinadigan model oddiy: formaga bitta `TnbDockingPaneHost`
qo'yiladi. Host panellar, guruhlar, tablar va drop-preview'ni o'zi boshqaradi.
Past darajadagi docking komponentlarini formaga qo'lda tashlash shart emas.

## Holat

Ishlaydigan qismlar:

- `TnbDockingPaneHost` - IDE palitrasidagi asosiy komponent.
- Host context menu orqali design-time pane yaratish.
- Pane context menu orqali design-time split right / split below.
- Runtime gorizontal va vertikal splitterli split-layout.
- `TnbDockingPaneHost` ichida runtime tablar.
- Tabbar'dagi `+` tugmasi yangi pane bilan yangi tab yaratadi.
- Bitta pane bor tab o'sha pane caption'i bilan nomlanadi.
- Bir nechta pane bor tab `Group` deb nomlanadi.
- Pane header'ini split-zonalarga sudrash.
- Pane header'ini tabbar'ga sudrash: pane alohida tab bo'ladi.
- Bitta pane'li tabni tabbar'dan aktiv guruhga qaytarib sudrash.
- Tabbar joylashuvi: yuqori, pastki, chap, o'ng.
- Tab matni yo'nalishi: auto, horizontal, vertical.
- Object Inspector orqali header actions.
- Pane sarlavhasini inline rename qilish.
- Close tugmasi default ko'rinadi.
- Host ichida focus mode.

Hali qilinmagan:

- floating windows;
- layout'ni JSON ko'rinishida saqlash/tiklash;
- to'liq design-time tab collection;
- butun ko'p-pane'li tab-guruhni nested group sifatida orqaga sudrash. Hozircha faqat bitta pane'li tab qaytariladi.

## Komponentlar

### `TnbDockingPaneHost`

Asosiy komponent. Uni formaga qo'ying va odatda `Align = Client` qiling.

Vazifalari:

- split-pane daraxti;
- tabbar va guruh tablari;
- runtime drag/drop;
- drop overlay;
- `OnContentNeeded` orqali content yaratish;
- child `TnbDockingPaneContent` kontrollaridan design-time layout.

Muhim xossalar:

| Xossa | Maqsad |
| --- | --- |
| `VisibleTabs` | Tabbar'ni ko'rsatadi yoki yashiradi. |
| `ShowAddButton` | Tabbar'da `+` tugmasini ko'rsatadi. |
| `TabPosition` | `dtpTop`, `dtpBottom`, `dtpLeft`, `dtpRight`. |
| `TabTextDirection` | `ttdAuto`, `ttdHorizontal`, `ttdVertical`. |
| `DesignChildrenOrientation` | Boshlang'ich design-time layout yo'nalishi. |
| `DesignChildrenLayoutMode` | Design-time children uchun split-layout yoki align-layout. |
| `SplitterSize` | Splitter qalinligi. |
| `SplitterColor` | Splitter/cover rangi. |
| `AutoMatchBg` | Host fonini aktiv pane'ga moslaydi. |

Eventlar:

| Event | Maqsad |
| --- | --- |
| `OnContentNeeded` | Host'ga yangi pane kerak bo'lganda chaqiriladi. |
| `OnActiveLeafChanged` | Aktiv pane o'zgardi. |
| `OnContentHeaderChanged` | Pane caption/header o'zgardi. |
| `OnHeaderDrag` | Pane header drag uchun tashqi xabar. |

### `TnbDockingPaneContent`

Pane kartasi. Odatda design-time editor yoki ilova kodi yaratadi.

Vazifalari:

- header;
- caption;
- inline rename;
- close button;
- action buttons;
- aktiv pane ramkasi;
- oddiy FMX-kontrollar uchun client area.

Muhim xossalar:

| Xossa | Maqsad |
| --- | --- |
| `Caption` | Pane sarlavhasi va bitta pane'li tab nomi. |
| `HeaderVisible` | Pane header'ini ko'rsatadi. |
| `HeaderDragEnabled` | Header drag'ni yoqadi. Runtime'da host o'z panellari uchun drag'ni yoqadi. |
| `CanClosePane` | Pane yopilishini ruxsat qiladi. |
| `ShowCloseButton` | Close tugmasini ko'rsatadi. Default `True`. |
| `HeaderActions` | Header o'ng tomonidagi action tugmalar kolleksiyasi. |
| `AllowResize` | Qaysi resize yo'nalishlari ruxsat qilingan. |
| `MinPaneWidth`, `MinPaneHeight` | Pane minimal o'lchami. |

### `TnbDockingDemoPane`

Development uchun test pane. Palitrada faqat `DEBUG` rejimida ro'yxatdan o'tadi.

## IDE Palitra

Package o'rnatilgandan keyin `nb FMX Docking` palitrasida asosiy komponent bor:

```text
TnbDockingPaneHost
```

`TnbDockingPaneContent` host va pane design-time buyruqlari orqali yaratiladi,
asosiy palitra komponenti sifatida emas.

## Designerda Tez Boshlash

1. Formaga `TnbDockingPaneHost` qo'ying.
2. `Align = Client` qiling.
3. Tablar kerak bo'lsa, `VisibleTabs = True` qiling.
4. Host ustida right-click -> `Add Pane Content`.
5. Yaratilgan pane'ni tanlang.
6. Pane ustida right-click -> `Split Pane Right` yoki `Split Pane Below`.
7. Kerakli `TnbDockingPaneContent` ichiga oddiy FMX-kontrollarni joylang.

Struktura misoli:

```text
Form1
  nbDockingPaneHost1
    nbDockingPaneContent1
      Memo1
    nbDockingPaneContent2
      Layout1
      Button1
```

Runtime'da foydalanuvchi:

- pane header'ini split-zonalarga sudraydi;
- pane header'ini tabbar'ga sudrab yangi tab yaratadi;
- `+` bosib yangi tab yaratadi;
- bitta pane'li tabni aktiv guruhga qaytarib sudraydi.

## Kod Orqali Pane Yaratish

Foydalanuvchi `+` bosganda yoki split so'ralganda maxsus pane kerak bo'lsa,
`OnContentNeeded` event'iga yoziling.

```pascal
procedure TForm1.DockHostContentNeeded(Sender: TObject;
  var AContent: TnbDockingPaneContent);
begin
  AContent := TnbDockingPaneContent.Create(Self);
  AContent.Caption := 'Terminal';

  // AContent ichiga istalgan FMX-kontrollarni joylash mumkin:
  // Memo1.Parent := AContent;
  // Memo1.Align := TAlignLayout.Client;
end;
```

Handler berilmasa, `TnbDockingPaneHost` oddiy default pane yaratadi.

## Header Actions

`TnbDockingPaneContent` ichida `HeaderActions` kolleksiyasi bor. Uni Object
Inspector orqali yoki kodda sozlash mumkin.

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

Close tugmasi avtomatik yaratiladi. Uni boshqaradigan xossalar:

- `ShowCloseButton`;
- `CanClosePane`.

## Build Va O'rnatish

Package loyihasi:

```text
src\nbFMXDocking.dproj
```

Developer Command Prompt orqali build:

```powershell
msbuild src\nbFMXDocking.dproj /t:Build /p:Config=Debug /p:Platform=Win32
```

IDE uchun Win32 design-time BPL kerak. Build'dan keyin `.bpl` ni shu yerda o'rnating:

```text
Component -> Install Packages -> Add...
```

Ilovalar uchun loyiha `Unit Search Path`iga `src` ni qo'shing, masalan:

```text
Z:\Repos\Devops\nbFmxDocking\src
```

## Package Haqida Muhim Eslatma

Hozirgi package design-time package:

```pascal
{$DESIGNONLY}
```

U registration unit va design editorlarni o'z ichiga oladi. Keyinchalik to'liq
runtime BPL tarqatish uchun loyihani ikki package'ga ajratish kerak:

- `DesignIDE`, `Reg_*` va design editorlarsiz runtime package;
- runtime package'ga bog'langan design-time package.

## Loyiha Fayllari

```text
src\nbDocking.PaneHost.pas       asosiy host, split tree, tabbar, drag/drop
src\nbDocking.Types.pas          TnbDockingPaneContent va header actions
src\nbDocking.PaneTree.pas       split-pane daraxti
src\nbDocking.DropOverlay.pas    drop zone preview
src\nbDocking.DesignEditors.pas  design-time context menu va property editors
src\Reg_nbFMXDocking.pas         IDE komponent registration
demo\DockingDesignTest.dproj     test loyiha
```

## Hozirgi Cheklovlar

- Host tablari hozircha runtime-only; Object Inspector'da to'liq published tab collection yo'q.
- Tabbar'dan orqaga sudrash bitta pane'li tablar uchun ishlaydi. Tab-guruh hali bitta nested group sifatida sudralmaydi.
- `TnbDockingTabHost` source tree ichida legacy/compatibility unit sifatida qolgan, lekin tavsiya etiladigan yo'l - `TnbDockingPaneHost`.
- Layout persistence hozircha ilova kodi tomonidan qilinadi.

## Publish Oldidan Tekshiruv

Minimal build check:

```powershell
msbuild src\nbFMXDocking.dproj /t:Build /p:Config=Debug /p:Platform=Win32
msbuild src\nbFMXDocking.dproj /t:Build /p:Config=Debug /p:Platform=Win64
msbuild demo\DockingDesignTest.dproj /t:Build /p:Config=Debug /p:Platform=Win64
```

Tavsiya etiladigan runtime smoke-test:

1. Design-time bir nechta pane yarating.
2. Ilovani ishga tushiring.
3. Pane'ni split-zonaga sudrang.
4. Pane'ni tabbar'ga sudrang.
5. Tablar orasida o'ting.
6. `+` bosing.
7. Bitta pane'li tabni aktiv guruhga qaytarib sudrang.
