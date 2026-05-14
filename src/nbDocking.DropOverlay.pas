unit nbDocking.DropOverlay;

(*
  TDockingDropOverlay — визуальная подсказка "куда полетит drop"
  для системы drag-drop табов в split-зоны панелей.

  Что показывает:
    Полупрозрачный синий прямоугольник, занимающий ровно ту половину
    активного pane, в которую попадёт новый pane после drop.
    Это VS Code-style preview — юзер сразу видит результат.

  Определение направления:
    Hit-test разбивает площадь pane на 4 краевые зоны (L/R/T/B)
    как и раньше. Центр и углы — "нет зоны" (drop отменён).
    Изменилось только отображение: вместо 4 видимых полос —
    одна большая полупрозрачная половина.

  Использование (для TabHost):
    Overlay := TDockingDropOverlay.Create(SomeOwner);
    Overlay.Parent := SomePaneHost;
    ...
    Overlay.ShowAt(PaneHost.ActiveLeafBounds);
    Hit := Overlay.HitTestZone(MouseX, MouseY);
    Overlay.Highlight(Hit);    // если HasZone=False, preview спрячется
    ...
    Overlay.HideOverlay;
*)

interface

uses
  System.Classes, System.SysUtils, System.UITypes, System.Types,
  FMX.Types, FMX.Controls, FMX.Layouts, FMX.Objects, FMX.Graphics,
  nbDocking.Types;

type
  (* Результат hit-test *)
  TDropHitResult = record
    HasZone: Boolean;
    Direction: TSplitDirection;
  end;

  TDockingDropOverlay = class(TLayout)
  private
    FPreview: TRectangle;             (* полупрозрачная половина-подсказка *)
    FZoneSizeFraction: Single;        (* доля краевой зоны для hit-test *)
    FPreviewColor: TAlphaColor;
    FCurrentHighlight: TDropHitResult;
    procedure BuildPreview;
    procedure ApplyPreview(const AHit: TDropHitResult);
  public
    constructor Create(AOwner: TComponent); override;

    (* Показать оверлей на заданном прямоугольнике (в координатах Parent).
       Прямоугольник обычно — TDockingPaneHost.ActiveLeafBounds. *)
    procedure ShowAt(const ABounds: TRectF);
    procedure HideOverlay;

    (* Hit-test. Координаты в системе Parent оверлея.
       Имя HitTestZone, не HitTest — иначе конфликт с TControl.HitTest:Boolean. *)
    function HitTestZone(const AX, AY: Single): TDropHitResult;

    (* Подсветить preview-половину. Если HasZone=False — спрятать preview. *)
    procedure Highlight(const AHit: TDropHitResult);

    property ZoneSizeFraction: Single read FZoneSizeFraction
      write FZoneSizeFraction;
    property PreviewColor: TAlphaColor read FPreviewColor write FPreviewColor;
  end;

(* Утилиты *)
function NoZone: TDropHitResult; inline;
function Zone(ADir: TSplitDirection): TDropHitResult; inline;

implementation

function NoZone: TDropHitResult;
begin
  Result.HasZone := False;
  Result.Direction := sdLeft;
end;

function Zone(ADir: TSplitDirection): TDropHitResult;
begin
  Result.HasZone := True;
  Result.Direction := ADir;
end;

{ TDockingDropOverlay }

constructor TDockingDropOverlay.Create(AOwner: TComponent);
begin
  inherited;
  HitTest := False;        (* оверлей мышь не ловит, ловит TabHost *)
  Visible := False;
  FZoneSizeFraction := 0.25;
  FPreviewColor := TAlphaColor($60_3D_6F_B5);   (* полупрозрачный синий *)
  FCurrentHighlight := NoZone;
  BuildPreview;
end;

procedure TDockingDropOverlay.BuildPreview;
begin
  FPreview := TRectangle.Create(Self);
  FPreview.Parent := Self;
  FPreview.Stroke.Kind := TBrushKind.None;
  FPreview.Fill.Color := FPreviewColor;
  FPreview.HitTest := False;
  FPreview.Visible := False;
  (* Position/Size выставляются в ApplyPreview под текущее направление *)
end;

procedure TDockingDropOverlay.ShowAt(const ABounds: TRectF);
begin
  Position.X := ABounds.Left;
  Position.Y := ABounds.Top;
  Width := ABounds.Width;
  Height := ABounds.Height;

  (* preview скрыт до первого Highlight *)
  FPreview.Visible := False;
  FCurrentHighlight := NoZone;

  BringToFront;
  Visible := True;
end;

procedure TDockingDropOverlay.HideOverlay;
begin
  FPreview.Visible := False;
  FCurrentHighlight := NoZone;
  Visible := False;
end;

function TDockingDropOverlay.HitTestZone(
  const AX, AY: Single): TDropHitResult;
var
  LocalX, LocalY, W, H, ZoneW, ZoneH: Single;
begin
  Result := NoZone;
  if not Visible then Exit;

  LocalX := AX - Position.X;
  LocalY := AY - Position.Y;
  W := Width;
  H := Height;
  if (LocalX < 0) or (LocalY < 0) or (LocalX > W) or (LocalY > H) then Exit;

  ZoneW := W * FZoneSizeFraction;
  ZoneH := H * FZoneSizeFraction;

  (* Краевые "коридоры" — без углов и без центра.
     Зона активна, только если курсор в нужной полосе И НЕ в углу. *)
  if (LocalX < ZoneW) and (LocalY >= ZoneH) and (LocalY <= H - ZoneH) then
    Exit(Zone(sdLeft));
  if (LocalX > W - ZoneW) and (LocalY >= ZoneH) and (LocalY <= H - ZoneH) then
    Exit(Zone(sdRight));
  if (LocalY < ZoneH) and (LocalX >= ZoneW) and (LocalX <= W - ZoneW) then
    Exit(Zone(sdAbove));
  if (LocalY > H - ZoneH) and (LocalX >= ZoneW) and (LocalX <= W - ZoneW) then
    Exit(Zone(sdBelow));

  Result := NoZone;
end;

procedure TDockingDropOverlay.Highlight(const AHit: TDropHitResult);
begin
  FCurrentHighlight := AHit;
  ApplyPreview(AHit);
end;

procedure TDockingDropOverlay.ApplyPreview(const AHit: TDropHitResult);
var
  HalfW, HalfH: Single;
begin
  if not AHit.HasZone then
  begin
    FPreview.Visible := False;
    Exit;
  end;

  HalfW := Width / 2;
  HalfH := Height / 2;

  (* Preview занимает ту половину overlay-а, куда поедет новый pane *)
  case AHit.Direction of
    sdLeft:
      begin
        FPreview.Position.X := 0;
        FPreview.Position.Y := 0;
        FPreview.Width := HalfW;
        FPreview.Height := Height;
      end;
    sdRight:
      begin
        FPreview.Position.X := HalfW;
        FPreview.Position.Y := 0;
        FPreview.Width := HalfW;
        FPreview.Height := Height;
      end;
    sdAbove:
      begin
        FPreview.Position.X := 0;
        FPreview.Position.Y := 0;
        FPreview.Width := Width;
        FPreview.Height := HalfH;
      end;
    sdBelow:
      begin
        FPreview.Position.X := 0;
        FPreview.Position.Y := HalfH;
        FPreview.Width := Width;
        FPreview.Height := HalfH;
      end;
  end;

  FPreview.Fill.Color := FPreviewColor;
  FPreview.Visible := True;
  FPreview.BringToFront;
end;

end.
