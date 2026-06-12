# nbFMXDocking

Языки: [Русский](README.md) | [English](README.en.md) | [O'zbekcha](README.uz.md)

`nbFMXDocking` - набор Delphi FireMonkey-компонентов для интерфейсов с docking-панелями:
split-layout, вкладки групп, перетаскивание панелей, header actions и design-time сборка
layout-а прямо в RAD Studio.

Основной сценарий сейчас простой: на форму кладется один `TnbDockingPaneHost`.
Он сам управляет панелями, группами, вкладками и drop-preview. Отдельные low-level
компоненты не нужно бросать на форму вручную.

## Статус

Работает:

- `TnbDockingPaneHost` как основной компонент на палитре IDE.
- Design-time добавление панелей через context menu host-а.
- Design-time split панелей вправо или вниз через context menu pane.
- Runtime split-layout с горизонтальными и вертикальными разделителями.
- Runtime вкладки внутри `TnbDockingPaneHost`.
- Кнопка `+` на tabbar создает новую вкладку с новой панелью.
- Вкладка с одной панелью называется caption этой панели.
- Вкладка с несколькими панелями называется `Group`.
- Перетаскивание pane header в split-зоны.
- Перетаскивание pane header на tabbar: панель становится отдельной вкладкой.
- Перетаскивание одиночной вкладки с tabbar обратно в активную группу.
- Положение tabbar: сверху, снизу, слева, справа.
- Направление текста вкладок: auto, horizontal, vertical.
- Header actions через Object Inspector.
- Inline rename заголовка панели.
- Кнопка закрытия панели по умолчанию.
- Focus mode внутри host-а.

Пока не реализовано:

- floating windows;
- сохранение/восстановление layout-а в JSON;
- полноценная design-time коллекция вкладок;
- перенос целой вкладки-группы обратно как вложенной группы. Сейчас обратно переносится одиночная вкладка.

## Компоненты

### `TnbDockingPaneHost`

Главный компонент. Его нужно положить на форму и обычно установить `Align = Client`.

Отвечает за:

- дерево split-панелей;
- tabbar и вкладки групп;
- runtime drag/drop;
- drop overlay;
- создание content через `OnContentNeeded`;
- design-time layout из дочерних `TnbDockingPaneContent`.

Важные свойства:

| Свойство | Назначение |
| --- | --- |
| `VisibleTabs` | Показывает или скрывает tabbar. |
| `ShowAddButton` | Показывает кнопку `+` на tabbar. |
| `TabPosition` | `dtpTop`, `dtpBottom`, `dtpLeft`, `dtpRight`. |
| `TabTextDirection` | `ttdAuto`, `ttdHorizontal`, `ttdVertical`. |
| `DesignChildrenOrientation` | Направление первого design-time layout-а. |
| `DesignChildrenLayoutMode` | Split-layout или align-layout для design-time children. |
| `SplitterSize` | Толщина split-разделителя. |
| `SplitterColor` | Цвет разделителя/cover. |
| `AutoMatchBg` | Подстраивает фон host-а под активную панель. |

События:

| Событие | Назначение |
| --- | --- |
| `OnContentNeeded` | Вызывается, когда host-у нужна новая панель. |
| `OnActiveLeafChanged` | Активная панель изменилась. |
| `OnContentHeaderChanged` | Caption/header активной или дочерней панели изменился. |
| `OnHeaderDrag` | Наружное уведомление о drag pane header. |

### `TnbDockingPaneContent`

Карточка панели. Обычно создается design-time editor-ом или кодом приложения.

Отвечает за:

- header;
- caption;
- inline rename;
- close button;
- action buttons;
- рамку активной панели;
- клиентскую область для обычных FMX-контролов.

Важные свойства:

| Свойство | Назначение |
| --- | --- |
| `Caption` | Текст заголовка панели и имя одиночной вкладки. |
| `HeaderVisible` | Показывает header панели. |
| `HeaderDragEnabled` | Разрешает drag заголовка. В runtime host включает drag для своих панелей. |
| `CanClosePane` | Разрешает закрытие панели. |
| `ShowCloseButton` | Показывает кнопку закрытия. По умолчанию `True`. |
| `HeaderActions` | Коллекция action-кнопок справа в header. |
| `AllowResize` | Какие стороны разрешено ресайзить. |
| `MinPaneWidth`, `MinPaneHeight` | Минимальный размер панели. |

### `TnbDockingDemoPane`

Тестовая панель для разработки. Регистрируется на палитре только в `DEBUG`.

## Палитра IDE

После установки package в IDE на палитре `nb FMX Docking` доступен основной компонент:

```text
TnbDockingPaneHost
```

`TnbDockingPaneContent` создается через design-time команды host-а и pane, а не как отдельный основной компонент палитры.

## Быстрый старт в дизайнере

1. Положите `TnbDockingPaneHost` на форму.
2. Установите `Align = Client`.
3. Если нужны вкладки, установите `VisibleTabs = True`.
4. Правый клик по host -> `Add Pane Content`.
5. Выделите созданную панель.
6. Правый клик по панели -> `Split Pane Right` или `Split Pane Below`.
7. Поместите обычные FMX-контролы внутрь нужного `TnbDockingPaneContent`.

Пример структуры:

```text
Form1
  nbDockingPaneHost1
    nbDockingPaneContent1
      Memo1
    nbDockingPaneContent2
      Layout1
      Button1
```

В runtime пользователь может:

- тянуть header панели в split-зоны;
- тянуть header панели на tabbar, чтобы сделать новую вкладку;
- нажимать `+`, чтобы создать новую вкладку;
- тянуть одиночную вкладку обратно в активную группу.

## Создание панелей через код

Если нужна пользовательская панель при нажатии `+` или split-запросе, подпишитесь на
`OnContentNeeded`.

```pascal
procedure TForm1.DockHostContentNeeded(Sender: TObject;
  var AContent: TnbDockingPaneContent);
begin
  AContent := TnbDockingPaneContent.Create(Self);
  AContent.Caption := 'Terminal';

  // Внутрь AContent можно добавить любые FMX-контролы:
  // Memo1.Parent := AContent;
  // Memo1.Align := TAlignLayout.Client;
end;
```

Если обработчик не задан, `TnbDockingPaneHost` создаст простую дефолтную панель сам.

## Header Actions

У `TnbDockingPaneContent` есть коллекция `HeaderActions`. Ее можно настроить в Object Inspector
или кодом.

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

Кнопка закрытия создается автоматически. Управляют ею:

- `ShowCloseButton`;
- `CanClosePane`.

## Сборка и установка

Package находится здесь:

```text
src\nbFMXDocking.dproj
```

Сборка из Developer Command Prompt:

```powershell
msbuild src\nbFMXDocking.dproj /t:Build /p:Config=Debug /p:Platform=Win32
```

Для IDE нужен Win32 design-time BPL. После сборки установите `.bpl` через:

```text
Component -> Install Packages -> Add...
```

Для приложений добавьте `src` в `Unit Search Path`, например:

```text
Z:\Repos\Devops\nbFmxDocking\src
```

## Важное про package

Текущий package является design-time package:

```pascal
{$DESIGNONLY}
```

Он содержит registration unit и design editors. Для полноценной поставки runtime BPL позже
нужно разделить проект на два package:

- runtime package без `DesignIDE`, `Reg_*` и design editors;
- design-time package, который зависит от runtime package.

## Файлы проекта

```text
src\nbDocking.PaneHost.pas       основной host, split tree, tabbar, drag/drop
src\nbDocking.Types.pas          TnbDockingPaneContent и header actions
src\nbDocking.PaneTree.pas       дерево split-панелей
src\nbDocking.DropOverlay.pas    preview зон drop-а
src\nbDocking.DesignEditors.pas  design-time context menu и property editors
src\Reg_nbFMXDocking.pas         регистрация компонентов в IDE
demo\DockingDesignTest.dproj     тестовый проект
```

## Ограничения текущей версии

- Вкладки host-а пока runtime-only; полноценной published коллекции вкладок в Object Inspector нет.
- Перенос обратно с tabbar поддержан для одиночной вкладки. Вкладка-группа пока не переносится как единый nested group.
- `TnbDockingTabHost` остается в исходниках как legacy/compatibility unit, но основной рекомендуемый путь - `TnbDockingPaneHost`.
- Persistence layout-а пока должен реализовать внешний код приложения.

## Проверка перед публикацией

Минимальный набор:

```powershell
msbuild src\nbFMXDocking.dproj /t:Build /p:Config=Debug /p:Platform=Win32
msbuild src\nbFMXDocking.dproj /t:Build /p:Config=Debug /p:Platform=Win64
msbuild demo\DockingDesignTest.dproj /t:Build /p:Config=Debug /p:Platform=Win64
```

Рекомендуемый runtime smoke-test:

1. Создать несколько панелей design-time.
2. Запустить приложение.
3. Перетащить панель в split-зону.
4. Перетащить панель на tabbar.
5. Переключить вкладки.
6. Нажать `+`.
7. Перетащить одиночную вкладку обратно в активную группу.
