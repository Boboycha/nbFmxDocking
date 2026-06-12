unit nbDocking.PaneTree;

(*
  N-арное дерево panes. Ключевые инварианты:

  - Split минимально вкладывает: если родитель листа уже имеет нужную
    ориентацию, новый лист становится соседом, иначе лист оборачивается
    в новый split (как в iTerm2/tmux).
  - Close с одним оставшимся ребёнком схлопывает split в этого ребёнка,
    каскадно вверх.
  - Sizes — нормализованные доли, сумма = 1.0, диапазон [0.05, 0.95].
  - TnbDockingPaneContent дерево НЕ владеет — только ссылки. Освобождением
    занимается визуальный слой (TnbDockingPaneHost через TComponent.Owner).
*)

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections,
  nbDocking.Types;

type
  TPaneNode = class;
  TPaneLeaf = class;
  TPaneSplit = class;
  TPaneTree = class;

  TPaneNode = class
  private
    FParent: TPaneSplit;
    FOwnerTree: TPaneTree;
  public
    constructor Create(AOwnerTree: TPaneTree);
    function IsLeaf: Boolean; virtual; abstract;
    function AsLeaf: TPaneLeaf;
    function AsSplit: TPaneSplit;
    property Parent: TPaneSplit read FParent;
    property OwnerTree: TPaneTree read FOwnerTree;
  end;

  TPaneLeaf = class(TPaneNode)
  private
    FContent: TnbDockingPaneContent;
  public
    constructor Create(AOwnerTree: TPaneTree; AContent: TnbDockingPaneContent);
    destructor Destroy; override;
    function IsLeaf: Boolean; override;
    property Content: TnbDockingPaneContent read FContent;
  end;

  TPaneSplit = class(TPaneNode)
  private
    FOrientation: TPaneOrientation;
    FChildren: TObjectList<TPaneNode>;
    FSizes: TList<Single>;
    procedure NormalizeSizes;
    function GetChild(AIndex: Integer): TPaneNode;
    function GetChildCount: Integer;
  public
    constructor Create(AOwnerTree: TPaneTree; AOrientation: TPaneOrientation);
    destructor Destroy; override;
    function IsLeaf: Boolean; override;

    procedure InsertChild(AIndex: Integer; ANode: TPaneNode;
      ANormalizedSize: Single = 0);
    procedure RemoveChild(ANode: TPaneNode);
    procedure ReplaceChild(AOld, ANew: TPaneNode);
    function IndexOfChild(ANode: TPaneNode): Integer;

    procedure SetSize(AIndex: Integer; AValue: Single);
    procedure SetSizes(const AValues: TArray<Single>);
    function GetSize(AIndex: Integer): Single;

    property Orientation: TPaneOrientation read FOrientation;
    property ChildCount: Integer read GetChildCount;
    property Children[AIndex: Integer]: TPaneNode read GetChild;
  end;

  TPaneTreeChangeEvent = procedure(Sender: TPaneTree) of object;

  TPaneTree = class
  private
    FRoot: TPaneNode;
    FOnChanged: TPaneTreeChangeEvent;
    procedure DoChanged;
    function DirectionToOrientation(ADir: TSplitDirection): TPaneOrientation;
    function DirectionInsertsBefore(ADir: TSplitDirection): Boolean;
    procedure CollapseSingleChild(ASplit: TPaneSplit);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;
    procedure SetRootNode(ANode: TPaneNode);
    function SetRootContent(AContent: TnbDockingPaneContent): TPaneLeaf;
    function SplitRoot(ADirection: TSplitDirection;
      ANewContent: TnbDockingPaneContent): TPaneLeaf;
    function SplitLeaf(ALeaf: TPaneLeaf; ADirection: TSplitDirection;
      ANewContent: TnbDockingPaneContent): TPaneLeaf;
    procedure CloseLeaf(ALeaf: TPaneLeaf);

    function FirstLeaf: TPaneLeaf;
    function LeafCount: Integer;
    procedure EnumerateLeaves(AProc: TProc<TPaneLeaf>);

    property Root: TPaneNode read FRoot;
    property OnChanged: TPaneTreeChangeEvent read FOnChanged write FOnChanged;
  end;

implementation

{ TPaneNode }

constructor TPaneNode.Create(AOwnerTree: TPaneTree);
begin
  inherited Create;
  FOwnerTree := AOwnerTree;
end;

function TPaneNode.AsLeaf: TPaneLeaf;
begin
  if Self is TPaneLeaf then
    Result := TPaneLeaf(Self)
  else
    Result := nil;
end;

function TPaneNode.AsSplit: TPaneSplit;
begin
  if Self is TPaneSplit then
    Result := TPaneSplit(Self)
  else
    Result := nil;
end;

{ TPaneLeaf }

constructor TPaneLeaf.Create(AOwnerTree: TPaneTree; AContent: TnbDockingPaneContent);
begin
  inherited Create(AOwnerTree);
  FContent := AContent;
end;

destructor TPaneLeaf.Destroy;
begin
  (* Контент НЕ уничтожаем — им владеет PaneHost через TComponent.Owner. *)
  FContent := nil;
  inherited;
end;

function TPaneLeaf.IsLeaf: Boolean;
begin
  Result := True;
end;

{ TPaneSplit }

constructor TPaneSplit.Create(AOwnerTree: TPaneTree; AOrientation: TPaneOrientation);
begin
  inherited Create(AOwnerTree);
  FOrientation := AOrientation;
  FChildren := TObjectList<TPaneNode>.Create(True);
  FSizes := TList<Single>.Create;
end;

destructor TPaneSplit.Destroy;
begin
  FSizes.Free;
  FChildren.Free;
  inherited;
end;

function TPaneSplit.IsLeaf: Boolean;
begin
  Result := False;
end;

function TPaneSplit.GetChildCount: Integer;
begin
  Result := FChildren.Count;
end;

function TPaneSplit.GetChild(AIndex: Integer): TPaneNode;
begin
  Result := FChildren[AIndex];
end;

function TPaneSplit.IndexOfChild(ANode: TPaneNode): Integer;
begin
  Result := FChildren.IndexOf(ANode);
end;

procedure TPaneSplit.InsertChild(AIndex: Integer; ANode: TPaneNode;
  ANormalizedSize: Single);
var
  NewSize, Scale: Single;
  I: Integer;
begin
  if ANode = nil then
    raise EDockingError.Create('TPaneSplit.InsertChild: nil node');
  if (AIndex < 0) or (AIndex > FChildren.Count) then
    raise EDockingError.Create('TPaneSplit.InsertChild: index out of range');

  if ANormalizedSize <= 0 then
    NewSize := 1.0 / (FChildren.Count + 1)
  else
    NewSize := ANormalizedSize;

  (* Освобождаем место — масштабируем существующие доли. *)
  if FChildren.Count > 0 then
  begin
    Scale := 1.0 - NewSize;
    for I := 0 to FSizes.Count - 1 do
      FSizes[I] := FSizes[I] * Scale;
  end;

  FChildren.Insert(AIndex, ANode);
  FSizes.Insert(AIndex, NewSize);
  ANode.FParent := Self;
  NormalizeSizes;
end;

procedure TPaneSplit.RemoveChild(ANode: TPaneNode);
var
  Idx, I: Integer;
  Released, Scale: Single;
begin
  Idx := FChildren.IndexOf(ANode);
  if Idx < 0 then
    raise EDockingError.Create('TPaneSplit.RemoveChild: node not found');

  Released := FSizes[Idx];
  FSizes.Delete(Idx);

  (* Не уничтожать удаляемого — за временем жизни следит вызывающий. *)
  FChildren.OwnsObjects := False;
  try
    FChildren.Delete(Idx);
  finally
    FChildren.OwnsObjects := True;
  end;
  ANode.FParent := nil;

  if (FSizes.Count > 0) and (Released < 1.0) then
  begin
    Scale := 1.0 / (1.0 - Released);
    for I := 0 to FSizes.Count - 1 do
      FSizes[I] := FSizes[I] * Scale;
    NormalizeSizes;
  end;
end;

procedure TPaneSplit.ReplaceChild(AOld, ANew: TPaneNode);
var
  Idx: Integer;
begin
  Idx := FChildren.IndexOf(AOld);
  if Idx < 0 then
    raise EDockingError.Create('TPaneSplit.ReplaceChild: old node not found');

  (* Не уничтожать старого — за временем жизни следит вызывающий. *)
  FChildren.OwnsObjects := False;
  try
    FChildren[Idx] := ANew;
  finally
    FChildren.OwnsObjects := True;
  end;
  AOld.FParent := nil;
  ANew.FParent := Self;
  (* FSizes[Idx] сохраняется — новый узел занимает место старого. *)
end;

procedure TPaneSplit.SetSize(AIndex: Integer; AValue: Single);
begin
  if (AIndex < 0) or (AIndex >= FSizes.Count) then
    raise EDockingError.Create('TPaneSplit.SetSize: index out of range');
  if AValue < 0.05 then AValue := 0.05;
  if AValue > 0.95 then AValue := 0.95;
  FSizes[AIndex] := AValue;
  NormalizeSizes;
end;

procedure TPaneSplit.SetSizes(const AValues: TArray<Single>);
var
  I: Integer;
  Value: Single;
begin
  if Length(AValues) <> FSizes.Count then
    raise EDockingError.Create('TPaneSplit.SetSizes: size count mismatch');

  for I := 0 to High(AValues) do
  begin
    Value := AValues[I];
    if Value < 0.001 then
      Value := 0.001;
    FSizes[I] := Value;
  end;
  NormalizeSizes;
end;

function TPaneSplit.GetSize(AIndex: Integer): Single;
begin
  Result := FSizes[AIndex];
end;

procedure TPaneSplit.NormalizeSizes;
var
  Sum: Single;
  I: Integer;
begin
  Sum := 0;
  for I := 0 to FSizes.Count - 1 do
    Sum := Sum + FSizes[I];

  if (Sum <= 0) and (FSizes.Count > 0) then
  begin
    (* Накопление floating-point ошибок съело сумму — раздаём равные доли. *)
    for I := 0 to FSizes.Count - 1 do
      FSizes[I] := 1.0 / FSizes.Count;
    Exit;
  end;

  for I := 0 to FSizes.Count - 1 do
    FSizes[I] := FSizes[I] / Sum;
end;

{ TPaneTree }

constructor TPaneTree.Create;
begin
  inherited Create;
  FRoot := nil;
end;

destructor TPaneTree.Destroy;
begin
  FRoot.Free;
  inherited;
end;

procedure TPaneTree.Clear;
begin
  FreeAndNil(FRoot);
  DoChanged;
end;

procedure TPaneTree.SetRootNode(ANode: TPaneNode);
begin
  if ANode <> nil then
    ANode.FParent := nil;
  FRoot.Free;
  FRoot := ANode;
  DoChanged;
end;

procedure TPaneTree.DoChanged;
begin
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

function TPaneTree.DirectionToOrientation(ADir: TSplitDirection): TPaneOrientation;
begin
  case ADir of
    sdLeft, sdRight: Result := poHorizontal;
    sdAbove, sdBelow: Result := poVertical;
  else
    Result := poHorizontal;
  end;
end;

function TPaneTree.DirectionInsertsBefore(ADir: TSplitDirection): Boolean;
begin
  Result := ADir in [sdLeft, sdAbove];
end;

function TPaneTree.SetRootContent(AContent: TnbDockingPaneContent): TPaneLeaf;
begin
  if FRoot <> nil then
    raise EDockingError.Create('TPaneTree.SetRootContent: tree is not empty');
  if AContent = nil then
    raise EDockingError.Create('TPaneTree.SetRootContent: nil content');

  Result := TPaneLeaf.Create(Self, AContent);
  FRoot := Result;
  DoChanged;
end;

function TPaneTree.SplitRoot(ADirection: TSplitDirection;
  ANewContent: TnbDockingPaneContent): TPaneLeaf;
var
  OldRoot: TPaneNode;
  NewRoot: TPaneSplit;
  TargetOrient: TPaneOrientation;
  InsertBefore: Boolean;
begin
  if ANewContent = nil then
    raise EDockingError.Create('TPaneTree.SplitRoot: nil content');

  if FRoot = nil then
    Exit(SetRootContent(ANewContent));

  TargetOrient := DirectionToOrientation(ADirection);
  InsertBefore := DirectionInsertsBefore(ADirection);
  OldRoot := FRoot;
  NewRoot := TPaneSplit.Create(Self, TargetOrient);
  Result := TPaneLeaf.Create(Self, ANewContent);

  FRoot := NewRoot;
  OldRoot.FParent := nil;

  if InsertBefore then
  begin
    NewRoot.InsertChild(0, Result, 0.5);
    NewRoot.InsertChild(1, OldRoot, 0.5);
  end
  else
  begin
    NewRoot.InsertChild(0, OldRoot, 0.5);
    NewRoot.InsertChild(1, Result, 0.5);
  end;

  DoChanged;
end;

function TPaneTree.SplitLeaf(ALeaf: TPaneLeaf; ADirection: TSplitDirection;
  ANewContent: TnbDockingPaneContent): TPaneLeaf;
var
  TargetOrient: TPaneOrientation;
  InsertBefore: Boolean;
  ParentSplit, WrappingSplit: TPaneSplit;
  NewLeaf: TPaneLeaf;
  LeafIdx: Integer;
begin
  if ALeaf = nil then
    raise EDockingError.Create('TPaneTree.SplitLeaf: nil leaf');
  if ANewContent = nil then
    raise EDockingError.Create('TPaneTree.SplitLeaf: nil content');
  if ALeaf.OwnerTree <> Self then
    raise EDockingError.Create('TPaneTree.SplitLeaf: leaf belongs to another tree');

  TargetOrient := DirectionToOrientation(ADirection);
  InsertBefore := DirectionInsertsBefore(ADirection);
  NewLeaf := TPaneLeaf.Create(Self, ANewContent);
  ParentSplit := ALeaf.Parent;

  if (ParentSplit <> nil) and (ParentSplit.Orientation = TargetOrient) then
  begin
    LeafIdx := ParentSplit.IndexOfChild(ALeaf);
    if InsertBefore then
      ParentSplit.InsertChild(LeafIdx, NewLeaf)
    else
      ParentSplit.InsertChild(LeafIdx + 1, NewLeaf);
  end
  else
  begin
    WrappingSplit := TPaneSplit.Create(Self, TargetOrient);

    if ParentSplit = nil then
    begin
      (* ALeaf был корнем — корнем становится WrappingSplit. *)
      FRoot := WrappingSplit;
      ALeaf.FParent := nil;
    end
    else
      ParentSplit.ReplaceChild(ALeaf, WrappingSplit);

    if InsertBefore then
    begin
      WrappingSplit.InsertChild(0, NewLeaf, 0.5);
      WrappingSplit.InsertChild(1, ALeaf, 0.5);
    end
    else
    begin
      WrappingSplit.InsertChild(0, ALeaf, 0.5);
      WrappingSplit.InsertChild(1, NewLeaf, 0.5);
    end;
  end;

  Result := NewLeaf;
  DoChanged;
end;

procedure TPaneTree.CloseLeaf(ALeaf: TPaneLeaf);
var
  ParentSplit: TPaneSplit;
begin
  if ALeaf = nil then
    raise EDockingError.Create('TPaneTree.CloseLeaf: nil leaf');
  if ALeaf.OwnerTree <> Self then
    raise EDockingError.Create('TPaneTree.CloseLeaf: leaf belongs to another tree');

  ParentSplit := ALeaf.Parent;

  if ParentSplit = nil then
  begin
    if FRoot = ALeaf then
    begin
      FRoot := nil;
      ALeaf.Free;
      DoChanged;
    end
    else
      raise EDockingError.Create('TPaneTree.CloseLeaf: orphan leaf');
    Exit;
  end;

  ParentSplit.RemoveChild(ALeaf);
  ALeaf.Free;

  CollapseSingleChild(ParentSplit);

  DoChanged;
end;

procedure TPaneTree.CollapseSingleChild(ASplit: TPaneSplit);
var
  Survivor: TPaneNode;
  GrandParent: TPaneSplit;
begin
  if (ASplit = nil) or (ASplit.ChildCount <> 1) then
    Exit;

  Survivor := ASplit.Children[0];

  (* Survivor нужен живым после Free(ASplit) — отбираем его у OwnsObjects. *)
  ASplit.FChildren.OwnsObjects := False;
  try
    ASplit.FChildren.Delete(0);
    ASplit.FSizes.Delete(0);
  finally
    ASplit.FChildren.OwnsObjects := True;
  end;

  GrandParent := ASplit.Parent;
  if GrandParent = nil then
  begin
    FRoot := Survivor;
    Survivor.FParent := nil;
  end
  else
    GrandParent.ReplaceChild(ASplit, Survivor);

  ASplit.Free;

  (* Каскад: схлопнутый split мог оставить деда с одним ребёнком. *)
  if (GrandParent <> nil) and (GrandParent.ChildCount = 1) then
    CollapseSingleChild(GrandParent);
end;

function TPaneTree.FirstLeaf: TPaneLeaf;

  function FindIn(ANode: TPaneNode): TPaneLeaf;
  var
    Split: TPaneSplit;
    I: Integer;
  begin
    Result := nil;
    if ANode = nil then Exit;
    if ANode is TPaneLeaf then
      Exit(TPaneLeaf(ANode));
    if ANode is TPaneSplit then
    begin
      Split := TPaneSplit(ANode);
      for I := 0 to Split.ChildCount - 1 do
      begin
        Result := FindIn(Split.Children[I]);
        if Result <> nil then Exit;
      end;
    end;
  end;

begin
  Result := FindIn(FRoot);
end;

function TPaneTree.LeafCount: Integer;
var
  Cnt: Integer;
begin
  Cnt := 0;
  EnumerateLeaves(
    procedure(ALeaf: TPaneLeaf)
    begin
      Inc(Cnt);
    end);
  Result := Cnt;
end;

procedure TPaneTree.EnumerateLeaves(AProc: TProc<TPaneLeaf>);

  procedure Walk(ANode: TPaneNode);
  var
    Split: TPaneSplit;
    I: Integer;
  begin
    if ANode = nil then Exit;
    if ANode is TPaneLeaf then
      AProc(TPaneLeaf(ANode))
    else if ANode is TPaneSplit then
    begin
      Split := TPaneSplit(ANode);
      for I := 0 to Split.ChildCount - 1 do
        Walk(Split.Children[I]);
    end;
  end;

begin
  Walk(FRoot);
end;

end.
