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

    procedure Activate;
    procedure Deactivate;

    (* Default = True; override чтобы заблокировать закрытие (например,
       терминал с незавершённой командой просит подтверждение). *)
    function CanClose: Boolean; virtual;

    (* Подписывается PaneHost — потомки сами трогать события не должны. *)
    property OnSplitRequest: TPaneSplitRequestEvent
      read FOnSplitRequest write FOnSplitRequest;
    property OnCloseRequest: TPaneCloseRequestEvent
      read FOnCloseRequest write FOnCloseRequest;
    property OnActivateRequest: TPaneActivateRequestEvent
      read FOnActivateRequest write FOnActivateRequest;
    property OnHeaderChanged: TPaneHeaderChangedEvent
      read FOnHeaderChanged write FOnHeaderChanged;
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

{ TDockingPaneContent }

constructor TDockingPaneContent.Create(AOwner: TComponent);
begin
  inherited;
  Align := TAlignLayout.Client;
  FHeaderBgColor := TAlphaColor($FF2A2A2A);
  FHeaderTextColor := TAlphaColor($FFE0E0E0);
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
