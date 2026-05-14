unit nbDocking.TabHost;

(*
  TDockingTabHost — контейнер нескольких TDockingPaneHost-ов как табов.

  Структура:
    Сверху — TabBar с TabButton-ами (по табу на кнопку) и "+" в конце.
    Снизу — ContentArea, в которой по очереди показываются PaneHost-ы.
    Видим только один PaneHost (активного таба), остальные Visible=False
    (но живут в памяти — терминалы не теряются при переключении).

  Что делает TabHost:
    - AddTab/CloseTab/ActivateTab
    - Запрашивает контент для нового pane через единый OnContentNeeded
      (forward к каждому внутреннему PaneHost)
    - Подписан на OnActiveLeafChanged каждого PaneHost-а:
      если PaneHost опустошился — таб закрывается (Termius-style)
    - Drag-drop reorder табов в полосе

  Отложенное закрытие таба через TTimer:
    Когда PaneHost внутри таба опустошается, мы внутри его стека вызова.
    Закрывать таб (а значит, уничтожать PaneHost) прямо здесь — AV.
    Используем TTimer с Interval=1 и список FPendingCloseTabs:
    обработчик таймера снимет все накопленные закрытия в следующий tick.

  Что НЕ делает (отложено):
    - Перетаскивание таба ВНЕ полосы (detach в floating-окно) — итерация 4
    - Перетаскивание таба МЕЖДУ TabHost-ами — итерация 4+
    - Скроллинг TabBar если табы не помещаются — сейчас просто срежется

  Декаплинг:
    TDockingTab — POCO-модель (Caption, Glyph, Dirty, ссылка на PaneHost).
*)

interface

uses
  System.Classes, System.SysUtils, System.UITypes, System.Types,
  System.Generics.Collections,
  FMX.Types, FMX.Controls, FMX.Layouts, FMX.StdCtrls, FMX.Edit,
  FMX.Objects, FMX.Graphics, FMX.TextLayout,
  nbDocking.Types, nbDocking.PaneTree, nbDocking.PaneHost,
  nbDocking.DropOverlay;

const
  TAB_BAR_HEIGHT              = 34;
  TAB_BUTTON_MIN_WIDTH        = 72;
  TAB_BUTTON_CLOSE_SIZE       = 18;
  TAB_BUTTON_PADDING          = 8;
  TAB_ADD_BUTTON_WIDTH        = 32;
  TAB_DRAG_THRESHOLD          = 5;
  TAB_DROP_INDICATOR_WIDTH    = 2;

type
  TDockingTabHost = class;
  TTabButton = class;

  (* Модель таба. Лёгкий класс, не TComponent — TabHost управляет временем жизни. *)
  TDockingTab = class
  private
    FCaption: string;
    FGlyph: string;
    FDirty: Boolean;
    FPaneHost: TDockingPaneHost;
    FOwner: TDockingTabHost;
    FButton: TTabButton;
    procedure SetCaption(const AValue: string);
    procedure SetDirty(AValue: Boolean);
  public
    constructor Create(AOwner: TDockingTabHost; const ACaption: string);
    destructor Destroy; override;

    property Caption: string read FCaption write SetCaption;
    property Glyph: string read FGlyph write FGlyph;
    property Dirty: Boolean read FDirty write SetDirty;
    property PaneHost: TDockingPaneHost read FPaneHost;
    property Owner: TDockingTabHost read FOwner;

    (* True если в табе ровно один pane (не группа).
       Только такие табы можно перетаскивать в split-зону. *)
    function IsSingle: Boolean;
  end;

  TDockingTabEvent = procedure(Sender: TObject; ATab: TDockingTab) of object;
  TDockingTabClosingEvent = procedure(Sender: TObject; ATab: TDockingTab;
    var ACanClose: Boolean) of object;
  TDockingActiveTabChangeEvent = procedure(Sender: TObject;
    AOldTab, ANewTab: TDockingTab) of object;

  TTabDragState = (
    dsIdle,
    dsArmed,            (* MouseDown, ждём 5px смещения *)
    dsDragging,         (* курсор внутри TabBar — режим reorder *)
    dsDraggingToPane    (* курсор вышел за TabBar — режим drop-в-split *)
  );

  TTabButton = class(TRectangle)
  private
    FTab: TDockingTab;
    FGroupGlyph: TText;
    FCaptionLabel: TLabel;
    FCaptionEdit: TEdit;
    FCloseBtn: TRectangle;
    FCloseGlyph: TText;
    FDragState: TTabDragState;
    FDragStartX: Single;
    FDragStartY: Single;
    FEditingCaption: Boolean;
    procedure BeginRename;
    procedure CommitRename;
    procedure CancelRename;
    function DesiredWidth: Single;
    procedure HandleDblClick(Sender: TObject);
    procedure HandleMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure HandleMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
    procedure HandleMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure HandleCloseMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure HandleEditExit(Sender: TObject);
    procedure HandleEditKeyDown(Sender: TObject; var Key: Word;
      var KeyChar: Char; Shift: TShiftState);
  public
    constructor Create(AOwner: TComponent; ATab: TDockingTab); reintroduce;
    procedure UpdateVisual(AIsActive: Boolean);
    procedure UpdateCaption;
    property Tab: TDockingTab read FTab;
  end;

  TDockingTabHost = class(TLayout)
  private
    FTabs: TObjectList<TDockingTab>;
    FActiveTab: TDockingTab;
    FTabBar: TLayout;
    FTabBarBg: TRectangle;
    FAddButton: TRectangle;
    FAddGlyph: TText;
    FDropIndicator: TRectangle;
    FContentArea: TLayout;

    (* Очередь отложенных закрытий + таймер *)
    FPendingCloseTabs: TList<TDockingTab>;
    FDeferTimer: TTimer;

    (* Drag-drop: оверлей с 4 drop-зонами поверх активного pane *)
    FDropOverlay: TDockingDropOverlay;
    FCurrentDropTarget: TDockingTab;     (* куда сейчас наведено *)
    FCurrentDropLeaf: TPaneLeaf;         (* конкретный leaf под курсором *)

    (* Drag header pane-а. Источник = leaf чужого PaneHost-а внутри одного из табов.
       Цель определяется по курсору: TabBar → новый таб, площадь pane-а → split. *)
    FHeaderDragSourceHost: TDockingPaneHost;
    FHeaderDragSourceLeaf: TPaneLeaf;
    FHeaderDragOverTabBar: Boolean;

    (* Стилевые свойства *)
    FTabBarColor: TAlphaColor;
    FTabActiveColor: TAlphaColor;
    FTabInactiveColor: TAlphaColor;
    FTabHoverColor: TAlphaColor;
    FTabTextColor: TAlphaColor;
    FAccentColor: TAlphaColor;

    FOnContentNeeded: TContentFactoryEvent;
    FOnTabAdded: TDockingTabEvent;
    FOnTabClosing: TDockingTabClosingEvent;
    FOnTabClosed: TDockingTabEvent;
    FOnActiveTabChanged: TDockingActiveTabChangeEvent;

    procedure BuildUI;
    procedure HandleTabBarResize(Sender: TObject);
    procedure HandleAddButtonClick(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure HandlePaneHostActiveLeafChanged(Sender: TObject;
      AOldLeaf, ANewLeaf: TPaneLeaf);
    procedure HandlePaneHostContentHeaderChanged(Sender: TObject;
      AContent: TDockingPaneContent);
    procedure HandlePaneHostContentNeeded(Sender: TObject;
      var AContent: TDockingPaneContent);
    procedure HandleDeferTimer(Sender: TObject);

    procedure RelayoutTabButtons;
    procedure UpdateTabButtonWidths;
    procedure InternalActivateTab(ATab: TDockingTab);
    function FindTabByPaneHost(APaneHost: TDockingPaneHost): TDockingTab;
    function IndexOfTab(ATab: TDockingTab): Integer;
    function CanCloseTabInternal(ATab: TDockingTab): Boolean;
    procedure ScheduleDeferredCloseTab(ATab: TDockingTab);

    procedure TabButton_Activate(ATab: TDockingTab);
    procedure TabButton_RequestClose(ATab: TDockingTab);
    procedure TabButton_StartDrag(AButton: TTabButton);
    procedure TabButton_UpdateDrag(AButton: TTabButton; AScreenX: Single);
    procedure TabButton_EndDrag(AButton: TTabButton; AScreenX: Single;
      AWasDragging: Boolean);
    function TabBarLocalX(AScreenX: Single): Single;
    function FindDropTargetIndex(ATabBarLocalX: Single;
      AExcludeTab: TDockingTab): Integer;

    (* Drag-drop в split-зону *)
    procedure TabButton_EnterPaneDrag(AButton: TTabButton);
    procedure TabButton_LeavePaneDrag(AButton: TTabButton);
    procedure TabButton_UpdatePaneDrag(AButton: TTabButton;
      const AScreenPt: TPointF);
    procedure TabButton_DropOnPane(AButton: TTabButton;
      const AScreenPt: TPointF);
    function FindDropTargetTab(const AScreenPt: TPointF;
      out APaneLocalPt: TPointF): TDockingTab;
    procedure PerformDockMove(ASourceTab, ATargetTab: TDockingTab;
      ADir: TSplitDirection);

    (* === Drag header pane-а === *)
    procedure HandlePaneHostHeaderDrag(ASender: TDockingPaneHost;
      ALeaf: TPaneLeaf; APhase: TPaneHeaderDragPhase; const AScreenPt: TPointF);
    procedure PaneHeader_Begin(ASourceHost: TDockingPaneHost;
      ASourceLeaf: TPaneLeaf);
    procedure PaneHeader_Update(const AScreenPt: TPointF);
    procedure PaneHeader_End(const AScreenPt: TPointF);
    procedure PaneHeader_ShowTabBarHint;
    procedure PaneHeader_HideTabBarHint;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    function AddTab(const ACaption: string = 'New tab'): TDockingTab;

    (* Создаёт таб с уже готовым контентом (например, перенесённым из другого
       таба при drag-drop). НЕ зовёт OnContentNeeded. *)
    function AddTabWithContent(const ACaption: string;
      AContent: TDockingPaneContent): TDockingTab;

    procedure CloseTab(ATab: TDockingTab);
    procedure ActivateTab(ATab: TDockingTab);
    procedure MoveTab(ATab: TDockingTab; ANewIndex: Integer);

    function TabCount: Integer;
    function GetTab(AIndex: Integer): TDockingTab;

    property ActiveTab: TDockingTab read FActiveTab;
    property Tabs[AIndex: Integer]: TDockingTab read GetTab;
  published
    property TabBarColor: TAlphaColor read FTabBarColor write FTabBarColor;
    property TabActiveColor: TAlphaColor read FTabActiveColor write FTabActiveColor;
    property TabInactiveColor: TAlphaColor read FTabInactiveColor write FTabInactiveColor;
    property TabHoverColor: TAlphaColor read FTabHoverColor write FTabHoverColor;
    property TabTextColor: TAlphaColor read FTabTextColor write FTabTextColor;
    property AccentColor: TAlphaColor read FAccentColor write FAccentColor;

    property OnContentNeeded: TContentFactoryEvent read FOnContentNeeded
      write FOnContentNeeded;
    property OnTabAdded: TDockingTabEvent read FOnTabAdded write FOnTabAdded;
    property OnTabClosing: TDockingTabClosingEvent read FOnTabClosing
      write FOnTabClosing;
    property OnTabClosed: TDockingTabEvent read FOnTabClosed write FOnTabClosed;
    property OnActiveTabChanged: TDockingActiveTabChangeEvent
      read FOnActiveTabChanged write FOnActiveTabChanged;
  end;

implementation

{ TDockingTab }

constructor TDockingTab.Create(AOwner: TDockingTabHost; const ACaption: string);
begin
  inherited Create;
  FOwner := AOwner;
  FCaption := ACaption;
  FDirty := False;
  FPaneHost := TDockingPaneHost.Create(AOwner);
  FPaneHost.Parent := AOwner.FContentArea;
  FPaneHost.Align := TAlignLayout.Client;
  FPaneHost.Visible := False;
  FPaneHost.OnContentNeeded := AOwner.HandlePaneHostContentNeeded;
  FPaneHost.OnActiveLeafChanged := AOwner.HandlePaneHostActiveLeafChanged;
  FPaneHost.OnContentHeaderChanged := AOwner.HandlePaneHostContentHeaderChanged;
  FPaneHost.OnHeaderDrag := AOwner.HandlePaneHostHeaderDrag;
end;

destructor TDockingTab.Destroy;
begin
  if FPaneHost <> nil then
  begin
    FPaneHost.Parent := nil;
    FPaneHost.Free;
    FPaneHost := nil;
  end;
  inherited;
end;

procedure TDockingTab.SetCaption(const AValue: string);
begin
  if FCaption = AValue then Exit;
  FCaption := AValue;
  if FButton <> nil then
    FButton.UpdateCaption;
  if FOwner <> nil then
    FOwner.UpdateTabButtonWidths;
end;

procedure TDockingTab.SetDirty(AValue: Boolean);
begin
  if FDirty = AValue then Exit;
  FDirty := AValue;
  if FButton <> nil then
    FButton.UpdateCaption;
  if FOwner <> nil then
    FOwner.UpdateTabButtonWidths;
end;

function TDockingTab.IsSingle: Boolean;
begin
  Result := (FPaneHost <> nil) and (FPaneHost.Tree.LeafCount = 1);
end;

{ TTabButton }

constructor TTabButton.Create(AOwner: TComponent; ATab: TDockingTab);
begin
  inherited Create(AOwner);
  FTab := ATab;
  FDragState := dsIdle;
  HitTest := True;
  Align := TAlignLayout.Left;
  Width := TAB_BUTTON_MIN_WIDTH;
  Margins.Rect := RectF(0, 4, 0, 0);
  Fill.Kind := TBrushKind.Solid;
  Stroke.Kind := TBrushKind.None;
  XRadius := 4;
  YRadius := 4;
  Corners := [TCorner.TopLeft, TCorner.TopRight];

  FCaptionLabel := TLabel.Create(Self);
  FCaptionLabel.Parent := Self;
  FCaptionLabel.Align := TAlignLayout.Client;
  FCaptionLabel.Margins.Rect := RectF(TAB_BUTTON_PADDING, 0,
    TAB_BUTTON_CLOSE_SIZE + TAB_BUTTON_PADDING, 0);
  FCaptionLabel.TextSettings.HorzAlign := TTextAlign.Leading;
  FCaptionLabel.TextSettings.VertAlign := TTextAlign.Center;
  FCaptionLabel.TextSettings.Font.Size := 13;
  FCaptionLabel.StyledSettings := [];
  FCaptionLabel.HitTest := False;

  FCaptionEdit := TEdit.Create(Self);
  FCaptionEdit.Parent := Self;
  FCaptionEdit.Align := TAlignLayout.Client;
  FCaptionEdit.Margins.Rect := RectF(TAB_BUTTON_PADDING, 4,
    TAB_BUTTON_CLOSE_SIZE + TAB_BUTTON_PADDING, 4);
  FCaptionEdit.Visible := False;
  FCaptionEdit.OnExit := HandleEditExit;
  FCaptionEdit.OnKeyDown := HandleEditKeyDown;

  (* Group glyph слева от caption, показывается только для не-single табов.
     Помечает таб как "группу" — drag в split-зону для таких отключён. *)
  FGroupGlyph := TText.Create(Self);
  FGroupGlyph.Parent := Self;
  FGroupGlyph.Align := TAlignLayout.Left;
  FGroupGlyph.Width := 16;
  FGroupGlyph.Margins.Rect := RectF(TAB_BUTTON_PADDING, 0, 0, 0);
  FGroupGlyph.Text := '▦';
  FGroupGlyph.TextSettings.HorzAlign := TTextAlign.Center;
  FGroupGlyph.TextSettings.VertAlign := TTextAlign.Center;
  FGroupGlyph.TextSettings.Font.Size := 12;
  FGroupGlyph.HitTest := False;
  FGroupGlyph.Visible := False;

  FCloseBtn := TRectangle.Create(Self);
  FCloseBtn.Parent := Self;
  FCloseBtn.Align := TAlignLayout.Right;
  FCloseBtn.Width := TAB_BUTTON_CLOSE_SIZE;
  FCloseBtn.Margins.Rect := RectF(0, 7, TAB_BUTTON_PADDING, 7);
  FCloseBtn.Fill.Kind := TBrushKind.None;
  FCloseBtn.Stroke.Kind := TBrushKind.None;
  FCloseBtn.XRadius := 3;
  FCloseBtn.YRadius := 3;
  FCloseBtn.HitTest := True;
  FCloseBtn.OnMouseDown := HandleCloseMouseDown;

  FCloseGlyph := TText.Create(Self);
  FCloseGlyph.Parent := FCloseBtn;
  FCloseGlyph.Align := TAlignLayout.Client;
  FCloseGlyph.Text := '✕';
  FCloseGlyph.TextSettings.HorzAlign := TTextAlign.Center;
  FCloseGlyph.TextSettings.VertAlign := TTextAlign.Center;
  FCloseGlyph.TextSettings.Font.Size := 11;
  FCloseGlyph.HitTest := False;

  OnMouseDown := HandleMouseDown;
  OnMouseMove := HandleMouseMove;
  OnMouseUp := HandleMouseUp;
  OnDblClick := HandleDblClick;

  UpdateCaption;
end;

procedure TTabButton.BeginRename;
begin
  if (FTab = nil) or (FCaptionEdit = nil) then Exit;

  FDragState := dsIdle;
  ReleaseCapture;

  FEditingCaption := True;
  FCaptionLabel.Visible := False;
  if FGroupGlyph <> nil then
    FGroupGlyph.Visible := False;
  FCaptionEdit.Text := FTab.Caption;
  FCaptionEdit.Visible := True;
  FCaptionEdit.SetFocus;
  FCaptionEdit.SelectAll;
end;

procedure TTabButton.CommitRename;
var
  Content: TDockingPaneContent;
  NewCaption: string;
begin
  if not FEditingCaption then Exit;
  FEditingCaption := False;

  NewCaption := Trim(FCaptionEdit.Text);
  FCaptionEdit.Visible := False;
  FCaptionLabel.Visible := True;

  if (FTab <> nil) and (NewCaption <> '') then
  begin
    if FTab.IsSingle then
    begin
      Content := FTab.PaneHost.ActiveLeafContent;
      if Content <> nil then
        Content.Caption := NewCaption;
    end;
    FTab.Caption := NewCaption;
  end
  else
    UpdateCaption;
end;

procedure TTabButton.CancelRename;
begin
  if not FEditingCaption then Exit;
  FEditingCaption := False;
  FCaptionEdit.Visible := False;
  FCaptionLabel.Visible := True;
  UpdateCaption;
end;

procedure TTabButton.HandleDblClick(Sender: TObject);
begin
  BeginRename;
end;

function TTabButton.DesiredWidth: Single;
var
  S: string;
  TextLayout: TTextLayout;
  TextWidth: Single;
begin
  if FTab = nil then Exit(TAB_BUTTON_MIN_WIDTH);

  S := FTab.Caption;
  if FTab.Dirty then
    S := '• ' + S;

  TextLayout := TTextLayoutManager.DefaultTextLayout.Create;
  try
    TextLayout.BeginUpdate;
    TextLayout.Text := S;
    TextLayout.Font := FCaptionLabel.TextSettings.Font;
    TextLayout.MaxSize := TTextLayout.MaxLayoutSize;
    TextLayout.WordWrap := False;
    TextLayout.Trimming := TTextTrimming.None;
    TextLayout.HorizontalAlign := TTextAlign.Leading;
    TextLayout.VerticalAlign := TTextAlign.Center;
    TextLayout.EndUpdate;

    TextWidth := TextLayout.Width + TextLayout.TextRect.Left * 2
      + FCaptionLabel.TextSettings.Font.Size / 3;
  finally
    TextLayout.Free;
  end;

  Result := TAB_BUTTON_PADDING * 2
    + TAB_BUTTON_CLOSE_SIZE
    + TAB_BUTTON_PADDING
    + TextWidth;

  if not FTab.IsSingle then
    Result := Result + FGroupGlyph.Width + TAB_BUTTON_PADDING;

  if Result < TAB_BUTTON_MIN_WIDTH then
    Result := TAB_BUTTON_MIN_WIDTH;
end;

procedure TTabButton.UpdateCaption;
var
  S: string;
  IsGroup: Boolean;
begin
  if FTab = nil then Exit;
  if FEditingCaption then Exit;

  S := FTab.Caption;
  if FTab.Dirty then
    S := '• ' + S;
  FCaptionLabel.Text := S;

  IsGroup := not FTab.IsSingle;
  if FGroupGlyph <> nil then
    FGroupGlyph.Visible := IsGroup;
end;

procedure TTabButton.UpdateVisual(AIsActive: Boolean);
var
  Host: TDockingTabHost;
begin
  if FTab = nil then Exit;
  Host := FTab.Owner;
  if Host = nil then Exit;
  if AIsActive then
    Fill.Color := Host.TabActiveColor
  else
    Fill.Color := Host.TabInactiveColor;
  FCaptionLabel.TextSettings.FontColor := Host.TabTextColor;
  FCloseGlyph.TextSettings.FontColor := Host.TabTextColor;
  if FGroupGlyph <> nil then
    FGroupGlyph.TextSettings.FontColor := Host.TabTextColor;
end;

procedure TTabButton.HandleMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
begin
  if Button <> TMouseButton.mbLeft then Exit;
  if FTab = nil then Exit;
  if FEditingCaption then Exit;

  (* НЕ активируем таб здесь!
     Если активировать на MouseDown, при попытке перетащить НЕ-активный таб
     он сразу становится активным, и dock-логика трактует его как drop-в-себя.
     Активацию откладываем до MouseUp: если drag не случился — кликом
     активируем; если случился (reorder/drop) — активация не нужна. *)

  FDragState := dsArmed;
  FDragStartX := X;
  FDragStartY := Y;
  Self.Capture;
end;

procedure TTabButton.HandleMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Single);
var
  ScreenPt, HostPt: TPointF;
  Host: TDockingTabHost;
  IsOutsideTabBar: Boolean;
begin
  if FDragState = dsIdle then Exit;
  if FTab = nil then Exit;
  if FEditingCaption then Exit;
  Host := FTab.Owner;
  if Host = nil then Exit;

  if FDragState = dsArmed then
  begin
    if (Abs(X - FDragStartX) > TAB_DRAG_THRESHOLD) or
       (Abs(Y - FDragStartY) > TAB_DRAG_THRESHOLD) then
    begin
      FDragState := dsDragging;
      Opacity := 0.6;
      Host.TabButton_StartDrag(Self);
    end;
  end;

  if FDragState in [dsDragging, dsDraggingToPane] then
  begin
    ScreenPt := LocalToScreen(PointF(X, Y));
    HostPt := Host.ScreenToLocal(ScreenPt);
    IsOutsideTabBar := HostPt.Y > TAB_BAR_HEIGHT;

    if FDragState = dsDragging then
    begin
      if IsOutsideTabBar and FTab.IsSingle then
      begin
        FDragState := dsDraggingToPane;
        Host.TabButton_EnterPaneDrag(Self);
        Host.TabButton_UpdatePaneDrag(Self, ScreenPt);
      end
      else
        Host.TabButton_UpdateDrag(Self, ScreenPt.X);
    end
    else
    begin
      if not IsOutsideTabBar then
      begin
        FDragState := dsDragging;
        Host.TabButton_LeavePaneDrag(Self);
        Host.TabButton_UpdateDrag(Self, ScreenPt.X);
      end
      else
        Host.TabButton_UpdatePaneDrag(Self, ScreenPt);
    end;
  end;
end;

procedure TTabButton.HandleMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
var
  ScreenPt: TPointF;
  PrevState: TTabDragState;
  Host: TDockingTabHost;
begin
  if Button <> TMouseButton.mbLeft then Exit;
  if FTab = nil then Exit;
  if FEditingCaption then Exit;
  Host := FTab.Owner;

  Self.ReleaseCapture;
  PrevState := FDragState;
  FDragState := dsIdle;

  if Host = nil then Exit;

  case PrevState of
    dsDragging:
      begin
        (* Reorder в TabBar — активируем перетащенный таб,
           чтобы юзер продолжил работать с ним. *)
        ScreenPt := LocalToScreen(PointF(X, Y));
        Host.TabButton_EndDrag(Self, ScreenPt.X, True);
        Host.TabButton_Activate(FTab);
        Opacity := 1.0;
      end;
    dsDraggingToPane:
      begin
        (* Drop в split-зону *)
        ScreenPt := LocalToScreen(PointF(X, Y));
        Host.TabButton_DropOnPane(Self, ScreenPt);
        Opacity := 1.0;
      end;
    dsArmed:
      begin
        (* Чистый клик без drag — активируем таб сейчас.
           На MouseDown активацию пропустили, чтобы не блокировать
           возможный drag (см. комментарий в HandleMouseDown). *)
        Host.TabButton_Activate(FTab);
      end;
  end;
end;

procedure TTabButton.HandleCloseMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
begin
  if Button <> TMouseButton.mbLeft then Exit;
  if FTab = nil then Exit;
  FDragState := dsIdle;
  FTab.Owner.TabButton_RequestClose(FTab);
end;

procedure TTabButton.HandleEditExit(Sender: TObject);
begin
  CommitRename;
end;

procedure TTabButton.HandleEditKeyDown(Sender: TObject; var Key: Word;
  var KeyChar: Char; Shift: TShiftState);
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

{ TDockingTabHost }

constructor TDockingTabHost.Create(AOwner: TComponent);
begin
  inherited;
  Align := TAlignLayout.Client;

  FTabs := TObjectList<TDockingTab>.Create(True);
  FPendingCloseTabs := TList<TDockingTab>.Create;

  FTabBarColor       := TAlphaColor($FFE5E5E5);
  FTabActiveColor    := TAlphaColor($FFFFFFFF);
  FTabInactiveColor  := TAlphaColor($FFD0D0D0);
  FTabHoverColor     := TAlphaColor($FFEEEEEE);
  FTabTextColor      := TAlphaColor($FF202020);
  FAccentColor       := TAlphaColor($FF3D6FB5);

  BuildUI;

  (* Drop-overlay создаётся один на TabHost. Перепаривается на активный
     PaneHost при заходе в режим dsDraggingToPane. *)
  FDropOverlay := TDockingDropOverlay.Create(Self);
  FCurrentDropTarget := nil;
  FCurrentDropLeaf := nil;

  (* Таймер отложенного закрытия табов. *)
  FDeferTimer := TTimer.Create(Self);
  FDeferTimer.Enabled := False;
  FDeferTimer.Interval := 1;
  FDeferTimer.OnTimer := HandleDeferTimer;
end;

destructor TDockingTabHost.Destroy;
begin
  if FDeferTimer <> nil then
    FDeferTimer.Enabled := False;
  if FPendingCloseTabs <> nil then
  begin
    FPendingCloseTabs.Clear;
    FPendingCloseTabs.Free;
  end;
  FTabs.Free;
  (* FDeferTimer и FTabBar/FAddButton/etc — Owner=Self, FMX освободит. *)
  inherited;
end;

procedure TDockingTabHost.BuildUI;
begin
  (* FTabBar — TLayout, а не TRectangle.
     Причина: TRectangle как родитель Align=Left детей в FMX ведёт себя
     странно — новые дети вставляются на индекс 1, а не в конец.
     В чистом TLayout порядок Children корректный.
     Цветной фон рисуется отдельным TRectangle, лежащим внутри FTabBar
     с Align=Contents (заполняет всё пространство), HitTest=False
     (не перехватывает клики), и помещается ПЕРЕД остальными детьми
     (нижний слой Z-order, чтобы кнопки рисовались поверх). *)
  FTabBar := TLayout.Create(Self);
  FTabBar.Parent := Self;
  FTabBar.Align := TAlignLayout.Top;
  FTabBar.Height := TAB_BAR_HEIGHT;
  FTabBar.HitTest := True;
  FTabBar.OnResize := HandleTabBarResize;

  FTabBarBg := TRectangle.Create(Self);
  FTabBarBg.Parent := FTabBar;
  FTabBarBg.Align := TAlignLayout.Contents;
  FTabBarBg.Fill.Color := FTabBarColor;
  FTabBarBg.Stroke.Kind := TBrushKind.None;
  FTabBarBg.HitTest := False;
  FTabBarBg.SendToBack;

  FAddButton := TRectangle.Create(Self);
  FAddButton.Parent := FTabBar;
  FAddButton.Align := TAlignLayout.Right;
  FAddButton.Width := TAB_ADD_BUTTON_WIDTH;
  FAddButton.Margins.Rect := RectF(2, 6, 2, 4);
  FAddButton.Fill.Kind := TBrushKind.None;
  FAddButton.Stroke.Kind := TBrushKind.None;
  FAddButton.XRadius := 3;
  FAddButton.YRadius := 3;
  FAddButton.HitTest := True;
  FAddButton.OnMouseDown := HandleAddButtonClick;

  FAddGlyph := TText.Create(Self);
  FAddGlyph.Parent := FAddButton;
  FAddGlyph.Align := TAlignLayout.Client;
  FAddGlyph.Text := '+';
  FAddGlyph.TextSettings.HorzAlign := TTextAlign.Center;
  FAddGlyph.TextSettings.VertAlign := TTextAlign.Center;
  FAddGlyph.TextSettings.Font.Size := 18;
  FAddGlyph.TextSettings.FontColor := FTabTextColor;
  FAddGlyph.HitTest := False;

  FDropIndicator := TRectangle.Create(Self);
  FDropIndicator.Parent := FTabBar;
  FDropIndicator.Width := TAB_DROP_INDICATOR_WIDTH;
  FDropIndicator.Height := TAB_BAR_HEIGHT - 4;
  FDropIndicator.Position.Y := 2;
  FDropIndicator.Fill.Color := FAccentColor;
  FDropIndicator.Stroke.Kind := TBrushKind.None;
  FDropIndicator.HitTest := False;
  FDropIndicator.Visible := False;

  FContentArea := TLayout.Create(Self);
  FContentArea.Parent := Self;
  FContentArea.Align := TAlignLayout.Client;
end;

procedure TDockingTabHost.HandleTabBarResize(Sender: TObject);
begin
  UpdateTabButtonWidths;
end;

procedure TDockingTabHost.HandleAddButtonClick(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  if Button <> TMouseButton.mbLeft then Exit;
  AddTab('New tab');
end;

(* === Очередь отложенных закрытий === *)

procedure TDockingTabHost.ScheduleDeferredCloseTab(ATab: TDockingTab);
begin
  if ATab = nil then Exit;
  if FPendingCloseTabs.IndexOf(ATab) >= 0 then Exit;
  FPendingCloseTabs.Add(ATab);
  if FDeferTimer <> nil then
    FDeferTimer.Enabled := True;
end;

procedure TDockingTabHost.HandleDeferTimer(Sender: TObject);
var
  Tab: TDockingTab;
begin
  FDeferTimer.Enabled := False;

  (* Снимаем все накопленные закрытия в порядке поступления.
     CloseTab может породить ещё одно закрытие через OnActiveLeafChanged
     соседнего PaneHost-а — оно добавится в FPendingCloseTabs и таймер
     снова взведётся. Но в текущей итерации проходим только то, что
     было на старте. *)
  while FPendingCloseTabs.Count > 0 do
  begin
    Tab := FPendingCloseTabs[0];
    FPendingCloseTabs.Delete(0);
    if FTabs.IndexOf(Tab) >= 0 then
      CloseTab(Tab);
  end;
end;

(* === High-level API === *)

function TDockingTabHost.AddTab(const ACaption: string): TDockingTab;
var
  NewTab: TDockingTab;
  Btn: TTabButton;
  InitialContent: TDockingPaneContent;
begin
  NewTab := TDockingTab.Create(Self, ACaption);
  FTabs.Add(NewTab);

  Btn := TTabButton.Create(Self, NewTab);
  NewTab.FButton := Btn;
  Btn.Parent := FTabBar;

  InitialContent := nil;
  if Assigned(FOnContentNeeded) then
    FOnContentNeeded(Self, InitialContent);
  if InitialContent <> nil then
    NewTab.PaneHost.SetInitialContent(InitialContent);

  (* Обновить caption — IsSingle теперь True (LeafCount=1), glyph ▦ скроется. *)
  Btn.UpdateCaption;
  UpdateTabButtonWidths;

  InternalActivateTab(NewTab);

  if Assigned(FOnTabAdded) then
    FOnTabAdded(Self, NewTab);

  Result := NewTab;
end;

function TDockingTabHost.AddTabWithContent(const ACaption: string;
  AContent: TDockingPaneContent): TDockingTab;
var
  NewTab: TDockingTab;
  Btn: TTabButton;
begin
  NewTab := TDockingTab.Create(Self, ACaption);
  FTabs.Add(NewTab);

  Btn := TTabButton.Create(Self, NewTab);
  NewTab.FButton := Btn;
  Btn.Parent := FTabBar;

  if AContent <> nil then
    NewTab.PaneHost.SetInitialContent(AContent);

  Btn.UpdateCaption;
  UpdateTabButtonWidths;
  InternalActivateTab(NewTab);

  if Assigned(FOnTabAdded) then
    FOnTabAdded(Self, NewTab);

  Result := NewTab;
end;

procedure TDockingTabHost.CloseTab(ATab: TDockingTab);
var
  Idx, NewActiveIdx: Integer;
  CanClose: Boolean;
  OldActive, NextActive: TDockingTab;
begin
  if ATab = nil then Exit;
  Idx := IndexOfTab(ATab);
  if Idx < 0 then Exit;

  if not CanCloseTabInternal(ATab) then Exit;

  CanClose := True;
  if Assigned(FOnTabClosing) then
    FOnTabClosing(Self, ATab, CanClose);
  if not CanClose then Exit;

  OldActive := FActiveTab;

  if ATab.FButton <> nil then
  begin
    ATab.FButton.Parent := nil;
    ATab.FButton.Free;
    ATab.FButton := nil;
  end;

  NextActive := nil;
  if ATab = OldActive then
  begin
    if Idx + 1 < FTabs.Count then
      NewActiveIdx := Idx + 1
    else
      NewActiveIdx := Idx - 1;
    if (NewActiveIdx >= 0) and (NewActiveIdx < FTabs.Count)
       and (FTabs[NewActiveIdx] <> ATab) then
      NextActive := FTabs[NewActiveIdx];
  end
  else
    NextActive := OldActive;

  if FActiveTab = ATab then
    FActiveTab := nil;

  FTabs.Remove(ATab);
  UpdateTabButtonWidths;

  InternalActivateTab(NextActive);

  if Assigned(FOnTabClosed) then
    FOnTabClosed(Self, nil);
end;

procedure TDockingTabHost.ActivateTab(ATab: TDockingTab);
begin
  InternalActivateTab(ATab);
end;

procedure TDockingTabHost.MoveTab(ATab: TDockingTab; ANewIndex: Integer);
var
  CurIdx: Integer;
begin
  CurIdx := IndexOfTab(ATab);
  if CurIdx < 0 then Exit;
  if ANewIndex < 0 then ANewIndex := 0;
  if ANewIndex > FTabs.Count - 1 then ANewIndex := FTabs.Count - 1;
  if ANewIndex = CurIdx then Exit;

  FTabs.OwnsObjects := False;
  try
    FTabs.Move(CurIdx, ANewIndex);
  finally
    FTabs.OwnsObjects := True;
  end;
  RelayoutTabButtons;
end;

function TDockingTabHost.TabCount: Integer;
begin
  Result := FTabs.Count;
end;

function TDockingTabHost.GetTab(AIndex: Integer): TDockingTab;
begin
  Result := FTabs[AIndex];
end;

(* === Внутренние операции === *)

procedure TDockingTabHost.InternalActivateTab(ATab: TDockingTab);
var
  Old: TDockingTab;
  I: Integer;
begin
  if ATab = FActiveTab then
  begin
    for I := 0 to FTabs.Count - 1 do
      if FTabs[I].FButton <> nil then
        FTabs[I].FButton.UpdateVisual(FTabs[I] = FActiveTab);
    Exit;
  end;

  Old := FActiveTab;

  if (Old <> nil) and (Old.PaneHost <> nil) then
    Old.PaneHost.Visible := False;

  FActiveTab := ATab;

  if (FActiveTab <> nil) and (FActiveTab.PaneHost <> nil) then
    FActiveTab.PaneHost.Visible := True;

  for I := 0 to FTabs.Count - 1 do
    if FTabs[I].FButton <> nil then
      FTabs[I].FButton.UpdateVisual(FTabs[I] = FActiveTab);

  if Assigned(FOnActiveTabChanged) then
    FOnActiveTabChanged(Self, Old, FActiveTab);
end;

procedure TDockingTabHost.RelayoutTabButtons;
var
  I: Integer;
  Btn: TTabButton;
  Buffer: TList<TFmxObject>;
begin
  if FTabBar = nil then Exit;

  Buffer := TList<TFmxObject>.Create;
  try
    for I := 0 to FTabs.Count - 1 do
    begin
      Btn := FTabs[I].FButton;
      if (Btn <> nil) and (Btn.Parent = FTabBar) then
        Buffer.Add(Btn);
    end;

    for I := 0 to Buffer.Count - 1 do
      FTabBar.RemoveObject(Buffer[I]);

    for I := 0 to Buffer.Count - 1 do
      FTabBar.AddObject(Buffer[I]);
  finally
    Buffer.Free;
  end;

  UpdateTabButtonWidths;
end;

procedure TDockingTabHost.UpdateTabButtonWidths;
var
  I, MaxIdx: Integer;
  DesiredTotal, AvailableWidth, Excess, Shrink: Single;
  Widths: TArray<Single>;
  Btn: TTabButton;
begin
  if (FTabBar = nil) or (FTabs = nil) then Exit;
  if FTabs.Count = 0 then Exit;

  SetLength(Widths, FTabs.Count);
  DesiredTotal := 0;
  for I := 0 to FTabs.Count - 1 do
  begin
    Btn := FTabs[I].FButton;
    if Btn <> nil then
    begin
      Widths[I] := Btn.DesiredWidth;
      DesiredTotal := DesiredTotal + Widths[I] + Btn.Margins.Left + Btn.Margins.Right;
    end
    else
    begin
      Widths[I] := TAB_BUTTON_MIN_WIDTH;
      DesiredTotal := DesiredTotal + Widths[I];
    end;
  end;
  if DesiredTotal <= 0 then Exit;

  (* Если FMX ещё не успел разложить TabBar, всё равно сразу
     ставим естественные ширины. Сжатие включится на ближайшем resize. *)
  AvailableWidth := FTabBar.Width - TAB_ADD_BUTTON_WIDTH - 8;
  if AvailableWidth <= 0 then
  begin
    for I := 0 to FTabs.Count - 1 do
    begin
      Btn := FTabs[I].FButton;
      if Btn <> nil then
        Btn.Width := Widths[I];
    end;
    Exit;
  end;

  Excess := DesiredTotal - AvailableWidth;
  while Excess > 0.5 do
  begin
    MaxIdx := -1;
    for I := 0 to High(Widths) do
      if (Widths[I] > TAB_BUTTON_MIN_WIDTH)
         and ((MaxIdx < 0) or (Widths[I] > Widths[MaxIdx])) then
        MaxIdx := I;

    if MaxIdx < 0 then Break;

    Shrink := Widths[MaxIdx] - TAB_BUTTON_MIN_WIDTH;
    if Shrink > Excess then
      Shrink := Excess;

    Widths[MaxIdx] := Widths[MaxIdx] - Shrink;
    Excess := Excess - Shrink;
  end;

  for I := 0 to FTabs.Count - 1 do
  begin
    Btn := FTabs[I].FButton;
    if Btn = nil then Continue;

    Btn.Width := Widths[I];
  end;
end;

function TDockingTabHost.FindTabByPaneHost(
  APaneHost: TDockingPaneHost): TDockingTab;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FTabs.Count - 1 do
    if FTabs[I].PaneHost = APaneHost then
      Exit(FTabs[I]);
end;

function TDockingTabHost.IndexOfTab(ATab: TDockingTab): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to FTabs.Count - 1 do
    if FTabs[I] = ATab then
      Exit(I);
end;

function TDockingTabHost.CanCloseTabInternal(ATab: TDockingTab): Boolean;
var
  AllOk: Boolean;
begin
  AllOk := True;
  if (ATab <> nil) and (ATab.PaneHost <> nil)
     and (ATab.PaneHost.Tree <> nil) then
    ATab.PaneHost.Tree.EnumerateLeaves(
      procedure(ALeaf: TPaneLeaf)
      begin
        if (ALeaf.Content <> nil) and (not ALeaf.Content.CanClose) then
          AllOk := False;
      end);
  Result := AllOk;
end;

(* === Обработчики событий внутренних PaneHost-ов === *)

procedure TDockingTabHost.HandlePaneHostActiveLeafChanged(Sender: TObject;
  AOldLeaf, ANewLeaf: TPaneLeaf);
var
  Host: TDockingPaneHost;
  Tab: TDockingTab;
begin
  if not (Sender is TDockingPaneHost) then Exit;
  Host := TDockingPaneHost(Sender);

  (* Обновить glyph таба — IsSingle мог измениться после split/close *)
  Tab := FindTabByPaneHost(Host);
  if (Tab <> nil) and (Tab.FButton <> nil) then
  begin
    Tab.FButton.UpdateCaption;
    UpdateTabButtonWidths;
  end;

  if not Host.IsEmpty then Exit;

  (* Termius-style: pane host опустошился → закрываем таб *)
  if Tab <> nil then
    ScheduleDeferredCloseTab(Tab);
end;

procedure TDockingTabHost.HandlePaneHostContentHeaderChanged(Sender: TObject;
  AContent: TDockingPaneContent);
var
  Host: TDockingPaneHost;
  Tab: TDockingTab;
begin
  if not (Sender is TDockingPaneHost) then Exit;
  Host := TDockingPaneHost(Sender);
  Tab := FindTabByPaneHost(Host);
  if Tab = nil then Exit;

  if Tab.IsSingle and (Host.ActiveLeafContent = AContent)
     and (AContent.Caption <> '') then
    Tab.Caption := AContent.Caption
  else if Tab.FButton <> nil then
  begin
    Tab.FButton.UpdateCaption;
    UpdateTabButtonWidths;
  end;
end;

procedure TDockingTabHost.HandlePaneHostContentNeeded(Sender: TObject;
  var AContent: TDockingPaneContent);
begin
  if Assigned(FOnContentNeeded) then
    FOnContentNeeded(Self, AContent);
end;

(* === API для TTabButton === *)

procedure TDockingTabHost.TabButton_Activate(ATab: TDockingTab);
begin
  InternalActivateTab(ATab);
end;

procedure TDockingTabHost.TabButton_RequestClose(ATab: TDockingTab);
begin
  CloseTab(ATab);
end;

procedure TDockingTabHost.TabButton_StartDrag(AButton: TTabButton);
begin
  FDropIndicator.Visible := True;
  FDropIndicator.BringToFront;
end;

procedure TDockingTabHost.TabButton_UpdateDrag(AButton: TTabButton;
  AScreenX: Single);
var
  LocalX: Single;
  TargetIdx: Integer;
  IndicatorX: Single;
  TargetBtn: TTabButton;
begin
  LocalX := TabBarLocalX(AScreenX);
  TargetIdx := FindDropTargetIndex(LocalX, AButton.Tab);

  if TargetIdx < 0 then
  begin
    FDropIndicator.Visible := False;
    Exit;
  end;

  if TargetIdx >= FTabs.Count then
  begin
    if FTabs.Count > 0 then
    begin
      TargetBtn := FTabs[FTabs.Count - 1].FButton;
      if TargetBtn <> nil then
        IndicatorX := TargetBtn.Position.X + TargetBtn.Width
      else
        IndicatorX := 0;
    end
    else
      IndicatorX := 0;
  end
  else
  begin
    TargetBtn := FTabs[TargetIdx].FButton;
    if TargetBtn <> nil then
      IndicatorX := TargetBtn.Position.X
    else
      IndicatorX := 0;
  end;

  FDropIndicator.Position.X := IndicatorX - TAB_DROP_INDICATOR_WIDTH / 2;
  FDropIndicator.Visible := True;
end;

procedure TDockingTabHost.TabButton_EndDrag(AButton: TTabButton;
  AScreenX: Single; AWasDragging: Boolean);
var
  LocalX: Single;
  TargetIdx, SrcIdx: Integer;
begin
  FDropIndicator.Visible := False;
  if not AWasDragging then Exit;

  LocalX := TabBarLocalX(AScreenX);
  TargetIdx := FindDropTargetIndex(LocalX, AButton.Tab);
  SrcIdx := IndexOfTab(AButton.Tab);
  if (SrcIdx < 0) or (TargetIdx < 0) then Exit;

  if TargetIdx > FTabs.Count - 1 then
    TargetIdx := FTabs.Count - 1;

  if TargetIdx = SrcIdx then Exit;
  MoveTab(AButton.Tab, TargetIdx);
end;

function TDockingTabHost.TabBarLocalX(AScreenX: Single): Single;
var
  Pt: TPointF;
begin
  Pt := FTabBar.ScreenToLocal(PointF(AScreenX, 0));
  Result := Pt.X;
end;

function TDockingTabHost.FindDropTargetIndex(ATabBarLocalX: Single;
  AExcludeTab: TDockingTab): Integer;
var
  I: Integer;
  Btn: TTabButton;
  MidX: Single;
begin
  Result := -1;
  for I := 0 to FTabs.Count - 1 do
  begin
    if FTabs[I] = AExcludeTab then Continue;
    Btn := FTabs[I].FButton;
    if Btn = nil then Continue;
    MidX := Btn.Position.X + Btn.Width / 2;
    if ATabBarLocalX < MidX then
      Exit(I);
  end;
  Result := FTabs.Count;
end;

(* === Drag-drop в split-зону (итерация 2.5) === *)

procedure TDockingTabHost.TabButton_EnterPaneDrag(AButton: TTabButton);
var
  Cur, Target: TDockingTab;
  TargetPaneHost: TDockingPaneHost;
begin
  FDropIndicator.Visible := False;
  Cursor := crDrag;

  Cur := AButton.Tab;

  (* Цель — активный таб. Особый случай: если тащимый и есть активный,
     цель остаётся им же. В этом случае drop означает не перенос таба,
     а "разделить нужный pane новым" (контент возьмём из фабрики). *)
  Target := FActiveTab;
  if Target = nil then Target := Cur;
  FCurrentDropTarget := Target;
  FCurrentDropLeaf := nil;

  (* Пересоздаём overlay каждый раз — избегаем накопления странностей
     после прошлых drag-ов (Parent:=nil, скрытие и т.п.). *)
  if FDropOverlay <> nil then
  begin
    FDropOverlay.Parent := nil;
    FDropOverlay.Free;
    FDropOverlay := nil;
  end;
  FDropOverlay := TDockingDropOverlay.Create(Self);

  if Target <> nil then
  begin
    TargetPaneHost := Target.PaneHost;
    FDropOverlay.Parent := TargetPaneHost;
    (* Стартовое позиционирование — на активный leaf, до первого
       UpdatePaneDrag, который перепозиционирует по курсору.
       Drop на свой же таб (источник = активный) не подсвечиваем — это no-op. *)
    if Target <> Cur then
      FDropOverlay.ShowAt(TargetPaneHost.ActiveLeafBounds);
  end;
end;

procedure TDockingTabHost.TabButton_LeavePaneDrag(AButton: TTabButton);
begin
  FDropOverlay.HideOverlay;
  FDropOverlay.Parent := nil;
  FCurrentDropTarget := nil;
  FCurrentDropLeaf := nil;
  Cursor := crDefault;
end;

procedure TDockingTabHost.TabButton_UpdatePaneDrag(AButton: TTabButton;
  const AScreenPt: TPointF);
var
  PaneLocalPt: TPointF;
  TargetTab: TDockingTab;
  TargetLeaf: TPaneLeaf;
  LeafBnds: TRectF;
  Hit: TDropHitResult;
begin
  TargetTab := FindDropTargetTab(AScreenPt, PaneLocalPt);

  if TargetTab = nil then
  begin
    FDropOverlay.HideOverlay;
    FCurrentDropTarget := nil;
    FCurrentDropLeaf := nil;
    Exit;
  end;

  (* Drop на свой же таб — overlay не показываем; HitTestZone у скрытого
     оверлея вернёт NoZone, так что и сам drop станет no-op. *)
  if TargetTab = AButton.Tab then
  begin
    FDropOverlay.HideOverlay;
    FCurrentDropTarget := TargetTab;
    FCurrentDropLeaf := nil;
    Exit;
  end;

  (* Найти КОНКРЕТНЫЙ leaf под курсором (не обязательно активный).
     Это даёт возможность сплитить любой pane целевого PaneHost-а,
     а не только активный. *)
  TargetLeaf := TargetTab.PaneHost.FindLeafAt(PaneLocalPt);
  if TargetLeaf = nil then
  begin
    FDropOverlay.HideOverlay;
    FCurrentDropLeaf := nil;
    Exit;
  end;

  (* Если поменялся целевой PaneHost ИЛИ leaf — пересоздать overlay на нём *)
  if (TargetTab <> FCurrentDropTarget) or (TargetLeaf <> FCurrentDropLeaf) then
  begin
    FCurrentDropTarget := TargetTab;
    FCurrentDropLeaf := TargetLeaf;
    FDropOverlay.Parent := TargetTab.PaneHost;
    LeafBnds := TargetTab.PaneHost.LeafBounds(TargetLeaf);
    FDropOverlay.ShowAt(LeafBnds);
  end;

  Hit := FDropOverlay.HitTestZone(PaneLocalPt.X, PaneLocalPt.Y);
  FDropOverlay.Highlight(Hit);
end;

procedure TDockingTabHost.TabButton_DropOnPane(AButton: TTabButton;
  const AScreenPt: TPointF);
var
  PaneLocalPt: TPointF;
  TargetTab: TDockingTab;
  TargetLeaf: TPaneLeaf;
  Hit: TDropHitResult;
begin
  TargetTab := FindDropTargetTab(AScreenPt, PaneLocalPt);
  TargetLeaf := nil;
  Hit := NoZone;
  if TargetTab <> nil then
  begin
    TargetLeaf := TargetTab.PaneHost.FindLeafAt(PaneLocalPt);
    if TargetLeaf <> nil then
      Hit := FDropOverlay.HitTestZone(PaneLocalPt.X, PaneLocalPt.Y);
  end;

  FDropOverlay.HideOverlay;
  FDropOverlay.Parent := nil;
  FCurrentDropTarget := nil;
  FCurrentDropLeaf := nil;
  Cursor := crDefault;

  if Hit.HasZone and (TargetTab <> nil) and (TargetLeaf <> nil) then
  begin
    (* Активировать конкретный leaf в target PaneHost, чтобы SplitActive
       сработал именно на него (он сплитит активный leaf). *)
    TargetTab.PaneHost.ActiveLeaf := TargetLeaf;
    PerformDockMove(AButton.Tab, TargetTab, Hit.Direction);
  end;
end;

function TDockingTabHost.FindDropTargetTab(const AScreenPt: TPointF;
  out APaneLocalPt: TPointF): TDockingTab;
var
  TargetPaneHost: TDockingPaneHost;
begin
  Result := nil;
  APaneLocalPt := PointF(0, 0);
  (* В этой итерации цель = активный таб (фокусированный pane).
     Если на v3 будет hit-test по другим табам — расширим логику. *)
  if FActiveTab = nil then Exit;
  Result := FActiveTab;
  TargetPaneHost := Result.PaneHost;
  if TargetPaneHost = nil then
  begin
    Result := nil;
    Exit;
  end;
  APaneLocalPt := TargetPaneHost.ScreenToLocal(AScreenPt);
end;

procedure TDockingTabHost.PerformDockMove(ASourceTab, ATargetTab: TDockingTab;
  ADir: TSplitDirection);
var
  Content: TDockingPaneContent;
begin
  if (ASourceTab = nil) or (ATargetTab = nil) then Exit;

  if ASourceTab = ATargetTab then
  begin
    (* Тащимый = активный = target. Это не перенос таба, а просьба
       "разделить мой текущий pane новым". SplitActive с nil заставит
       PaneHost дёрнуть свою фабрику OnContentNeeded (которая у нас
       форвардит к OnContentNeeded TabHost-а). *)
    ATargetTab.PaneHost.SplitActive(ADir, nil);
    Exit;
  end;

  if not ASourceTab.IsSingle then Exit;

  (* Перенос: забрать контент из source и вложить в split target *)
  Content := ASourceTab.PaneHost.TakeActiveContent;
  if Content = nil then Exit;
  ATargetTab.PaneHost.SplitActive(ADir, Content);
end;

(* === Drag header pane-а === *)

procedure TDockingTabHost.HandlePaneHostHeaderDrag(ASender: TDockingPaneHost;
  ALeaf: TPaneLeaf; APhase: TPaneHeaderDragPhase; const AScreenPt: TPointF);
begin
  case APhase of
    phdStart: PaneHeader_Begin(ASender, ALeaf);
    phdMove:  PaneHeader_Update(AScreenPt);
    phdEnd:   PaneHeader_End(AScreenPt);
  end;
end;

procedure TDockingTabHost.PaneHeader_Begin(ASourceHost: TDockingPaneHost;
  ASourceLeaf: TPaneLeaf);
begin
  FHeaderDragSourceHost := ASourceHost;
  FHeaderDragSourceLeaf := ASourceLeaf;
  FHeaderDragOverTabBar := False;
  Cursor := crDrag;

  (* Пересоздаём overlay, как делает TabButton_EnterPaneDrag — чтобы
     избежать накопленных проблем с Parent/Visible после прошлых drag-ов. *)
  if FDropOverlay <> nil then
  begin
    FDropOverlay.Parent := nil;
    FDropOverlay.Free;
    FDropOverlay := nil;
  end;
  FDropOverlay := TDockingDropOverlay.Create(Self);
  FCurrentDropTarget := nil;
  FCurrentDropLeaf := nil;
end;

procedure TDockingTabHost.PaneHeader_Update(const AScreenPt: TPointF);
var
  HostPt, PaneLocalPt: TPointF;
  IsOverTabBar: Boolean;
  TargetTab: TDockingTab;
  TargetLeaf: TPaneLeaf;
  LeafBnds: TRectF;
  Hit: TDropHitResult;
begin
  if FHeaderDragSourceLeaf = nil then Exit;

  HostPt := ScreenToLocal(AScreenPt);
  IsOverTabBar := (HostPt.Y >= 0) and (HostPt.Y <= TAB_BAR_HEIGHT)
                  and (HostPt.X >= 0) and (HostPt.X <= Width);

  if IsOverTabBar then
  begin
    (* Skрываем split-overlay, показываем подсказку в таббаре. *)
    FDropOverlay.HideOverlay;
    FCurrentDropTarget := nil;
    FCurrentDropLeaf := nil;
    if not FHeaderDragOverTabBar then
    begin
      FHeaderDragOverTabBar := True;
      PaneHeader_ShowTabBarHint;
    end;
    Exit;
  end;

  if FHeaderDragOverTabBar then
  begin
    FHeaderDragOverTabBar := False;
    PaneHeader_HideTabBarHint;
  end;

  (* Над активным pane host-ом — обычная split-логика *)
  if FActiveTab = nil then Exit;
  TargetTab := FActiveTab;
  PaneLocalPt := TargetTab.PaneHost.ScreenToLocal(AScreenPt);
  TargetLeaf := TargetTab.PaneHost.FindLeafAt(PaneLocalPt);

  if TargetLeaf = nil then
  begin
    FDropOverlay.HideOverlay;
    FCurrentDropLeaf := nil;
    Exit;
  end;

  (* Drop на тот же лист, который тащим — overlay прячем. Так юзер сразу
     видит, что drop на самого себя ничего не сделает (HitTestZone у скрытого
     overlay вернёт NoZone, и PaneHeader_End не выполнит split). *)
  if TargetLeaf = FHeaderDragSourceLeaf then
  begin
    FDropOverlay.HideOverlay;
    FCurrentDropTarget := TargetTab;
    FCurrentDropLeaf := TargetLeaf;
    Exit;
  end;

  if (TargetTab <> FCurrentDropTarget) or (TargetLeaf <> FCurrentDropLeaf) then
  begin
    FCurrentDropTarget := TargetTab;
    FCurrentDropLeaf := TargetLeaf;
    FDropOverlay.Parent := TargetTab.PaneHost;
    LeafBnds := TargetTab.PaneHost.LeafBounds(TargetLeaf);
    FDropOverlay.ShowAt(LeafBnds);
  end;

  Hit := FDropOverlay.HitTestZone(PaneLocalPt.X, PaneLocalPt.Y);
  FDropOverlay.Highlight(Hit);
end;

procedure TDockingTabHost.PaneHeader_End(const AScreenPt: TPointF);
var
  HostPt, PaneLocalPt: TPointF;
  IsOverTabBar: Boolean;
  TargetTab: TDockingTab;
  TargetLeaf: TPaneLeaf;
  Hit: TDropHitResult;
  Content: TDockingPaneContent;
  SourceLeaf: TPaneLeaf;
  SourceHost: TDockingPaneHost;
  Caption: string;
begin
  SourceLeaf := FHeaderDragSourceLeaf;
  SourceHost := FHeaderDragSourceHost;

  HostPt := ScreenToLocal(AScreenPt);
  IsOverTabBar := (HostPt.Y >= 0) and (HostPt.Y <= TAB_BAR_HEIGHT)
                  and (HostPt.X >= 0) and (HostPt.X <= Width);

  TargetTab := nil;
  TargetLeaf := nil;
  Hit := NoZone;
  if (not IsOverTabBar) and (FActiveTab <> nil) then
  begin
    TargetTab := FActiveTab;
    PaneLocalPt := TargetTab.PaneHost.ScreenToLocal(AScreenPt);
    TargetLeaf := TargetTab.PaneHost.FindLeafAt(PaneLocalPt);
    if TargetLeaf <> nil then
      Hit := FDropOverlay.HitTestZone(PaneLocalPt.X, PaneLocalPt.Y);
  end;

  (* Чистим визуал ДО действий — иначе при пересборке деревьев
     overlay может зацепиться за исчезающие layout-ы. *)
  FDropOverlay.HideOverlay;
  FDropOverlay.Parent := nil;
  FCurrentDropTarget := nil;
  FCurrentDropLeaf := nil;
  PaneHeader_HideTabBarHint;
  FHeaderDragOverTabBar := False;
  Cursor := crDefault;

  FHeaderDragSourceHost := nil;
  FHeaderDragSourceLeaf := nil;

  if (SourceLeaf = nil) or (SourceHost = nil) then Exit;

  (* Drop на TabBar — новый таб с содержимым source. *)
  if IsOverTabBar then
  begin
    Caption := 'Tab';
    if SourceLeaf.Content <> nil then
      Caption := SourceLeaf.Content.Caption;
    Content := SourceHost.TakeLeafContent(SourceLeaf);
    if Content <> nil then
      AddTabWithContent(Caption, Content);
    Exit;
  end;

  (* Drop на pane — split цели. *)
  if not Hit.HasZone then Exit;
  if (TargetTab = nil) or (TargetLeaf = nil) then Exit;
  if TargetLeaf = SourceLeaf then Exit;     (* drop на себя — no-op *)

  Content := SourceHost.TakeLeafContent(SourceLeaf);
  if Content = nil then Exit;

  (* После TakeLeafContent дерево source могло перестроиться,
     но target leaf жив (мы трогали только source). Активируем
     цель и сплитим её. *)
  TargetTab.PaneHost.ActiveLeaf := TargetLeaf;
  TargetTab.PaneHost.SplitActive(Hit.Direction, Content);
end;

procedure TDockingTabHost.PaneHeader_ShowTabBarHint;
var
  LastBtn: TTabButton;
  IndicatorX: Single;
begin
  if FDropIndicator = nil then Exit;
  (* Индикатор справа от последнего таба — место, куда добавится новый *)
  if FTabs.Count > 0 then
  begin
    LastBtn := FTabs[FTabs.Count - 1].FButton;
    if LastBtn <> nil then
      IndicatorX := LastBtn.Position.X + LastBtn.Width
    else
      IndicatorX := 0;
  end
  else
    IndicatorX := 0;
  FDropIndicator.Position.X := IndicatorX - TAB_DROP_INDICATOR_WIDTH / 2;
  FDropIndicator.Visible := True;
  FDropIndicator.BringToFront;
end;

procedure TDockingTabHost.PaneHeader_HideTabBarHint;
begin
  if FDropIndicator <> nil then
    FDropIndicator.Visible := False;
end;

end.
