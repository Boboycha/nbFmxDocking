unit nbDocking.PaneHost;

(*
  TnbDockingPaneHost keeps the docking tree and visual split layout.
  Design-time panes are real TnbDockingPaneContent children. User controls live
  inside those content controls and are streamed by normal FMX parent/child rules.
  Runtime rebuild detaches live content controls before recreating transient slots,
  so slots can be freed without freeing their content.
*)

interface

uses
  System.Classes, System.SysUtils, System.UITypes, System.Types,
  System.Generics.Collections,
  System.Math,
  FMX.Types, FMX.Controls, FMX.Layouts, FMX.StdCtrls, FMX.Objects,
  FMX.Graphics,
  nbDocking.Types, nbDocking.PaneTree, nbDocking.DropOverlay;

const
  PANE_TAB_BAR_HEIGHT = 44;
  PANE_TAB_ADD_BUTTON_WIDTH = 34;
  PANE_TAB_DRAG_THRESHOLD = 5;
  {$IFDEF LINUX}
  PANE_TAB_ICON_FONT = '';
  PANE_TAB_ICON_ADD = '+';
  {$ELSE}
  PANE_TAB_ICON_FONT = 'Segoe MDL2 Assets';
  PANE_TAB_ICON_ADD = #$E710;
  {$ENDIF}

type
  TContentFactoryEvent = procedure(Sender: TObject;
    var AContent: TnbDockingPaneContent) of object;
  TActiveLeafChangeEvent = procedure(Sender: TObject;
    AOldLeaf, ANewLeaf: TPaneLeaf) of object;
  TContentHeaderChangeEvent = procedure(Sender: TObject;
    AContent: TnbDockingPaneContent) of object;
  TDesignChildrenLayoutMode = (dlmSplit, dlmAlign);
  TnbDockingTabPosition = (dtpTop, dtpBottom, dtpLeft, dtpRight);
  TnbDockingTabTextDirection = (ttdAuto, ttdHorizontal, ttdVertical);

  TnbDockingPaneHost = class;

  (* Drag заголовка карточки обрабатывается host-ом и также транслируется наружу. *)
  TPaneHeaderDragEvent = procedure(ASender: TnbDockingPaneHost; ALeaf: TPaneLeaf;
    APhase: TPaneHeaderDragPhase; const AScreenPt: TPointF) of object;

  (* Какой split режет сплиттер и индекс ребёнка-соседа слева/сверху. *)
  TSplitterInfo = class
  public
    Split: TPaneSplit;
    LeftChildIndex: Integer;
    constructor Create(ASplit: TPaneSplit; ALeftIdx: Integer);
  end;

  TPaneHostTab = class
  public
    Caption: string;
    Tree: TPaneTree;
    ActiveLeaf: TPaneLeaf;
    constructor Create(const ACaption: string);
    destructor Destroy; override;
  end;

  (* Элемент сайдбара focus-mode — клик переключает активный лист. *)
  TPaneFocusItem = class(TRectangle)
  public
    Leaf: TPaneLeaf;
  end;

  TnbDockingPaneHost = class(TLayout)
  private
    FTree: TPaneTree;
    FActiveLeaf: TPaneLeaf;
    FTabs: TObjectList<TPaneHostTab>;
    FActiveTabIndex: Integer;
    FTabButtons: TObjectList<TRectangle>;
    FWorkspaceLayout: TLayout;
    FTabBar: TRectangle;
    FAddButton: TRectangle;
    FAddGlyph: TText;
    FRootLayout: TLayout;
    FBuilding: Boolean;
    FRebuildingDesignChildren: Boolean;
    FBackgroundColor: TAlphaColor;
    FSplitterSize: Single;
    FSplitterColor: TAlphaColor;
    FSplitterCovers: TList<TRectangle>;
    FAutoMatchBg: Boolean;
    FBackgroundRect: TRectangle;
    FSplitterInfos: TObjectList<TSplitterInfo>;
    FDesignSplitters: TObjectList<TSplitter>;
    FLegacyLeafFrameThickness: Single;
    FLegacyLeafFrameColor: TAlphaColor;
    FLegacyActiveLeafFrameColor: TAlphaColor;
    FLegacyHeaderHeight: Single;
    FAutoBuildDesignChildren: Boolean;
    FDesignChildrenOrientation: TPaneOrientation;
    FDesignChildrenLayoutMode: TDesignChildrenLayoutMode;
    FVisibleTabs: Boolean;
    FShowAddButton: Boolean;
    FTabPosition: TnbDockingTabPosition;
    FTabTextDirection: TnbDockingTabTextDirection;
    FDropOverlay: TDockingDropOverlay;
    FDragSourceLeaf: TPaneLeaf;
    FCurrentDropLeaf: TPaneLeaf;
    FCurrentDropHit: TDropHitResult;
    FTabDragIndex: Integer;
    FTabDragStartX: Single;
    FTabDragStartY: Single;
    FTabDragActive: Boolean;
    FTabDragTargetLeaf: TPaneLeaf;
    FTabDragHit: TDropHitResult;
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
    procedure HandleContentHeaderDrag(ASender: TnbDockingPaneContent;
      APhase: TPaneHeaderDragPhase; const AScreenPt: TPointF);
    procedure PaneHeaderDragBegin(ALeaf: TPaneLeaf);
    procedure PaneHeaderDragUpdate(const AScreenPt: TPointF);
    procedure PaneHeaderDragEnd(const AScreenPt: TPointF);
    procedure ClearDropOverlay;
    function IsPointOverTabBar(const AScreenPt: TPointF): Boolean;
    procedure SetTabBarDropHighlight(AValue: Boolean);
    function CreateDefaultContent: TnbDockingPaneContent;
    procedure EnsurePrimaryTab;
    procedure SaveActiveTabState;
    function AddTabWithContent(const ACaption: string;
      AContent: TnbDockingPaneContent): Integer;
    function CaptionForTab(ATab: TPaneHostTab; const AFallback: string): string;
    procedure ActivateTabIndex(AIndex: Integer);
    procedure UpdateTabButtonStates;
    procedure RebuildTabButtons;
    procedure HandleTabButtonMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure HandleTabButtonMouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Single);
    procedure HandleTabButtonMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure UpdateTabDrag(const AScreenPt: TPointF);
    procedure FinishTabDrag(const AScreenPt: TPointF);
    procedure CancelTabDrag;
    procedure HandleAddButtonClick(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure HandleAddButtonMouseEnter(Sender: TObject);
    procedure HandleAddButtonMouseLeave(Sender: TObject);
    procedure HandleSplitLayoutResize(Sender: TObject);
    procedure HandleSplitterMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);

    procedure WireContent(AContent: TnbDockingPaneContent);
    procedure UnwireContent(AContent: TnbDockingPaneContent);
    function ContainsNestedHost(AContent: TnbDockingPaneContent): Boolean;
    procedure NormalizeContainerContent(AContent: TnbDockingPaneContent);
    procedure RebuildTreeFromDesignChildren;
    function TryReadDesignChildSizes(AContents: TList<TnbDockingPaneContent>;
      AOrientation: TPaneOrientation; out ASizes: TArray<Single>): Boolean;
    function TryReadRootSplitSizes(AContents: TList<TnbDockingPaneContent>;
      AOrientation: TPaneOrientation; out ASizes: TArray<Single>): Boolean;
    procedure ApplyDesignChildSizesToRootSplit(
      AContents: TList<TnbDockingPaneContent>);
    procedure CollectDirectContents(AContents: TList<TnbDockingPaneContent>);
    procedure LayoutDirectChildren(AContents: TList<TnbDockingPaneContent>;
      AInteractiveSplitters: Boolean);
    procedure LayoutDesignChildren(AContents: TList<TnbDockingPaneContent>);
    procedure LayoutAlignedDesignChildren(AContents: TList<TnbDockingPaneContent>);
    procedure AddAlignedSplitterFor(AContent: TnbDockingPaneContent);
    procedure LayoutLoadedSplitters(AContents: TList<TnbDockingPaneContent>);
    procedure DetachAllContents;
    procedure RebuildVisualTree;
    procedure RebuildFocusVisualTree;
    function BuildNode(ANode: TPaneNode; AContainer: TFmxObject;
      AAlign: TAlignLayout; ASize: Single): TFmxObject;
    function BuildLeaf(ALeaf: TPaneLeaf; AContainer: TFmxObject;
      AAlign: TAlignLayout; ASize: Single): TLayout;
    function BuildSplit(ASplit: TPaneSplit; AContainer: TFmxObject;
      AAlign: TAlignLayout; ASize: Single): TLayout;
    function CountSplitters(AContainer: TFmxObject): Integer;
    function NodeAllowsResize(ANode: TPaneNode;
      AOrientation: TPaneOrientation): Boolean;
    function NodeMinSize(ANode: TPaneNode;
      AOrientation: TPaneOrientation): Single;
    function CanResizeBetween(ASplit: TPaneSplit; ALeftIdx: Integer): Boolean;
    procedure RecalcSplitChildSizes(ASplit: TPaneSplit; ASplitLayout: TLayout);
    procedure RecalcSplitProportions(ASplit: TPaneSplit; AContainer: TLayout);
    function FindLeafByContent(AContent: TnbDockingPaneContent): TPaneLeaf;
    function FindSlotFor(AContainer: TFmxObject; ALeaf: TPaneLeaf): TLayout;
    procedure InternalSetActive(ALeaf: TPaneLeaf);
    procedure SetActiveLeaf(AValue: TPaneLeaf);
    procedure SetFocusMode(AValue: Boolean);
    procedure SetBackgroundColor(AValue: TAlphaColor);
    procedure SyncBgFromContent(AContent: TnbDockingPaneContent);
    procedure HandleFocusItemMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure SetAutoBuildDesignChildren(AValue: Boolean);
    procedure SetDesignChildrenOrientation(AValue: TPaneOrientation);
    procedure SetDesignChildrenLayoutMode(AValue: TDesignChildrenLayoutMode);
    procedure SetVisibleTabs(AValue: Boolean);
    procedure SetShowAddButton(AValue: Boolean);
    procedure SetTabPosition(AValue: TnbDockingTabPosition);
    procedure SetTabTextDirection(AValue: TnbDockingTabTextDirection);
    procedure UpdateTabBarChrome;
  protected
    procedure Loaded; override;
    procedure Resize; override;
    procedure DoAddObject(const AObject: TFmxObject); override;
    procedure DoRemoveObject(const AObject: TFmxObject); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure SetInitialContent(AContent: TnbDockingPaneContent);
    procedure ReplaceTreeRoot(ANode: TPaneNode; AActiveLeaf: TPaneLeaf = nil);
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
    property BackgroundColor: TAlphaColor read FBackgroundColor
      write SetBackgroundColor;
    property SplitterSize: Single read FSplitterSize write FSplitterSize;
    property SplitterColor: TAlphaColor read FSplitterColor write FSplitterColor;
    property LeafFrameThickness: Single read FLegacyLeafFrameThickness
      write FLegacyLeafFrameThickness stored False;
    property LeafFrameColor: TAlphaColor read FLegacyLeafFrameColor
      write FLegacyLeafFrameColor stored False;
    property ActiveLeafFrameColor: TAlphaColor read FLegacyActiveLeafFrameColor
      write FLegacyActiveLeafFrameColor stored False;
    property HeaderHeight: Single read FLegacyHeaderHeight
      write FLegacyHeaderHeight stored False;
    property AutoMatchBg: Boolean read FAutoMatchBg write FAutoMatchBg;
    property AutoBuildDesignChildren: Boolean read FAutoBuildDesignChildren
      write SetAutoBuildDesignChildren default True;
    property DesignChildrenOrientation: TPaneOrientation
      read FDesignChildrenOrientation write SetDesignChildrenOrientation
      default poHorizontal;
    property DesignChildrenLayoutMode: TDesignChildrenLayoutMode
      read FDesignChildrenLayoutMode write SetDesignChildrenLayoutMode
      default dlmSplit;
    property VisibleTabs: Boolean read FVisibleTabs write SetVisibleTabs
      default False;
    property ShowAddButton: Boolean read FShowAddButton write SetShowAddButton
      default True;
    property TabPosition: TnbDockingTabPosition read FTabPosition
      write SetTabPosition default dtpTop;
    property TabTextDirection: TnbDockingTabTextDirection
      read FTabTextDirection write SetTabTextDirection default ttdAuto;
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

type
  TControlAccess = class(TControl);

{ TSplitterInfo }

constructor TSplitterInfo.Create(ASplit: TPaneSplit; ALeftIdx: Integer);
begin
  inherited Create;
  Split := ASplit;
  LeftChildIndex := ALeftIdx;
end;

{ TPaneHostTab }

constructor TPaneHostTab.Create(const ACaption: string);
begin
  inherited Create;
  Caption := ACaption;
  Tree := TPaneTree.Create;
  ActiveLeaf := nil;
end;

destructor TPaneHostTab.Destroy;
begin
  Tree.Free;
  inherited;
end;

{ TnbDockingPaneHost }

constructor TnbDockingPaneHost.Create(AOwner: TComponent);
begin
  inherited;
  Align := TAlignLayout.Client;

  FTabs := TObjectList<TPaneHostTab>.Create(True);
  FTabButtons := TObjectList<TRectangle>.Create(True);
  FActiveTabIndex := -1;
  FTree := nil;
  EnsurePrimaryTab;

  FBuilding := False;
  FRebuildingDesignChildren := False;
  (* Прозрачно по умолчанию — сквозь зазоры виден фон формы-хоста.
     Карточки рисуют свой фон сами. *)
  FBackgroundColor := TAlphaColor(0);
  FSplitterSize := 4.0;
  FSplitterColor := TAlphaColor(0);
  FSplitterCovers := TList<TRectangle>.Create;
  FAutoMatchBg := False;
  FSplitterInfos := TObjectList<TSplitterInfo>.Create(True);
  FDesignSplitters := TObjectList<TSplitter>.Create(True);
  FAutoBuildDesignChildren := True;
  FDesignChildrenOrientation := poHorizontal;
  FDesignChildrenLayoutMode := dlmSplit;
  FVisibleTabs := False;
  FShowAddButton := True;
  FTabPosition := dtpTop;
  FTabTextDirection := ttdAuto;

  FWorkspaceLayout := TLayout.Create(Self);
  FWorkspaceLayout.Parent := Self;
  FWorkspaceLayout.Stored := False;
  FWorkspaceLayout.Locked := True;
  FWorkspaceLayout.Align := TAlignLayout.Client;
  FWorkspaceLayout.HitTest := True;

  FTabBar := TRectangle.Create(Self);
  FTabBar.Parent := Self;
  FTabBar.Stored := False;
  FTabBar.Locked := True;
  FTabBar.Align := TAlignLayout.None;
  FTabBar.Visible := False;
  FTabBar.HitTest := True;
  FTabBar.Fill.Kind := TBrushKind.Solid;
  FTabBar.Fill.Color := TAlphaColor($FFE5E5E5);
  FTabBar.Stroke.Kind := TBrushKind.None;

  FAddButton := TRectangle.Create(Self);
  FAddButton.Parent := FTabBar;
  FAddButton.Stored := False;
  FAddButton.Locked := True;
  FAddButton.Align := TAlignLayout.None;
  FAddButton.Width := PANE_TAB_ADD_BUTTON_WIDTH;
  FAddButton.Height := PANE_TAB_ADD_BUTTON_WIDTH - 10;
  FAddButton.Fill.Kind := TBrushKind.None;
  FAddButton.Stroke.Kind := TBrushKind.None;
  FAddButton.XRadius := 6;
  FAddButton.YRadius := 6;
  FAddButton.HitTest := True;
  FAddButton.OnMouseDown := HandleAddButtonClick;
  FAddButton.OnMouseEnter := HandleAddButtonMouseEnter;
  FAddButton.OnMouseLeave := HandleAddButtonMouseLeave;

  FAddGlyph := TText.Create(Self);
  FAddGlyph.Parent := FAddButton;
  FAddGlyph.Stored := False;
  FAddGlyph.Locked := True;
  FAddGlyph.Align := TAlignLayout.Client;
  FAddGlyph.Text := PANE_TAB_ICON_ADD;
  FAddGlyph.TextSettings.HorzAlign := TTextAlign.Center;
  FAddGlyph.TextSettings.VertAlign := TTextAlign.Center;
  FAddGlyph.TextSettings.Font.Family := PANE_TAB_ICON_FONT;
  FAddGlyph.TextSettings.Font.Size := 15;
  FAddGlyph.TextSettings.FontColor := TAlphaColor($FF202020);
  FAddGlyph.HitTest := False;

  FDropOverlay := TDockingDropOverlay.Create(Self);
  FDropOverlay.Parent := Self;
  FDropOverlay.Stored := False;
  FDropOverlay.Locked := True;
  FDropOverlay.HideOverlay;
  FDragSourceLeaf := nil;
  FCurrentDropLeaf := nil;
  FCurrentDropHit := NoZone;
  FTabDragIndex := -1;
  FTabDragStartX := 0;
  FTabDragStartY := 0;
  FTabDragActive := False;
  FTabDragTargetLeaf := nil;
  FTabDragHit := NoZone;

  FBackgroundRect := TRectangle.Create(Self);
  FBackgroundRect.Parent := FWorkspaceLayout;
  FBackgroundRect.Stored := False;
  FBackgroundRect.Locked := True;
  FBackgroundRect.Align := TAlignLayout.Contents;
  FBackgroundRect.Fill.Kind := TBrushKind.Solid;
  FBackgroundRect.Fill.Color := FBackgroundColor;
  FBackgroundRect.Stroke.Kind := TBrushKind.None;
  FBackgroundRect.HitTest := False;
  FBackgroundRect.SendToBack;

  FRootLayout := TLayout.Create(Self);
  FRootLayout.Parent := FWorkspaceLayout;
  FRootLayout.Stored := False;
  FRootLayout.Locked := True;
  FRootLayout.Align := TAlignLayout.Client;
  FRootLayout.Visible := False;
  FRootLayout.HitTest := True;
  UpdateTabBarChrome;
end;

procedure TnbDockingPaneHost.Loaded;
begin
  inherited;
  if csDesigning in ComponentState then
    RebuildTreeFromDesignChildren
  else
    TThread.Queue(nil,
      procedure
      begin
        if (not (csDestroying in ComponentState)) and (FTree.Root = nil) then
          RebuildTreeFromDesignChildren;
      end);
end;

procedure TnbDockingPaneHost.Resize;
var
  Contents: TList<TnbDockingPaneContent>;
begin
  inherited;
  UpdateTabBarChrome;

  if (csLoading in ComponentState)
     or (not FAutoBuildDesignChildren)
     or FBuilding
     or FRebuildingDesignChildren then
    Exit;

  if (not (csDesigning in ComponentState)) and (FTree.Root = nil) then
  begin
    RebuildTreeFromDesignChildren;
    Exit;
  end;

  if (FTree.Root = nil) or ((FRootLayout <> nil) and FRootLayout.Visible) then
    Exit;

  Contents := TList<TnbDockingPaneContent>.Create;
  try
    CollectDirectContents(Contents);
    if Contents.Count = 0 then Exit;

    if FDesignChildrenLayoutMode = dlmAlign then
    begin
      LayoutAlignedDesignChildren(Contents);
      Exit;
    end;

    if csDesigning in ComponentState then
      LayoutDesignChildren(Contents)
    else
      LayoutLoadedSplitters(Contents);
  finally
    Contents.Free;
  end;
end;

procedure TnbDockingPaneHost.DoAddObject(const AObject: TFmxObject);
begin
  inherited;

  if (csDesigning in ComponentState)
     and (AObject is TnbDockingPaneContent)
     and FAutoBuildDesignChildren
     and not (csLoading in ComponentState)
     and not FBuilding
     and not FRebuildingDesignChildren then
    RebuildTreeFromDesignChildren;
end;

procedure TnbDockingPaneHost.DoRemoveObject(const AObject: TFmxObject);
begin
  inherited;
  if (csDesigning in ComponentState)
     and (AObject is TnbDockingPaneContent)
     and FAutoBuildDesignChildren
     and not (csLoading in ComponentState)
     and not FBuilding
     and not FRebuildingDesignChildren then
    RebuildTreeFromDesignChildren;
end;

destructor TnbDockingPaneHost.Destroy;
begin
  FDesignSplitters.Free;
  FSplitterInfos.Free;
  FSplitterCovers.Free;
  FTabButtons.Free;
  FTabs.Free;
  inherited;
end;

procedure TnbDockingPaneHost.WireContent(AContent: TnbDockingPaneContent);
begin
  AContent.OnSplitRequest := HandleContentSplitRequest;
  AContent.OnCloseRequest := HandleContentCloseRequest;
  AContent.OnActivateRequest := HandleContentActivateRequest;
  AContent.OnHeaderChanged := HandleContentHeaderChanged;
  AContent.OnHeaderDrag := HandleContentHeaderDrag;
  if not (csDesigning in ComponentState) then
    AContent.HeaderDragEnabled := True;
end;

procedure TnbDockingPaneHost.UnwireContent(AContent: TnbDockingPaneContent);
begin
  if AContent = nil then Exit;
  AContent.OnSplitRequest := nil;
  AContent.OnCloseRequest := nil;
  AContent.OnActivateRequest := nil;
  AContent.OnHeaderChanged := nil;
  AContent.OnHeaderDrag := nil;
end;

function TnbDockingPaneHost.ContainsNestedHost(
  AContent: TnbDockingPaneContent): Boolean;
var
  I: Integer;
begin
  Result := False;
  if AContent = nil then
    Exit;

  for I := 0 to AContent.ChildrenCount - 1 do
    if AContent.Children[I] is TnbDockingPaneHost then
      Exit(True);
end;

procedure TnbDockingPaneHost.NormalizeContainerContent(
  AContent: TnbDockingPaneContent);
begin
  if (AContent = nil) or not ContainsNestedHost(AContent) then
    Exit;

  AContent.HeaderVisible := False;
  AContent.Fill.Kind := TBrushKind.None;
  AContent.Stroke.Kind := TBrushKind.None;
  AContent.Stroke.Thickness := 0;
  AContent.Padding.Rect := RectF(0, 0, 0, 0);
  AContent.XRadius := 0;
  AContent.YRadius := 0;
end;

procedure TnbDockingPaneHost.RebuildTreeFromDesignChildren;
var
  Contents: TList<TnbDockingPaneContent>;
  SavedOnChanged: TPaneTreeChangeEvent;
  I: Integer;
  Content: TnbDockingPaneContent;
  NewLeaf: TPaneLeaf;
  Direction: TSplitDirection;
begin
  if (not FAutoBuildDesignChildren) or FBuilding or FRebuildingDesignChildren then
    Exit;

  Contents := TList<TnbDockingPaneContent>.Create;
  try
    CollectDirectContents(Contents);

    if Contents.Count = 0 then
    begin
      if (not (csDesigning in ComponentState)) and (FTree.Root <> nil) then
        Exit;
      FTree.Clear;
      FActiveLeaf := nil;
      FDesignSplitters.Clear;
      Exit;
    end;

    if FDesignChildrenLayoutMode = dlmAlign then
    begin
      FRebuildingDesignChildren := True;
      SavedOnChanged := FTree.OnChanged;
      FTree.OnChanged := nil;
      try
        FTree.Clear;
        FActiveLeaf := nil;
        for I := 0 to Contents.Count - 1 do
        begin
          Content := Contents[I];
          NormalizeContainerContent(Content);
          WireContent(Content);
        end;
      finally
        FTree.OnChanged := SavedOnChanged;
        FRebuildingDesignChildren := False;
      end;
      LayoutAlignedDesignChildren(Contents);
      Exit;
    end;

    if FDesignChildrenOrientation = poVertical then
      Direction := sdBelow
    else
      Direction := sdRight;

    FRebuildingDesignChildren := True;
    SavedOnChanged := FTree.OnChanged;
    FTree.OnChanged := nil;
    try
      FTree.Clear;
      FActiveLeaf := nil;

      for I := 0 to Contents.Count - 1 do
      begin
        Content := Contents[I];
        NormalizeContainerContent(Content);
        WireContent(Content);

        if FTree.Root = nil then
          FActiveLeaf := FTree.SetRootContent(Content)
        else
        begin
          NewLeaf := FTree.SplitLeaf(FActiveLeaf, Direction, Content);
          FActiveLeaf := NewLeaf;
        end;
      end;
    finally
      FTree.OnChanged := SavedOnChanged;
      FRebuildingDesignChildren := False;
    end;

    ApplyDesignChildSizesToRootSplit(Contents);

    if csDesigning in ComponentState then
      LayoutDesignChildren(Contents)
    else
    begin
      InternalSetActive(FTree.FirstLeaf);
      RebuildVisualTree;
      Exit;
    end;
    InternalSetActive(FTree.FirstLeaf);
  finally
    Contents.Free;
  end;
end;

function TnbDockingPaneHost.TryReadDesignChildSizes(
  AContents: TList<TnbDockingPaneContent>; AOrientation: TPaneOrientation;
  out ASizes: TArray<Single>): Boolean;
var
  I: Integer;
  Sum, Value: Single;
begin
  Result := False;
  ASizes := nil;
  if AContents.Count = 0 then Exit;

  SetLength(ASizes, AContents.Count);
  Sum := 0;
  for I := 0 to AContents.Count - 1 do
  begin
    if AOrientation = poHorizontal then
      Value := AContents[I].Width
    else
      Value := AContents[I].Height;

    if Value <= 1 then
      Exit;

    ASizes[I] := Value;
    Sum := Sum + Value;
  end;

  Result := Sum > 0;
end;

function TnbDockingPaneHost.TryReadRootSplitSizes(
  AContents: TList<TnbDockingPaneContent>; AOrientation: TPaneOrientation;
  out ASizes: TArray<Single>): Boolean;
var
  I: Integer;
  Split: TPaneSplit;
  Sum: Single;
begin
  Result := False;
  ASizes := nil;

  if (AContents.Count = 0) or not (FTree.Root is TPaneSplit) then
    Exit;

  Split := TPaneSplit(FTree.Root);
  if (Split.Orientation <> AOrientation)
     or (Split.ChildCount <> AContents.Count) then
    Exit;

  SetLength(ASizes, AContents.Count);
  Sum := 0;
  for I := 0 to AContents.Count - 1 do
  begin
    ASizes[I] := Split.GetSize(I);
    Sum := Sum + ASizes[I];
  end;

  Result := Sum > 0;
end;

procedure TnbDockingPaneHost.ApplyDesignChildSizesToRootSplit(
  AContents: TList<TnbDockingPaneContent>);
var
  I: Integer;
  Sizes: TArray<Single>;
  Split: TPaneSplit;
begin
  if (AContents.Count < 2) or not (FTree.Root is TPaneSplit) then
    Exit;

  Split := TPaneSplit(FTree.Root);
  if (Split.Orientation <> FDesignChildrenOrientation)
     or (Split.ChildCount <> AContents.Count) then
    Exit;

  if not TryReadDesignChildSizes(AContents, FDesignChildrenOrientation, Sizes) then
    Exit;

  for I := 0 to High(Sizes) do
    if Sizes[I] <= 0 then
      Exit;

  Split.SetSizes(Sizes);
end;

procedure TnbDockingPaneHost.CollectDirectContents(
  AContents: TList<TnbDockingPaneContent>);
var
  I: Integer;
begin
  if AContents = nil then Exit;
  AContents.Clear;

  for I := 0 to ChildrenCount - 1 do
    if Children[I] is TnbDockingPaneContent then
      AContents.Add(TnbDockingPaneContent(Children[I]));
end;

procedure TnbDockingPaneHost.LayoutDirectChildren(
  AContents: TList<TnbDockingPaneContent>; AInteractiveSplitters: Boolean);
var
  I: Integer;
  Content: TnbDockingPaneContent;
  Splitter: TSplitter;
  Split: TPaneSplit;
  Info: TSplitterInfo;
  AvailableSize, ContentSize, Offset, SizeSum: Single;
  SplitterCount: Integer;
  Sizes: TArray<Single>;
begin
  FDesignSplitters.Clear;
  FSplitterInfos.Clear;
  FSplitterCovers.Clear;
  if AContents.Count = 0 then Exit;

  if FRootLayout <> nil then
    FRootLayout.Visible := False;

  BeginUpdate;
  try
    SizeSum := 0;
    if not TryReadRootSplitSizes(AContents, FDesignChildrenOrientation, Sizes) then
      TryReadDesignChildSizes(AContents, FDesignChildrenOrientation, Sizes);
    if Length(Sizes) = AContents.Count then
      for I := 0 to High(Sizes) do
        SizeSum := SizeSum + Sizes[I];
    SplitterCount := 0;
    if FTree.Root is TPaneSplit then
      for I := 0 to AContents.Count - 2 do
        if CanResizeBetween(TPaneSplit(FTree.Root), I) then
          Inc(SplitterCount);

    if FDesignChildrenOrientation = poVertical then
    begin
      AvailableSize := Height - Padding.Top - Padding.Bottom
        - (FSplitterSize * SplitterCount);
      if AvailableSize <= 0 then
        AvailableSize := 600;
      Offset := 0;

      for I := 0 to AContents.Count - 1 do
      begin
        Content := AContents[I];
        if SizeSum > 0 then
          ContentSize := AvailableSize * (Sizes[I] / SizeSum)
        else
          ContentSize := AvailableSize / AContents.Count;
        ContentSize := Max(ContentSize, Content.MinPaneHeight);
        Content.Align := TAlignLayout.Top;
        Content.Height := ContentSize;
        Content.Position.Y := Offset;
        if I = AContents.Count - 1 then
          Content.Align := TAlignLayout.Client;
        Offset := Offset + ContentSize;

        if (I < AContents.Count - 1)
           and (FTree.Root is TPaneSplit)
           and CanResizeBetween(TPaneSplit(FTree.Root), I) then
        begin
          Splitter := TSplitter.Create(nil);
          FDesignSplitters.Add(Splitter);
          Splitter.Stored := False;
          Splitter.ShowGrip := False;
          Splitter.Padding.Rect := RectF(0, 0, 0, 0);
          Splitter.Margins.Rect := RectF(0, 0, 0, 0);
          Splitter.Align := TAlignLayout.Top;
          Splitter.Height := FSplitterSize;
          Splitter.Position.Y := Offset;
          if AInteractiveSplitters then
          begin
            Splitter.MinSize := Max(AContents[I].MinPaneHeight,
              AContents[I + 1].MinPaneHeight);
            Splitter.OnMouseUp := HandleSplitterMouseUp;
            if FTree.Root is TPaneSplit then
            begin
              Split := TPaneSplit(FTree.Root);
              Info := TSplitterInfo.Create(Split, I);
              FSplitterInfos.Add(Info);
              Splitter.TagObject := Info;
            end;
            if (FSplitterColor shr 24) > 0 then
            begin
              var Cover := TRectangle.Create(Self);
              Cover.Parent := Splitter;
              Cover.Align := TAlignLayout.Contents;
              Cover.Fill.Color := FSplitterColor;
              Cover.Stroke.Kind := TBrushKind.None;
              Cover.HitTest := False;
              FSplitterCovers.Add(Cover);
            end
            else
              Splitter.Opacity := 0;
            InsertObject(Content.Index + 1, Splitter);
          end
          else
          begin
            Splitter.Parent := Self;
            Splitter.Locked := True;
            Splitter.HitTest := False;
          end;
          Offset := Offset + FSplitterSize;
        end;
      end;
    end
    else
    begin
      AvailableSize := Width - Padding.Left - Padding.Right
        - (FSplitterSize * SplitterCount);
      if AvailableSize <= 0 then
        AvailableSize := 800;
      Offset := 0;

      for I := 0 to AContents.Count - 1 do
      begin
        Content := AContents[I];
        if SizeSum > 0 then
          ContentSize := AvailableSize * (Sizes[I] / SizeSum)
        else
          ContentSize := AvailableSize / AContents.Count;
        ContentSize := Max(ContentSize, Content.MinPaneWidth);
        Content.Align := TAlignLayout.Left;
        Content.Width := ContentSize;
        Content.Position.X := Offset;
        if I = AContents.Count - 1 then
          Content.Align := TAlignLayout.Client;
        Offset := Offset + ContentSize;

        if (I < AContents.Count - 1)
           and (FTree.Root is TPaneSplit)
           and CanResizeBetween(TPaneSplit(FTree.Root), I) then
        begin
          Splitter := TSplitter.Create(nil);
          FDesignSplitters.Add(Splitter);
          Splitter.Stored := False;
          Splitter.ShowGrip := False;
          Splitter.Padding.Rect := RectF(0, 0, 0, 0);
          Splitter.Margins.Rect := RectF(0, 0, 0, 0);
          Splitter.Align := TAlignLayout.Left;
          Splitter.Width := FSplitterSize;
          Splitter.Position.X := Offset;
          if AInteractiveSplitters then
          begin
            Splitter.MinSize := Max(AContents[I].MinPaneWidth,
              AContents[I + 1].MinPaneWidth);
            Splitter.OnMouseUp := HandleSplitterMouseUp;
            if FTree.Root is TPaneSplit then
            begin
              Split := TPaneSplit(FTree.Root);
              Info := TSplitterInfo.Create(Split, I);
              FSplitterInfos.Add(Info);
              Splitter.TagObject := Info;
            end;
            if (FSplitterColor shr 24) > 0 then
            begin
              var Cover := TRectangle.Create(Self);
              Cover.Parent := Splitter;
              Cover.Align := TAlignLayout.Contents;
              Cover.Fill.Color := FSplitterColor;
              Cover.Stroke.Kind := TBrushKind.None;
              Cover.HitTest := False;
              FSplitterCovers.Add(Cover);
            end
            else
              Splitter.Opacity := 0;
            InsertObject(Content.Index + 1, Splitter);
          end
          else
          begin
            Splitter.Parent := Self;
            Splitter.Locked := True;
            Splitter.HitTest := False;
          end;
          Offset := Offset + FSplitterSize;
        end;
      end;
    end;

    if FBackgroundRect <> nil then
      FBackgroundRect.SendToBack;
  finally
    EndUpdate;
  end;
end;

procedure TnbDockingPaneHost.LayoutDesignChildren(
  AContents: TList<TnbDockingPaneContent>);
begin
  LayoutDirectChildren(AContents, False);
end;

procedure TnbDockingPaneHost.LayoutAlignedDesignChildren(
  AContents: TList<TnbDockingPaneContent>);
var
  I: Integer;
  Content: TnbDockingPaneContent;
begin
  FDesignSplitters.Clear;
  FSplitterInfos.Clear;
  FSplitterCovers.Clear;

  if FRootLayout <> nil then
    FRootLayout.Visible := False;

  BeginUpdate;
  try
    for I := 0 to AContents.Count - 1 do
    begin
      Content := AContents[I];
      if Content.Align = TAlignLayout.None then
        Content.Align := TAlignLayout.Client;
      case Content.Align of
        TAlignLayout.Left, TAlignLayout.Right:
          if Content.Width < Content.MinPaneWidth then
            Content.Width := Content.MinPaneWidth;
        TAlignLayout.Top, TAlignLayout.Bottom:
          if Content.Height < Content.MinPaneHeight then
            Content.Height := Content.MinPaneHeight;
      end;
      Content.HeaderDragEnabled := not (csDesigning in ComponentState);
      Content.BringToFront;
      AddAlignedSplitterFor(Content);
    end;
    if FBackgroundRect <> nil then
      FBackgroundRect.SendToBack;
  finally
    EndUpdate;
  end;
end;

procedure TnbDockingPaneHost.AddAlignedSplitterFor(AContent: TnbDockingPaneContent);
var
  Splitter: TSplitter;
  NeedsSplitter, InsertBeforeContent: Boolean;

  procedure AddCover;
  var
    Cover: TRectangle;
  begin
    if (FSplitterColor shr 24) = 0 then
    begin
      Splitter.Opacity := 0;
      Exit;
    end;

    Cover := TRectangle.Create(Self);
    Cover.Parent := Splitter;
    Cover.Align := TAlignLayout.Contents;
    Cover.Fill.Color := FSplitterColor;
    Cover.Stroke.Kind := TBrushKind.None;
    Cover.HitTest := False;
    FSplitterCovers.Add(Cover);
  end;

begin
  if AContent = nil then Exit;

  InsertBeforeContent := False;

  case AContent.Align of
    TAlignLayout.Left:
      NeedsSplitter := rsHorizontal in AContent.AllowResize;
    TAlignLayout.Right:
      begin
        NeedsSplitter := rsHorizontal in AContent.AllowResize;
        InsertBeforeContent := True;
      end;
    TAlignLayout.Top:
      NeedsSplitter := rsVertical in AContent.AllowResize;
    TAlignLayout.Bottom:
      begin
        NeedsSplitter := rsVertical in AContent.AllowResize;
        InsertBeforeContent := True;
      end;
  else
    NeedsSplitter := False;
  end;

  if not NeedsSplitter then Exit;

  Splitter := TSplitter.Create(nil);
  FDesignSplitters.Add(Splitter);
  Splitter.Stored := False;
  Splitter.ShowGrip := False;
  Splitter.Padding.Rect := RectF(0, 0, 0, 0);
  Splitter.Margins.Rect := RectF(0, 0, 0, 0);

  case AContent.Align of
    TAlignLayout.Left, TAlignLayout.Right:
      begin
        Splitter.Align := AContent.Align;
        Splitter.Width := FSplitterSize;
        Splitter.MinSize := AContent.MinPaneWidth;
      end;
    TAlignLayout.Top, TAlignLayout.Bottom:
      begin
        Splitter.Align := AContent.Align;
        Splitter.Height := FSplitterSize;
        Splitter.MinSize := AContent.MinPaneHeight;
      end;
  end;

  AddCover;

  if InsertBeforeContent then
    InsertObject(AContent.Index, Splitter)
  else
    InsertObject(AContent.Index + 1, Splitter);
end;

procedure TnbDockingPaneHost.LayoutLoadedSplitters(
  AContents: TList<TnbDockingPaneContent>);
begin
  LayoutDirectChildren(AContents, True);
end;

procedure TnbDockingPaneHost.HandleContentHeaderChanged(
  Sender: TnbDockingPaneContent);
var
  Leaf: TPaneLeaf;
begin
  (* Карточка сама перерисовалась — нам важно только обновить host
     и внешних подписчиков. *)
  if FAutoMatchBg then
  begin
    Leaf := FindLeafByContent(Sender);
    if (Leaf <> nil) and (Leaf = FActiveLeaf) then
      SyncBgFromContent(Sender);
  end;
  if FFocusMode then
  begin
    Leaf := FindLeafByContent(Sender);
    if (Leaf <> nil) and (Leaf = FActiveLeaf) then
      RebuildVisualTree;
  end;
  if Assigned(FOnContentHeaderChanged) then
    FOnContentHeaderChanged(Self, Sender);
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

procedure TnbDockingPaneHost.HandleContentHeaderDrag(
  ASender: TnbDockingPaneContent; APhase: TPaneHeaderDragPhase;
  const AScreenPt: TPointF);
var
  Leaf: TPaneLeaf;
begin
  Leaf := FindLeafByContent(ASender);
  if Leaf = nil then Exit;
  if not (csDesigning in ComponentState) then
  begin
    case APhase of
      phdStart: PaneHeaderDragBegin(Leaf);
      phdMove: PaneHeaderDragUpdate(AScreenPt);
      phdEnd: PaneHeaderDragEnd(AScreenPt);
    end;
  end;
  NotifyHeaderDrag(Leaf, APhase, AScreenPt);
end;

procedure TnbDockingPaneHost.PaneHeaderDragBegin(ALeaf: TPaneLeaf);
begin
  FDragSourceLeaf := ALeaf;
  FCurrentDropLeaf := nil;
  FCurrentDropHit := NoZone;
  if FDropOverlay <> nil then
  begin
    FDropOverlay.Parent := Self;
    FDropOverlay.HideOverlay;
  end;
end;

procedure TnbDockingPaneHost.PaneHeaderDragUpdate(const AScreenPt: TPointF);
var
  LocalPt: TPointF;
  TargetLeaf: TPaneLeaf;
  Hit: TDropHitResult;
begin
  if (FDragSourceLeaf = nil) or (FDropOverlay = nil) then Exit;

  if IsPointOverTabBar(AScreenPt) then
  begin
    ClearDropOverlay;
    SetTabBarDropHighlight(True);
    Exit;
  end;
  SetTabBarDropHighlight(False);

  LocalPt := ScreenToLocal(AScreenPt);
  TargetLeaf := FindLeafAt(LocalPt);
  if (TargetLeaf = nil) or (TargetLeaf = FDragSourceLeaf) then
  begin
    ClearDropOverlay;
    Exit;
  end;

  if TargetLeaf <> FCurrentDropLeaf then
  begin
    FCurrentDropLeaf := TargetLeaf;
    FDropOverlay.Parent := Self;
    FDropOverlay.ShowAt(LeafBounds(TargetLeaf));
  end;

  Hit := FDropOverlay.HitTestZone(LocalPt.X, LocalPt.Y);
  FCurrentDropHit := Hit;
  FDropOverlay.Highlight(Hit);
end;

procedure TnbDockingPaneHost.PaneHeaderDragEnd(const AScreenPt: TPointF);
var
  LocalPt: TPointF;
  TargetLeaf, SourceLeaf: TPaneLeaf;
  Hit: TDropHitResult;
  Content, TargetContent: TnbDockingPaneContent;
  DropOnTabBar: Boolean;
  NewCaption: string;
begin
  SourceLeaf := FDragSourceLeaf;
  TargetLeaf := FCurrentDropLeaf;
  Hit := FCurrentDropHit;
  DropOnTabBar := IsPointOverTabBar(AScreenPt);

  if (not DropOnTabBar) and (not Hit.HasZone) and (FDropOverlay <> nil) then
  begin
    LocalPt := ScreenToLocal(AScreenPt);
    TargetLeaf := FindLeafAt(LocalPt);
    if (TargetLeaf <> nil) and (TargetLeaf <> SourceLeaf) then
      Hit := FDropOverlay.HitTestZone(LocalPt.X, LocalPt.Y);
  end;

  ClearDropOverlay;
  FDragSourceLeaf := nil;

  if DropOnTabBar then
  begin
    if SourceLeaf = nil then Exit;
    if FTree.LeafCount <= 1 then Exit;
    if SourceLeaf.Content <> nil then
      NewCaption := SourceLeaf.Content.Caption
    else
      NewCaption := 'Group';
    Content := TakeLeafContent(SourceLeaf);
    if Content <> nil then
      AddTabWithContent(NewCaption, Content);
    Exit;
  end;

  if (SourceLeaf = nil) or (TargetLeaf = nil) or (TargetLeaf = SourceLeaf)
     or (not Hit.HasZone) then
    Exit;

  TargetContent := TargetLeaf.Content;
  Content := TakeLeafContent(SourceLeaf);
  if Content = nil then Exit;
  TargetLeaf := FindLeafByContent(TargetContent);
  if TargetLeaf = nil then
  begin
    if FTree.Root = nil then
      SetInitialContent(Content)
    else
    begin
      InternalSetActive(FTree.FirstLeaf);
      SplitActive(Hit.Direction, Content);
    end;
    Exit;
  end;
  ActiveLeaf := TargetLeaf;
  SplitActive(Hit.Direction, Content);
end;

procedure TnbDockingPaneHost.ClearDropOverlay;
begin
  if FDropOverlay <> nil then
    FDropOverlay.HideOverlay;
  SetTabBarDropHighlight(False);
  FCurrentDropLeaf := nil;
  FCurrentDropHit := NoZone;
end;

function TnbDockingPaneHost.IsPointOverTabBar(
  const AScreenPt: TPointF): Boolean;
var
  Pt: TPointF;
begin
  Result := False;
  if (not FVisibleTabs) or (FTabBar = nil) or (not FTabBar.Visible) then
    Exit;
  Pt := FTabBar.ScreenToLocal(AScreenPt);
  Result := (Pt.X >= 0) and (Pt.X <= FTabBar.Width)
    and (Pt.Y >= 0) and (Pt.Y <= FTabBar.Height);
end;

procedure TnbDockingPaneHost.SetTabBarDropHighlight(AValue: Boolean);
begin
  if FTabBar = nil then Exit;
  if AValue then
  begin
    FTabBar.Stroke.Kind := TBrushKind.Solid;
    FTabBar.Stroke.Color := TAlphaColor($FF3D6FB5);
    FTabBar.Stroke.Thickness := 2;
  end
  else
    FTabBar.Stroke.Kind := TBrushKind.None;
end;

function TnbDockingPaneHost.CreateDefaultContent: TnbDockingPaneContent;
begin
  Result := TnbDockingPaneContent.Create(Self);
  Result.Stored := False;
  Result.Caption := 'Pane ' + (FTree.LeafCount + 1).ToString;
  Result.ShowCloseButton := True;
end;

procedure TnbDockingPaneHost.EnsurePrimaryTab;
var
  Tab: TPaneHostTab;
begin
  if (FTabs <> nil) and (FTabs.Count > 0) then
    Exit;
  Tab := TPaneHostTab.Create('Group');
  Tab.Tree.OnChanged := HandleTreeChanged;
  FTabs.Add(Tab);
  FActiveTabIndex := 0;
  FTree := Tab.Tree;
end;

procedure TnbDockingPaneHost.SaveActiveTabState;
begin
  if (FTabs = nil) or (FActiveTabIndex < 0)
     or (FActiveTabIndex >= FTabs.Count) then
    Exit;
  FTabs[FActiveTabIndex].ActiveLeaf := FActiveLeaf;
end;

function TnbDockingPaneHost.AddTabWithContent(const ACaption: string;
  AContent: TnbDockingPaneContent): Integer;
var
  Tab: TPaneHostTab;
  Leaf: TPaneLeaf;
begin
  Result := -1;
  if AContent = nil then Exit;

  Tab := TPaneHostTab.Create(ACaption);
  AContent.Parent := nil;
  WireContent(AContent);
  Leaf := Tab.Tree.SetRootContent(AContent);
  Tab.ActiveLeaf := Leaf;
  Tab.Tree.OnChanged := HandleTreeChanged;
  Result := FTabs.Add(Tab);
  ActivateTabIndex(Result);
end;

function TnbDockingPaneHost.CaptionForTab(ATab: TPaneHostTab;
  const AFallback: string): string;
var
  Leaf: TPaneLeaf;
begin
  Result := AFallback;
  if (ATab = nil) or (ATab.Tree = nil) then Exit;
  if ATab.Tree.LeafCount = 1 then
  begin
    Leaf := ATab.Tree.FirstLeaf;
    if (Leaf <> nil) and (Leaf.Content <> nil)
       and (Leaf.Content.Caption <> '') then
      Exit(Leaf.Content.Caption);
  end;
  if ATab.Tree.LeafCount > 1 then
    Result := 'Group';
end;

procedure TnbDockingPaneHost.ActivateTabIndex(AIndex: Integer);
var
  OldLeaf, NewLeaf: TPaneLeaf;
begin
  EnsurePrimaryTab;
  if (AIndex < 0) or (AIndex >= FTabs.Count) then Exit;
  if AIndex = FActiveTabIndex then Exit;

  OldLeaf := FActiveLeaf;
  if (OldLeaf <> nil) and (OldLeaf.Content <> nil) then
  begin
    OldLeaf.Content.Deactivate;
    OldLeaf.Content.SetActive(False);
  end;

  SaveActiveTabState;
  FActiveTabIndex := AIndex;
  FTree := FTabs[AIndex].Tree;
  FTree.OnChanged := HandleTreeChanged;
  FActiveLeaf := nil;
  NewLeaf := FTabs[AIndex].ActiveLeaf;
  if NewLeaf = nil then
    NewLeaf := FTree.FirstLeaf;
  InternalSetActive(NewLeaf);
  RebuildVisualTree;
  if (FTabButtons <> nil) and (FTabButtons.Count = FTabs.Count) then
    UpdateTabButtonStates
  else
    RebuildTabButtons;
end;

procedure TnbDockingPaneHost.HandleTabButtonMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  if Button <> TMouseButton.mbLeft then Exit;
  if not (Sender is TControl) then Exit;

  FTabDragIndex := TControl(Sender).Tag;
  FTabDragStartX := X;
  FTabDragStartY := Y;
  FTabDragActive := False;
  FTabDragTargetLeaf := nil;
  FTabDragHit := NoZone;
  TControlAccess(Sender).Capture;
end;

procedure TnbDockingPaneHost.HandleTabButtonMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Single);
var
  ScreenPt: TPointF;
begin
  if FTabDragIndex < 0 then Exit;
  if not (Sender is TControl) then Exit;

  if (not FTabDragActive)
     and ((Abs(X - FTabDragStartX) > PANE_TAB_DRAG_THRESHOLD)
          or (Abs(Y - FTabDragStartY) > PANE_TAB_DRAG_THRESHOLD)) then
    FTabDragActive := True;

  if FTabDragActive then
  begin
    ScreenPt := TControl(Sender).LocalToScreen(PointF(X, Y));
    UpdateTabDrag(ScreenPt);
  end;
end;

procedure TnbDockingPaneHost.HandleTabButtonMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  TabIndex: Integer;
  WasDragging: Boolean;
  ScreenPt: TPointF;
begin
  if Button <> TMouseButton.mbLeft then Exit;
  if not (Sender is TControl) then Exit;

  TControlAccess(Sender).ReleaseCapture;
  TabIndex := FTabDragIndex;
  WasDragging := FTabDragActive;
  ScreenPt := TControl(Sender).LocalToScreen(PointF(X, Y));

  if WasDragging then
    TThread.Queue(nil,
      procedure
      begin
        if not (csDestroying in ComponentState) then
          FinishTabDrag(ScreenPt);
      end)
  else
  begin
    CancelTabDrag;
    TThread.Queue(nil,
      procedure
      begin
        if not (csDestroying in ComponentState) then
          ActivateTabIndex(TabIndex);
      end);
  end;
end;

procedure TnbDockingPaneHost.UpdateTabDrag(const AScreenPt: TPointF);
var
  LocalPt: TPointF;
  TargetLeaf: TPaneLeaf;
  Hit: TDropHitResult;
begin
  if (FTabDragIndex < 0) or (FTabDragIndex >= FTabs.Count)
     or (FDropOverlay = nil) then
    Exit;
  if FTabDragIndex = FActiveTabIndex then
  begin
    ClearDropOverlay;
    Exit;
  end;
  if FTabs[FTabDragIndex].Tree.LeafCount <> 1 then
  begin
    ClearDropOverlay;
    Exit;
  end;

  LocalPt := ScreenToLocal(AScreenPt);
  TargetLeaf := FindLeafAt(LocalPt);
  if TargetLeaf = nil then
  begin
    ClearDropOverlay;
    FTabDragTargetLeaf := nil;
    FTabDragHit := NoZone;
    Exit;
  end;

  if TargetLeaf <> FTabDragTargetLeaf then
  begin
    FTabDragTargetLeaf := TargetLeaf;
    FDropOverlay.Parent := Self;
    FDropOverlay.ShowAt(LeafBounds(TargetLeaf));
  end;

  Hit := FDropOverlay.HitTestZone(LocalPt.X, LocalPt.Y);
  FTabDragHit := Hit;
  FDropOverlay.Highlight(Hit);
end;

procedure TnbDockingPaneHost.FinishTabDrag(const AScreenPt: TPointF);
var
  SourceTab: TPaneHostTab;
  SourceLeaf, TargetLeaf: TPaneLeaf;
  Content, TargetContent: TnbDockingPaneContent;
  Hit: TDropHitResult;
  SourceIndex: Integer;
begin
  SourceIndex := FTabDragIndex;
  TargetLeaf := FTabDragTargetLeaf;
  Hit := FTabDragHit;
  CancelTabDrag;

  if (SourceIndex < 0) or (SourceIndex >= FTabs.Count)
     or (SourceIndex = FActiveTabIndex) or (not Hit.HasZone)
     or (TargetLeaf = nil) then
    Exit;

  SourceTab := FTabs[SourceIndex];
  if SourceTab.Tree.LeafCount <> 1 then Exit;
  SourceLeaf := SourceTab.Tree.FirstLeaf;
  if (SourceLeaf = nil) or (SourceLeaf.Content = nil) then Exit;

  TargetContent := TargetLeaf.Content;
  Content := SourceLeaf.Content;
  Content.Parent := nil;
  SourceTab.Tree.Clear;

  FTabs.Delete(SourceIndex);
  if SourceIndex < FActiveTabIndex then
    Dec(FActiveTabIndex);
  FTree := FTabs[FActiveTabIndex].Tree;
  TargetLeaf := FindLeafByContent(TargetContent);
  if TargetLeaf = nil then
  begin
    AddTabWithContent(Content.Caption, Content);
    Exit;
  end;

  FActiveLeaf := TargetLeaf;
  SplitActive(Hit.Direction, Content);
  RebuildTabButtons;
end;

procedure TnbDockingPaneHost.CancelTabDrag;
begin
  ClearDropOverlay;
  FTabDragIndex := -1;
  FTabDragActive := False;
  FTabDragTargetLeaf := nil;
  FTabDragHit := NoZone;
end;

procedure TnbDockingPaneHost.UpdateTabButtonStates;
var
  I: Integer;
  Btn: TRectangle;
begin
  if FTabButtons = nil then Exit;
  for I := 0 to FTabButtons.Count - 1 do
  begin
    Btn := FTabButtons[I];
    if Btn = nil then Continue;
    if I = FActiveTabIndex then
      Btn.Fill.Color := TAlphaColor($FFFFFFFF)
    else
      Btn.Fill.Color := TAlphaColor($FFE5E5E5);
  end;
end;

procedure TnbDockingPaneHost.RebuildTabButtons;
var
  I: Integer;
  Btn: TRectangle;
  Txt: TText;
  BtnWidth, BtnHeight, Pos, BarSize: Single;
  TextIsVertical: Boolean;
begin
  if (FTabBar = nil) or (FTabButtons = nil) or (FTabs = nil) then Exit;

  FTabButtons.Clear;
  if not FVisibleTabs then Exit;

  BarSize := PANE_TAB_BAR_HEIGHT;
  Pos := 8;
  for I := 0 to FTabs.Count - 1 do
  begin
    Btn := TRectangle.Create(Self);
    FTabButtons.Add(Btn);
    Btn.Parent := FTabBar;
    Btn.Stored := False;
    Btn.Locked := True;
    Btn.Align := TAlignLayout.None;
    Btn.Tag := I;
    Btn.HitTest := True;
    Btn.XRadius := 6;
    Btn.YRadius := 6;
    Btn.OnMouseDown := HandleTabButtonMouseDown;
    Btn.OnMouseMove := HandleTabButtonMouseMove;
    Btn.OnMouseUp := HandleTabButtonMouseUp;
    Btn.Stroke.Kind := TBrushKind.Solid;
    Btn.Stroke.Color := TAlphaColor($553D6FB5);
    if I = FActiveTabIndex then
      Btn.Fill.Color := TAlphaColor($FFFFFFFF)
    else
      Btn.Fill.Color := TAlphaColor($FFE5E5E5);

    Txt := TText.Create(Self);
    Txt.Parent := Btn;
    Txt.Stored := False;
    Txt.Locked := True;
    Txt.Align := TAlignLayout.Client;
    Txt.Text := CaptionForTab(FTabs[I], FTabs[I].Caption);
    Txt.TextSettings.HorzAlign := TTextAlign.Center;
    Txt.TextSettings.VertAlign := TTextAlign.Center;
    Txt.TextSettings.Font.Size := 12;
    Txt.TextSettings.FontColor := TAlphaColor($FF202020);
    Txt.HitTest := False;

    TextIsVertical := FTabTextDirection = ttdVertical;
    if FTabTextDirection = ttdAuto then
      TextIsVertical := FTabPosition in [dtpLeft, dtpRight];
    if TextIsVertical then
      Txt.RotationAngle := -90
    else
      Txt.RotationAngle := 0;

    if FTabPosition in [dtpLeft, dtpRight] then
    begin
      BtnWidth := BarSize - 8;
      BtnHeight := 88;
      Btn.Position.X := 4;
      Btn.Position.Y := Pos;
      Pos := Pos + BtnHeight + 6;
    end
    else
    begin
      BtnWidth := 104;
      BtnHeight := BarSize - 16;
      Btn.Position.X := Pos;
      Btn.Position.Y := 8;
      Pos := Pos + BtnWidth + 6;
    end;
    Btn.Width := BtnWidth;
    Btn.Height := BtnHeight;
  end;
end;

procedure TnbDockingPaneHost.HandleAddButtonClick(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  Content: TnbDockingPaneContent;
  Caption: string;
begin
  if Button <> TMouseButton.mbLeft then Exit;

  Content := nil;
  if Assigned(FOnContentNeeded) then
    FOnContentNeeded(Self, Content);
  if Content = nil then
    Content := CreateDefaultContent;

  Caption := Content.Caption;
  if Caption = '' then
    Caption := 'Pane ' + (FTabs.Count + 1).ToString;
  AddTabWithContent(Caption, Content);
end;

procedure TnbDockingPaneHost.HandleAddButtonMouseEnter(Sender: TObject);
begin
  if FAddButton = nil then Exit;
  FAddButton.Fill.Kind := TBrushKind.Solid;
  FAddButton.Fill.Color := TAlphaColor($22000000);
end;

procedure TnbDockingPaneHost.HandleAddButtonMouseLeave(Sender: TObject);
begin
  if FAddButton = nil then Exit;
  FAddButton.Fill.Kind := TBrushKind.None;
end;

procedure TnbDockingPaneHost.HandleTreeChanged(Sender: TPaneTree);
begin
  if FFocusMode and (FTree.LeafCount <= 1) then
    FFocusMode := False;
  if not FBuilding then
    RebuildVisualTree;
  if not FBuilding then
    RebuildTabButtons;
end;

procedure TnbDockingPaneHost.SetInitialContent(AContent: TnbDockingPaneContent);
begin
  if FTree.Root <> nil then
    raise EDockingError.Create('TnbDockingPaneHost.SetInitialContent: tree is not empty');
  if AContent = nil then
    raise EDockingError.Create('TnbDockingPaneHost.SetInitialContent: nil content');

  AContent.Parent := nil;
  WireContent(AContent);

  FTree.SetRootContent(AContent);
  InternalSetActive(FTree.FirstLeaf);
end;

procedure TnbDockingPaneHost.ReplaceTreeRoot(ANode: TPaneNode;
  AActiveLeaf: TPaneLeaf);

  procedure WireNode(ANode: TPaneNode);
  var
    Split: TPaneSplit;
    I: Integer;
  begin
    if ANode = nil then Exit;
    if ANode is TPaneLeaf then
    begin
      if TPaneLeaf(ANode).Content <> nil then
      begin
        TPaneLeaf(ANode).Content.Parent := nil;
        WireContent(TPaneLeaf(ANode).Content);
      end;
      Exit;
    end;

    Split := ANode.AsSplit;
    if Split = nil then Exit;
    for I := 0 to Split.ChildCount - 1 do
      WireNode(Split.Children[I]);
  end;

begin
  WireNode(ANode);
  FBuilding := True;
  try
    FTree.SetRootNode(ANode);
  finally
    FBuilding := False;
  end;

  FActiveLeaf := nil;
  if AActiveLeaf = nil then
    AActiveLeaf := FTree.FirstLeaf;
  InternalSetActive(AActiveLeaf);
  RebuildVisualTree;
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
     кнопку, FMX вернётся в TSpeedButton.Click → AV. *)
  if ToCloseContent <> nil then
    TThread.ForceQueue(TThread.CurrentThread,
      procedure
      begin
        ToCloseContent.Free;
      end);

  InternalSetActive(FTree.FirstLeaf);

  (* Пустое дерево: InternalSetActive вышел рано (nil = nil) — стреляем
     событием вручную для внешних подписчиков. *)
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
  Result.SetActive(False);
  UnwireContent(Result);
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

procedure TnbDockingPaneHost.SetAutoBuildDesignChildren(AValue: Boolean);
begin
  if FAutoBuildDesignChildren = AValue then Exit;
  FAutoBuildDesignChildren := AValue;
  if FAutoBuildDesignChildren then
    RebuildTreeFromDesignChildren;
end;

procedure TnbDockingPaneHost.SetDesignChildrenOrientation(
  AValue: TPaneOrientation);
begin
  if FDesignChildrenOrientation = AValue then Exit;
  FDesignChildrenOrientation := AValue;
  RebuildTreeFromDesignChildren;
end;

procedure TnbDockingPaneHost.SetDesignChildrenLayoutMode(
  AValue: TDesignChildrenLayoutMode);
begin
  if FDesignChildrenLayoutMode = AValue then Exit;
  FDesignChildrenLayoutMode := AValue;
  RebuildTreeFromDesignChildren;
end;

procedure TnbDockingPaneHost.SetVisibleTabs(AValue: Boolean);
begin
  if FVisibleTabs = AValue then Exit;
  FVisibleTabs := AValue;
  UpdateTabBarChrome;
end;

procedure TnbDockingPaneHost.SetShowAddButton(AValue: Boolean);
begin
  if FShowAddButton = AValue then Exit;
  FShowAddButton := AValue;
  UpdateTabBarChrome;
end;

procedure TnbDockingPaneHost.SetTabPosition(AValue: TnbDockingTabPosition);
begin
  if FTabPosition = AValue then Exit;
  FTabPosition := AValue;
  UpdateTabBarChrome;
end;

procedure TnbDockingPaneHost.SetTabTextDirection(
  AValue: TnbDockingTabTextDirection);
begin
  if FTabTextDirection = AValue then Exit;
  FTabTextDirection := AValue;
  UpdateTabBarChrome;
end;

procedure TnbDockingPaneHost.UpdateTabBarChrome;
var
  BarSize, BtnSize: Single;
begin
  if FTabBar = nil then Exit;

  BarSize := PANE_TAB_BAR_HEIGHT;
  BtnSize := PANE_TAB_ADD_BUTTON_WIDTH - 10;
  FTabBar.Visible := FVisibleTabs;
  Padding.Rect := RectF(0, 0, 0, 0);
  case FTabPosition of
    dtpBottom:
      begin
        FTabBar.Align := TAlignLayout.None;
        FTabBar.Position.X := 0;
        FTabBar.Position.Y := Height - BarSize;
        FTabBar.Width := Width;
        FTabBar.Height := BarSize;
        if FVisibleTabs then
          Padding.Bottom := BarSize;
      end;
    dtpLeft:
      begin
        FTabBar.Align := TAlignLayout.None;
        FTabBar.Position.X := 0;
        FTabBar.Position.Y := 0;
        FTabBar.Width := BarSize;
        FTabBar.Height := Height;
        if FVisibleTabs then
          Padding.Left := BarSize;
      end;
    dtpRight:
      begin
        FTabBar.Align := TAlignLayout.None;
        FTabBar.Position.X := Width - BarSize;
        FTabBar.Position.Y := 0;
        FTabBar.Width := BarSize;
        FTabBar.Height := Height;
        if FVisibleTabs then
          Padding.Right := BarSize;
      end;
  else
    FTabBar.Align := TAlignLayout.None;
    FTabBar.Position.X := 0;
    FTabBar.Position.Y := 0;
    FTabBar.Width := Width;
    FTabBar.Height := BarSize;
    if FVisibleTabs then
      Padding.Top := BarSize;
  end;

  if FVisibleTabs then
    FTabBar.BringToFront;

  RebuildTabButtons;

  if FAddButton <> nil then
  begin
    FAddButton.Visible := FVisibleTabs and FShowAddButton;
    FAddButton.Width := BtnSize;
    FAddButton.Height := BtnSize;
    if FTabPosition in [dtpLeft, dtpRight] then
    begin
      FAddButton.Position.X := (BarSize - BtnSize) / 2;
      FAddButton.Position.Y := FTabBar.Height - BtnSize - 8;
    end
    else
    begin
      FAddButton.Position.X := FTabBar.Width - BtnSize - 8;
      FAddButton.Position.Y := (BarSize - BtnSize) / 2;
    end;
    if FAddButton.Visible then
      FAddButton.BringToFront;
  end;

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
  Slot: TLayout;
  Pt1, Pt2: TPointF;
begin
  Result := RectF(0, 0, 0, 0);
  if ALeaf = nil then Exit;

  Slot := FindSlotFor(FRootLayout, ALeaf);
  if Slot = nil then Exit;

  Pt1 := Slot.LocalToAbsolute(PointF(0, 0));
  Pt2 := Slot.LocalToAbsolute(PointF(Slot.Width, Slot.Height));
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

function TnbDockingPaneHost.FindSlotFor(AContainer: TFmxObject;
  ALeaf: TPaneLeaf): TLayout;
var
  I: Integer;
  Child: TFmxObject;
begin
  Result := nil;
  if (AContainer = nil) or (ALeaf = nil) then Exit;
  for I := 0 to AContainer.ChildrenCount - 1 do
  begin
    Child := AContainer.Children[I];
    if (Child is TLayout) and (TLayout(Child).TagObject = ALeaf) then
      Exit(TLayout(Child));
    Result := FindSlotFor(Child, ALeaf);
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
  begin
    OldLeaf.Content.Deactivate;
    OldLeaf.Content.SetActive(False);
  end;

  FActiveLeaf := ALeaf;
  SaveActiveTabState;

  if (FActiveLeaf <> nil) and (FActiveLeaf.Content <> nil) then
  begin
    FActiveLeaf.Content.SetActive(True);
    FActiveLeaf.Content.Activate;
    if FAutoMatchBg then
      SyncBgFromContent(FActiveLeaf.Content);
  end;

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
var
  I: Integer;
  Tree: TPaneTree;
begin
  if (FTabs <> nil) and (FTabs.Count > 0) then
    for I := 0 to FTabs.Count - 1 do
    begin
      Tree := FTabs[I].Tree;
      if Tree = nil then Continue;
      Tree.EnumerateLeaves(
        procedure(ALeaf: TPaneLeaf)
        begin
          if (ALeaf.Content <> nil) and (ALeaf.Content.Parent <> nil) then
            ALeaf.Content.Parent := nil;
        end);
    end
  else if FTree <> nil then
    FTree.EnumerateLeaves(
      procedure(ALeaf: TPaneLeaf)
      begin
        if (ALeaf.Content <> nil) and (ALeaf.Content.Parent <> nil) then
          ALeaf.Content.Parent := nil;
      end);
end;

procedure TnbDockingPaneHost.RebuildVisualTree;
begin
  if FBuilding then Exit;
  FBuilding := True;
  try
    DetachAllContents;
    FDesignSplitters.Clear;
    FSplitterInfos.Clear;
    FSplitterCovers.Clear;

    FRootLayout.Free;
    FRootLayout := TLayout.Create(Self);
    FRootLayout.Parent := FWorkspaceLayout;
    FRootLayout.Stored := False;
    FRootLayout.Locked := True;
    FRootLayout.Align := TAlignLayout.Client;
    FRootLayout.Visible := True;
    FRootLayout.HitTest := True;
    if FBackgroundRect <> nil then
      FBackgroundRect.SendToBack;

    if FFocusMode then
    begin
      RebuildFocusVisualTree;
      Exit;
    end;

    if FTree.Root <> nil then
      BuildNode(FTree.Root, FRootLayout, TAlignLayout.Client, 0);

    (* После rebuild активность нужно восстановить — карточка-то живая,
       но её Stroke могла сброситься, если контент пересоздан. *)
    if (FActiveLeaf <> nil) and (FActiveLeaf.Content <> nil) then
      FActiveLeaf.Content.SetActive(True);
  finally
    FBuilding := False;
  end;
end;

procedure TnbDockingPaneHost.RebuildFocusVisualTree;
var
  Sidebar: TLayout;
  SidebarBg: TRectangle;
  TitleLabel, ItemTitle, ItemSubTitle: TLabel;
  Item: TPaneFocusItem;
  TopOffset: Single;
  CountText: string;
  Bg, TextColor, Surface, Selected, Muted, Accent: TAlphaColor;

  function Blend(C1, C2: TAlphaColor; W2: Single): TAlphaColor;
  var
    W1: Single;
  begin
    if W2 < 0 then W2 := 0;
    if W2 > 1 then W2 := 1;
    W1 := 1 - W2;
    Result :=
      (Round(((C1 shr 24) and $FF) * W1 + ((C2 shr 24) and $FF) * W2) shl 24) or
      (Round(((C1 shr 16) and $FF) * W1 + ((C2 shr 16) and $FF) * W2) shl 16) or
      (Round(((C1 shr 8) and $FF) * W1 + ((C2 shr 8) and $FF) * W2) shl 8) or
      Round((C1 and $FF) * W1 + (C2 and $FF) * W2);
  end;
begin
  if FActiveLeaf = nil then
    FActiveLeaf := FTree.FirstLeaf;
  if FActiveLeaf = nil then Exit;

  CountText := FTree.LeafCount.ToString;
  if FActiveLeaf.Content <> nil then
  begin
    Bg := FActiveLeaf.Content.HeaderBgColor;
    TextColor := FActiveLeaf.Content.HeaderTextColor;
  end
  else
  begin
    Bg := FBackgroundColor;
    TextColor := TAlphaColor($FFE0E0E0);
  end;

  Surface := Blend(Bg, TextColor, 0.08);
  Selected := Blend(Bg, TextColor, 0.16);
  Muted := Blend(TextColor, Bg, 0.42);
  Accent := TextColor;

  Sidebar := TLayout.Create(Self);
  Sidebar.Parent := FRootLayout;
  Sidebar.Align := TAlignLayout.Left;
  Sidebar.Width := 210;
  Sidebar.Padding.Rect := RectF(8, 12, 8, 8);

  SidebarBg := TRectangle.Create(Self);
  SidebarBg.Parent := Sidebar;
  SidebarBg.Align := TAlignLayout.Contents;
  SidebarBg.Fill.Color := Surface;
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
  TitleLabel.TextSettings.FontColor := Muted;
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
        Item.Fill.Color := Selected
      else
        Item.Fill.Color := TAlphaColor(0);

      ItemTitle := TLabel.Create(Self);
      ItemTitle.Parent := Item;
      ItemTitle.Align := TAlignLayout.Top;
      ItemTitle.Height := 24;
      ItemTitle.Margins.Rect := RectF(10, 4, 8, 0);
      ItemTitle.Text := CaptionText;
      ItemTitle.StyledSettings := [];
      ItemTitle.TextSettings.Font.Size := 12;
      if ALeaf = FActiveLeaf then
        ItemTitle.TextSettings.FontColor := Accent
      else
        ItemTitle.TextSettings.FontColor := TextColor;
      ItemTitle.TextSettings.VertAlign := TTextAlign.Center;
      ItemTitle.HitTest := False;

      ItemSubTitle := TLabel.Create(Self);
      ItemSubTitle.Parent := Item;
      ItemSubTitle.Align := TAlignLayout.Client;
      ItemSubTitle.Margins.Rect := RectF(10, 0, 8, 3);
      ItemSubTitle.Text := 'content';
      ItemSubTitle.StyledSettings := [];
      ItemSubTitle.TextSettings.Font.Size := 11;
      ItemSubTitle.TextSettings.FontColor := Muted;
      ItemSubTitle.TextSettings.VertAlign := TTextAlign.Center;
      ItemSubTitle.HitTest := False;

      TopOffset := TopOffset + 52;
    end);

  BuildLeaf(FActiveLeaf, FRootLayout, TAlignLayout.Client, 0);
  if FActiveLeaf.Content <> nil then
    FActiveLeaf.Content.SetActive(True);
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
  AAlign: TAlignLayout; ASize: Single): TLayout;
var
  Slot: TLayout;
begin
  (* Слот — тонкий контейнер; вся визуальная карточка живёт в Content. *)
  Slot := TLayout.Create(Self);
  Slot.Parent := AContainer;
  Slot.Align := AAlign;
  if AAlign = TAlignLayout.Left then Slot.Width := ASize
  else if AAlign = TAlignLayout.Top then Slot.Height := ASize;
  Slot.TagObject := ALeaf;

  if ALeaf.Content <> nil then
  begin
    ALeaf.Content.Parent := Slot;
    ALeaf.Content.Align := TAlignLayout.Client;
  end;

  Result := Slot;
end;

function TnbDockingPaneHost.CountSplitters(AContainer: TFmxObject): Integer;
var
  I: Integer;
begin
  Result := 0;
  if AContainer = nil then Exit;
  for I := 0 to AContainer.ChildrenCount - 1 do
    if AContainer.Children[I] is TSplitter then
      Inc(Result);
end;

function TnbDockingPaneHost.NodeAllowsResize(ANode: TPaneNode;
  AOrientation: TPaneOrientation): Boolean;
var
  Split: TPaneSplit;
  I: Integer;
  Side: TPaneResizeSide;
begin
  Result := False;
  if ANode = nil then Exit;

  if AOrientation = poHorizontal then
    Side := rsHorizontal
  else
    Side := rsVertical;

  if ANode is TPaneLeaf then
  begin
    Result := (TPaneLeaf(ANode).Content <> nil)
      and (Side in TPaneLeaf(ANode).Content.AllowResize);
    Exit;
  end;

  Split := ANode.AsSplit;
  if Split = nil then Exit(False);
  Result := False;
  for I := 0 to Split.ChildCount - 1 do
    if NodeAllowsResize(Split.Children[I], AOrientation) then
      Exit(True);
end;

function TnbDockingPaneHost.NodeMinSize(ANode: TPaneNode;
  AOrientation: TPaneOrientation): Single;
var
  Split: TPaneSplit;
  I: Integer;
begin
  Result := 50;
  if ANode = nil then Exit;

  if ANode is TPaneLeaf then
  begin
    if TPaneLeaf(ANode).Content = nil then Exit;
    if AOrientation = poHorizontal then
      Result := TPaneLeaf(ANode).Content.MinPaneWidth
    else
      Result := TPaneLeaf(ANode).Content.MinPaneHeight;
    Exit;
  end;

  Split := ANode.AsSplit;
  if Split = nil then Exit;
  Result := 0;
  for I := 0 to Split.ChildCount - 1 do
    Result := Result + NodeMinSize(Split.Children[I], AOrientation);
  if Split.Orientation = AOrientation then
    Result := Result + FSplitterSize * Max(0, Split.ChildCount - 1);
end;

function TnbDockingPaneHost.CanResizeBetween(ASplit: TPaneSplit;
  ALeftIdx: Integer): Boolean;
begin
  Result := (ASplit <> nil)
    and (ALeftIdx >= 0)
    and (ALeftIdx < ASplit.ChildCount - 1)
    and NodeAllowsResize(ASplit.Children[ALeftIdx], ASplit.Orientation)
    and NodeAllowsResize(ASplit.Children[ALeftIdx + 1], ASplit.Orientation);
end;

function TnbDockingPaneHost.BuildSplit(ASplit: TPaneSplit; AContainer: TFmxObject;
  AAlign: TAlignLayout; ASize: Single): TLayout;
var
  SplitLayout: TLayout;
  I: Integer;
  ChildAlign: TAlignLayout;
  AvailableSize, EffectiveSize, ChildSize: Single;
  SplitterCount: Integer;
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
    SplitterCount := 0;
    for I := 0 to ASplit.ChildCount - 2 do
      if CanResizeBetween(ASplit, I) then
        Inc(SplitterCount);
    EffectiveSize := AvailableSize - (FSplitterSize * SplitterCount);
    if EffectiveSize <= 0 then
      EffectiveSize := AvailableSize;

    for I := 0 to ASplit.ChildCount - 1 do
    begin
      if ASplit.Orientation = poHorizontal then
        ChildAlign := TAlignLayout.Left
      else
        ChildAlign := TAlignLayout.Top;
      if I = ASplit.ChildCount - 1 then
        ChildAlign := TAlignLayout.Client;

      ChildSize := ASplit.GetSize(I) * EffectiveSize;
      ChildSize := Max(ChildSize, NodeMinSize(ASplit.Children[I],
        ASplit.Orientation));

      BuildNode(ASplit.Children[I], SplitLayout, ChildAlign, ChildSize);

      if (I < ASplit.ChildCount - 1) and CanResizeBetween(ASplit, I) then
      begin
        Splitter := TSplitter.Create(Self);
        Splitter.Parent := SplitLayout;
        Splitter.ShowGrip := False;
        Splitter.Padding.Rect := RectF(0, 0, 0, 0);
        Splitter.Margins.Rect := RectF(0, 0, 0, 0);
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
        Splitter.MinSize := Max(NodeMinSize(ASplit.Children[I],
          ASplit.Orientation), NodeMinSize(ASplit.Children[I + 1],
          ASplit.Orientation));
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
        end
        else
          (* Цвет не задан — сплиттер полностью невидим (тянуть можно). *)
          Splitter.Opacity := 0;
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
  TotalSplitterSize := FSplitterSize * CountSplitters(ASplitLayout);
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
      NewSize := Max(NewSize, NodeMinSize(ASplit.Children[I],
        ASplit.Orientation));
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
  TotalSplitterSize := FSplitterSize * CountSplitters(AContainer);
  EffectiveSize := TotalSize - TotalSplitterSize;
  if EffectiveSize <= 0 then Exit;

  SetLength(Sizes, ASplit.ChildCount);
  ChildIdx := 0;
  for I := 0 to AContainer.ChildrenCount - 1 do
  begin
    Obj := AContainer.Children[I];
    if Obj is TSplitter then Continue;
    if (Obj = FBackgroundRect) or (Obj = FRootLayout) then Continue;
    if not (Obj is TControl) then Continue;
    if not ((Obj is TnbDockingPaneContent)
       or ((Obj is TLayout) and (TLayout(Obj).TagObject is TPaneNode))) then
      Continue;
    if ChildIdx >= ASplit.ChildCount then Break;
    if ASplit.Orientation = poHorizontal then
      Sizes[ChildIdx] := TControl(Obj).Width / EffectiveSize
    else
      Sizes[ChildIdx] := TControl(Obj).Height / EffectiveSize;
    Inc(ChildIdx);
  end;

  (* SetSize меняет только пропорции — OnChanged дерева не зовётся,
     rebuild визуала не нужен. *)
  for I := 0 to High(Sizes) do
    ASplit.SetSize(I, Sizes[I]);
end;

end.
