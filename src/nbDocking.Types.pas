unit nbDocking.Types;

(*
  Инвариант декаплинга: TDockingPaneContent общается с хостом только
  через события (OnSplitRequest / OnCloseRequest / OnActivateRequest /
  OnHeaderChanged). Прямых ссылок на хост у контента нет — это позволяет
  использовать любой потомок (терминал, SFTP, логи) в любом контейнере.
*)

interface

uses
  System.Classes, System.SysUtils, System.UITypes,
  System.Generics.Collections,
  FMX.Types, FMX.Layouts, FMX.Controls;

type
  TSplitDirection = (sdLeft, sdRight, sdAbove, sdBelow);
  TPaneOrientation = (poHorizontal, poVertical);

  TDockingPaneContent = class;

  TPaneSplitRequestEvent = procedure(Sender: TDockingPaneContent;
    ADirection: TSplitDirection) of object;
  TPaneCloseRequestEvent = procedure(Sender: TDockingPaneContent) of object;
  TPaneActivateRequestEvent = procedure(Sender: TDockingPaneContent) of object;
  TPaneHeaderChangedEvent = procedure(Sender: TDockingPaneContent) of object;
  TPaneHeaderActionEvent = procedure(Sender: TDockingPaneContent;
    const AActionId: string) of object;

  TDockingPaneHeaderAction = class
  private
    FId: string;
    FGlyph: string;
    FHint: string;
    FOnExecute: TPaneHeaderActionEvent;
  public
    constructor Create(const AId, AGlyph, AHint: string;
      AOnExecute: TPaneHeaderActionEvent);

    property Id: string read FId;
    property Glyph: string read FGlyph write FGlyph;
    property Hint: string read FHint write FHint;
    property OnExecute: TPaneHeaderActionEvent read FOnExecute write FOnExecute;
  end;

  TDockingPaneContent = class(TLayout)
  private
    FCaption: string;
    FGlyph: string;
    FHeaderBgColor: TAlphaColor;
    FHeaderTextColor: TAlphaColor;
    FOnSplitRequest: TPaneSplitRequestEvent;
    FOnCloseRequest: TPaneCloseRequestEvent;
    FOnActivateRequest: TPaneActivateRequestEvent;
    FOnHeaderChanged: TPaneHeaderChangedEvent;
    FHeaderActions: TObjectList<TDockingPaneHeaderAction>;
    procedure SetCaption(const AValue: string);
    procedure SetHeaderBgColor(AValue: TAlphaColor);
    procedure SetHeaderTextColor(AValue: TAlphaColor);
  protected
    procedure DoActivate; virtual;
    procedure DoDeactivate; virtual;
    procedure DoHeaderChanged;

    (* Вспомогательные методы для потомков:
       попросить хост о split/close/activate. *)
    procedure RequestSplit(ADirection: TSplitDirection);
    procedure RequestClose;
    procedure RequestActivate;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Activate;
    procedure Deactivate;

    (* Default = True; override чтобы заблокировать закрытие (например,
       терминал с незавершённой командой просит подтверждение). *)
    function CanClose: Boolean; virtual;

    function AddHeaderAction(const AId, AGlyph: string;
      AOnExecute: TPaneHeaderActionEvent;
      const AHint: string = ''): TDockingPaneHeaderAction;
    procedure RemoveHeaderAction(const AId: string);
    procedure ClearHeaderActions;
    function FindHeaderAction(const AId: string): TDockingPaneHeaderAction;
    procedure ExecuteHeaderAction(const AId: string);

    (* Подписывается PaneHost — потомки сами трогать события не должны. *)
    property OnSplitRequest: TPaneSplitRequestEvent
      read FOnSplitRequest write FOnSplitRequest;
    property OnCloseRequest: TPaneCloseRequestEvent
      read FOnCloseRequest write FOnCloseRequest;
    property OnActivateRequest: TPaneActivateRequestEvent
      read FOnActivateRequest write FOnActivateRequest;
    property OnHeaderChanged: TPaneHeaderChangedEvent
      read FOnHeaderChanged write FOnHeaderChanged;
    property HeaderActions: TObjectList<TDockingPaneHeaderAction>
      read FHeaderActions;
  published
    property Caption: string read FCaption write SetCaption;
    property Glyph: string read FGlyph write FGlyph;

    (* Termius-style: цвета title bar в тон с фоном контента. *)
    property HeaderBgColor: TAlphaColor read FHeaderBgColor
      write SetHeaderBgColor default TAlphaColor($FF2A2A2A);
    property HeaderTextColor: TAlphaColor read FHeaderTextColor
      write SetHeaderTextColor default TAlphaColor($FFE0E0E0);
  end;

  EDockingError = class(Exception);

implementation

{ TDockingPaneHeaderAction }

constructor TDockingPaneHeaderAction.Create(const AId, AGlyph, AHint: string;
  AOnExecute: TPaneHeaderActionEvent);
begin
  inherited Create;
  FId := AId;
  FGlyph := AGlyph;
  FHint := AHint;
  FOnExecute := AOnExecute;
end;

{ TDockingPaneContent }

constructor TDockingPaneContent.Create(AOwner: TComponent);
begin
  inherited;
  Align := TAlignLayout.Client;
  FHeaderBgColor := TAlphaColor($FF2A2A2A);
  FHeaderTextColor := TAlphaColor($FFE0E0E0);
  FHeaderActions := TObjectList<TDockingPaneHeaderAction>.Create(True);
end;

destructor TDockingPaneContent.Destroy;
begin
  FHeaderActions.Free;
  inherited;
end;

procedure TDockingPaneContent.Activate;
begin
  DoActivate;
end;

procedure TDockingPaneContent.Deactivate;
begin
  DoDeactivate;
end;

function TDockingPaneContent.CanClose: Boolean;
begin
  Result := True;
end;

function TDockingPaneContent.AddHeaderAction(const AId, AGlyph: string;
  AOnExecute: TPaneHeaderActionEvent;
  const AHint: string): TDockingPaneHeaderAction;
begin
  if Trim(AId) = '' then
    raise EDockingError.Create('TDockingPaneContent.AddHeaderAction: empty action id');
  if FindHeaderAction(AId) <> nil then
    raise EDockingError.CreateFmt(
      'TDockingPaneContent.AddHeaderAction: duplicate action id "%s"', [AId]);

  Result := TDockingPaneHeaderAction.Create(AId, AGlyph, AHint, AOnExecute);
  FHeaderActions.Add(Result);
  DoHeaderChanged;
end;

procedure TDockingPaneContent.RemoveHeaderAction(const AId: string);
var
  I: Integer;
begin
  for I := FHeaderActions.Count - 1 downto 0 do
    if SameText(FHeaderActions[I].Id, AId) then
    begin
      FHeaderActions.Delete(I);
      DoHeaderChanged;
      Exit;
    end;
end;

procedure TDockingPaneContent.ClearHeaderActions;
begin
  if FHeaderActions.Count = 0 then Exit;
  FHeaderActions.Clear;
  DoHeaderChanged;
end;

function TDockingPaneContent.FindHeaderAction(
  const AId: string): TDockingPaneHeaderAction;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FHeaderActions.Count - 1 do
    if SameText(FHeaderActions[I].Id, AId) then
      Exit(FHeaderActions[I]);
end;

procedure TDockingPaneContent.ExecuteHeaderAction(const AId: string);
var
  Action: TDockingPaneHeaderAction;
begin
  Action := FindHeaderAction(AId);
  if (Action <> nil) and Assigned(Action.OnExecute) then
    Action.OnExecute(Self, Action.Id);
end;

procedure TDockingPaneContent.DoActivate;
begin
end;

procedure TDockingPaneContent.DoDeactivate;
begin
end;

procedure TDockingPaneContent.DoHeaderChanged;
begin
  if Assigned(FOnHeaderChanged) then
    FOnHeaderChanged(Self);
end;

procedure TDockingPaneContent.SetCaption(const AValue: string);
begin
  if FCaption = AValue then Exit;
  FCaption := AValue;
  DoHeaderChanged;
end;

procedure TDockingPaneContent.SetHeaderBgColor(AValue: TAlphaColor);
begin
  if FHeaderBgColor = AValue then Exit;
  FHeaderBgColor := AValue;
  DoHeaderChanged;
end;

procedure TDockingPaneContent.SetHeaderTextColor(AValue: TAlphaColor);
begin
  if FHeaderTextColor = AValue then Exit;
  FHeaderTextColor := AValue;
  DoHeaderChanged;
end;

procedure TDockingPaneContent.RequestSplit(ADirection: TSplitDirection);
begin
  if Assigned(FOnSplitRequest) then
    FOnSplitRequest(Self, ADirection);
end;

procedure TDockingPaneContent.RequestClose;
begin
  if Assigned(FOnCloseRequest) then
    FOnCloseRequest(Self);
end;

procedure TDockingPaneContent.RequestActivate;
begin
  if Assigned(FOnActivateRequest) then
    FOnActivateRequest(Self);
end;

end.
