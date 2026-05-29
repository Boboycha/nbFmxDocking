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
  System.Classes, System.SysUtils, System.UITypes, System.Types,
  System.Generics.Collections,
  System.Math,
  FMX.Types, FMX.Controls, FMX.Layouts, FMX.StdCtrls, FMX.Edit,
  FMX.Styles.Objects,
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
     зависимости (например, подпись таба в TabHost). Сама карточка
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

  (* Кнопка action в rtHeader — styled FMX button с привязанным id. *)
  TPaneHeaderActionButton = class(TSpeedButton)
  private
    FLocalBg: TAlphaColor;
    FLocalBorder: TAlphaColor;
    FLocalText: TAlphaColor;
    procedure HandleApplyStyleLookup(Sender: TObject);
    procedure PaintLocalChrome;
  public
    ActionId: string;
    UsesIconFont: Boolean;
    constructor Create(AOwner: TComponent); override;
    procedure ApplyLocalChrome(ABg, ABorder, AText: TAlphaColor);
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
    function AddDefaultCloseAction: TDockingPaneHeaderAction;
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
  ACTION_BTN_WIDTH    = 22;
  ACTION_BTN_SLOT     = 25;   (* ширина кнопки + правый отступ *)
  CARD_RADIUS         = 0;
  CARD_PADDING_OTHER  = 0;
  CARD_PADDING_BOTTOM = 0;    (* защита скруглённого нижнего угла *)
  STROKE_THICKNESS    = 1.0;
  DRAG_THRESHOLD      = 5;
  DOCK_ICON_FONT      = 'Segoe MDL2 Assets';
  DOCK_ICON_ADD       = #$E710;
  DOCK_ICON_CANCEL    = #$E711;
  DOCK_ICON_BROADCAST = #$E909;
  DOCK_ICON_FOLDER    = #$E8B7;
  DOCK_ICON_THEME     = #$E790;

type
  (* Cast-наследник для доступа к protected Capture/ReleaseCapture. *)
  TControlAccess = class(TControl);

function HeaderActionGlyphFor(const AId, AGlyph: string;
  out AUsesIconFont: Boolean): string;
var
  GlyphText, HexText: string;
  Code, P: Integer;
begin
  GlyphText := Trim(AGlyph);
  AUsesIconFont := True;

  if SameText(AId, 'add') or SameText(GlyphText, 'add') or
    SameText(GlyphText, 'plus') or (GlyphText = '+') then
    Exit(DOCK_ICON_ADD);
  if SameText(AId, 'close') or SameText(GlyphText, 'close') or
    SameText(GlyphText, 'x') then
    Exit(DOCK_ICON_CANCEL);
  if SameText(AId, 'broadcast') or SameText(GlyphText, 'broadcast') or
    SameText(GlyphText, 'B') then
    Exit(DOCK_ICON_BROADCAST);
  if SameText(AId, 'sftp') or SameText(GlyphText, 'sftp') or
    SameText(GlyphText, 'folder') or SameText(GlyphText, 'S') then
    Exit(DOCK_ICON_FOLDER);
  if SameText(AId, 'theme') or SameText(GlyphText, 'theme') or
    SameText(GlyphText, 'T') then
    Exit(DOCK_ICON_THEME);

  P := Pos('MDL2:', UpperCase(GlyphText));
  if P > 0 then
  begin
    HexText := Copy(GlyphText, P + 5, 4);
    if TryStrToInt('$' + HexText, Code) and
      (Code >= $E700) and (Code <= $F8FF) then
      Exit(Char(Code));
  end;

  if (Length(GlyphText) = 1) and
    (Ord(GlyphText[1]) >= $E700) and (Ord(GlyphText[1]) <= $F8FF) then
    Exit(GlyphText);

  AUsesIconFont := False;
  Result := GlyphText;
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
  OnApplyStyleLookup := HandleApplyStyleLookup;
end;

procedure TPaneHeaderActionButton.HandleApplyStyleLookup(Sender: TObject);
begin
  PaintLocalChrome;
end;

procedure TPaneHeaderActionButton.PaintLocalChrome;
var
  Obj: TFmxObject;
  Shape: TShape;
  Txt: TTextControl;
  BtnTxt: TButtonStyleTextObject;

  procedure PaintShape(const AName: string);
  begin
    Obj := FindStyleResource(AName);
    if Obj is TShape then
    begin
      Shape := TShape(Obj);
      Shape.Fill.Kind := TBrushKind.Solid;
      Shape.Fill.Color := FLocalBg;
      Shape.Stroke.Kind := TBrushKind.Solid;
      Shape.Stroke.Color := FLocalBorder;
    end;
  end;

  procedure PaintTextResource;
  begin
    Obj := FindStyleResource('text');
    if Obj is TButtonStyleTextObject then
    begin
      BtnTxt := TButtonStyleTextObject(Obj);
      BtnTxt.NormalColor := FLocalText;
      BtnTxt.HotColor := FLocalText;
      BtnTxt.FocusedColor := FLocalText;
      BtnTxt.PressedColor := FLocalText;
      if UsesIconFont then
      begin
        BtnTxt.TextSettings.Font.Family := DOCK_ICON_FONT;
        BtnTxt.TextSettings.Font.Size := 13;
      end
      else
      begin
        BtnTxt.TextSettings.Font.Family := '';
        BtnTxt.TextSettings.Font.Size := 12;
      end;
      BtnTxt.TextSettings.FontColor := FLocalText;
      BtnTxt.TextSettings.HorzAlign := TTextAlign.Center;
      BtnTxt.TextSettings.VertAlign := TTextAlign.Center;
      BtnTxt.TextSettings.Trimming := TTextTrimming.None;
    end
    else if Obj is TTextControl then
    begin
      Txt := TTextControl(Obj);
      Txt.StyledSettings := Txt.StyledSettings - [TStyledSetting.FontColor,
        TStyledSetting.Family, TStyledSetting.Size];
      if UsesIconFont then
      begin
        Txt.TextSettings.Font.Family := DOCK_ICON_FONT;
        Txt.TextSettings.Font.Size := 13;
      end
      else
      begin
        Txt.TextSettings.Font.Family := '';
        Txt.TextSettings.Font.Size := 12;
      end;
      Txt.TextSettings.FontColor := FLocalText;
      Txt.TextSettings.HorzAlign := TTextAlign.Center;
      Txt.TextSettings.VertAlign := TTextAlign.Center;
      Txt.TextSettings.Trimming := TTextTrimming.None;
    end;
  end;

begin
  StyledSettings := StyledSettings - [TStyledSetting.FontColor,
    TStyledSetting.Family, TStyledSetting.Size];
  if UsesIconFont then
  begin
    TextSettings.Font.Family := DOCK_ICON_FONT;
    TextSettings.Font.Size := 13;
  end;
  TextSettings.FontColor := FLocalText;
  PaintShape('background');
  PaintShape('bg');
  PaintTextResource;
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
  (* Кнопку закрытия добавляет каждый потомок сам в конце своих action'ов:
     AddHeaderAction('close', 'x', AddCloseHandler, 'Close') — чтобы ✕
     был самым правым в header. База предоставляет готовый handler через
     AddDefaultCloseAction. *)
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
    Btn.StyledSettings := Btn.StyledSettings - [TStyledSetting.FontColor,
      TStyledSetting.Family, TStyledSetting.Size];
    if Btn.UsesIconFont then
      Btn.TextSettings.Font.Family := DOCK_ICON_FONT
    else
      Btn.TextSettings.Font.Family := '';
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
  Result := True;
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
begin
  if FEditingTitle then Exit;
  if not (Sender is TPaneHeaderActionButton) then Exit;
  Btn := TPaneHeaderActionButton(Sender);
  RequestActivate;
  ExecuteHeaderAction(Btn.ActionId);
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

function TnbDockingPaneContent.AddDefaultCloseAction: TDockingPaneHeaderAction;
begin
  Result := AddHeaderAction('close', 'x', HandleCloseAction, 'Close');
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
  UsesIconFont: Boolean;
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
    Btn.Height := HEADER_HEIGHT - 7;
    Btn.Margins.Rect := RectF(0, 3, 4, 3);
    Btn.StyleLookup := ScopedHeaderActionStyle('speedbuttonstyle');
    Btn.Text := HeaderActionGlyphFor(Action.Id, Action.Glyph, UsesIconFont);
    Btn.UsesIconFont := UsesIconFont;
    Btn.StyledSettings := Btn.StyledSettings - [TStyledSetting.FontColor,
      TStyledSetting.Family, TStyledSetting.Size];
    Btn.TextSettings.HorzAlign := TTextAlign.Center;
    Btn.TextSettings.VertAlign := TTextAlign.Center;
    if UsesIconFont then
    begin
      Btn.TextSettings.Font.Family := DOCK_ICON_FONT;
      Btn.TextSettings.Font.Size := 13;
    end
    else
    begin
      Btn.TextSettings.Font.Family := '';
      Btn.TextSettings.Font.Size := 12;
    end;
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
    FActionButtons[I].Position.Y := 3;
    FActionButtons[I].Width := ACTION_BTN_WIDTH;
    FActionButtons[I].Height := HEADER_HEIGHT - 7;
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

end.
