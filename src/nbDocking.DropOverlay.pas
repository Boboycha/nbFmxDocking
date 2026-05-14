unit nbDocking.DropOverlay;

(*
  VS Code-style drop preview: подсвечивает половину pane, в которую
  поедет дроп. Hit-test использует четыре краевых "коридора" с долей
  FZoneSizeFraction; центр и углы → NoZone (drop отменён).
*)

interface

uses
  System.Classes, System.SysUtils, System.UITypes, System.Types,
  FMX.Types, FMX.Controls, FMX.Layouts, FMX.Objects, FMX.Graphics,
  nbDocking.Types;

type
  TDropHitResult = record
    HasZone: Boolean;
    Direction: TSplitDirection;
  end;

  TDockingDropOverlay = class(TLayout)
  private
    FPreview: TRectangle;
    FZoneSizeFraction: Single;
    FPreviewColor: TAlphaColor;
    FCurrentHighlight: TDropHitResult;
    procedure BuildPreview;
    procedure ApplyPreview(const AHit: TDropHitResult);
  public
    constructor Create(AOwner: TComponent); override;

    procedure ShowAt(const ABounds: TRectF);
    procedure HideOverlay;

    (* Имя HitTestZone — TControl.HitTest:Boolean занят. *)
    function HitTestZone(const AX, AY: Single): TDropHitResult;
    procedure Highlight(const AHit: TDropHitResult);

    property ZoneSizeFraction: Single read FZoneSizeFraction
      write FZoneSizeFraction;
    property PreviewColor: TAlphaColor read FPreviewColor write FPreviewColor;
  end;

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
  (* Мышь ловит TabHost, который и решает, когда оверлей показывать. *)
  HitTest := False;
  Visible := False;
  FZoneSizeFraction := 0.25;
  FPreviewColor := TAlphaColor($60_3D_6F_B5);
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
end;

procedure TDockingDropOverlay.ShowAt(const ABounds: TRectF);
begin
  Position.X := ABounds.Left;
  Position.Y := ABounds.Top;
  Width := ABounds.Width;
  Height := ABounds.Height;

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

  (* Краевые коридоры: в углах и в центре зона неактивна. *)
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
