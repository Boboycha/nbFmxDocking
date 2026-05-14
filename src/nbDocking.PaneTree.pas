unit nbDocking.PaneTree;

(*
  N-арное дерево panes для системы докинга.

  Узлы:
    TPaneSplit — внутренний узел: ориентация + N детей + N долей размера
    TPaneLeaf  — лист: держит TDockingPaneContent

  Алгоритм Split:
    Если родитель текущего листа уже той же ориентации,
      что и направление split — новый лист добавляется соседом
      в существующий split-узел.
    Иначе — лист оборачивается в новый split-узел из двух детей.
    Это держит дерево минимально вложенным (как в iTerm2/tmux).

  Алгоритм Close:
    Лист удаляется из родителя.
    Если у родителя остался один ребёнок — родитель схлопывается
    в этого единственного ребёнка (каскадом вверх).
    Закрытие последнего листа делает дерево пустым.

  Размеры (Sizes) — нормализованные доли (сумма = 1.0).
    При InsertChild новый получает долю 1/N, остальные масштабируются.
    При RemoveChild освободившаяся доля распределяется пропорционально.

  Контент (TDockingPaneContent) дерево НЕ уничтожает.
  Им владеет визуальный слой (TDockingPaneHost).
  Дерево хранит только ссылки.

  Для UI: после любой структурной операции дерево вызывает
  событие OnChanged. Слой UI перестраивает визуал.
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
    FContent: TDockingPaneContent;
  public
    constructor Create(AOwnerTree: TPaneTree; AContent: TDockingPaneContent);
    destructor Destroy; override;
    function IsLeaf: Boolean; override;
    property Content: TDockingPaneContent read FContent;
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

    (* Установить корневой лист с заданным контентом.
       Дерево должно быть пустым. *)
    function SetRootContent(AContent: TDockingPaneContent): TPaneLeaf;

    (* Разделить лист в указанном направлении, добавив новый pane.
       Возвращает только что созданный лист. *)
    function SplitLeaf(ALeaf: TPaneLeaf; ADirection: TSplitDirection;
      ANewContent: TDockingPaneContent): TPaneLeaf;

    (* Закрыть лист. Контент НЕ уничтожается здесь —
       это забота UI-слоя (PaneHost). *)
    procedure CloseLeaf(ALeaf: TPaneLeaf);

    (* Утилиты обхода *)
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

constructor TPaneLeaf.Create(AOwnerTree: TPaneTree; AContent: TDockingPaneContent);
begin
  inherited Create(AOwnerTree);
  FContent := AContent;
end;

destructor TPaneLeaf.Destroy;
begin
  (* Контент НЕ уничтожаем — им владеет PaneHost (через TComponent.Owner).
     Здесь только разрываем ссылку. *)
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
  FChildren := TObjectList<TPaneNode>.Create(True);  (* OwnsObjects = True *)
  FSizes := TList<Single>.Create;
end;

destructor TPaneSplit.Destroy;
begin
  (* FChildren.Free уничтожит всех оставшихся детей рекурсивно *)
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

  (* Уменьшаем существующих пропорционально, чтобы освободить место *)
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

  (* Не уничтожать удаляемого — за этим следит вызывающий *)
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

  (* Не уничтожать старого — за ним проследит вызывающий *)
  FChildren.OwnsObjects := False;
  try
    FChildren[Idx] := ANew;
  finally
    FChildren.OwnsObjects := True;
  end;
  AOld.FParent := nil;
  ANew.FParent := Self;
  (* Размер сохраняется — занимает то же место, что и старый *)
end;

procedure TPaneSplit.SetSize(AIndex: Integer; AValue: Single);
begin
  if (AIndex < 0) or (AIndex >= FSizes.Count) then
    raise EDockingError.Create('TPaneSplit.SetSize: index out of range');
  if AValue < 0.05 then AValue := 0.05;   (* минимум 5%, чтобы pane не исчез *)
  if AValue > 0.95 then AValue := 0.95;
  FSizes[AIndex] := AValue;
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
    (* Защита от накопления ошибок: равные доли *)
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
  FRoot.Free;     (* рекурсивно — split.Free уничтожит детей *)
  inherited;
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

function TPaneTree.SetRootContent(AContent: TDockingPaneContent): TPaneLeaf;
begin
  if FRoot <> nil then
    raise EDockingError.Create('TPaneTree.SetRootContent: tree is not empty');
  if AContent = nil then
    raise EDockingError.Create('TPaneTree.SetRootContent: nil content');

  Result := TPaneLeaf.Create(Self, AContent);
  FRoot := Result;
  DoChanged;
end;

function TPaneTree.SplitLeaf(ALeaf: TPaneLeaf; ADirection: TSplitDirection;
  ANewContent: TDockingPaneContent): TPaneLeaf;
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
    (* Добавляем соседом в существующий split *)
    LeafIdx := ParentSplit.IndexOfChild(ALeaf);
    if InsertBefore then
      ParentSplit.InsertChild(LeafIdx, NewLeaf)
    else
      ParentSplit.InsertChild(LeafIdx + 1, NewLeaf);
  end
  else
  begin
    (* Оборачиваем лист в новый split-узел *)
    WrappingSplit := TPaneSplit.Create(Self, TargetOrient);

    if ParentSplit = nil then
    begin
      (* Лист был корнем — корнем становится новый split *)
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
    (* Закрываем последний лист — дерево опустеет *)
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

  (* Если у родителя остался один ребёнок — схлопнуть split *)
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

  (* Изымаем survivor из ASplit без уничтожения *)
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
    (* Схлапываемый split был корнем *)
    FRoot := Survivor;
    Survivor.FParent := nil;
  end
  else
    GrandParent.ReplaceChild(ASplit, Survivor);

  ASplit.Free;

  (* Каскад вверх — на случай редких аномалий *)
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
