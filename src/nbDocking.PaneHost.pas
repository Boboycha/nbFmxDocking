unit nbDocking.PaneHost;

(*
  Инварианты владения и rebuild-а:

  - Owner каждого TDockingPaneContent = PaneHost. При уничтожении хоста
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
    var AContent: TDockingPaneContent) of object;
  TActiveLeafChangeEvent = procedure(Sender: TObject;
    AOldLeaf, ANewLeaf: TPaneLeaf) of object;
  TContentHeaderChangeEvent = procedure(Sender: TObject;
    AContent: TDockingPaneContent) of object;

  (* Drag заголовка pane транслируется наверх — drop-цель ищет TabHost. *)
  TPaneHeaderDragPhase = (phdStart, phdMove, phdEnd);

  TDockingPaneHost = class;

  TPaneHeaderDragEvent = procedure(ASender: TDockingPaneHost; ALeaf: TPaneLeaf;
    APhase: TPaneHeaderDragPhase; const AScreenPt: TPointF) of object;

  (* Какой split режет сплиттер и индекс ребёнка-соседа слева/сверху. *)
  TSplitterInfo = class
  public
    Split: TPaneSplit;
    LeftChildIndex: Integer;
    constructor Create(ASplit: TPaneSplit; ALeftIdx: Integer);
  end;

  TPaneHeaderDragState = (hdsIdle, hdsArmed, hdsDragging);

  TPaneLeafFrame = class(TRectangle)
  private
    FHost: TDockingPaneHost;
    FLeaf: TPaneLeaf;
    FHeader: TRectangle;
    FTitleLabel: TLabel;
    FTitleEdit: TEdit;
    FActionsLayout: TLayout;
    FCloseBtn: TRectangle;
    FCloseGlyph: TText;
    FDragState: TPaneHeaderDragState;
    FDragStartX, FDragStartY: Single;
    FEditingTitle: Boolean;
    procedure BeginRename;
    procedure CommitRename;
    procedure CancelRename;
    procedure HandleFrameMouseDown(Sender: TObject; Button: TMouseButton;
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
    procedure HandleEditExit(Sender: TObject);
    procedure HandleEditKeyDown(Sender: TObject; var Key: Word;
      var KeyChar: Char; Shift: TShiftState);
  public
    constructor Create(AHost: TDockingPaneHost; ALeaf: TPaneLeaf); reintroduce;
    procedure UpdateFromContent;
    procedure SetActive(AIsActive: Boolean);
    procedure SetHeaderVisible(AVisible: Boolean);
    property Leaf: TPaneLeaf read FLeaf;
    property Header: TRectangle read FHeader;

    (* Слот под доп. кнопки header (split-icon, reload, maximize и т.п.) —
       Align=Right, видимость = (Leaf = ActiveLeaf). *)
    property ActionsLayout: TLayout read FActionsLayout;
  end;

  TDockingPaneHost = class(TLayout)
  private
    FTree: TPaneTree;
    FActiveLeaf: TPaneLeaf;
    FRootLayout: TLayout;
    FBuilding: Boolean;
    FLeafFrameThickness: Single;
    FLeafFrameColor: TAlphaColor;
    FActiveLeafFrameColor: TAlphaColor;
    FHeaderHeight: Single;
    FSplitterSize: Single;
    FSplitterInfos: TObjectList<TSplitterInfo>;
    FOnContentNeeded: TContentFactoryEvent;
    FOnActiveLeafChanged: TActiveLeafChangeEvent;
    FOnContentHeaderChanged: TContentHeaderChangeEvent;
    FOnHeaderDrag: TPaneHeaderDragEvent;

    procedure HandleTreeChanged(Sender: TPaneTree);
    procedure HandleContentSplitRequest(Sender: TDockingPaneContent;
      ADirection: TSplitDirection);
    procedure HandleContentCloseRequest(Sender: TDockingPaneContent);
    procedure HandleContentActivateRequest(Sender: TDockingPaneContent);
    procedure HandleContentHeaderChanged(Sender: TDockingPaneContent);
    procedure HandleSplitLayoutResize(Sender: TObject);
    procedure HandleSplitterMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);

    procedure WireContent(AContent: TDockingPaneContent);
    procedure DetachAllContents;
    procedure RebuildVisualTree;
    function BuildNode(ANode: TPaneNode; AContainer: TFmxObject;
      AAlign: TAlignLayout; ASize: Single): TFmxObject;
    function BuildLeaf(ALeaf: TPaneLeaf; AContainer: TFmxObject;
      AAlign: TAlignLayout; ASize: Single): TPaneLeafFrame;
    function BuildSplit(ASplit: TPaneSplit; AContainer: TFmxObject;
      AAlign: TAlignLayout; ASize: Single): TLayout;
    procedure RecalcSplitChildSizes(ASplit: TPaneSplit; ASplitLayout: TLayout);
    procedure RecalcSplitProportions(ASplit: TPaneSplit; AContainer: TLayout);
    function FindLeafByContent(AContent: TDockingPaneContent): TPaneLeaf;
    function FindFrameRectFor(AContainer: TFmxObject;
      ALeaf: TPaneLeaf): TRectangle;
    procedure UpdateActiveFrames;
    procedure InternalSetActive(ALeaf: TPaneLeaf);
    procedure SetActiveLeaf(AValue: TPaneLeaf);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure SetInitialContent(AContent: TDockingPaneContent);
    function SplitActive(ADirection: TSplitDirection;
      ANewContent: TDockingPaneContent = nil): TPaneLeaf;
    procedure CloseActive;
    procedure ActivateContent(AContent: TDockingPaneContent);
    function IsEmpty: Boolean;

    (* В отличие от CloseActive — контент НЕ уничтожается, лист удаляется
       из дерева; для drag-drop переноса в другой хост. *)
    function TakeActiveContent: TDockingPaneContent;
    function TakeLeafContent(ALeaf: TPaneLeaf): TDockingPaneContent;

    procedure NotifyHeaderDrag(ALeaf: TPaneLeaf; APhase: TPaneHeaderDragPhase;
      const AScreenPt: TPointF);

    function ActiveLeafContent: TDockingPaneContent;
    function ActiveLeafBounds: TRectF;
    function FindLeafAt(const APt: TPointF): TPaneLeaf;
    function LeafBounds(ALeaf: TPaneLeaf): TRectF;

    property Tree: TPaneTree read FTree;
    property ActiveLeaf: TPaneLeaf read FActiveLeaf write SetActiveLeaf;
  published
    property LeafFrameThickness: Single read FLeafFrameThickness
      write FLeafFrameThickness;
    property LeafFrameColor: TAlphaColor read FLeafFrameColor
      write FLeafFrameColor;
    property ActiveLeafFrameColor: TAlphaColor read FActiveLeafFrameColor
      write FActiveLeafFrameColor;
    property SplitterSize: Single read FSplitterSize write FSplitterSize;
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

{ TPaneLeafFrame }

constructor TPaneLeafFrame.Create(AHost: TDockingPaneHost; ALeaf: TPaneLeaf);
begin
  inherited Create(AHost);
  FHost := AHost;
  FLeaf := ALeaf;
  XRadius:=10;
  YRadius:=10;
  (* TagObject связывает frame с листом для FindFrameRectFor. *)
  TagObject := ALeaf;

  Fill.Kind := TBrushKind.None;
  Stroke.Color := AHost.LeafFrameColor;
  Stroke.Thickness := AHost.LeafFrameThickness;
  HitTest := True;
  Padding.Rect := RectF(AHost.LeafFrameThickness, AHost.LeafFrameThickness,
                        AHost.LeafFrameThickness, AHost.LeafFrameThickness);
  OnMouseDown := HandleFrameMouseDown;

  FHeader := TRectangle.Create(Self);
  FHeader.Corners:=[TCorner.TopLeft, TCorner.TopRight];
  FHeader.XRadius:=10;
  FHeader.YRadius:=10;

  FHeader.Parent := Self;
  FHeader.Align := TAlignLayout.Top;
  FHeader.Height := AHost.HeaderHeight;
  FHeader.Stroke.Kind := TBrushKind.None;
  FHeader.Fill.Kind := TBrushKind.None;
  FHeader.HitTest := True;
  FHeader.OnMouseDown := HandleHeaderMouseDown;
  FHeader.OnMouseMove := HandleHeaderMouseMove;
  FHeader.OnMouseUp := HandleHeaderMouseUp;

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

  FCloseBtn := TRectangle.Create(Self);
  FCloseBtn.Parent := FActionsLayout;
  FCloseBtn.Align := TAlignLayout.Right;
  FCloseBtn.Width := 20;
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
  FCloseGlyph.Text := '✕';
  FCloseGlyph.TextSettings.HorzAlign := TTextAlign.Center;
  FCloseGlyph.TextSettings.VertAlign := TTextAlign.Center;
  FCloseGlyph.TextSettings.Font.Size := 11;
  FCloseGlyph.HitTest := False;

  FHeader.OnDblClick := HandleHeaderDblClick;
end;

procedure TPaneLeafFrame.BeginRename;
var
  C: TDockingPaneContent;
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
  C: TDockingPaneContent;
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
  C: TDockingPaneContent;
begin
  if FLeaf = nil then Exit;
  C := FLeaf.Content;
  if C = nil then Exit;
  if FEditingTitle then Exit;

  FHeader.Fill.Color := C.HeaderBgColor;
  FTitleLabel.TextSettings.FontColor := C.HeaderTextColor;
  FCloseGlyph.TextSettings.FontColor := C.HeaderTextColor;
  FTitleLabel.Text := C.Caption;
end;

procedure TPaneLeafFrame.SetActive(AIsActive: Boolean);
begin
  if AIsActive then
  begin
    Stroke.Color := FHost.ActiveLeafFrameColor;
    Stroke.Thickness := FHost.LeafFrameThickness + 1;
  end
  else
  begin
    Stroke.Color := FHost.LeafFrameColor;
    Stroke.Thickness := FHost.LeafFrameThickness;
  end;
  if FActionsLayout <> nil then
    FActionsLayout.Visible := AIsActive;
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

{ TDockingPaneHost }

constructor TDockingPaneHost.Create(AOwner: TComponent);
begin
  inherited;
  Align := TAlignLayout.Client;

  FTree := TPaneTree.Create;
  FTree.OnChanged := HandleTreeChanged;

  FBuilding := False;
  FLeafFrameThickness := 1.0;
  FLeafFrameColor := TAlphaColor($FFCCCCCC);
  FActiveLeafFrameColor := TAlphaColor($FF3D6FB5);
  FHeaderHeight := 24;
  FSplitterSize := 4.0;
  FSplitterInfos := TObjectList<TSplitterInfo>.Create(True);

  FRootLayout := TLayout.Create(Self);
  FRootLayout.Parent := Self;
  FRootLayout.Align := TAlignLayout.Client;
end;

destructor TDockingPaneHost.Destroy;
begin
  FSplitterInfos.Free;
  FTree.Free;
  (* Контенты висят с Owner=Self — их FMX уничтожит каскадом. *)
  inherited;
end;

procedure TDockingPaneHost.WireContent(AContent: TDockingPaneContent);
begin
  AContent.OnSplitRequest := HandleContentSplitRequest;
  AContent.OnCloseRequest := HandleContentCloseRequest;
  AContent.OnActivateRequest := HandleContentActivateRequest;
  AContent.OnHeaderChanged := HandleContentHeaderChanged;
end;

procedure TDockingPaneHost.HandleContentSplitRequest(
  Sender: TDockingPaneContent; ADirection: TSplitDirection);
var
  Leaf: TPaneLeaf;
begin
  Leaf := FindLeafByContent(Sender);
  if Leaf = nil then Exit;
  if Leaf <> FActiveLeaf then InternalSetActive(Leaf);
  SplitActive(ADirection, nil);
end;

procedure TDockingPaneHost.HandleContentCloseRequest(
  Sender: TDockingPaneContent);
var
  Leaf: TPaneLeaf;
begin
  Leaf := FindLeafByContent(Sender);
  if Leaf = nil then Exit;
  if Leaf <> FActiveLeaf then InternalSetActive(Leaf);
  CloseActive;
end;

procedure TDockingPaneHost.HandleContentActivateRequest(
  Sender: TDockingPaneContent);
var
  Leaf: TPaneLeaf;
begin
  Leaf := FindLeafByContent(Sender);
  if Leaf <> nil then InternalSetActive(Leaf);
end;

procedure TDockingPaneHost.HandleContentHeaderChanged(
  Sender: TDockingPaneContent);
var
  Leaf: TPaneLeaf;
  Frame: TRectangle;
begin
  Leaf := FindLeafByContent(Sender);
  if Leaf = nil then Exit;
  Frame := FindFrameRectFor(FRootLayout, Leaf);
  if (Frame <> nil) and (Frame is TPaneLeafFrame) then
    TPaneLeafFrame(Frame).UpdateFromContent;

  if Assigned(FOnContentHeaderChanged) then
    FOnContentHeaderChanged(Self, Sender);
end;

procedure TDockingPaneHost.HandleTreeChanged(Sender: TPaneTree);
begin
  if not FBuilding then
    RebuildVisualTree;
end;

procedure TDockingPaneHost.SetInitialContent(AContent: TDockingPaneContent);
begin
  if FTree.Root <> nil then
    raise EDockingError.Create('TDockingPaneHost.SetInitialContent: tree is not empty');
  if AContent = nil then
    raise EDockingError.Create('TDockingPaneHost.SetInitialContent: nil content');

  if AContent.Owner <> Self then
    InsertComponent(AContent);
  AContent.Parent := nil;
  WireContent(AContent);

  FTree.SetRootContent(AContent);
  InternalSetActive(FTree.FirstLeaf);
end;

function TDockingPaneHost.SplitActive(ADirection: TSplitDirection;
  ANewContent: TDockingPaneContent): TPaneLeaf;
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

procedure TDockingPaneHost.CloseActive;
var
  ToClose: TPaneLeaf;
  ToCloseContent: TDockingPaneContent;
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

  (* Free контента откладываем: мы внутри стека OnClick кнопки "✕",
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

procedure TDockingPaneHost.ActivateContent(AContent: TDockingPaneContent);
var
  Leaf: TPaneLeaf;
begin
  Leaf := FindLeafByContent(AContent);
  if Leaf <> nil then InternalSetActive(Leaf);
end;

function TDockingPaneHost.IsEmpty: Boolean;
begin
  Result := FTree.Root = nil;
end;

function TDockingPaneHost.ActiveLeafContent: TDockingPaneContent;
begin
  if FActiveLeaf <> nil then
    Result := FActiveLeaf.Content
  else
    Result := nil;
end;

function TDockingPaneHost.TakeActiveContent: TDockingPaneContent;
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

function TDockingPaneHost.ActiveLeafBounds: TRectF;
begin
  Result := LeafBounds(FActiveLeaf);
end;

function TDockingPaneHost.TakeLeafContent(ALeaf: TPaneLeaf): TDockingPaneContent;
begin
  if ALeaf = nil then Exit(nil);
  if ALeaf <> FActiveLeaf then
    InternalSetActive(ALeaf);
  Result := TakeActiveContent;
end;

procedure TDockingPaneHost.NotifyHeaderDrag(ALeaf: TPaneLeaf;
  APhase: TPaneHeaderDragPhase; const AScreenPt: TPointF);
begin
  if Assigned(FOnHeaderDrag) then
    FOnHeaderDrag(Self, ALeaf, APhase, AScreenPt);
end;

function TDockingPaneHost.LeafBounds(ALeaf: TPaneLeaf): TRectF;
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

function TDockingPaneHost.FindLeafAt(const APt: TPointF): TPaneLeaf;
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

function TDockingPaneHost.FindFrameRectFor(
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

procedure TDockingPaneHost.SetActiveLeaf(AValue: TPaneLeaf);
begin
  InternalSetActive(AValue);
end;

procedure TDockingPaneHost.InternalSetActive(ALeaf: TPaneLeaf);
var
  OldLeaf: TPaneLeaf;
begin
  if ALeaf = FActiveLeaf then Exit;
  OldLeaf := FActiveLeaf;

  if (OldLeaf <> nil) and (OldLeaf.Content <> nil) then
    OldLeaf.Content.Deactivate;

  FActiveLeaf := ALeaf;

  if (FActiveLeaf <> nil) and (FActiveLeaf.Content <> nil) then
    FActiveLeaf.Content.Activate;

  UpdateActiveFrames;

  if Assigned(FOnActiveLeafChanged) then
    FOnActiveLeafChanged(Self, OldLeaf, FActiveLeaf);
end;

function TDockingPaneHost.FindLeafByContent(
  AContent: TDockingPaneContent): TPaneLeaf;
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

procedure TDockingPaneHost.DetachAllContents;
begin
  FTree.EnumerateLeaves(
    procedure(ALeaf: TPaneLeaf)
    begin
      if (ALeaf.Content <> nil) and (ALeaf.Content.Parent <> nil) then
        ALeaf.Content.Parent := nil;
    end);
end;

procedure TDockingPaneHost.RebuildVisualTree;

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

    FRootLayout.Free;
    FRootLayout := TLayout.Create(Self);
    FRootLayout.Parent := Self;
    FRootLayout.Align := TAlignLayout.Client;

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

function TDockingPaneHost.BuildNode(ANode: TPaneNode; AContainer: TFmxObject;
  AAlign: TAlignLayout; ASize: Single): TFmxObject;
begin
  if ANode is TPaneLeaf then
    Result := TFmxObject(BuildLeaf(TPaneLeaf(ANode), AContainer, AAlign, ASize))
  else
    Result := BuildSplit(TPaneSplit(ANode), AContainer, AAlign, ASize);
end;

function TDockingPaneHost.BuildLeaf(ALeaf: TPaneLeaf; AContainer: TFmxObject;
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

function TDockingPaneHost.BuildSplit(ASplit: TPaneSplit; AContainer: TFmxObject;
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
      end;
    end;
  finally
    SplitLayout.EndUpdate;
  end;

  Result := SplitLayout;
end;

procedure TDockingPaneHost.HandleSplitLayoutResize(Sender: TObject);
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

procedure TDockingPaneHost.RecalcSplitChildSizes(ASplit: TPaneSplit;
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

procedure TDockingPaneHost.HandleSplitterMouseUp(Sender: TObject;
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

procedure TDockingPaneHost.RecalcSplitProportions(ASplit: TPaneSplit;
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

procedure TDockingPaneHost.UpdateActiveFrames;

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
