unit nbDocking.Types;

(*
  TnbDockingPaneContent — самодостаточная карточка (TRectangle):
  скругление углов, прозрачный rtHeader сверху (заголовок + action-кнопки),
  Client под содержимое потомка, опц. rtFooter снизу.

  Контент общается с хостом только через события (OnSplitRequest,
  OnCloseRequest, OnActivateRequest, OnHeaderDrag). Прямых ссылок на
  хост нет — это позволяет использовать любой потомок (терминал, SFTP,
  редактор) в любом контейнере.

  Заголовок умеет:
    - inline-rename (двойной клик по заголовку → TEdit → Enter/Esc);
    - drag-source (MouseDown/Move/Up на rtHeader → OnHeaderDrag);
    - кнопки-действия (glyph-кнопки) через AddHeaderAction.

  Активность: host вызывает SetActive(True/False) при смене ActiveLeaf —
  меняется цвет Stroke карточки.
*)

interface

uses
  System.Classes, System.SysUtils, System.JSON, System.UITypes, System.Types,
  System.Generics.Collections,
  System.Math,
  FMX.Types, FMX.Controls, FMX.Layouts, FMX.StdCtrls, FMX.Edit,
  FMX.Styles.Objects, FMX.Ani,
  FMX.Objects, FMX.Graphics;

type
  TSplitDirection = (sdLeft, sdRight, sdAbove, sdBelow);
  TPaneOrientation = (poHorizontal, poVertical);
  TPaneResizeSide = (rsHorizontal, rsVertical);
  TPaneResizeSides = set of TPaneResizeSide;
  TPaneHeaderDragPhase = (phdStart, phdMove, phdEnd);
  TPaneHeaderDragState = (hdsIdle, hdsArmed, hdsDragging);

  TnbDockingPaneContent = class;

  TPaneSplitRequestEvent = procedure(Sender: TnbDockingPaneContent;
    ADirection: TSplitDirection) of object;
  TPaneCloseRequestEvent = procedure(Sender: TnbDockingPaneContent) of object;
  TPaneActivateRequestEvent = procedure(Sender: TnbDockingPaneContent) of object;
  TPaneHeaderActionEvent = procedure(Sender: TnbDockingPaneContent;
    const AActionId: string) of object;

  (* Drag заголовка карточки. Координата — экранная (LocalToScreen). *)
  TContentHeaderDragEvent = procedure(ASender: TnbDockingPaneContent;
    APhase: TPaneHeaderDragPhase; const AScreenPt: TPointF) of object;

  TPaneRenamedEvent = procedure(ASender: TnbDockingPaneContent;
    const AOldCaption, ANewCaption: string) of object;

  (* Подписи/цвета header контента изменились — host обновляет внешние
     зависимости (например, подпись вкладки host-а). Сама карточка
     перерисовывается в setter'е, событие — только для тех, кто СНАРУЖИ. *)
  TPaneHeaderChangedEvent = procedure(Sender: TnbDockingPaneContent) of object;

  TDockingPaneHeaderAction = class(TCollectionItem)
  private
    FId: string;
    FGlyph: string;
    FHint: string;
    FOnExecute: TPaneHeaderActionEvent;
    procedure SetId(const AValue: string);
    procedure SetGlyph(const AValue: string);
    procedure SetHint(const AValue: string);
    procedure SetOnExecute(AValue: TPaneHeaderActionEvent);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(Collection: TCollection); override;

  published
    property Id: string read FId write SetId;
    property Glyph: string read FGlyph write SetGlyph;
    property Hint: string read FHint write SetHint;
    property OnExecute: TPaneHeaderActionEvent read FOnExecute
      write SetOnExecute;
  end;

  TDockingPaneHeaderActions = class(TOwnedCollection)
  private
    function GetItem(Index: Integer): TDockingPaneHeaderAction;
    procedure SetItem(Index: Integer; AValue: TDockingPaneHeaderAction);
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    constructor Create(AOwner: TPersistent);
    function Add: TDockingPaneHeaderAction;
    property Items[Index: Integer]: TDockingPaneHeaderAction
      read GetItem write SetItem; default;
  end;

  TPaneHeaderVectorIcon = class(TControl)
  private
    FIconColor: TAlphaColor;
    FIconName: string;
    procedure SetIconColor(const AValue: TAlphaColor);
    procedure SetIconName(const AValue: string);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    property IconName: string read FIconName write SetIconName;
    property IconColor: TAlphaColor read FIconColor write SetIconColor;
  end;

  (* Кнопка action в rtHeader — styled FMX button с привязанным id. *)
  TPaneHeaderActionButton = class(TSpeedButton)
  private
    FIcon: TPaneHeaderVectorIcon;
    FLocalBg: TAlphaColor;
    FLocalBorder: TAlphaColor;
    FLocalText: TAlphaColor;
    procedure HandleApplyStyleLookup(Sender: TObject);
    procedure HandleLocalMouseEnter(Sender: TObject);
    procedure HandleLocalMouseLeave(Sender: TObject);
  public
    ActionId: string;
    constructor Create(AOwner: TComponent); override;
    procedure PaintLocalChrome;
    procedure ApplyLocalChrome(ABg, ABorder, AText: TAlphaColor);
    procedure SetIconName(const AValue: string);
  end;

  TnbDockingPaneContent = class(TRectangle)
  private
    FHeader: TRectangle;
    FHeaderDivider: TRectangle;
    FCaptionLabel: TLabel;
    FCaptionEdit: TEdit;
    FActionsBar: TLayout;
    FFooter: TRectangle;

    FCaption: string;
    FHeaderBgColor: TAlphaColor;
    FHeaderTextColor: TAlphaColor;
    FInactiveStrokeColor: TAlphaColor;
    FActiveStrokeColor: TAlphaColor;
    FActive: Boolean;
    FEditingTitle: Boolean;
    FHeaderDragEnabled: Boolean;
    FAllowResize: TPaneResizeSides;
    FMinPaneWidth: Single;
    FMinPaneHeight: Single;
    FAlwaysShowActive: Boolean;
    FCanClose: Boolean;
    FShowCloseButton: Boolean;
    FDragState: TPaneHeaderDragState;
    FDragStartX, FDragStartY: Single;

    FHeaderActions: TDockingPaneHeaderActions;
    FActionButtons: TList<TPaneHeaderActionButton>;
    FHeaderActionStyleLookupPrefix: string;

    FOnSplitRequest: TPaneSplitRequestEvent;
    FOnCloseRequest: TPaneCloseRequestEvent;
    FOnActivateRequest: TPaneActivateRequestEvent;
    FOnHeaderDrag: TContentHeaderDragEvent;
    FOnRenamed: TPaneRenamedEvent;
    FOnHeaderChanged: TPaneHeaderChangedEvent;

    procedure SetCaption(const AValue: string);
    procedure SetHeaderBgColor(AValue: TAlphaColor);
    procedure SetHeaderTextColor(AValue: TAlphaColor);
    procedure SetHeaderVisible(AValue: Boolean);
    function GetHeaderVisible: Boolean;
    procedure SetMinPaneWidth(AValue: Single);
    procedure SetMinPaneHeight(AValue: Single);
    procedure SetHeaderActions(AValue: TDockingPaneHeaderActions);
    procedure SetHeaderActionStyleLookupPrefix(const AValue: string);
    procedure SetAlwaysShowActive(AValue: Boolean);
    procedure SetCanClose(AValue: Boolean);
    procedure SetShowCloseButton(AValue: Boolean);
    procedure ApplyHeaderColors;
    procedure DoHeaderChanged;
    procedure UpdateStrokeForActive;
    procedure RebuildActionButtons;
    procedure LayoutActionButtons;
    function ScopedHeaderActionStyle(const ABaseStyle: string): string;

    procedure HandleSelfMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure HandleHeaderMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure HandleHeaderMouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Single);
    procedure HandleHeaderMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure HandleHeaderDblClick(Sender: TObject);
    procedure HandleActionClick(Sender: TObject);
    procedure HandleActionMouseEnter(Sender: TObject);
    procedure HandleActionMouseLeave(Sender: TObject);
    procedure HandleEditExit(Sender: TObject);
    procedure HandleEditKeyDown(Sender: TObject; var Key: Word;
      var KeyChar: Char; Shift: TShiftState);
    procedure HandleCloseAction(Sender: TnbDockingPaneContent;
      const AActionId: string);
  protected
    procedure DoAddObject(const AObject: TFmxObject); override;

    (* Переопределить в потомке для реакции на активацию/деактивацию pane.
       Имена с префиксом DoPane*, чтобы не маскировать виртуальные
       DoActivate/DoDeactivate у TControl. *)
    procedure DoPaneActivate; virtual;
    procedure DoPaneDeactivate; virtual;

    (* Вспомогательные методы для потомков: попросить хост о split/close/activate. *)
    procedure RequestSplit(ADirection: TSplitDirection);
    procedure RequestClose;
    procedure RequestActivate;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Activate; reintroduce;
    procedure Deactivate; reintroduce;
    (* Default = True; override чтобы заблокировать закрытие. *)
    function CanClose: Boolean; virtual;

    (* Host -> карточка: смена статуса активности (меняет Stroke). *)
    procedure SetActive(AValue: Boolean);

    function AddHeaderAction(const AId, AGlyph: string;
      AOnExecute: TPaneHeaderActionEvent;
      const AHint: string = ''): TDockingPaneHeaderAction;
    (* Стандартный close-action ("x" → RequestClose). Конвенция: вызывать
       последним из конструктора потомка, чтобы ✕ был крайним справа. *)
    function AddDefaultCloseAction(const AHint: string = 'Close'): TDockingPaneHeaderAction;
    procedure RemoveHeaderAction(const AId: string);
    procedure ClearHeaderActions;
    function FindHeaderAction(const AId: string): TDockingPaneHeaderAction;
    procedure ExecuteHeaderAction(const AId: string);

    procedure BeginRename;
    procedure CommitRename;
    procedure CancelRename;

    (* Ленивое создание прозрачного rtFooter (Align=MostBottom, Height=24).
       Потомок получает доступ через свойство Footer и кладёт туда статус-бар,
       прогресс и т.п. *)
    procedure EnsureFooter;

    property Header: TRectangle read FHeader;
    property TitleBar: TRectangle read FHeader;
    property Footer: TRectangle read FFooter;
    property Active: Boolean read FActive;
    property HeaderActionStyleLookupPrefix: string
      read FHeaderActionStyleLookupPrefix
      write SetHeaderActionStyleLookupPrefix;
    (* True (по умолчанию) — header можно тащить, эмитируется OnHeaderDrag.
       False — drag-UX полностью отключён (для встроенных sub-pane'ов,
       которые не должны перетаскиваться между host'ами). *)
    (* True (по умолчанию) — rtHeader виден сверху карточки.
       False — header скрыт и не занимает места: контент начинается прямо
       от верхнего края карточки. Полезно для менеджеров, где имя уже
       показано в табе и в собственных sub-pane'ах. *)
    (* True — Stroke всегда рисуется яркой (как у активного pane), даже
     если SetActive(False). Для менеджер-карточек, у которых индикатор
     активности не нужен, а нужна стабильно видимая рамка. *)
    property OnSplitRequest: TPaneSplitRequestEvent
      read FOnSplitRequest write FOnSplitRequest;
    property OnHeaderDrag: TContentHeaderDragEvent
      read FOnHeaderDrag write FOnHeaderDrag;
  published
    property Caption: string read FCaption write SetCaption;
    property HeaderVisible: Boolean read GetHeaderVisible write SetHeaderVisible
      default True;
    property HeaderDragEnabled: Boolean read FHeaderDragEnabled
      write FHeaderDragEnabled default True;
    property AllowResize: TPaneResizeSides read FAllowResize
      write FAllowResize default [rsHorizontal, rsVertical];
    property MinPaneWidth: Single read FMinPaneWidth write SetMinPaneWidth;
    property MinPaneHeight: Single read FMinPaneHeight write SetMinPaneHeight;
    property AlwaysShowActive: Boolean read FAlwaysShowActive
      write SetAlwaysShowActive default False;
    property CanClosePane: Boolean read FCanClose write SetCanClose
      default True;
    property ShowCloseButton: Boolean read FShowCloseButton
      write SetShowCloseButton default True;
    property HeaderBgColor: TAlphaColor read FHeaderBgColor
      write SetHeaderBgColor default TAlphaColor($FF2A2A2A);
    property HeaderTextColor: TAlphaColor read FHeaderTextColor
      write SetHeaderTextColor default TAlphaColor($FFE0E0E0);
    property HeaderActions: TDockingPaneHeaderActions read FHeaderActions
      write SetHeaderActions;
    property OnCloseRequest: TPaneCloseRequestEvent
      read FOnCloseRequest write FOnCloseRequest;
    property OnActivateRequest: TPaneActivateRequestEvent
      read FOnActivateRequest write FOnActivateRequest;
    property OnRenamed: TPaneRenamedEvent
      read FOnRenamed write FOnRenamed;
    property OnHeaderChanged: TPaneHeaderChangedEvent
      read FOnHeaderChanged write FOnHeaderChanged;
  end;

  EDockingError = class(Exception);

implementation

const
  HEADER_HEIGHT       = 32;
  ACTION_BTN_WIDTH    = 24;
  ACTION_BTN_SLOT     = 28;   (* ширина кнопки + правый отступ *)
  CARD_RADIUS         = 0;
  CARD_PADDING_OTHER  = 0;
  CARD_PADDING_BOTTOM = 0;    (* защита скруглённого нижнего угла *)
  STROKE_THICKNESS    = 1.0;
  DRAG_THRESHOLD      = 5;

type
  (* Cast-наследник для доступа к protected Capture/ReleaseCapture. *)
  TControlAccess = class(TControl);

  TDockIconDef = record
    Fill: Boolean;
    Data: string;
  end;

const
  DOCK_ICON_DEFS_JSON =
    '{' +
    '"plus":{"fill":false,"data":"M 12 5 L 12 19 M 5 12 L 19 12"},' +
    '"close":{"fill":false,"data":"M 6 6 L 18 18 M 18 6 L 6 18"},' +
    '"save":{"fill":false,"data":"M 5 4 L 16 4 L 20 8 L 20 19 C 20 19.55 19.55 20 19 20 L 5 20 C 4.45 20 4 19.55 4 19 L 4 5 C 4 4.45 4.45 4 5 4 Z M 8 4 L 8 9.5 L 15 9.5 L 15 4 M 7 20 L 7 13.5 L 17 13.5 L 17 20"},' +
    '"delete":{"fill":false,"data":"M 4 7 L 20 7 M 9.5 7 L 9.5 5 C 9.5 4.45 9.95 4 10.5 4 L 13.5 4 C 14.05 4 14.5 4.45 14.5 5 L 14.5 7 M 6 7 L 7 19.1 C 7.04 19.6 7.5 20 8 20 L 16 20 C 16.5 20 16.96 19.6 17 19.1 L 18 7 M 10 10.5 L 10 16.5 M 14 10.5 L 14 16.5"},' +
    '"edit":{"fill":false,"data":"M 4.5 19.5 L 8.7 18.7 L 19 8.4 C 19.65 7.75 19.65 6.7 19 6.05 L 17.95 5 C 17.3 4.35 16.25 4.35 15.6 5 L 5.3 15.3 Z M 14.7 5.9 L 18.1 9.3"},' +
    '"refresh":{"fill":false,"data":"M 19 7 L 19 12 L 14 12 M 18.1 11.5 A 6.5 6.5 0 1 0 16.6 17.1 M 5 17 L 5 12 L 10 12 M 5.9 12.5 A 6.5 6.5 0 1 0 7.4 6.9"},' +
    '"copy":{"fill":false,"data":"M 10 9 L 19 9 C 19.55 9 20 9.45 20 10 L 20 19 C 20 19.55 19.55 20 19 20 L 10 20 C 9.45 20 9 19.55 9 19 L 9 10 C 9 9.45 9.45 9 10 9 Z M 5.5 15 L 5 15 C 4.45 15 4 14.55 4 14 L 4 5 C 4 4.45 4.45 4 5 4 L 14 4 C 14.55 4 15 4.45 15 5 L 15 5.5"},' +
    '"paste":{"fill":false,"data":"M 9.5 3.5 L 14.5 3.5 C 15.05 3.5 15.5 3.95 15.5 4.5 L 15.5 5.5 C 15.5 6.05 15.05 6.5 14.5 6.5 L 9.5 6.5 C 8.95 6.5 8.5 6.05 8.5 5.5 L 8.5 4.5 C 8.5 3.95 8.95 3.5 9.5 3.5 Z M 15.5 5 L 17 5 C 17.55 5 18 5.45 18 6 L 18 19.5 C 18 20.05 17.55 20.5 17 20.5 L 7 20.5 C 6.45 20.5 6 20.05 6 19.5 L 6 6 C 6 5.45 6.45 5 7 5 L 8.5 5"},' +
    '"download":{"fill":false,"data":"M 12 4 L 12 15.5 M 7 10.5 L 12 15.5 L 17 10.5 M 4 17 L 4 19 C 4 19.55 4.45 20 5 20 L 19 20 C 19.55 20 20 19.55 20 19 L 20 17"},' +
    '"play":{"fill":true,"data":"M 8.5 5.5 L 19 12 L 8.5 18.5 Z"},' +
    '"back":{"fill":false,"data":"M 20 12 L 4 12 M 10 6 L 4 12 L 10 18"},' +
    '"key":{"fill":false,"data":"M 4 11.5 A 3.25 3.25 0 1 0 10.5 11.5 A 3.25 3.25 0 1 0 4 11.5 M 10.5 11.5 L 20 11.5 M 16.5 11.5 L 16.5 15 M 20 11.5 L 20 14.5"},' +
    '"select":{"fill":false,"data":"M 4.5 12.5 L 9.5 17.5 L 19.5 6.5"},' +
    '"broadcast":{"fill":false,"data":"M 3 12 A 2 2 0 1 0 7 12 A 2 2 0 1 0 3 12 M 17 5 A 2 2 0 1 0 21 5 A 2 2 0 1 0 17 5 M 17 12 A 2 2 0 1 0 21 12 A 2 2 0 1 0 17 12 M 17 19 A 2 2 0 1 0 21 19 A 2 2 0 1 0 17 19 M 7 12 L 17 12 M 6.8 11.1 L 17.2 5.9 M 6.8 12.9 L 17.2 18.1"},' +
    '"folder":{"fill":false,"data":"M 4 6 C 4 5.45 4.45 5 5 5 L 9.6 5 L 11.6 7 L 19 7 C 19.55 7 20 7.45 20 8 L 20 18 C 20 18.55 19.55 19 19 19 L 5 19 C 4.45 19 4 18.55 4 18 Z"},' +
    '"theme":{"fill":false,"data":"M 12 21.5 A 9.5 9.5 0 1 1 21.5 12 C 21.5 13.65 20.15 15 18.5 15 L 16.5 15 C 15.4 15 14.5 15.9 14.5 17 C 14.5 17.5 14.7 17.95 15 18.35 C 15.3 18.75 15.5 19.2 15.5 19.7 C 15.5 20.7 14.7 21.5 13.7 21.5 Z M 12.5 6.5 A 1 1 0 1 0 14.5 6.5 A 1 1 0 1 0 12.5 6.5 M 16.5 10.5 A 1 1 0 1 0 18.5 10.5 A 1 1 0 1 0 16.5 10.5 M 7.5 7.5 A 1 1 0 1 0 9.5 7.5 A 1 1 0 1 0 7.5 7.5 M 5.5 12.5 A 1 1 0 1 0 7.5 12.5 A 1 1 0 1 0 5.5 12.5"},' +
    '"focus":{"fill":false,"data":"M 5 10 L 5 5 L 10 5 M 14 5 L 19 5 L 19 10 M 19 14 L 19 19 L 14 19 M 10 19 L 5 19 L 5 14"},' +
    '"scripts":{"fill":false,"data":"M 8 7 L 3.5 12 L 8 17 M 16 7 L 20.5 12 L 16 17 M 13.5 5.5 L 10.5 18.5"}' +
    '}';

  DOCK_ICON_ALIASES_JSON =
    '{' +
    '"add":"plus","create":"plus","plus":"plus","+":"plus",' +
    '"close":"close","cancel":"close","x":"close",' +
    '"delete":"delete","edit":"edit","reload":"refresh","refresh":"refresh",' +
    '"save":"save","copy":"copy","paste":"paste",' +
    '"import":"download","download":"download","generate":"key","key":"key",' +
    '"select":"select","back":"back","connect":"play","run":"play","play":"play",' +
    '"focus":"focus","scripts":"scripts","script":"scripts",' +
    '"broadcast":"broadcast","b":"broadcast",' +
    '"sftp":"folder","folder":"folder","s":"folder",' +
    '"theme":"theme","t":"theme"' +
    '}';

var
  GDockIconDefs: TDictionary<string, TDockIconDef>;
  GDockIconAliases: TDictionary<string, string>;

procedure EnsureDockIconAliases; forward;

function HeaderActionIconFor(const AId, AGlyph: string): string;
var
  Key, GlyphText: string;
begin
  EnsureDockIconAliases;
  Key := LowerCase(Trim(AId));
  if (Key <> '') and (GDockIconAliases <> nil)
     and GDockIconAliases.TryGetValue(Key, Result) then
    Exit;

  GlyphText := Trim(AGlyph);
  Key := LowerCase(GlyphText);
  if (Key <> '') and (GDockIconAliases <> nil)
     and GDockIconAliases.TryGetValue(Key, Result) then
    Exit;

  Result := LowerCase(GlyphText);
  if Result = '' then
    Result := 'dot';
end;

procedure EnsureDockIconAliases;
var
  Root: TJSONValue;
  Obj: TJSONObject;
  Pair: TJSONPair;
  I: Integer;
begin
  if GDockIconAliases <> nil then Exit;

  GDockIconAliases := TDictionary<string, string>.Create;
  Root := TJSONObject.ParseJSONValue(DOCK_ICON_ALIASES_JSON);
  try
    if not (Root is TJSONObject) then Exit;
    Obj := TJSONObject(Root);

    for I := 0 to Obj.Count - 1 do
    begin
      Pair := Obj.Pairs[I];
      if (Pair = nil) or (Pair.JsonValue = nil) then
        Continue;
      GDockIconAliases.AddOrSetValue(LowerCase(Pair.JsonString.Value),
        LowerCase(Pair.JsonValue.Value));
    end;
  finally
    Root.Free;
  end;
end;

procedure EnsureDockIconDefs;
var
  Root: TJSONValue;
  Obj, IconObj: TJSONObject;
  Pair: TJSONPair;
  FillValue, DataValue: TJSONValue;
  Def: TDockIconDef;
  I: Integer;
begin
  if GDockIconDefs <> nil then Exit;

  GDockIconDefs := TDictionary<string, TDockIconDef>.Create;
  Root := TJSONObject.ParseJSONValue(DOCK_ICON_DEFS_JSON);
  try
    if not (Root is TJSONObject) then Exit;
    Obj := TJSONObject(Root);

    for I := 0 to Obj.Count - 1 do
    begin
      Pair := Obj.Pairs[I];
      if (Pair = nil) or not (Pair.JsonValue is TJSONObject) then
        Continue;

      IconObj := TJSONObject(Pair.JsonValue);
      FillValue := IconObj.GetValue('fill');
      DataValue := IconObj.GetValue('data');
      if DataValue = nil then
        Continue;

      Def.Fill := (FillValue <> nil) and SameText(FillValue.Value, 'true');
      Def.Data := DataValue.Value;
      GDockIconDefs.AddOrSetValue(LowerCase(Pair.JsonString.Value), Def);
    end;
  finally
    Root.Free;
  end;
end;

procedure BuildDockIconPath(const AName: string; APath: TPathData;
  out AFill: Boolean);
var
  N: string;
  Def: TDockIconDef;
begin
  APath.Clear;
  AFill := False;
  N := LowerCase(Trim(AName));

  EnsureDockIconDefs;
  if (GDockIconDefs <> nil) and GDockIconDefs.TryGetValue(N, Def) then
  begin
    AFill := Def.Fill;
    APath.Data := Def.Data;
    Exit;
  end;

  AFill := True;
  APath.Data := 'M 12 9.5 A 2.5 2.5 0 1 0 12 14.5 A 2.5 2.5 0 1 0 12 9.5';
end;

function BlendColor(AColor1, AColor2: TAlphaColor;
  AWeight2: Single): TAlphaColor;
var
  W1: Single;
begin
  if AWeight2 < 0 then AWeight2 := 0;
  if AWeight2 > 1 then AWeight2 := 1;
  W1 := 1 - AWeight2;
  Result :=
    (Round(((AColor1 shr 24) and $FF) * W1 + ((AColor2 shr 24) and $FF) * AWeight2) shl 24) or
    (Round(((AColor1 shr 16) and $FF) * W1 + ((AColor2 shr 16) and $FF) * AWeight2) shl 16) or
    (Round(((AColor1 shr 8) and $FF) * W1 + ((AColor2 shr 8) and $FF) * AWeight2) shl 8) or
    Round((AColor1 and $FF) * W1 + (AColor2 and $FF) * AWeight2);
end;

{ TPaneHeaderVectorIcon }

constructor TPaneHeaderVectorIcon.Create(AOwner: TComponent);
begin
  inherited;
  FIconColor := TAlphaColors.White;
  FIconName := 'dot';
  HitTest := False;
end;

procedure TPaneHeaderVectorIcon.Paint;
var
  Path: TPathData;
  R: TRectF;
  FillIcon: Boolean;
begin
  inherited;
  if (Width <= 0) or (Height <= 0) then Exit;

  Path := TPathData.Create;
  try
    BuildDockIconPath(FIconName, Path, FillIcon);
    R := LocalRect;
    R.Inflate(-1, -1);
    Path.FitToRect(R);

    Canvas.Stroke.Kind := TBrushKind.Solid;
    Canvas.Stroke.Color := FIconColor;
    Canvas.Stroke.Thickness := 1.4;
    (* Скруглённые концы и стыки — иначе тонкие штрихи выглядят "рублеными" *)
    Canvas.Stroke.Cap := TStrokeCap.Round;
    Canvas.Stroke.Join := TStrokeJoin.Round;
    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Fill.Color := FIconColor;
    if FillIcon then
      Canvas.FillPath(Path, AbsoluteOpacity)
    else
      Canvas.DrawPath(Path, AbsoluteOpacity);
  finally
    Path.Free;
  end;
end;

procedure TPaneHeaderVectorIcon.SetIconColor(const AValue: TAlphaColor);
begin
  if FIconColor = AValue then Exit;
  FIconColor := AValue;
  Repaint;
end;

procedure TPaneHeaderVectorIcon.SetIconName(const AValue: string);
begin
  if SameText(FIconName, AValue) then Exit;
  FIconName := AValue;
  Repaint;
end;

{ TDockingPaneHeaderAction }

constructor TDockingPaneHeaderAction.Create(Collection: TCollection);
begin
  inherited;
end;

function TDockingPaneHeaderAction.GetDisplayName: string;
begin
  if FId <> '' then
    Result := FId
  else if FGlyph <> '' then
    Result := FGlyph
  else
    Result := inherited GetDisplayName;
end;

procedure TDockingPaneHeaderAction.SetId(const AValue: string);
begin
  if FId = AValue then Exit;
  FId := AValue;
  Changed(False);
end;

procedure TDockingPaneHeaderAction.SetGlyph(const AValue: string);
begin
  if FGlyph = AValue then Exit;
  FGlyph := AValue;
  Changed(False);
end;

procedure TDockingPaneHeaderAction.SetHint(const AValue: string);
begin
  if FHint = AValue then Exit;
  FHint := AValue;
  Changed(False);
end;

procedure TDockingPaneHeaderAction.SetOnExecute(
  AValue: TPaneHeaderActionEvent);
begin
  FOnExecute := AValue;
  Changed(False);
end;

{ TDockingPaneHeaderActions }

constructor TDockingPaneHeaderActions.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner, TDockingPaneHeaderAction);
end;

function TDockingPaneHeaderActions.Add: TDockingPaneHeaderAction;
begin
  Result := inherited Add as TDockingPaneHeaderAction;
end;

function TDockingPaneHeaderActions.GetItem(
  Index: Integer): TDockingPaneHeaderAction;
begin
  Result := inherited GetItem(Index) as TDockingPaneHeaderAction;
end;

procedure TDockingPaneHeaderActions.SetItem(Index: Integer;
  AValue: TDockingPaneHeaderAction);
begin
  inherited SetItem(Index, AValue);
end;

procedure TDockingPaneHeaderActions.Update(Item: TCollectionItem);
var
  Owner: TPersistent;
begin
  inherited;
  Owner := GetOwner;
  if Owner is TnbDockingPaneContent then
    TnbDockingPaneContent(Owner).RebuildActionButtons;
end;

{ TPaneHeaderActionButton }

constructor TPaneHeaderActionButton.Create(AOwner: TComponent);
begin
  inherited;
  FLocalBg := TAlphaColor($FF2A2A2A);
  FLocalBorder := TAlphaColor($40E0E0E0);
  FLocalText := TAlphaColor($FFE0E0E0);
  Text := '';
  FIcon := TPaneHeaderVectorIcon.Create(Self);
  FIcon.Parent := Self;
  FIcon.Align := TAlignLayout.Client;
  FIcon.Margins.Rect := RectF(5, 5, 5, 5);
  FIcon.IconColor := FLocalText;
  FIcon.HitTest := False;
  OnApplyStyleLookup := HandleApplyStyleLookup;
  OnMouseEnter := HandleLocalMouseEnter;
  OnMouseLeave := HandleLocalMouseLeave;
end;

procedure TPaneHeaderActionButton.HandleApplyStyleLookup(Sender: TObject);
begin
  PaintLocalChrome;
end;

procedure TPaneHeaderActionButton.HandleLocalMouseEnter(Sender: TObject);
begin
  Opacity := 1.0;
  PaintLocalChrome;
end;

procedure TPaneHeaderActionButton.HandleLocalMouseLeave(Sender: TObject);
begin
  Opacity := 0.72;
  PaintLocalChrome;
end;

procedure TPaneHeaderActionButton.PaintLocalChrome;
var
  Obj: TFmxObject;
  Shape: TShape;
  HoverBg, HoverBorder: TAlphaColor;

  procedure DisableStyleColorAnimations(AObject: TFmxObject);
  var
    I: Integer;
    Anim: TColorAnimation;
    Prop: string;
  begin
    if AObject = nil then
      Exit;

    if AObject is TColorAnimation then
    begin
      Anim := TColorAnimation(AObject);
      Prop := LowerCase(Anim.PropertyName);
      if Prop = 'fill.color' then
      begin
        Anim.StartValue := FLocalBg;
        Anim.StopValue := HoverBg;
        Anim.Enabled := False;
      end
      else if Prop = 'stroke.color' then
      begin
        Anim.StartValue := FLocalBorder;
        Anim.StopValue := HoverBorder;
        Anim.Enabled := False;
      end;
    end;

    for I := 0 to AObject.ChildrenCount - 1 do
      DisableStyleColorAnimations(AObject.Children[I]);
  end;

  procedure PaintShape(const AName: string);
  var
    Bg, Border: TAlphaColor;
  begin
    Obj := FindStyleResource(AName);
    if Obj is TShape then
    begin
      Shape := TShape(Obj);
      Bg := FLocalBg;
      Border := FLocalBorder;
      if Opacity >= 0.99 then
      begin
        Bg := HoverBg;
        Border := HoverBorder;
      end;
      Shape.Fill.Kind := TBrushKind.Solid;
      Shape.Fill.Color := Bg;
      Shape.Stroke.Kind := TBrushKind.Solid;
      Shape.Stroke.Color := Border;
    end;
  end;

begin
  HoverBg := BlendColor(FLocalBg, FLocalText, 0.10);
  HoverBorder := BlendColor(FLocalBorder, FLocalText, 0.42);
  StyledSettings := StyledSettings - [TStyledSetting.FontColor,
    TStyledSetting.Family, TStyledSetting.Size];
  Text := '';
  TextSettings.FontColor := FLocalText;
  if FIcon <> nil then
    FIcon.IconColor := FLocalText;
  DisableStyleColorAnimations(ResourceLink);
  PaintShape('background');
  PaintShape('bg');
end;

procedure TPaneHeaderActionButton.ApplyLocalChrome(ABg, ABorder,
  AText: TAlphaColor);
begin
  FLocalBg := ABg;
  FLocalBorder := ABorder;
  FLocalText := AText;
  ApplyStyleLookup;
  PaintLocalChrome;
end;

procedure TPaneHeaderActionButton.SetIconName(const AValue: string);
begin
  Text := '';
  if FIcon <> nil then
    FIcon.IconName := AValue;
end;

{ TnbDockingPaneContent }

constructor TnbDockingPaneContent.Create(AOwner: TComponent);
begin
  inherited;

  (* Карточка: скругление + padding (защита от прямоугольного содержимого
     по краям) + цветной Stroke (индикатор активности). *)
  Align := TAlignLayout.Client;
  HitTest := True;
  XRadius := 0;
  YRadius := 0;
  Padding.Rect := RectF(CARD_PADDING_OTHER, CARD_PADDING_OTHER,
                        CARD_PADDING_OTHER, CARD_PADDING_BOTTOM);
  Fill.Kind := TBrushKind.Solid;
  Stroke.Kind := TBrushKind.Solid;
  Stroke.Thickness := STROKE_THICKNESS;
  OnMouseDown := HandleSelfMouseDown;

  FHeaderBgColor := TAlphaColor($FF2A2A2A);
  FHeaderTextColor := TAlphaColor($FFE0E0E0);
  FHeaderDragEnabled := True;
  FAllowResize := [rsHorizontal, rsVertical];
  FMinPaneWidth := 50;
  FMinPaneHeight := 50;
  FCanClose := True;
  FShowCloseButton := True;

  FHeaderActions := TDockingPaneHeaderActions.Create(Self);
  FActionButtons := TList<TPaneHeaderActionButton>.Create;

  (* rtHeader — прозрачный полоска MostTop. Текст и кнопки рисуются прямо
     на фоне карточки (Fill.Color = HeaderBgColor). *)
  FHeader := TRectangle.Create(Self);
  FHeader.Parent := Self;
  FHeader.Stored := False;
  FHeader.Locked := True;
  FHeader.Align := TAlignLayout.MostTop;
  FHeader.Height := HEADER_HEIGHT;
  FHeader.Fill.Kind := TBrushKind.None;
  FHeader.Stroke.Kind := TBrushKind.None;
  FHeader.HitTest := True;
  FHeader.OnMouseDown := HandleHeaderMouseDown;
  FHeader.OnMouseMove := HandleHeaderMouseMove;
  FHeader.OnMouseUp := HandleHeaderMouseUp;
  FHeader.OnDblClick := HandleHeaderDblClick;

  (* ActionsBar — Align=Right в rtHeader. Создаётся ДО Caption, чтобы FMX
     отдал Caption (Align=Client) только остаток ширины. *)
  FActionsBar := TLayout.Create(Self);
  FActionsBar.Parent := FHeader;
  FActionsBar.Stored := False;
  FActionsBar.Locked := True;
  FActionsBar.Align := TAlignLayout.Right;
  FActionsBar.Width := 0;
  FActionsBar.HitTest := True;

  FCaptionLabel := TLabel.Create(Self);
  FCaptionLabel.Parent := FHeader;
  FCaptionLabel.Stored := False;
  FCaptionLabel.Locked := True;
  FCaptionLabel.Align := TAlignLayout.Client;
  FCaptionLabel.Margins.Rect := RectF(8, 0, 4, 0);
  FCaptionLabel.TextSettings.HorzAlign := TTextAlign.Leading;
  FCaptionLabel.TextSettings.VertAlign := TTextAlign.Center;
  FCaptionLabel.TextSettings.Font.Size := 12;
  FCaptionLabel.StyledSettings := [];
  FCaptionLabel.HitTest := False;

  FCaptionEdit := TEdit.Create(Self);
  FCaptionEdit.Parent := FHeader;
  FCaptionEdit.Stored := False;
  FCaptionEdit.Locked := True;
  FCaptionEdit.Align := TAlignLayout.Client;
  FCaptionEdit.Margins.Rect := RectF(8, 2, 4, 2);
  FCaptionEdit.Visible := False;
  FCaptionEdit.OnExit := HandleEditExit;
  FCaptionEdit.OnKeyDown := HandleEditKeyDown;

  FHeaderDivider := TRectangle.Create(Self);
  FHeaderDivider.Parent := FHeader;
  FHeaderDivider.Stored := False;
  FHeaderDivider.Locked := True;
  FHeaderDivider.Align := TAlignLayout.Bottom;
  FHeaderDivider.Height := 1;
  FHeaderDivider.Fill.Kind := TBrushKind.Solid;
  FHeaderDivider.Stroke.Kind := TBrushKind.None;
  FHeaderDivider.HitTest := False;

  ApplyHeaderColors;
  AddDefaultCloseAction;
end;

destructor TnbDockingPaneContent.Destroy;
var
  I: Integer;
begin
  for I := FActionButtons.Count - 1 downto 0 do
    FActionButtons[I].Free;
  FActionButtons.Free;
  FHeaderActions.Free;
  inherited;
end;

procedure TnbDockingPaneContent.DoAddObject(const AObject: TFmxObject);
begin
  inherited;

  if (AObject is TnbDockingPaneContent)
     and (AObject.Parent = Self)
     and (Parent <> nil)
     and not (csLoading in ComponentState) then
    AObject.Parent := Parent;
end;

procedure TnbDockingPaneContent.ApplyHeaderColors;
var
  I: Integer;
  Btn: TPaneHeaderActionButton;
begin
  Fill.Color := FHeaderBgColor;
  if FHeaderDivider <> nil then
    FHeaderDivider.Fill.Color := BlendColor(FHeaderBgColor, FHeaderTextColor,
      0.13);
  if FCaptionLabel <> nil then
    FCaptionLabel.TextSettings.FontColor := FHeaderTextColor;

  (* Activity is shown only by the pane outline; the content keeps its own
     terminal/theme colors. *)
  FActiveStrokeColor := BlendColor(FHeaderBgColor, FHeaderTextColor, 0.48);
  FInactiveStrokeColor := BlendColor(FHeaderBgColor, FHeaderTextColor, 0.13);

  (* Header action buttons are flat; only glyph color follows pane header. *)
  for I := 0 to FActionButtons.Count - 1 do
  begin
    Btn := FActionButtons[I];
    Btn.StyleLookup := ScopedHeaderActionStyle('speedbuttonstyle');
    Btn.StyledSettings := Btn.StyledSettings - [TStyledSetting.FontColor];
    Btn.SetIconName(HeaderActionIconFor(Btn.ActionId, Btn.Text));
    Btn.TextSettings.FontColor := FHeaderTextColor;
    Btn.ApplyLocalChrome(FHeaderBgColor,
      BlendColor(FHeaderBgColor, FHeaderTextColor, 0.22),
      FHeaderTextColor);
  end;

  UpdateStrokeForActive;
end;

procedure TnbDockingPaneContent.UpdateStrokeForActive;
begin
  Stroke.Kind := TBrushKind.Solid;
  Stroke.Thickness := STROKE_THICKNESS;
  Padding.Rect := RectF(CARD_PADDING_OTHER, CARD_PADDING_OTHER,
    CARD_PADDING_OTHER, CARD_PADDING_OTHER);
  if FActive or FAlwaysShowActive then
  begin
    Stroke.Color := FActiveStrokeColor
  end
  else
  begin
    Stroke.Color := FInactiveStrokeColor;
  end;
end;

procedure TnbDockingPaneContent.SetCaption(const AValue: string);
var
  Old: string;
begin
  if FCaption = AValue then Exit;
  Old := FCaption;
  FCaption := AValue;
  if FCaptionLabel <> nil then
    FCaptionLabel.Text := AValue;
  if Assigned(FOnRenamed) then
    FOnRenamed(Self, Old, AValue);
  DoHeaderChanged;
end;

procedure TnbDockingPaneContent.SetHeaderBgColor(AValue: TAlphaColor);
begin
  if FHeaderBgColor = AValue then Exit;
  FHeaderBgColor := AValue;
  ApplyHeaderColors;
  DoHeaderChanged;
end;

procedure TnbDockingPaneContent.SetHeaderTextColor(AValue: TAlphaColor);
begin
  if FHeaderTextColor = AValue then Exit;
  FHeaderTextColor := AValue;
  ApplyHeaderColors;
  DoHeaderChanged;
end;

procedure TnbDockingPaneContent.SetHeaderVisible(AValue: Boolean);
begin
  if FHeader = nil then Exit;
  if FHeader.Visible = AValue then Exit;
  FHeader.Visible := AValue;
  (* Height=0 при скрытии — иначе FMX Align=MostTop может оставить gap. *)
  if AValue then
    FHeader.Height := HEADER_HEIGHT
  else
    FHeader.Height := 0;
end;

function TnbDockingPaneContent.GetHeaderVisible: Boolean;
begin
  Result := (FHeader <> nil) and FHeader.Visible;
end;

procedure TnbDockingPaneContent.SetMinPaneWidth(AValue: Single);
begin
  AValue := Max(0, AValue);
  if SameValue(FMinPaneWidth, AValue) then Exit;
  FMinPaneWidth := AValue;
end;

procedure TnbDockingPaneContent.SetMinPaneHeight(AValue: Single);
begin
  AValue := Max(0, AValue);
  if SameValue(FMinPaneHeight, AValue) then Exit;
  FMinPaneHeight := AValue;
end;

procedure TnbDockingPaneContent.SetHeaderActions(
  AValue: TDockingPaneHeaderActions);
begin
  FHeaderActions.Assign(AValue);
  RebuildActionButtons;
end;

function TnbDockingPaneContent.ScopedHeaderActionStyle(
  const ABaseStyle: string): string;
begin
  if FHeaderActionStyleLookupPrefix = '' then
    Result := ABaseStyle
  else
    Result := FHeaderActionStyleLookupPrefix + ABaseStyle;
end;

procedure TnbDockingPaneContent.SetHeaderActionStyleLookupPrefix(
  const AValue: string);
begin
  if FHeaderActionStyleLookupPrefix = AValue then Exit;
  FHeaderActionStyleLookupPrefix := AValue;
  ApplyHeaderColors;
end;

procedure TnbDockingPaneContent.SetAlwaysShowActive(AValue: Boolean);
begin
  if FAlwaysShowActive = AValue then Exit;
  FAlwaysShowActive := AValue;
  UpdateStrokeForActive;
end;

procedure TnbDockingPaneContent.DoHeaderChanged;
begin
  if Assigned(FOnHeaderChanged) then
    FOnHeaderChanged(Self);
end;

procedure TnbDockingPaneContent.SetActive(AValue: Boolean);
begin
  if FActive = AValue then Exit;
  FActive := AValue;
  UpdateStrokeForActive;
end;

procedure TnbDockingPaneContent.Activate;
begin
  DoPaneActivate;
end;

procedure TnbDockingPaneContent.Deactivate;
begin
  DoPaneDeactivate;
end;

function TnbDockingPaneContent.CanClose: Boolean;
begin
  Result := FCanClose;
end;

procedure TnbDockingPaneContent.SetCanClose(AValue: Boolean);
begin
  if FCanClose = AValue then Exit;
  FCanClose := AValue;
end;

procedure TnbDockingPaneContent.SetShowCloseButton(AValue: Boolean);
begin
  if FShowCloseButton = AValue then Exit;
  FShowCloseButton := AValue;
  if FShowCloseButton then
    AddDefaultCloseAction
  else
    RemoveHeaderAction('close');
end;

procedure TnbDockingPaneContent.DoPaneActivate;
begin
end;

procedure TnbDockingPaneContent.DoPaneDeactivate;
begin
end;

procedure TnbDockingPaneContent.RequestSplit(ADirection: TSplitDirection);
begin
  if Assigned(FOnSplitRequest) then
    FOnSplitRequest(Self, ADirection);
end;

procedure TnbDockingPaneContent.RequestClose;
begin
  if Assigned(FOnCloseRequest) then
    FOnCloseRequest(Self);
end;

procedure TnbDockingPaneContent.RequestActivate;
begin
  if Assigned(FOnActivateRequest) then
    FOnActivateRequest(Self);
end;

procedure TnbDockingPaneContent.HandleSelfMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  (* Любой клик в карточку = запрос активации.
     Дочерние контролы потомков, которые сами потребляют клик,
     могут вызвать RequestActivate явно (см. TFleetTerminalPane). *)
  RequestActivate;
end;

procedure TnbDockingPaneContent.HandleHeaderMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  if Button <> TMouseButton.mbLeft then Exit;
  if FEditingTitle then Exit;
  RequestActivate;
  if not FHeaderDragEnabled then Exit;
  FDragState := hdsArmed;
  FDragStartX := X;
  FDragStartY := Y;
  TControlAccess(FHeader).Capture;
end;

procedure TnbDockingPaneContent.HandleHeaderMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Single);
var
  ScreenPt: TPointF;
begin
  if FDragState = hdsIdle then Exit;
  if FEditingTitle then Exit;

  if FDragState = hdsArmed then
  begin
    if (Abs(X - FDragStartX) > DRAG_THRESHOLD) or
       (Abs(Y - FDragStartY) > DRAG_THRESHOLD) then
    begin
      FDragState := hdsDragging;
      Opacity := 0.6;
      ScreenPt := FHeader.LocalToScreen(PointF(X, Y));
      if Assigned(FOnHeaderDrag) then
        FOnHeaderDrag(Self, phdStart, ScreenPt);
    end;
  end;

  if FDragState = hdsDragging then
  begin
    ScreenPt := FHeader.LocalToScreen(PointF(X, Y));
    if Assigned(FOnHeaderDrag) then
      FOnHeaderDrag(Self, phdMove, ScreenPt);
  end;
end;

procedure TnbDockingPaneContent.HandleHeaderMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  ScreenPt: TPointF;
  WasDragging: Boolean;
begin
  if Button <> TMouseButton.mbLeft then Exit;
  if FEditingTitle then Exit;
  TControlAccess(FHeader).ReleaseCapture;
  WasDragging := FDragState = hdsDragging;
  FDragState := hdsIdle;
  Opacity := 1.0;
  if WasDragging and Assigned(FOnHeaderDrag) then
  begin
    ScreenPt := FHeader.LocalToScreen(PointF(X, Y));
    FOnHeaderDrag(Self, phdEnd, ScreenPt);
  end;
end;

procedure TnbDockingPaneContent.HandleHeaderDblClick(Sender: TObject);
begin
  BeginRename;
end;

procedure TnbDockingPaneContent.BeginRename;
begin
  if FEditingTitle then Exit;
  FDragState := hdsIdle;
  TControlAccess(FHeader).ReleaseCapture;
  FEditingTitle := True;
  FCaptionLabel.Visible := False;
  FCaptionEdit.Text := FCaption;
  FCaptionEdit.Visible := True;
  FCaptionEdit.SetFocus;
  FCaptionEdit.SelectAll;
end;

procedure TnbDockingPaneContent.CommitRename;
var
  NewCap: string;
begin
  if not FEditingTitle then Exit;
  FEditingTitle := False;
  NewCap := Trim(FCaptionEdit.Text);
  FCaptionEdit.Visible := False;
  FCaptionLabel.Visible := True;
  if (NewCap <> '') and (NewCap <> FCaption) then
    Caption := NewCap;
end;

procedure TnbDockingPaneContent.CancelRename;
begin
  if not FEditingTitle then Exit;
  FEditingTitle := False;
  FCaptionEdit.Visible := False;
  FCaptionLabel.Visible := True;
end;

procedure TnbDockingPaneContent.HandleEditExit(Sender: TObject);
begin
  CommitRename;
end;

procedure TnbDockingPaneContent.HandleEditKeyDown(Sender: TObject;
  var Key: Word; var KeyChar: Char; Shift: TShiftState);
begin
  case Key of
    vkReturn:
      begin
        Key := 0;
        CommitRename;
      end;
    vkEscape:
      begin
        Key := 0;
        CancelRename;
      end;
  end;
end;

procedure TnbDockingPaneContent.HandleActionClick(Sender: TObject);
var
  Btn: TPaneHeaderActionButton;
  ActionId: string;
begin
  if FEditingTitle then Exit;
  if not (Sender is TPaneHeaderActionButton) then Exit;
  Btn := TPaneHeaderActionButton(Sender);
  ActionId := Btn.ActionId;
  RequestActivate;
  TThread.ForceQueue(nil,
    procedure
    begin
      if not (csDestroying in ComponentState) then
        ExecuteHeaderAction(ActionId);
    end);
end;

procedure TnbDockingPaneContent.HandleCloseAction(
  Sender: TnbDockingPaneContent; const AActionId: string);
begin
  RequestClose;
end;

function TnbDockingPaneContent.AddHeaderAction(const AId, AGlyph: string;
  AOnExecute: TPaneHeaderActionEvent;
  const AHint: string): TDockingPaneHeaderAction;
begin
  if Trim(AId) = '' then
    raise EDockingError.Create('TnbDockingPaneContent.AddHeaderAction: empty action id');
  if FindHeaderAction(AId) <> nil then
    raise EDockingError.CreateFmt(
      'TnbDockingPaneContent.AddHeaderAction: duplicate action id "%s"', [AId]);

  FHeaderActions.BeginUpdate;
  try
    Result := FHeaderActions.Add;
    Result.FId := AId;
    Result.FGlyph := AGlyph;
    Result.FHint := AHint;
    Result.FOnExecute := AOnExecute;
  finally
    FHeaderActions.EndUpdate;
  end;
  RebuildActionButtons;
end;

function TnbDockingPaneContent.AddDefaultCloseAction(const AHint: string): TDockingPaneHeaderAction;
begin
  (* Всегда удаляем и добавляем заново, чтобы ✕ оказался последним *)
  RemoveHeaderAction('close');
  Result := AddHeaderAction('close', 'x', HandleCloseAction, AHint);
end;

procedure TnbDockingPaneContent.RemoveHeaderAction(const AId: string);
var
  I: Integer;
begin
  for I := FHeaderActions.Count - 1 downto 0 do
    if SameText(FHeaderActions[I].Id, AId) then
    begin
      FHeaderActions.Delete(I);
      RebuildActionButtons;
      Exit;
    end;
end;

procedure TnbDockingPaneContent.ClearHeaderActions;
begin
  if FHeaderActions.Count = 0 then Exit;
  FHeaderActions.Clear;
  RebuildActionButtons;
end;

function TnbDockingPaneContent.FindHeaderAction(
  const AId: string): TDockingPaneHeaderAction;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FHeaderActions.Count - 1 do
    if SameText(FHeaderActions[I].Id, AId) then
      Exit(FHeaderActions[I]);
end;

procedure TnbDockingPaneContent.ExecuteHeaderAction(const AId: string);
var
  Action: TDockingPaneHeaderAction;
begin
  Action := FindHeaderAction(AId);
  if (Action <> nil) and Assigned(Action.OnExecute) then
    Action.OnExecute(Self, Action.Id)
  else if (Action <> nil) and SameText(Action.Id, 'close') then
    RequestClose;
end;

procedure TnbDockingPaneContent.RebuildActionButtons;
var
  I: Integer;
  Action: TDockingPaneHeaderAction;
  Btn: TPaneHeaderActionButton;
begin
  if FActionsBar = nil then Exit;

  for I := FActionButtons.Count - 1 downto 0 do
    FActionButtons[I].Free;
  FActionButtons.Clear;

  for I := 0 to FHeaderActions.Count - 1 do
  begin
    Action := FHeaderActions[I];
    Btn := TPaneHeaderActionButton.Create(Self);
    Btn.Parent := FActionsBar;
    Btn.Stored := False;
    Btn.Locked := True;
    Btn.Align := TAlignLayout.None;
    Btn.Width := ACTION_BTN_WIDTH;
    Btn.Height := ACTION_BTN_WIDTH;
    Btn.Margins.Rect := RectF(0, 2, 4, 2);
    Btn.StyleLookup := ScopedHeaderActionStyle('speedbuttonstyle');
    Btn.SetIconName(HeaderActionIconFor(Action.Id, Action.Glyph));
    Btn.StyledSettings := Btn.StyledSettings - [TStyledSetting.FontColor];
    Btn.TextSettings.HorzAlign := TTextAlign.Center;
    Btn.TextSettings.VertAlign := TTextAlign.Center;
    Btn.TextSettings.FontColor := FHeaderTextColor;
    Btn.TextSettings.Trimming := TTextTrimming.None;
    Btn.ApplyLocalChrome(FHeaderBgColor,
      BlendColor(FHeaderBgColor, FHeaderTextColor, 0.22),
      FHeaderTextColor);
    Btn.Opacity := 0.72;
    Btn.HitTest := True;
    Btn.ActionId := Action.Id;
    Btn.OnClick := HandleActionClick;
    Btn.OnMouseEnter := HandleActionMouseEnter;
    Btn.OnMouseLeave := HandleActionMouseLeave;
    if Action.Hint <> '' then
    begin
      Btn.Hint := Action.Hint;
      Btn.ShowHint := True;
    end;
    FActionButtons.Add(Btn);
  end;

  LayoutActionButtons;
end;

procedure TnbDockingPaneContent.LayoutActionButtons;
var
  I: Integer;
begin
  for I := 0 to FActionButtons.Count - 1 do
  begin
    FActionButtons[I].Position.X := I * ACTION_BTN_SLOT;
    FActionButtons[I].Position.Y := (HEADER_HEIGHT - ACTION_BTN_WIDTH) / 2;
    FActionButtons[I].Width := ACTION_BTN_WIDTH;
    FActionButtons[I].Height := ACTION_BTN_WIDTH;
  end;
  FActionsBar.Width := FActionButtons.Count * ACTION_BTN_SLOT;
end;

procedure TnbDockingPaneContent.HandleActionMouseEnter(Sender: TObject);
begin
  if Sender is TPaneHeaderActionButton then
  begin
    TPaneHeaderActionButton(Sender).Opacity := 1.0;
    TPaneHeaderActionButton(Sender).PaintLocalChrome;
  end;
end;

procedure TnbDockingPaneContent.HandleActionMouseLeave(Sender: TObject);
begin
  if Sender is TPaneHeaderActionButton then
  begin
    TPaneHeaderActionButton(Sender).Opacity := 0.72;
    TPaneHeaderActionButton(Sender).PaintLocalChrome;
  end;
end;

procedure TnbDockingPaneContent.EnsureFooter;
begin
  if FFooter <> nil then Exit;
  FFooter := TRectangle.Create(Self);
  FFooter.Parent := Self;
  FFooter.Stored := False;
  FFooter.Locked := True;
  FFooter.Align := TAlignLayout.MostBottom;
  FFooter.Height := 24;
  FFooter.Fill.Kind := TBrushKind.None;
  FFooter.Stroke.Kind := TBrushKind.None;
  FFooter.HitTest := True;
end;

initialization
  RegisterFmxClasses([TnbDockingPaneContent, TPaneHeaderActionButton]);
finalization
  GDockIconAliases.Free;
  GDockIconDefs.Free;

end.
