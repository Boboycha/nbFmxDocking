unit nbDocking.Types;

(*
  Базовые типы системы докинга nbFMXDocking.

  Здесь живут енумы, базовый класс содержимого pane и события.
  Никакой UI-логики — только контракты, чтобы их можно было
  тащить в любые юниты без зависимости от визуального слоя.

  Класс TDockingPaneContent — абстрактная "вкладка/панель",
  которую можно положить в pane. Терминал, SFTP, сниппеты, логи —
  все будут наследниками (в составе nbDevOpsCockpit или иного
  потребляющего пакета).

  Декаплинг: контент общается с PaneHost ТОЛЬКО через события
    OnSplitRequest / OnCloseRequest / OnActivateRequest.
    Контент не знает, в каком PaneHost он живёт.
    PaneHost подписывается при добавлении контента.
*)

interface

uses
  System.Classes, System.SysUtils, System.UITypes,
  FMX.Types, FMX.Layouts, FMX.Controls;

type
  (* Направление split-операции относительно текущего pane.
     "Слева/справа" => горизонтальный split (дети в строку).
     "Сверху/снизу" => вертикальный split (дети в столбец). *)
  TSplitDirection = (sdLeft, sdRight, sdAbove, sdBelow);

  (* Ориентация split-узла в дереве *)
  TPaneOrientation = (
    poHorizontal,   (* дети расположены в строку (split по горизонтали) *)
    poVertical      (* дети расположены в столбец (split по вертикали) *)
  );

  TDockingPaneContent = class;

  (* События запроса split/close/activate, которые контент эмитит наверх *)
  TPaneSplitRequestEvent = procedure(Sender: TDockingPaneContent;
    ADirection: TSplitDirection) of object;
  TPaneCloseRequestEvent = procedure(Sender: TDockingPaneContent) of object;
  TPaneActivateRequestEvent = procedure(Sender: TDockingPaneContent) of object;

  (* Изменился стиль заголовка контента (цвета, caption) — PaneHost
     подпишется и обновит свой title bar для этого pane. *)
  TPaneHeaderChangedEvent = procedure(Sender: TDockingPaneContent) of object;

  (* Базовый класс для любого содержимого pane.
     Терминал, SFTP, сниппеты, логи — все будут наследниками.
     Для тестов есть TDockingDemoPane в nbDocking.Demo. *)
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

    (* Вызывается host-ом при изменении активного pane *)
    procedure Activate;
    procedure Deactivate;

    (* Можно ли сейчас закрыть pane? Например, терминал может спросить
       подтверждение, если есть незавершённая команда. По умолчанию — да. *)
    function CanClose: Boolean; virtual;

    (* События — подписывается PaneHost. Потомки контента сами их не трогают. *)
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

    (* Цвета title bar, который PaneHost рисует над контентом.
       Termius-style: title bar в тон с фоном content-а.
       Терминал-наследник возьмёт эти значения из своей Terminal.Theme.
       DemoPane выставит под цвет своего fill. *)
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
  FHeaderBgColor := TAlphaColor($FF2A2A2A);     (* тёмный по умолчанию *)
  FHeaderTextColor := TAlphaColor($FFE0E0E0);   (* светлый текст *)
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
  (* потомки могут переопределить — поставить фокус, обновить статусбар и т.д. *)
end;

procedure TDockingPaneContent.DoDeactivate;
begin
  (* потомки могут переопределить *)
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
