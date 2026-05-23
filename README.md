# nbFMXDocking

Языки: [Русский](README.md) | [English](README.en.md) | [O'zbekcha](README.uz.md)

`nbFMXDocking` — набор Delphi FireMonkey-компонентов для tabbed docking UI:
вкладки, split-панели, перетаскивание pane-заголовков, header actions и
design-time сборка layout'а прямо в IDE.

Проще говоря: это FMX-основа для интерфейсов в стиле IDE, Termius, iTerm2,
VS Code panels или tmux, где приложение само поставляет содержимое панелей:
терминал, SFTP-браузер, лог, редактор, мониторинг и так далее.

## Статус

Уже работает:

- `TnbDockingPaneHost` — один docking-host с деревом split-панелей.
- `TnbDockingTabHost` — вкладки, каждая вкладка содержит свой `PaneHost`.
- `TnbDockingPaneContent` — базовая карточка содержимого с заголовком,
  рамкой, inline rename и action-кнопками.
- Горизонтальные и вертикальные split'ы.
- Design-time создание pane'ов и split'ов через контекстное меню IDE.
- Header actions через Object Inspector.
- Перетаскивание вкладок внутри tab bar.
- Перетаскивание одиночной вкладки в pane-zone другой вкладки.
- Перетаскивание pane-заголовка в tab bar или split-zone.
- VS Code-style drop preview.
- Focus mode внутри `TnbDockingPaneHost`.
- Demo-проект `DockingTest`.

Пока не реализовано:

- отдельный shell-компонент `sidebar | main | bottom`;
- floating windows;
- JSON persistence layout'а.

## Важный Нюанс Про Пакет

Сейчас `src\nbFMXDocking.dpk` собран как design-time package:

```pascal
{$DESIGNONLY}
```

Он нужен для установки компонентов в IDE и содержит регистрацию
`Reg_nbFMXDocking`.

Для приложений в текущем workspace runtime units обычно подключаются через
`Unit Search Path`, например:

```text
Z:\Repos\Devops\nbFmxDocking\src
```

Если понадобится распространять компонент как полноценный runtime BPL, пакет
надо будет разделить на два:

- runtime package без `DesignIDE`, `Reg_*`, design editors;
- design-time package, который requires runtime package.

## Компоненты

| Компонент | Где использовать | Что делает |
| --- | --- | --- |
| `TnbDockingPaneContent` | как базовый класс или design-time pane | Карточка содержимого: header, caption, рамка, actions, activation |
| `TnbDockingPaneHost` | форма, layout, sub-layout | Один docking layout без вкладок |
| `TnbDockingTabHost` | главный контейнер приложения | Tab bar + набор `TnbDockingPaneHost` |
| `TnbDockingDemoPane` | demo/debug | Простая тестовая pane, регистрируется только в DEBUG |

Палитра IDE:

```text
nb FMX Docking
```

## Установка В IDE

1. Откройте `ProjectGroup1.groupproj` или `src\nbFMXDocking.dproj`.
2. Соберите package под Win32 или Win64, в зависимости от IDE.
3. Установите BPL через IDE.

Из Developer Command Prompt:

```powershell
msbuild src\nbFMXDocking.dproj /t:Build /p:Config=Debug /p:Platform=Win64
```

Потом в RAD Studio:

```text
Component -> Install Packages -> Add...
```

Выберите собранный `.bpl` из output-папки проекта.

Для приложений добавьте `src` в Unit Search Path проекта.

## Быстрый Старт: Design-Time

Самый простой сценарий — собрать layout прямо в дизайнере формы.

1. Положите `TnbDockingPaneHost` на форму.
2. Установите `Align = Client`.
3. Щёлкните правой кнопкой по host -> `Add Pane Content`.
4. Выделите созданный `TnbDockingPaneContent`.
5. Щёлкните правой кнопкой по pane -> `Split Pane Right` или `Split Pane Below`.
6. Помещайте обычные FMX-контролы внутрь нужного `TnbDockingPaneContent`.

Например:

```text
Form1
  nbDockingPaneHost1
    nbDockingPaneContent1
      Memo1
    nbDockingPaneContent2
      Layout1
      Button1
```

Для нескольких pane'ов одинаковой ориентации используйте:

```text
TnbDockingPaneHost.DesignChildrenOrientation = poHorizontal
```

или:

```text
poVertical
```

`AutoBuildDesignChildren = True` означает: host сам собирает docking-tree из
прямых дочерних `TnbDockingPaneContent` при загрузке формы.

### Как Класть Контролы В Pane

`TnbDockingPaneContent` — это обычный FMX-контейнер. Внутрь можно класть:

- `TLayout`
- `TRectangle`
- `TMemo`
- `TListBox`
- собственные FMX-контролы
- любые визуальные компоненты, которые нормально живут внутри FMX parent

Не следует вручную класть `TnbDockingPaneContent` внутрь другого
`TnbDockingPaneContent`. Для split'ов используйте контекстное меню:

```text
Split Pane Right
Split Pane Below
```

Так дизайнер создаст правильную структуру и splitters.

## Быстрый Старт: Runtime С TabHost

Обычно приложение создаёт собственный потомок `TnbDockingPaneContent`.

Минимальный пример:

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

Форма с `TnbDockingTabHost`:

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

`AddTab` вызывает `OnContentNeeded`. Если надо добавить уже готовую pane:

```pascal
FTabHost.AddTabWithContent('Server 1', TLogPane.Create(Self));
```

## Runtime Без Вкладок: PaneHost

Если вкладки не нужны, можно использовать `TnbDockingPaneHost` напрямую.

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

`SplitActive` принимает направление:

```pascal
sdLeft
sdRight
sdAbove
sdBelow
```

Если второй параметр `nil`, host запросит новую pane через `OnContentNeeded`.

## Header Actions

У `TnbDockingPaneContent` есть коллекция:

```pascal
HeaderActions: TDockingPaneHeaderActions
```

Каждый action содержит:

| Свойство | Назначение |
| --- | --- |
| `Id` | стабильный идентификатор кнопки |
| `Glyph` | символ или alias |
| `Hint` | tooltip |
| `OnExecute` | обработчик клика |

Пример runtime:

```pascal
AddHeaderAction('refresh', 'MDL2:E72C', HandleRefresh, 'Refresh');
AddHeaderAction('theme', 'theme', HandleTheme, 'Theme');
AddDefaultCloseAction;
```

`AddDefaultCloseAction` лучше вызывать последним, чтобы close-кнопка была
крайней справа.

### Glyph

`Glyph` понимает несколько удобных alias'ов:

| Значение | Результат |
| --- | --- |
| `add`, `plus`, `+` | плюс |
| `close`, `x` | закрыть |
| `broadcast`, `B` | broadcast |
| `sftp`, `folder`, `S` | папка |
| `theme`, `T` | тема |
| `MDL2:E712` | конкретный Segoe MDL2 Assets glyph |

В Object Inspector у `Glyph` есть редактор с кнопкой `...`: можно искать и
выбирать MDL2-символы визуально.

Если `Glyph` не распознан как alias или MDL2-код, он рисуется как обычный
текст.

## Важные Свойства

### TnbDockingPaneContent

| Свойство | Что делает |
| --- | --- |
| `Caption` | заголовок pane |
| `HeaderVisible` | показывает или скрывает header |
| `HeaderDragEnabled` | разрешает drag pane-заголовка |
| `AlwaysShowActive` | держит активную рамку даже без фокуса |
| `HeaderBgColor` | цвет фона карточки/header theme |
| `HeaderTextColor` | цвет текста и glyph'ов |
| `HeaderActions` | коллекция кнопок в заголовке |

События:

| Событие | Когда вызывается |
| --- | --- |
| `OnCloseRequest` | pane просит закрыться |
| `OnActivateRequest` | pane просит стать активной |
| `OnRenamed` | пользователь переименовал pane |
| `OnHeaderChanged` | изменились caption/colors/actions |

### TnbDockingPaneHost

| Свойство | Что делает |
| --- | --- |
| `BackgroundColor` | фон host'а |
| `AutoMatchBg` | подстраивает фон host'а под активную pane |
| `SplitterSize` | размер splitters |
| `SplitterColor` | цвет splitters |
| `AutoBuildDesignChildren` | строит дерево из design-time pane-детей |
| `DesignChildrenOrientation` | ориентация design-time pane-детей |
| `FocusMode` | временно показывает активную pane крупно + список слева |

События:

| Событие | Назначение |
| --- | --- |
| `OnContentNeeded` | host просит создать новую pane |
| `OnActiveLeafChanged` | изменился активный leaf |
| `OnContentHeaderChanged` | content поменял header |
| `OnHeaderDrag` | pane-заголовок тащат мышью |

### TnbDockingTabHost

| Свойство | Что делает |
| --- | --- |
| `TabBarColor` | фон tab bar |
| `TabActiveColor` | цвет активной вкладки |
| `TabInactiveColor` | цвет неактивной вкладки |
| `TabHoverColor` | hover цвет |
| `TabTextColor` | цвет текста вкладок |
| `AccentColor` | акцент drop/selection |
| `TabAddVisible` | показывает кнопку `+` |
| `TabBarActionText` | текст правой action-кнопки tab bar |
| `TabBarActionVisible` | показывает правую action-кнопку |
| `PaneHostAutoMatchBg` | прокидывается во внутренние hosts |

События:

| Событие | Назначение |
| --- | --- |
| `OnContentNeeded` | нужна новая pane для новой вкладки/split |
| `OnTabAdded` | вкладка добавлена |
| `OnTabClick` | клик по вкладке |
| `OnTabClosing` | можно отменить закрытие |
| `OnTabClosed` | вкладка закрыта |
| `OnActiveTabChanged` | активная вкладка изменилась |
| `OnTabBarActionClick` | клик по правой action-кнопке tab bar |

## Как Работает Drag & Drop

Поддерживаются два drag-сценария.

### Вкладка

- Перетащить вкладку внутри tab bar — reorder.
- Перетащить одиночную вкладку в область pane — split в выбранную сторону.
- Вкладку с несколькими pane'ами нельзя тащить как split-source, потому что
  она уже представляет группу.

### Pane Header

- Перетащить заголовок pane в tab bar — pane станет новой вкладкой.
- Перетащить заголовок pane в другую pane-zone — pane переедет как split.

Во время drag показывается drop preview.

## Focus Mode

`TnbDockingPaneHost.FocusMode` не меняет дерево layout'а. Он временно
перестраивает визуальный вид:

- слева список всех leaf'ов;
- справа активная pane на всё оставшееся пространство.

Выход из focus mode возвращает исходные split-пропорции.

```pascal
Host.EnterFocusMode;
Host.ExitFocusMode;
Host.ToggleFocusMode;
```

## Жизненный Цикл И Ownership

Важная идея: `TPaneTree` хранит ссылки на `TnbDockingPaneContent`, но не
владеет ими как owner.

Практические правила:

- Не освобождайте pane вручную, если она уже передана host'у.
- Для закрытия используйте `CloseActive`, close action или `RequestClose`.
- Для переноса между host'ами используется `TakeActiveContent` /
  `TakeLeafContent`: content вынимается из дерева, но не уничтожается.
- Не импортируйте `nbDocking.PaneHost` или `nbDocking.TabHost` в unit базового
  content-класса. Content общается снаружи через события.
- Если close происходит из click handler'а внутри закрываемой pane, free
  должен быть отложен на следующий tick. В компоненте это уже сделано.

## Build

Требуется RAD Studio / Delphi с FireMonkey.

Проверялось на Delphi 13.x.

```powershell
msbuild src\nbFMXDocking.dproj /t:Build /p:Config=Debug /p:Platform=Win64
msbuild demo\DockingTest.dproj /t:Build /p:Config=Debug /p:Platform=Win64
```

Для Win32:

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

Планируемые следующие слои:

1. `nbDocking.Shell` — layout из нескольких зон: sidebar, main, bottom.
2. `nbDocking.FloatWindow` — отстыковка pane в отдельную форму.
3. `nbDocking.Persistence` — сохранение/восстановление layout'а.
