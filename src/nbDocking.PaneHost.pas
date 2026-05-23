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
  FMX.Types, FMX.Controls, FMX.Layouts, FMX.StdCtrls, FMX.Objects,
  FMX.Graphics,
  nbDocking.Types, nbDocking.PaneTree;

type
  TContentFactoryEvent = procedure(Sender: TObject;
    var AContent: TnbDockingPaneContent) of object;
  TActiveLeafChangeEvent = procedure(Sender: TObject;
    AOldLeaf, ANewLeaf: TPaneLeaf) of object;
  TContentHeaderChangeEvent = procedure(Sender: TObject;
    AContent: TnbDockingPaneContent) of object;

  TnbDockingPaneHost = class;

  (* Drag заголовка карточки транслируется наверх — drop-цель ищет TabHost. *)
  TPaneHeaderDragEvent = procedure(ASender: TnbDockingPaneHost; ALeaf: TPaneLeaf;
    APhase: TPaneHeaderDragPhase; const AScreenPt: TPointF) of object;

  (* Какой split режет сплиттер и индекс ребёнка-соседа слева/сверху. *)
  TSplitterInfo = class
  public
    Split: TPaneSplit;
    LeftChildIndex: Integer;
    constructor Create(ASplit: TPaneSplit; ALeftIdx: Integer);
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
    procedure HandleSplitLayoutResize(Sender: TObject);
    procedure HandleSplitterMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);

    procedure WireContent(AContent: TnbDockingPaneContent);
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
  protected
    procedure Loaded; override;
    procedure Resize; override;
    procedure DoAddObject(const AObject: TFmxObject); override;
    procedure DoRemoveObject(const AObject: TFmxObject); override;
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

{ TnbDockingPaneHost }

constructor TnbDockingPaneHost.Create(AOwner: TComponent);
begin
  inherited;
  Align := TAlignLayout.Client;

  FTree := TPaneTree.Create;
  FTree.OnChanged := HandleTreeChanged;

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

  FBackgroundRect := TRectangle.Create(Self);
  FBackgroundRect.Parent := Self;
  FBackgroundRect.Stored := False;
  FBackgroundRect.Locked := True;
  FBackgroundRect.Align := TAlignLayout.Contents;
  FBackgroundRect.Fill.Kind := TBrushKind.Solid;
  FBackgroundRect.Fill.Color := FBackgroundColor;
  FBackgroundRect.Stroke.Kind := TBrushKind.None;
  FBackgroundRect.HitTest := False;
  FBackgroundRect.SendToBack;

  FRootLayout := TLayout.Create(Self);
  FRootLayout.Parent := Self;
  FRootLayout.Stored := False;
  FRootLayout.Locked := True;
  FRootLayout.Align := TAlignLayout.Client;
  FRootLayout.Visible := False;
  FRootLayout.HitTest := False;
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
  FTree.Free;
  inherited;
end;

procedure TnbDockingPaneHost.WireContent(AContent: TnbDockingPaneContent);
begin
  AContent.OnSplitRequest := HandleContentSplitRequest;
  AContent.OnCloseRequest := HandleContentCloseRequest;
  AContent.OnActivateRequest := HandleContentActivateRequest;
  AContent.OnHeaderChanged := HandleContentHeaderChanged;
  AContent.OnHeaderDrag := HandleContentHeaderDrag;
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
      if FRootLayout <> nil then
        FRootLayout.Visible := False;
      LayoutLoadedSplitters(Contents);
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

    if FDesignChildrenOrientation = poVertical then
    begin
      AvailableSize := Height - (FSplitterSize * (AContents.Count - 1));
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
        Content.Align := TAlignLayout.Top;
        Content.Height := ContentSize;
        Content.Position.Y := Offset;
        if I = AContents.Count - 1 then
          Content.Align := TAlignLayout.Client;
        Offset := Offset + ContentSize;

        if I < AContents.Count - 1 then
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
            Splitter.MinSize := 50;
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
      AvailableSize := Width - (FSplitterSize * (AContents.Count - 1));
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
        Content.Align := TAlignLayout.Left;
        Content.Width := ContentSize;
        Content.Position.X := Offset;
        if I = AContents.Count - 1 then
          Content.Align := TAlignLayout.Client;
        Offset := Offset + ContentSize;

        if I < AContents.Count - 1 then
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
            Splitter.MinSize := 50;
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
  (* Карточка сама перерисовалась — нам важно только обновить внешних
     подписчиков (например, подписи табов в TabHost). *)
  if FAutoMatchBg then
  begin
    Leaf := FindLeafByContent(Sender);
    if (Leaf <> nil) and (Leaf = FActiveLeaf) then
      SyncBgFromContent(Sender);
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
  NotifyHeaderDrag(Leaf, APhase, AScreenPt);
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
  Result.SetActive(False);
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
begin
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
    FRootLayout.Parent := Self;
    FRootLayout.Stored := False;
    FRootLayout.Locked := True;
    FRootLayout.Align := TAlignLayout.Client;
    FRootLayout.Visible := True;
    FRootLayout.HitTest := False;
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

function TnbDockingPaneHost.BuildSplit(ASplit: TPaneSplit; AContainer: TFmxObject;
  AAlign: TAlignLayout; ASize: Single): TLayout;
var
  SplitLayout: TLayout;
  I: Integer;
  ChildAlign: TAlignLayout;
  AvailableSize, EffectiveSize, ChildSize: Single;
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
    EffectiveSize := AvailableSize - (FSplitterSize * (ASplit.ChildCount - 1));
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
      if ChildSize < 30 then ChildSize := 30;

      BuildNode(ASplit.Children[I], SplitLayout, ChildAlign, ChildSize);

      if I < ASplit.ChildCount - 1 then
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
