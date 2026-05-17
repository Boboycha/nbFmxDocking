unit nbDocking.PaneHost;

(*
  Инварианты владения и rebuild-а:

  - Owner каждого TnbDockingPaneContent = PaneHost. При уничтожении хоста
    FMX cascade подберёт и контент.
  - На любое OnChanged дерева визуал пересоздаётся целиком. Перед сносом
    старых обёрток DetachAllContents выставляет Parent := nil у живых
    контентов — иначе FMX каскадно уничтожит их вместе с обёрткой.
  - Контент уничтожается ТОЛЬКО в CloseActive (через TThread.Queue —
    см. комментарий там). TakeActiveContent/TakeLeafContent снимают
    контент с дерева без Free для переноса в другой хост.
*)

interface

uses
  System.Classes, System.SysUtils, System.UITypes, System.Types,
  System.Generics.Collections,
  FMX.Types, FMX.Controls, FMX.Layouts, FMX.StdCtrls, FMX.Edit,
  FMX.Objects, FMX.Graphics,
  nbDocking.Types, nbDocking.PaneTree;

type
  TContentFactoryEvent = procedure(Sender: TObject;
    var AContent: TnbDockingPaneContent) of object;
  TActiveLeafChangeEvent = procedure(Sender: TObject;
    AOldLeaf, ANewLeaf: TPaneLeaf) of object;
  TContentHeaderChangeEvent = procedure(Sender: TObject;
    AContent: TnbDockingPaneContent) of object;

  (* Drag заголовка pane транслируется наверх — drop-цель ищет TabHost. *)
  TPaneHeaderDragPhase = (phdStart, phdMove, phdEnd);

  TnbDockingPaneHost = class;

  TPaneHeaderDragEvent = procedure(ASender: TnbDockingPaneHost; ALeaf: TPaneLeaf;
    APhase: TPaneHeaderDragPhase; const AScreenPt: TPointF) of object;

  (* Какой split режет сплиттер и индекс ребёнка-соседа слева/сверху. *)
  TSplitterInfo = class
  public
    Split: TPaneSplit;
    LeftChildIndex: Integer;
    constructor Create(ASplit: TPaneSplit; ALeftIdx: Integer);
  end;

  TPaneHeaderDragState = (hdsIdle, hdsArmed, hdsDragging);

  TPaneHeaderActionButton = class(TRectangle)
  public
    ActionId: string;
  end;

  TPaneFocusItem = class(TRectangle)
  public
    Leaf: TPaneLeaf;
  end;

  TPaneLeafFrame = class(TRectangle)
  private
    FHost: TnbDockingPaneHost;
    FLeaf: TPaneLeaf;
    FHeader: TRectangle;
    FTitleLabel: TLabel;
    FTitleEdit: TEdit;
    FActionsLayout: TLayout;
    FFocusBtn: TRectangle;
    FFocusGlyph: TText;
    FCloseBtn: TRectangle;
    FCloseGlyph: TText;
    FActionButtons: TList<TPaneHeaderActionButton>;
    FDragState: TPaneHeaderDragState;
    FDragStartX, FDragStartY: Single;
    FEditingTitle: Boolean;
    FHeaderHovered: Boolean;
    procedure BeginRename;
    procedure CommitRename;
    procedure CancelRename;
    procedure RebuildHeaderActions;
    procedure LayoutHeaderActionButtons;
    procedure UpdateHeaderActionsVisibility;
    procedure HandleFrameMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure HandleActionMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure HandleFrameMouseEnter(Sender: TObject);
    procedure HandleFrameMouseLeave(Sender: TObject);
    procedure HandleFocusMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure HandleCloseMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure HandleHeaderDblClick(Sender: TObject);
    procedure HandleHeaderMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure HandleHeaderMouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Single);
    procedure HandleHeaderMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure HandleHeaderMouseEnter(Sender: TObject);
    procedure HandleHeaderMouseLeave(Sender: TObject);
    procedure HandleEditExit(Sender: TObject);
    procedure HandleEditKeyDown(Sender: TObject; var Key: Word;
      var KeyChar: Char; Shift: TShiftState);
  public
    constructor Create(AHost: TnbDockingPaneHost; ALeaf: TPaneLeaf); reintroduce;
    destructor Destroy; override;
    procedure UpdateFromContent;
    procedure SetActive(AIsActive: Boolean);
    procedure SetHeaderVisible(AVisible: Boolean);
    property Leaf: TPaneLeaf read FLeaf;
    property Header: TRectangle read FHeader;

    (* Слот под доп. кнопки header (split-icon, reload, maximize и т.п.) —
       Align=Right, видимость = (Leaf = ActiveLeaf). *)
    property ActionsLayout: TLayout read FActionsLayout;
  end;

  TnbDockingPaneHost = class(TLayout)
  private
    FTree: TPaneTree;
    FActiveLeaf: TPaneLeaf;
    FRootLayout: TLayout;
    FBuilding: Boolean;
    FLeafFrameThickness: Single;
    FLeafFrameColor: TAlphaColor;
    FActiveLeafFrameColor: TAlphaColor;
    FBackgroundColor: TAlphaColor;
    FHeaderHeight: Single;
    FSplitterSize: Single;
    FSplitterColor: TAlphaColor;
    FSplitterCovers: TList<TRectangle>;
    FAutoMatchBg: Boolean;
    FBackgroundRect: TRectangle;
    FSplitterInfos: TObjectList<TSplitterInfo>;
    FOnContentNeeded: TContentFactoryEvent;
    FOnActiveLeafChanged: TActiveLeafChangeEvent;
    FOnContentHeaderChanged: TContentHeaderChangeEvent;
    FOnHeaderDrag: TPaneHeaderDragEvent;
    FFocusMode: Boolean;

    procedure HandleTreeChanged(Sender: TPaneTree);
    procedure HandleContentSplitRequest(Sender: TnbDockingPaneContent;
      ADirection: TSplitDirection);
    procedure HandleContentCloseRequest(Sender: TnbDockingPaneContent);
    procedure HandleContentActivateRequest(Sender: TnbDockingPaneContent);
    procedure HandleContentHeaderChanged(Sender: TnbDockingPaneContent);
    procedure HandleSplitLayoutResize(Sender: TObject);
    procedure HandleSplitterMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);

    procedure WireContent(AContent: TnbDockingPaneContent);
    procedure DetachAllContents;
    procedure RebuildVisualTree;
    procedure RebuildFocusVisualTree;
    function BuildNode(ANode: TPaneNode; AContainer: TFmxObject;
      AAlign: TAlignLayout; ASize: Single): TFmxObject;
    function BuildLeaf(ALeaf: TPaneLeaf; AContainer: TFmxObject;
      AAlign: TAlignLayout; ASize: Single): TPaneLeafFrame;
    function BuildSplit(ASplit: TPaneSplit; AContainer: TFmxObject;
      AAlign: TAlignLayout; ASize: Single): TLayout;
    procedure RecalcSplitChildSizes(ASplit: TPaneSplit; ASplitLayout: TLayout);
    procedure RecalcSplitProportions(ASplit: TPaneSplit; AContainer: TLayout);
    function FindLeafByContent(AContent: TnbDockingPaneContent): TPaneLeaf;
    function FindFrameRectFor(AContainer: TFmxObject;
      ALeaf: TPaneLeaf): TRectangle;
    procedure UpdateActiveFrames;
    procedure InternalSetActive(ALeaf: TPaneLeaf);
    procedure SetActiveLeaf(AValue: TPaneLeaf);
    procedure SetFocusMode(AValue: Boolean);
    procedure SetBackgroundColor(AValue: TAlphaColor);
    procedure SyncBgFromContent(AContent: TnbDockingPaneContent);
    procedure HandleFocusItemMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure SetInitialContent(AContent: TnbDockingPaneContent);
    function SplitActive(ADirection: TSplitDirection;
      ANewContent: TnbDockingPaneContent = nil): TPaneLeaf;
    procedure CloseActive;
    procedure ActivateContent(AContent: TnbDockingPaneContent);
    function IsEmpty: Boolean;

    (* В отличие от CloseActive — контент НЕ уничтожается, лист удаляется
       из дерева; для drag-drop переноса в другой хост. *)
    function TakeActiveContent: TnbDockingPaneContent;
    function TakeLeafContent(ALeaf: TPaneLeaf): TnbDockingPaneContent;

    procedure NotifyHeaderDrag(ALeaf: TPaneLeaf; APhase: TPaneHeaderDragPhase;
      const AScreenPt: TPointF);
    procedure EnterFocusMode;
    procedure ExitFocusMode;
    procedure ToggleFocusMode;

    function ActiveLeafContent: TnbDockingPaneContent;
    function ActiveLeafBounds: TRectF;
    function FindLeafAt(const APt: TPointF): TPaneLeaf;
    function LeafBounds(ALeaf: TPaneLeaf): TRectF;

    property Tree: TPaneTree read FTree;
    property ActiveLeaf: TPaneLeaf read FActiveLeaf write SetActiveLeaf;
    property FocusMode: Boolean read FFocusMode write SetFocusMode;
  published
    property LeafFrameThickness: Single read FLeafFrameThickness
      write FLeafFrameThickness;
    property LeafFrameColor: TAlphaColor read FLeafFrameColor
      write FLeafFrameColor;
    property ActiveLeafFrameColor: TAlphaColor read FActiveLeafFrameColor
      write FActiveLeafFrameColor;
    property BackgroundColor: TAlphaColor read FBackgroundColor
      write SetBackgroundColor;
    property SplitterSize: Single read FSplitterSize write FSplitterSize;
    property SplitterColor: TAlphaColor read FSplitterColor write FSplitterColor;
    property AutoMatchBg: Boolean read FAutoMatchBg write FAutoMatchBg;
    property HeaderHeight: Single read FHeaderHeight write FHeaderHeight;
    property OnContentNeeded: TContentFactoryEvent read FOnContentNeeded
      write FOnContentNeeded;
    property OnActiveLeafChanged: TActiveLeafChangeEvent
      read FOnActiveLeafChanged write FOnActiveLeafChanged;
    property OnContentHeaderChanged: TContentHeaderChangeEvent
      read FOnContentHeaderChanged write FOnContentHeaderChanged;
    property OnHeaderDrag: TPaneHeaderDragEvent read FOnHeaderDrag
      write FOnHeaderDrag;
  end;

implementation

{ TSplitterInfo }

constructor TSplitterInfo.Create(ASplit: TPaneSplit; ALeftIdx: Integer);
begin
  inherited Create;
  Split := ASplit;
  LeftChildIndex := ALeftIdx;
end;

type
  (* Доступ к protected Capture/ReleaseCapture FHeader через cast-наследника. *)
  TControlAccess = class(TControl);

function BlendPaneColor(AColor1, AColor2: TAlphaColor;
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

{ TPaneLeafFrame }

constructor TPaneLeafFrame.Create(AHost: TnbDockingPaneHost; ALeaf: TPaneLeaf);
begin
  inherited Create(AHost);
  FHost := AHost;
  FLeaf := ALeaf;
  FActionButtons := TList<TPaneHeaderActionButton>.Create;
  XRadius:=10;
  YRadius:=10;
  (* TagObject связывает frame с листом для FindFrameRectFor. *)
  TagObject := ALeaf;

  Fill.Kind := TBrushKind.Solid;
  Fill.Color := AHost.BackgroundColor;
  Stroke.Color := AHost.LeafFrameColor;
  Stroke.Thickness := AHost.LeafFrameThickness;
  HitTest := True;
  Padding.Rect := RectF(AHost.LeafFrameThickness, AHost.LeafFrameThickness,
                        AHost.LeafFrameThickness, AHost.LeafFrameThickness);
  OnMouseDown := HandleFrameMouseDown;
  OnMouseEnter := HandleFrameMouseEnter;
  OnMouseLeave := HandleFrameMouseLeave;

  FHeader := TRectangle.Create(Self);
  FHeader.Corners:=[TCorner.TopLeft, TCorner.TopRight];
  FHeader.XRadius:=10;
  FHeader.YRadius:=10;

  FHeader.Parent := Self;
  FHeader.Align := TAlignLayout.Top;
  FHeader.Height := AHost.HeaderHeight;
  FHeader.Stroke.Kind := TBrushKind.None;
  FHeader.Fill.Kind := TBrushKind.Solid;
  FHeader.HitTest := True;
  FHeader.OnMouseDown := HandleHeaderMouseDown;
  FHeader.OnMouseMove := HandleHeaderMouseMove;
  FHeader.OnMouseUp := HandleHeaderMouseUp;
  FHeader.OnMouseEnter := HandleHeaderMouseEnter;
  FHeader.OnMouseLeave := HandleHeaderMouseLeave;

  FActionsLayout := TLayout.Create(Self);
  FActionsLayout.Parent := FHeader;
  FActionsLayout.Align := TAlignLayout.Right;
  FActionsLayout.Width := 24;
  FActionsLayout.Visible := False;
  FActionsLayout.HitTest := True;

  (* Порядок создания важен: FTitleLabel (Align=Client) после
     FActionsLayout (Align=Right) — иначе FMX отдаст Client всё, не
     оставив Right-слоту места. *)
  FTitleLabel := TLabel.Create(Self);
  FTitleLabel.Parent := FHeader;
  FTitleLabel.Align := TAlignLayout.Client;
  FTitleLabel.Margins.Rect := RectF(8, 0, 4, 0);
  FTitleLabel.TextSettings.HorzAlign := TTextAlign.Leading;
  FTitleLabel.TextSettings.VertAlign := TTextAlign.Center;
  FTitleLabel.TextSettings.Font.Size := 12;
  FTitleLabel.StyledSettings := [];
  FTitleLabel.HitTest := False;

  FTitleEdit := TEdit.Create(Self);
  FTitleEdit.Parent := FHeader;
  FTitleEdit.Align := TAlignLayout.Client;
  FTitleEdit.Margins.Rect := RectF(8, 2, 4, 2);
  FTitleEdit.Visible := False;
  FTitleEdit.OnExit := HandleEditExit;
  FTitleEdit.OnKeyDown := HandleEditKeyDown;

  FFocusBtn := TRectangle.Create(Self);
  FFocusBtn.Parent := FActionsLayout;
  FFocusBtn.Align := TAlignLayout.None;
  FFocusBtn.Width := 20;
  FFocusBtn.Height := AHost.HeaderHeight - 7;
  FFocusBtn.Margins.Rect := RectF(0, 3, 4, 3);
  FFocusBtn.Fill.Kind := TBrushKind.None;
  FFocusBtn.Stroke.Kind := TBrushKind.None;
  FFocusBtn.XRadius := 3;
  FFocusBtn.YRadius := 3;
  FFocusBtn.HitTest := True;
  FFocusBtn.OnMouseDown := HandleFocusMouseDown;

  FFocusGlyph := TText.Create(Self);
  FFocusGlyph.Parent := FFocusBtn;
  FFocusGlyph.Align := TAlignLayout.Client;
  FFocusGlyph.Text := 'F';
  FFocusGlyph.TextSettings.HorzAlign := TTextAlign.Center;
  FFocusGlyph.TextSettings.VertAlign := TTextAlign.Center;
  FFocusGlyph.TextSettings.Font.Size := 11;
  FFocusGlyph.HitTest := False;

  FCloseBtn := TRectangle.Create(Self);
  FCloseBtn.Parent := FActionsLayout;
  FCloseBtn.Align := TAlignLayout.None;
  FCloseBtn.Width := 20;
  FCloseBtn.Height := AHost.HeaderHeight - 7;
  FCloseBtn.Margins.Rect := RectF(0, 3, 4, 3);
  FCloseBtn.Fill.Kind := TBrushKind.None;
  FCloseBtn.Stroke.Kind := TBrushKind.None;
  FCloseBtn.XRadius := 3;
  FCloseBtn.YRadius := 3;
  FCloseBtn.HitTest := True;
  FCloseBtn.OnMouseDown := HandleCloseMouseDown;

  FCloseGlyph := TText.Create(Self);
  FCloseGlyph.Parent := FCloseBtn;
  FCloseGlyph.Align := TAlignLayout.Client;
  FCloseGlyph.Text := 'x';
  FCloseGlyph.TextSettings.HorzAlign := TTextAlign.Center;
  FCloseGlyph.TextSettings.VertAlign := TTextAlign.Center;
  FCloseGlyph.TextSettings.Font.Size := 11;
  FCloseGlyph.HitTest := False;

  FHeader.OnDblClick := HandleHeaderDblClick;
  LayoutHeaderActionButtons;
end;

destructor TPaneLeafFrame.Destroy;
var
  I: Integer;
begin
  for I := FActionButtons.Count - 1 downto 0 do
    FActionButtons[I].Free;
  FActionButtons.Free;
  inherited;
end;

procedure TPaneLeafFrame.BeginRename;
var
  C: TnbDockingPaneContent;
begin
  if (FLeaf = nil) or (FTitleEdit = nil) then Exit;
  C := FLeaf.Content;
  if C = nil then Exit;

  FDragState := hdsIdle;
  TControlAccess(FHeader).ReleaseCapture;

  FEditingTitle := True;
  FTitleLabel.Visible := False;
  FTitleEdit.Text := C.Caption;
  FTitleEdit.Visible := True;
  FTitleEdit.SetFocus;
  FTitleEdit.SelectAll;
end;

procedure TPaneLeafFrame.CommitRename;
var
  C: TnbDockingPaneContent;
  NewCaption: string;
begin
  if not FEditingTitle then Exit;
  FEditingTitle := False;

  NewCaption := Trim(FTitleEdit.Text);
  FTitleEdit.Visible := False;
  FTitleLabel.Visible := True;

  if FLeaf <> nil then
  begin
    C := FLeaf.Content;
    if (C <> nil) and (NewCaption <> '') then
      C.Caption := NewCaption
    else
      UpdateFromContent;
  end;
end;

procedure TPaneLeafFrame.CancelRename;
begin
  if not FEditingTitle then Exit;
  FEditingTitle := False;
  FTitleEdit.Visible := False;
  FTitleLabel.Visible := True;
  UpdateFromContent;
end;

procedure TPaneLeafFrame.UpdateFromContent;
var
  C: TnbDockingPaneContent;
begin
  if FLeaf = nil then Exit;
  C := FLeaf.Content;
  if C = nil then Exit;
  if FEditingTitle then Exit;

  Fill.Kind := TBrushKind.Solid;
  Fill.Color := C.HeaderBgColor;
  FHeader.Fill.Kind := TBrushKind.Solid;
  FHeader.Fill.Color := C.HeaderBgColor;
  FTitleLabel.TextSettings.FontColor := C.HeaderTextColor;
  FFocusGlyph.TextSettings.FontColor := C.HeaderTextColor;
  FCloseGlyph.TextSettings.FontColor := C.HeaderTextColor;
  FTitleLabel.Text := C.Caption;
  RebuildHeaderActions;
  SetActive(FLeaf = FHost.ActiveLeaf);
end;

procedure TPaneLeafFrame.RebuildHeaderActions;
var
  C: TnbDockingPaneContent;
  I: Integer;
  Action: TDockingPaneHeaderAction;
  ActionButton: TPaneHeaderActionButton;
  ActionGlyph: TText;
begin
  if (FLeaf = nil) or (FActionsLayout = nil) then Exit;
  C := FLeaf.Content;
  if C = nil then Exit;

  for I := FActionButtons.Count - 1 downto 0 do
    FActionButtons[I].Free;
  FActionButtons.Clear;

  for I := 0 to C.HeaderActions.Count - 1 do
  begin
    Action := C.HeaderActions[I];

    ActionButton := TPaneHeaderActionButton.Create(Self);
    ActionButton.Parent := FActionsLayout;
    ActionButton.Align := TAlignLayout.None;
    ActionButton.Width := 20;
    ActionButton.Height := FHost.HeaderHeight - 7;
    ActionButton.Margins.Rect := RectF(0, 3, 4, 3);
    ActionButton.Fill.Kind := TBrushKind.None;
    ActionButton.Stroke.Kind := TBrushKind.None;
    ActionButton.XRadius := 3;
    ActionButton.YRadius := 3;
    ActionButton.HitTest := True;
    ActionButton.ActionId := Action.Id;
    ActionButton.OnMouseDown := HandleActionMouseDown;

    ActionGlyph := TText.Create(Self);
    ActionGlyph.Parent := ActionButton;
    ActionGlyph.Align := TAlignLayout.Client;
    ActionGlyph.Text := Action.Glyph;
    ActionGlyph.TextSettings.HorzAlign := TTextAlign.Center;
    ActionGlyph.TextSettings.VertAlign := TTextAlign.Center;
    ActionGlyph.TextSettings.Font.Size := 11;
    ActionGlyph.TextSettings.FontColor := C.HeaderTextColor;
    ActionGlyph.HitTest := False;

    FActionButtons.Add(ActionButton);
  end;

  LayoutHeaderActionButtons;
end;

procedure TPaneLeafFrame.LayoutHeaderActionButtons;
var
  I: Integer;
  FocusVisible: Boolean;
  Slot: Integer;
begin
  if FActionsLayout = nil then Exit;

  FocusVisible := (FHost.Tree.LeafCount >= 2) or FHost.FocusMode;
  Slot := 0;
  for I := 0 to FActionButtons.Count - 1 do
  begin
    FActionButtons[I].Position.X := Slot * 24;
    FActionButtons[I].Position.Y := 3;
    FActionButtons[I].Width := 20;
    FActionButtons[I].Height := FHost.HeaderHeight - 7;
    Inc(Slot);
  end;

  if FFocusBtn <> nil then
  begin
    FFocusBtn.Visible := FocusVisible;
    if FocusVisible then
    begin
      FFocusBtn.Position.X := Slot * 24;
      FFocusBtn.Position.Y := 3;
      FFocusBtn.Width := 20;
      FFocusBtn.Height := FHost.HeaderHeight - 7;
      Inc(Slot);
    end;
  end;

  if FCloseBtn <> nil then
  begin
    FCloseBtn.Position.X := Slot * 24;
    FCloseBtn.Position.Y := 3;
    FCloseBtn.Width := 20;
    FCloseBtn.Height := FHost.HeaderHeight - 7;
    Inc(Slot);
  end;
  FActionsLayout.Width := Slot * 24;
  UpdateHeaderActionsVisibility;
end;

procedure TPaneLeafFrame.UpdateHeaderActionsVisibility;
begin
  if FActionsLayout <> nil then
    FActionsLayout.Visible := (FLeaf = FHost.ActiveLeaf) or FEditingTitle
      or FHeaderHovered;
end;

procedure TPaneLeafFrame.SetActive(AIsActive: Boolean);
var
  C: TnbDockingPaneContent;
begin
  if AIsActive then
  begin
    C := nil;
    if FLeaf <> nil then
      C := FLeaf.Content;
    if C <> nil then
      Stroke.Color := C.HeaderTextColor
    else
      Stroke.Color := FHost.ActiveLeafFrameColor;
    Stroke.Thickness := FHost.LeafFrameThickness;
  end
  else
  begin
    C := nil;
    if FLeaf <> nil then
      C := FLeaf.Content;
    if C <> nil then
      Stroke.Color := BlendPaneColor(C.HeaderBgColor, C.HeaderTextColor, 0.42)
    else
      Stroke.Color := FHost.LeafFrameColor;
    Stroke.Thickness := FHost.LeafFrameThickness;
  end;
  Padding.Rect := RectF(Stroke.Thickness, Stroke.Thickness,
                        Stroke.Thickness, Stroke.Thickness);
  UpdateHeaderActionsVisibility;
end;

procedure TPaneLeafFrame.SetHeaderVisible(AVisible: Boolean);
begin
  if FHeader = nil then Exit;
  FHeader.Visible := AVisible;
end;

procedure TPaneLeafFrame.HandleFrameMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  if FLeaf = nil then Exit;
  if FLeaf <> FHost.ActiveLeaf then
    FHost.ActiveLeaf := FLeaf;
end;

procedure TPaneLeafFrame.HandleActionMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  C: TnbDockingPaneContent;
  ActionButton: TPaneHeaderActionButton;
begin
  if Button <> TMouseButton.mbLeft then Exit;
  if FEditingTitle then Exit;
  if (FLeaf = nil) or not (Sender is TPaneHeaderActionButton) then Exit;

  if FLeaf <> FHost.ActiveLeaf then
    FHost.ActiveLeaf := FLeaf;

  C := FLeaf.Content;
  if C = nil then Exit;

  ActionButton := TPaneHeaderActionButton(Sender);
  C.ExecuteHeaderAction(ActionButton.ActionId);
end;

procedure TPaneLeafFrame.HandleFocusMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  if Button <> TMouseButton.mbLeft then Exit;
  if FEditingTitle then Exit;
  if (FLeaf <> nil) and (FLeaf <> FHost.ActiveLeaf) then
    FHost.ActiveLeaf := FLeaf;
  FHost.ToggleFocusMode;
end;

procedure TPaneLeafFrame.HandleCloseMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  if Button <> TMouseButton.mbLeft then Exit;
  if FEditingTitle then Exit;
  if (FLeaf <> nil) and (FLeaf <> FHost.ActiveLeaf) then
    FHost.ActiveLeaf := FLeaf;
  FHost.CloseActive;
end;

procedure TPaneLeafFrame.HandleHeaderDblClick(Sender: TObject);
begin
  BeginRename;
end;

procedure TPaneLeafFrame.HandleHeaderMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  if Button <> TMouseButton.mbLeft then Exit;
  if FLeaf = nil then Exit;
  if FEditingTitle then Exit;

  if FLeaf <> FHost.ActiveLeaf then
    FHost.ActiveLeaf := FLeaf;

  FDragState := hdsArmed;
  FDragStartX := X;
  FDragStartY := Y;
  TControlAccess(FHeader).Capture;
end;

procedure TPaneLeafFrame.HandleHeaderMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Single);
const
  DRAG_THRESHOLD = 5;
var
  ScreenPt: TPointF;
begin
  if FDragState = hdsIdle then Exit;
  if FLeaf = nil then Exit;
  if FEditingTitle then Exit;

  if FDragState = hdsArmed then
  begin
    if (Abs(X - FDragStartX) > DRAG_THRESHOLD) or
       (Abs(Y - FDragStartY) > DRAG_THRESHOLD) then
    begin
      FDragState := hdsDragging;
      Opacity := 0.6;
      ScreenPt := FHeader.LocalToScreen(PointF(X, Y));
      FHost.NotifyHeaderDrag(FLeaf, phdStart, ScreenPt);
    end;
  end;

  if FDragState = hdsDragging then
  begin
    ScreenPt := FHeader.LocalToScreen(PointF(X, Y));
    FHost.NotifyHeaderDrag(FLeaf, phdMove, ScreenPt);
  end;
end;

procedure TPaneLeafFrame.HandleHeaderMouseUp(Sender: TObject;
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
  if WasDragging and (FLeaf <> nil) then
  begin
    ScreenPt := FHeader.LocalToScreen(PointF(X, Y));
    FHost.NotifyHeaderDrag(FLeaf, phdEnd, ScreenPt);
  end;
end;

procedure TPaneLeafFrame.HandleFrameMouseEnter(Sender: TObject);
begin
  FHeaderHovered := True;
  UpdateHeaderActionsVisibility;
end;

procedure TPaneLeafFrame.HandleFrameMouseLeave(Sender: TObject);
begin
  FHeaderHovered := False;
  if FDragState = hdsIdle then
    UpdateHeaderActionsVisibility;
end;

procedure TPaneLeafFrame.HandleHeaderMouseEnter(Sender: TObject);
begin
  HandleFrameMouseEnter(Sender);
end;

procedure TPaneLeafFrame.HandleHeaderMouseLeave(Sender: TObject);
begin
  HandleFrameMouseLeave(Sender);
end;

procedure TPaneLeafFrame.HandleEditExit(Sender: TObject);
begin
  CommitRename;
end;

procedure TPaneLeafFrame.HandleEditKeyDown(Sender: TObject; var Key: Word;
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

{ TnbDockingPaneHost }

constructor TnbDockingPaneHost.Create(AOwner: TComponent);
begin
  inherited;
  Align := TAlignLayout.Client;

  FTree := TPaneTree.Create;
  FTree.OnChanged := HandleTreeChanged;

  FBuilding := False;
  FLeafFrameThickness := 1.0;
  FLeafFrameColor := TAlphaColor($FFCCCCCC);
  FActiveLeafFrameColor := TAlphaColor($FF3D6FB5);
  FBackgroundColor := TAlphaColor($FFE5E5E5);
  FHeaderHeight := 24;
  FSplitterSize := 4.0;
  FSplitterColor := TAlphaColor(0);
  FSplitterCovers := TList<TRectangle>.Create;
  FAutoMatchBg := False;
  FSplitterInfos := TObjectList<TSplitterInfo>.Create(True);

  FBackgroundRect := TRectangle.Create(Self);
  FBackgroundRect.Parent := Self;
  FBackgroundRect.Align := TAlignLayout.Contents;
  FBackgroundRect.Fill.Kind := TBrushKind.Solid;
  FBackgroundRect.Fill.Color := FBackgroundColor;
  FBackgroundRect.Stroke.Kind := TBrushKind.None;
  FBackgroundRect.HitTest := False;
  FBackgroundRect.SendToBack;

  FRootLayout := TLayout.Create(Self);
  FRootLayout.Parent := Self;
  FRootLayout.Align := TAlignLayout.Client;
end;

destructor TnbDockingPaneHost.Destroy;
begin
  FSplitterInfos.Free;
  FSplitterCovers.Free;
  FTree.Free;
  (* Контенты висят с Owner=Self — их FMX уничтожит каскадом. *)
  inherited;
end;

procedure TnbDockingPaneHost.WireContent(AContent: TnbDockingPaneContent);
begin
  AContent.OnSplitRequest := HandleContentSplitRequest;
  AContent.OnCloseRequest := HandleContentCloseRequest;
  AContent.OnActivateRequest := HandleContentActivateRequest;
  AContent.OnHeaderChanged := HandleContentHeaderChanged;
end;

procedure TnbDockingPaneHost.HandleContentSplitRequest(
  Sender: TnbDockingPaneContent; ADirection: TSplitDirection);
var
  Leaf: TPaneLeaf;
begin
  Leaf := FindLeafByContent(Sender);
  if Leaf = nil then Exit;
  if Leaf <> FActiveLeaf then InternalSetActive(Leaf);
  SplitActive(ADirection, nil);
end;

procedure TnbDockingPaneHost.HandleContentCloseRequest(
  Sender: TnbDockingPaneContent);
var
  Leaf: TPaneLeaf;
begin
  Leaf := FindLeafByContent(Sender);
  if Leaf = nil then Exit;
  if Leaf <> FActiveLeaf then InternalSetActive(Leaf);
  CloseActive;
end;

procedure TnbDockingPaneHost.HandleContentActivateRequest(
  Sender: TnbDockingPaneContent);
var
  Leaf: TPaneLeaf;
begin
  Leaf := FindLeafByContent(Sender);
  if Leaf <> nil then InternalSetActive(Leaf);
end;

procedure TnbDockingPaneHost.HandleContentHeaderChanged(
  Sender: TnbDockingPaneContent);
var
  Leaf: TPaneLeaf;
  Frame: TRectangle;
begin
  Leaf := FindLeafByContent(Sender);
  if Leaf = nil then Exit;
  Frame := FindFrameRectFor(FRootLayout, Leaf);
  if (Frame <> nil) and (Frame is TPaneLeafFrame) then
    TPaneLeafFrame(Frame).UpdateFromContent;

  if FAutoMatchBg and (Leaf = FActiveLeaf) then
    SyncBgFromContent(Sender);

  if Assigned(FOnContentHeaderChanged) then
    FOnContentHeaderChanged(Self, Sender);
end;

procedure TnbDockingPaneHost.HandleTreeChanged(Sender: TPaneTree);
begin
  if FFocusMode and (FTree.LeafCount <= 1) then
    FFocusMode := False;
  if not FBuilding then
    RebuildVisualTree;
end;

procedure TnbDockingPaneHost.SetInitialContent(AContent: TnbDockingPaneContent);
begin
  if FTree.Root <> nil then
    raise EDockingError.Create('TnbDockingPaneHost.SetInitialContent: tree is not empty');
  if AContent = nil then
    raise EDockingError.Create('TnbDockingPaneHost.SetInitialContent: nil content');

  if AContent.Owner <> Self then
    InsertComponent(AContent);
  AContent.Parent := nil;
  WireContent(AContent);

  FTree.SetRootContent(AContent);
  InternalSetActive(FTree.FirstLeaf);
end;

function TnbDockingPaneHost.SplitActive(ADirection: TSplitDirection;
  ANewContent: TnbDockingPaneContent): TPaneLeaf;
var
  NewLeaf: TPaneLeaf;
begin
  Result := nil;
  if FActiveLeaf = nil then Exit;

  if ANewContent = nil then
  begin
    if Assigned(FOnContentNeeded) then
      FOnContentNeeded(Self, ANewContent);
    if ANewContent = nil then Exit;
  end;

  if ANewContent.Owner <> Self then
    InsertComponent(ANewContent);
  ANewContent.Parent := nil;
  WireContent(ANewContent);

  NewLeaf := FTree.SplitLeaf(FActiveLeaf, ADirection, ANewContent);
  Result := NewLeaf;
  InternalSetActive(NewLeaf);
end;

procedure TnbDockingPaneHost.CloseActive;
var
  ToClose: TPaneLeaf;
  ToCloseContent: TnbDockingPaneContent;
begin
  if FActiveLeaf = nil then Exit;
  ToClose := FActiveLeaf;
  ToCloseContent := ToClose.Content;
  if (ToCloseContent <> nil) and (not ToCloseContent.CanClose) then Exit;

  if ToCloseContent <> nil then
  begin
    ToCloseContent.Deactivate;
    (* Parent := nil — иначе FMX уничтожит контент каскадом при rebuild. *)
    ToCloseContent.Parent := nil;
  end;

  (* FActiveLeaf := nil ДО CloseLeaf: иначе после Free листа указатель
     повиснет, а RebuildVisualTree → InternalSetActive прочитает Content. *)
  FActiveLeaf := nil;

  FTree.CloseLeaf(ToClose);

  (* Free контента откладываем: мы внутри стека OnClick кнопки "x",
     которая является потомком ToCloseContent. Синхронный Free убьёт
     кнопку, FMX вернётся в TButton.Click → AV. *)
  if ToCloseContent <> nil then
    TThread.Queue(nil,
      procedure
      begin
        ToCloseContent.Free;
      end);

  InternalSetActive(FTree.FirstLeaf);

  (* Пустое дерево: InternalSetActive вышел рано (nil = nil) — стреляем
     событием вручную, чтобы TabHost закрыл соответствующий таб. *)
  if (FActiveLeaf = nil) and Assigned(FOnActiveLeafChanged) then
    FOnActiveLeafChanged(Self, nil, nil);
end;

procedure TnbDockingPaneHost.ActivateContent(AContent: TnbDockingPaneContent);
var
  Leaf: TPaneLeaf;
begin
  Leaf := FindLeafByContent(AContent);
  if Leaf <> nil then InternalSetActive(Leaf);
end;

function TnbDockingPaneHost.IsEmpty: Boolean;
begin
  Result := FTree.Root = nil;
end;

function TnbDockingPaneHost.ActiveLeafContent: TnbDockingPaneContent;
begin
  if FActiveLeaf <> nil then
    Result := FActiveLeaf.Content
  else
    Result := nil;
end;

function TnbDockingPaneHost.TakeActiveContent: TnbDockingPaneContent;
var
  ToClose: TPaneLeaf;
begin
  Result := nil;
  if FActiveLeaf = nil then Exit;

  ToClose := FActiveLeaf;
  Result := ToClose.Content;
  if Result = nil then Exit;

  (* CloseActive минус Free контента — caller перевесит его на новый Parent. *)
  Result.Deactivate;
  Result.Parent := nil;

  FActiveLeaf := nil;
  FTree.CloseLeaf(ToClose);
  InternalSetActive(FTree.FirstLeaf);

  if (FActiveLeaf = nil) and Assigned(FOnActiveLeafChanged) then
    FOnActiveLeafChanged(Self, nil, nil);
end;

function TnbDockingPaneHost.ActiveLeafBounds: TRectF;
begin
  Result := LeafBounds(FActiveLeaf);
end;

function TnbDockingPaneHost.TakeLeafContent(ALeaf: TPaneLeaf): TnbDockingPaneContent;
begin
  if ALeaf = nil then Exit(nil);
  if ALeaf <> FActiveLeaf then
    InternalSetActive(ALeaf);
  Result := TakeActiveContent;
end;

procedure TnbDockingPaneHost.NotifyHeaderDrag(ALeaf: TPaneLeaf;
  APhase: TPaneHeaderDragPhase; const AScreenPt: TPointF);
begin
  if FFocusMode then Exit;
  if Assigned(FOnHeaderDrag) then
    FOnHeaderDrag(Self, ALeaf, APhase, AScreenPt);
end;

procedure TnbDockingPaneHost.EnterFocusMode;
begin
  FocusMode := True;
end;

procedure TnbDockingPaneHost.ExitFocusMode;
begin
  FocusMode := False;
end;

procedure TnbDockingPaneHost.ToggleFocusMode;
begin
  FocusMode := not FFocusMode;
end;

procedure TnbDockingPaneHost.SetFocusMode(AValue: Boolean);
begin
  if AValue and (FTree.LeafCount <= 1) then
    AValue := False;
  if FFocusMode = AValue then Exit;

  FFocusMode := AValue;
  RebuildVisualTree;
end;

procedure TnbDockingPaneHost.SetBackgroundColor(AValue: TAlphaColor);
var
  Cover: TRectangle;
begin
  if FBackgroundColor = AValue then Exit;
  FBackgroundColor := AValue;
  if FBackgroundRect <> nil then
    FBackgroundRect.Fill.Color := FBackgroundColor;
  for Cover in FSplitterCovers do
    Cover.Fill.Color := FBackgroundColor;
  RebuildVisualTree;
end;

procedure TnbDockingPaneHost.SyncBgFromContent(AContent: TnbDockingPaneContent);
var
  NewColor: TAlphaColor;
  Cover: TRectangle;
begin
  if AContent = nil then Exit;
  NewColor := AContent.HeaderBgColor;
  if FBackgroundColor = NewColor then Exit;
  FBackgroundColor := NewColor;
  FSplitterColor   := NewColor;
  if FBackgroundRect <> nil then
    FBackgroundRect.Fill.Color := NewColor;
  for Cover in FSplitterCovers do
    Cover.Fill.Color := NewColor;
end;

procedure TnbDockingPaneHost.HandleFocusItemMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  Item: TPaneFocusItem;
begin
  if Button <> TMouseButton.mbLeft then Exit;
  if not (Sender is TPaneFocusItem) then Exit;

  Item := TPaneFocusItem(Sender);
  if Item.Leaf = nil then Exit;

  InternalSetActive(Item.Leaf);
  RebuildVisualTree;
end;

function TnbDockingPaneHost.LeafBounds(ALeaf: TPaneLeaf): TRectF;
var
  Rect: TRectangle;
  Pt1, Pt2: TPointF;
begin
  Result := RectF(0, 0, 0, 0);
  if ALeaf = nil then Exit;

  Rect := FindFrameRectFor(FRootLayout, ALeaf);
  if Rect = nil then Exit;

  Pt1 := Rect.LocalToAbsolute(PointF(0, 0));
  Pt2 := Rect.LocalToAbsolute(PointF(Rect.Width, Rect.Height));
  Pt1 := Self.AbsoluteToLocal(Pt1);
  Pt2 := Self.AbsoluteToLocal(Pt2);
  Result := RectF(Pt1.X, Pt1.Y, Pt2.X, Pt2.Y);
end;

function TnbDockingPaneHost.FindLeafAt(const APt: TPointF): TPaneLeaf;
var
  Found: TPaneLeaf;
begin
  Found := nil;
  if FTree <> nil then
    FTree.EnumerateLeaves(
      procedure(ALeaf: TPaneLeaf)
      var
        B: TRectF;
      begin
        if Found <> nil then Exit;
        B := LeafBounds(ALeaf);
        if (B.Width <= 0) or (B.Height <= 0) then Exit;
        if (APt.X >= B.Left) and (APt.X <= B.Right)
           and (APt.Y >= B.Top) and (APt.Y <= B.Bottom) then
          Found := ALeaf;
      end);
  Result := Found;
end;

function TnbDockingPaneHost.FindFrameRectFor(
  AContainer: TFmxObject; ALeaf: TPaneLeaf): TRectangle;
var
  I: Integer;
  Child: TFmxObject;
begin
  Result := nil;
  if (AContainer = nil) or (ALeaf = nil) then Exit;
  for I := 0 to AContainer.ChildrenCount - 1 do
  begin
    Child := AContainer.Children[I];
    if (Child is TRectangle)
       and (TRectangle(Child).TagObject is TPaneLeaf)
       and (TPaneLeaf(TRectangle(Child).TagObject) = ALeaf) then
      Exit(TRectangle(Child));
    Result := FindFrameRectFor(Child, ALeaf);
    if Result <> nil then Exit;
  end;
end;

procedure TnbDockingPaneHost.SetActiveLeaf(AValue: TPaneLeaf);
begin
  InternalSetActive(AValue);
end;

procedure TnbDockingPaneHost.InternalSetActive(ALeaf: TPaneLeaf);
var
  OldLeaf: TPaneLeaf;
begin
  if ALeaf = FActiveLeaf then Exit;
  OldLeaf := FActiveLeaf;

  if (OldLeaf <> nil) and (OldLeaf.Content <> nil) then
    OldLeaf.Content.Deactivate;

  FActiveLeaf := ALeaf;

  if (FActiveLeaf <> nil) and (FActiveLeaf.Content <> nil) then
  begin
    FActiveLeaf.Content.Activate;
    if FAutoMatchBg then
      SyncBgFromContent(FActiveLeaf.Content);
  end;

  UpdateActiveFrames;

  if Assigned(FOnActiveLeafChanged) then
    FOnActiveLeafChanged(Self, OldLeaf, FActiveLeaf);
end;

function TnbDockingPaneHost.FindLeafByContent(
  AContent: TnbDockingPaneContent): TPaneLeaf;
var
  Found: TPaneLeaf;
begin
  Found := nil;
  FTree.EnumerateLeaves(
    procedure(ALeaf: TPaneLeaf)
    begin
      if (Found = nil) and (ALeaf.Content = AContent) then
        Found := ALeaf;
    end);
  Result := Found;
end;

procedure TnbDockingPaneHost.DetachAllContents;
begin
  FTree.EnumerateLeaves(
    procedure(ALeaf: TPaneLeaf)
    begin
      if (ALeaf.Content <> nil) and (ALeaf.Content.Parent <> nil) then
        ALeaf.Content.Parent := nil;
    end);
end;

procedure TnbDockingPaneHost.RebuildVisualTree;

  procedure ApplyHeaderVisibility(AContainer: TFmxObject; AVisible: Boolean);
  var
    I: Integer;
    Child: TFmxObject;
  begin
    if AContainer = nil then Exit;
    for I := 0 to AContainer.ChildrenCount - 1 do
    begin
      Child := AContainer.Children[I];
      if Child is TPaneLeafFrame then
        TPaneLeafFrame(Child).SetHeaderVisible(AVisible);
      ApplyHeaderVisibility(Child, AVisible);
    end;
  end;

var
  ShowHeaders: Boolean;
begin
  if FBuilding then Exit;
  FBuilding := True;
  try
    DetachAllContents;
    FSplitterInfos.Clear;
    FSplitterCovers.Clear;

    FRootLayout.Free;
    FRootLayout := TLayout.Create(Self);
    FRootLayout.Parent := Self;
    FRootLayout.Align := TAlignLayout.Client;
    if FBackgroundRect <> nil then
      FBackgroundRect.SendToBack;

    if FFocusMode then
    begin
      RebuildFocusVisualTree;
      Exit;
    end;

    if FTree.Root <> nil then
      BuildNode(FTree.Root, FRootLayout, TAlignLayout.Client, 0);

    UpdateActiveFrames;

    (* Termius-style: один лист — заголовок прячем, имя есть на табе. *)
    ShowHeaders := FTree.LeafCount >= 2;
    ApplyHeaderVisibility(FRootLayout, ShowHeaders);
  finally
    FBuilding := False;
  end;
end;

procedure TnbDockingPaneHost.RebuildFocusVisualTree;
var
  Sidebar: TLayout;
  SidebarBg: TRectangle;
  TitleLabel, ItemTitle, ItemSubTitle: TLabel;
  ActiveFrame: TPaneLeafFrame;
  Item: TPaneFocusItem;
  TopOffset: Single;
  CountText: string;
begin
  if FActiveLeaf = nil then
    FActiveLeaf := FTree.FirstLeaf;
  if FActiveLeaf = nil then Exit;

  CountText := FTree.LeafCount.ToString;

  Sidebar := TLayout.Create(Self);
  Sidebar.Parent := FRootLayout;
  Sidebar.Align := TAlignLayout.Left;
  Sidebar.Width := 210;
  Sidebar.Padding.Rect := RectF(8, 12, 8, 8);

  SidebarBg := TRectangle.Create(Self);
  SidebarBg.Parent := Sidebar;
  SidebarBg.Align := TAlignLayout.Contents;
  SidebarBg.Fill.Color := TAlphaColor($FF1E2233);
  SidebarBg.Stroke.Kind := TBrushKind.None;
  SidebarBg.HitTest := False;
  SidebarBg.SendToBack;

  TitleLabel := TLabel.Create(Self);
  TitleLabel.Parent := Sidebar;
  TitleLabel.Align := TAlignLayout.Top;
  TitleLabel.Height := 34;
  TitleLabel.Text := 'Panels - ' + CountText;
  TitleLabel.StyledSettings := [];
  TitleLabel.TextSettings.Font.Size := 12;
  TitleLabel.TextSettings.FontColor := TAlphaColor($FFB8BED6);
  TitleLabel.TextSettings.VertAlign := TTextAlign.Center;
  TitleLabel.HitTest := False;

  TopOffset := 44;
  FTree.EnumerateLeaves(
    procedure(ALeaf: TPaneLeaf)
    var
      CaptionText: string;
    begin
      if ALeaf.Content <> nil then
        CaptionText := ALeaf.Content.Caption
      else
        CaptionText := 'Panel';

      Item := TPaneFocusItem.Create(Self);
      Item.Parent := Sidebar;
      Item.Align := TAlignLayout.None;
      Item.Position.X := 0;
      Item.Position.Y := TopOffset;
      Item.Width := Sidebar.Width - Sidebar.Padding.Left - Sidebar.Padding.Right;
      Item.Height := 46;
      Item.Leaf := ALeaf;
      Item.XRadius := 6;
      Item.YRadius := 6;
      Item.Stroke.Kind := TBrushKind.None;
      Item.HitTest := True;
      Item.OnMouseDown := HandleFocusItemMouseDown;
      if ALeaf = FActiveLeaf then
        Item.Fill.Color := TAlphaColor($FF2A2E44)
      else
        Item.Fill.Color := TAlphaColor($001E2233);

      ItemTitle := TLabel.Create(Self);
      ItemTitle.Parent := Item;
      ItemTitle.Align := TAlignLayout.Top;
      ItemTitle.Height := 24;
      ItemTitle.Margins.Rect := RectF(10, 4, 8, 0);
      ItemTitle.Text := CaptionText;
      ItemTitle.StyledSettings := [];
      ItemTitle.TextSettings.Font.Size := 12;
      if ALeaf = FActiveLeaf then
        ItemTitle.TextSettings.FontColor := TAlphaColor($FF00E08A)
      else
        ItemTitle.TextSettings.FontColor := TAlphaColor($FFA8ADC4);
      ItemTitle.TextSettings.VertAlign := TTextAlign.Center;
      ItemTitle.HitTest := False;

      ItemSubTitle := TLabel.Create(Self);
      ItemSubTitle.Parent := Item;
      ItemSubTitle.Align := TAlignLayout.Client;
      ItemSubTitle.Margins.Rect := RectF(10, 0, 8, 3);
      ItemSubTitle.Text := 'content';
      ItemSubTitle.StyledSettings := [];
      ItemSubTitle.TextSettings.Font.Size := 11;
      ItemSubTitle.TextSettings.FontColor := TAlphaColor($FF767B91);
      ItemSubTitle.TextSettings.VertAlign := TTextAlign.Center;
      ItemSubTitle.HitTest := False;

      TopOffset := TopOffset + 52;
    end);

  ActiveFrame := BuildLeaf(FActiveLeaf, FRootLayout, TAlignLayout.Client, 0);
  ActiveFrame.SetHeaderVisible(True);
  UpdateActiveFrames;
end;

function TnbDockingPaneHost.BuildNode(ANode: TPaneNode; AContainer: TFmxObject;
  AAlign: TAlignLayout; ASize: Single): TFmxObject;
begin
  if ANode is TPaneLeaf then
    Result := TFmxObject(BuildLeaf(TPaneLeaf(ANode), AContainer, AAlign, ASize))
  else
    Result := BuildSplit(TPaneSplit(ANode), AContainer, AAlign, ASize);
end;

function TnbDockingPaneHost.BuildLeaf(ALeaf: TPaneLeaf; AContainer: TFmxObject;
  AAlign: TAlignLayout; ASize: Single): TPaneLeafFrame;
var
  Frame: TPaneLeafFrame;
begin
  Frame := TPaneLeafFrame.Create(Self, ALeaf);
  Frame.Parent := AContainer;
  Frame.Align := AAlign;
  if AAlign = TAlignLayout.Left then Frame.Width := ASize
  else if AAlign = TAlignLayout.Top then Frame.Height := ASize;

  if ALeaf.Content <> nil then
  begin
    ALeaf.Content.Parent := Frame;
    ALeaf.Content.Align := TAlignLayout.Client;
  end;

  Frame.UpdateFromContent;
  Result := Frame;
end;

function TnbDockingPaneHost.BuildSplit(ASplit: TPaneSplit; AContainer: TFmxObject;
  AAlign: TAlignLayout; ASize: Single): TLayout;
var
  SplitLayout: TLayout;
  I: Integer;
  ChildAlign: TAlignLayout;
  AvailableSize, ChildSize: Single;
  Splitter: TSplitter;
  Info: TSplitterInfo;
begin
  SplitLayout := TLayout.Create(Self);
  SplitLayout.Parent := AContainer;
  SplitLayout.Align := AAlign;
  if AAlign = TAlignLayout.Left then SplitLayout.Width := ASize
  else if AAlign = TAlignLayout.Top then SplitLayout.Height := ASize;
  SplitLayout.TagObject := ASplit;
  SplitLayout.OnResize := HandleSplitLayoutResize;

  (* FMX AlignObjects сортирует Top/Left-children по Position. Без
     BeginUpdate уже размещённый сплиттер получает Position.Y > 0, а новый
     pane (Position.Y = 0) попадает в AlignList ПЕРЕД ним — сплиттеры
     уезжают вниз. Один realign в EndUpdate сохраняет порядок вставки. *)
  SplitLayout.BeginUpdate;
  try
    (* SplitLayout c Align=Client ещё может не иметь размера — берём
       приближение, первый OnResize пересчитает. *)
    if AContainer is TControl then
    begin
      if ASplit.Orientation = poHorizontal then
        AvailableSize := TControl(AContainer).Width
      else
        AvailableSize := TControl(AContainer).Height;
      if AvailableSize <= 0 then AvailableSize := 800;
    end
    else
      AvailableSize := 800;

    for I := 0 to ASplit.ChildCount - 1 do
    begin
      if ASplit.Orientation = poHorizontal then
        ChildAlign := TAlignLayout.Left
      else
        ChildAlign := TAlignLayout.Top;
      if I = ASplit.ChildCount - 1 then
        ChildAlign := TAlignLayout.Client;

      ChildSize := ASplit.GetSize(I) * AvailableSize;
      if ChildSize < 30 then ChildSize := 30;

      BuildNode(ASplit.Children[I], SplitLayout, ChildAlign, ChildSize);

      if I < ASplit.ChildCount - 1 then
      begin
        Splitter := TSplitter.Create(Self);
        Splitter.Parent := SplitLayout;
        if ASplit.Orientation = poHorizontal then
        begin
          Splitter.Align := TAlignLayout.Left;
          Splitter.Width := FSplitterSize;
        end
        else
        begin
          Splitter.Align := TAlignLayout.Top;
          Splitter.Height := FSplitterSize;
        end;
        Splitter.MinSize := 50;
        (* FMX TSplitter не эмитит OnMoved — capture мыши на drag,
           отпуск приходит в OnMouseUp. *)
        Splitter.OnMouseUp := HandleSplitterMouseUp;

        Info := TSplitterInfo.Create(ASplit, I);
        FSplitterInfos.Add(Info);
        Splitter.TagObject := Info;
        if (FSplitterColor shr 24) > 0 then
        begin
          var Cover := TRectangle.Create(Self);
          Cover.Parent := Splitter;
          Cover.Align := TAlignLayout.Contents;
          Cover.Fill.Color := FSplitterColor;
          Cover.Stroke.Kind := TBrushKind.None;
          Cover.HitTest := False;
          FSplitterCovers.Add(Cover);
        end;
      end;
    end;
  finally
    SplitLayout.EndUpdate;
  end;

  Result := SplitLayout;
end;

procedure TnbDockingPaneHost.HandleSplitLayoutResize(Sender: TObject);
var
  SplitLayout: TLayout;
  ASplit: TPaneSplit;
begin
  if FBuilding then Exit;
  if not (Sender is TLayout) then Exit;
  SplitLayout := TLayout(Sender);
  if not (SplitLayout.TagObject is TPaneSplit) then Exit;
  ASplit := TPaneSplit(SplitLayout.TagObject);
  RecalcSplitChildSizes(ASplit, SplitLayout);
end;

procedure TnbDockingPaneHost.RecalcSplitChildSizes(ASplit: TPaneSplit;
  ASplitLayout: TLayout);
var
  I: Integer;
  TotalSize, TotalSplitterSize, EffectiveSize, NewSize: Single;
  Obj: TFmxObject;
  PaneVisuals: TList<TFmxObject>;
begin
  if ASplit.ChildCount = 0 then Exit;
  if ASplit.Orientation = poHorizontal then
    TotalSize := ASplitLayout.Width
  else
    TotalSize := ASplitLayout.Height;
  TotalSplitterSize := FSplitterSize * (ASplit.ChildCount - 1);
  EffectiveSize := TotalSize - TotalSplitterSize;
  if EffectiveSize <= 0 then Exit;

  PaneVisuals := TList<TFmxObject>.Create;
  try
    for I := 0 to ASplitLayout.ChildrenCount - 1 do
    begin
      Obj := ASplitLayout.Children[I];
      if Obj is TSplitter then Continue;
      PaneVisuals.Add(Obj);
    end;

    (* Последний ребёнок Align=Client — он сам заберёт остаток. *)
    for I := 0 to PaneVisuals.Count - 2 do
    begin
      if I >= ASplit.ChildCount then Break;
      NewSize := ASplit.GetSize(I) * EffectiveSize;
      if NewSize < 30 then NewSize := 30;
      if PaneVisuals[I] is TControl then
      begin
        if ASplit.Orientation = poHorizontal then
          TControl(PaneVisuals[I]).Width := NewSize
        else
          TControl(PaneVisuals[I]).Height := NewSize;
      end;
    end;
  finally
    PaneVisuals.Free;
  end;
end;

procedure TnbDockingPaneHost.HandleSplitterMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  Splitter: TSplitter;
  Info: TSplitterInfo;
begin
  if Button <> TMouseButton.mbLeft then Exit;
  if not (Sender is TSplitter) then Exit;
  Splitter := TSplitter(Sender);
  if not (Splitter.TagObject is TSplitterInfo) then Exit;
  Info := TSplitterInfo(Splitter.TagObject);
  if not (Splitter.Parent is TLayout) then Exit;
  RecalcSplitProportions(Info.Split, TLayout(Splitter.Parent));
end;

procedure TnbDockingPaneHost.RecalcSplitProportions(ASplit: TPaneSplit;
  AContainer: TLayout);
var
  I, ChildIdx: Integer;
  TotalSize, TotalSplitterSize, EffectiveSize: Single;
  Sizes: TArray<Single>;
  Obj: TFmxObject;
begin
  if ASplit.Orientation = poHorizontal then
    TotalSize := AContainer.Width
  else
    TotalSize := AContainer.Height;
  TotalSplitterSize := FSplitterSize * (ASplit.ChildCount - 1);
  EffectiveSize := TotalSize - TotalSplitterSize;
  if EffectiveSize <= 0 then Exit;

  SetLength(Sizes, ASplit.ChildCount);
  ChildIdx := 0;
  for I := 0 to AContainer.ChildrenCount - 1 do
  begin
    Obj := AContainer.Children[I];
    if Obj is TSplitter then Continue;
    if ChildIdx >= ASplit.ChildCount then Break;
    if Obj is TControl then
    begin
      if ASplit.Orientation = poHorizontal then
        Sizes[ChildIdx] := TControl(Obj).Width / EffectiveSize
      else
        Sizes[ChildIdx] := TControl(Obj).Height / EffectiveSize;
    end;
    Inc(ChildIdx);
  end;

  (* SetSize меняет только пропорции — OnChanged дерева не зовётся,
     rebuild визуала не нужен. *)
  for I := 0 to High(Sizes) do
    ASplit.SetSize(I, Sizes[I]);
end;

procedure TnbDockingPaneHost.UpdateActiveFrames;

  procedure ApplyTo(AContainer: TFmxObject);
  var
    I: Integer;
    Child: TFmxObject;
    Frame: TPaneLeafFrame;
    IsActive: Boolean;
  begin
    if AContainer = nil then Exit;
    for I := 0 to AContainer.ChildrenCount - 1 do
    begin
      Child := AContainer.Children[I];
      if Child is TPaneLeafFrame then
      begin
        Frame := TPaneLeafFrame(Child);
        IsActive := (Frame.Leaf = FActiveLeaf) and (FActiveLeaf <> nil);
        Frame.SetActive(IsActive);
      end;
      ApplyTo(Child);
    end;
  end;

begin
  ApplyTo(FRootLayout);
end;

end.
