unit nbDocking.Demo;

(*
  DEBUG-заглушка для проверки движка докинга без реального контента.
*)

interface

uses
  System.Classes, System.SysUtils, System.UITypes,
  FMX.Types, FMX.Controls, FMX.Layouts, FMX.Objects, FMX.StdCtrls,
  FMX.Graphics,
  nbDocking.Types;

type
  TnbDockingDemoPane = class(TnbDockingPaneContent)
  private
    FNumber: Integer;
    FFillColor: TAlphaColor;
    FBg: TRectangle;
    FNumberLabel: TLabel;
    FBtnSplitLeft: TSpeedButton;
    FBtnSplitUp: TSpeedButton;
    FBtnSplitDown: TSpeedButton;
    FBtnSplitRight: TSpeedButton;
    FBtnClose: TSpeedButton;
    procedure BuildUI;
    procedure HandleBgMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure HandleSplitLeftClick(Sender: TObject);
    procedure HandleSplitUpClick(Sender: TObject);
    procedure HandleSplitDownClick(Sender: TObject);
    procedure HandleSplitRightClick(Sender: TObject);
    procedure HandleCloseClick(Sender: TObject);
    procedure UpdateLabel;
    procedure SetNumber(AValue: Integer);
  public
    constructor Create(AOwner: TComponent); override;

    class function CreateNext(AOwner: TComponent): TnbDockingDemoPane;

    property Number: Integer read FNumber write SetNumber;
    property FillColor: TAlphaColor read FFillColor write FFillColor;
  end;

implementation

uses
  System.UIConsts;

var
  GNextNumber: Integer = 0;

const
  PALETTE: array[0..7] of TAlphaColor = (
    TAlphaColor($FF89B4FA), TAlphaColor($FFA6E3A1),
    TAlphaColor($FFF9E2AF), TAlphaColor($FFFAB387),
    TAlphaColor($FFCBA6F7), TAlphaColor($FFF38BA8),
    TAlphaColor($FF94E2D5), TAlphaColor($FFEBA0AC)
  );

{ TnbDockingDemoPane }

constructor TnbDockingDemoPane.Create(AOwner: TComponent);
begin
  inherited;
  Inc(GNextNumber);
  FNumber := GNextNumber;
  FFillColor := PALETTE[(FNumber - 1) mod Length(PALETTE)];
  Caption := 'Pane #' + IntToStr(FNumber);
  BuildUI;
end;

class function TnbDockingDemoPane.CreateNext(AOwner: TComponent): TnbDockingDemoPane;
begin
  Result := TnbDockingDemoPane.Create(AOwner);
end;

procedure TnbDockingDemoPane.SetNumber(AValue: Integer);
begin
  FNumber := AValue;
  Caption := 'Pane #' + IntToStr(FNumber);
  if FFillColor = 0 then
    FFillColor := PALETTE[(FNumber - 1) mod Length(PALETTE)];
  if FBg <> nil then
    FBg.Fill.Color := FFillColor;
  UpdateLabel;
end;

procedure TnbDockingDemoPane.BuildUI;
var
  BtnRow: TLayout;
  CenterBox: TLayout;
begin
  FBg := TRectangle.Create(Self);
  FBg.Parent := Self;
  FBg.Align := TAlignLayout.Client;
  FBg.Fill.Kind := TBrushKind.Solid;
  FBg.Fill.Color := FFillColor;
  FBg.Stroke.Kind := TBrushKind.None;
  FBg.HitTest := True;
  FBg.OnMouseDown := HandleBgMouseDown;

  CenterBox := TLayout.Create(Self);
  CenterBox.Parent := FBg;
  CenterBox.Align := TAlignLayout.Center;
  CenterBox.Width := 360;
  CenterBox.Height := 160;
  CenterBox.HitTest := False;

  FNumberLabel := TLabel.Create(Self);
  FNumberLabel.Parent := CenterBox;
  FNumberLabel.Align := TAlignLayout.Top;
  FNumberLabel.Height := 60;
  FNumberLabel.TextSettings.HorzAlign := TTextAlign.Center;
  FNumberLabel.TextSettings.VertAlign := TTextAlign.Center;
  FNumberLabel.TextSettings.Font.Size := 28;
  FNumberLabel.TextSettings.FontColor := TAlphaColor($FF202020);
  FNumberLabel.StyledSettings := [];
  UpdateLabel;

  BtnRow := TLayout.Create(Self);
  BtnRow.Parent := CenterBox;
  BtnRow.Align := TAlignLayout.Top;
  BtnRow.Height := 40;
  BtnRow.Margins.Top := 12;
  BtnRow.HitTest := False;

  FBtnSplitLeft := TSpeedButton.Create(Self);
  FBtnSplitLeft.Parent := BtnRow;
  FBtnSplitLeft.Align := TAlignLayout.Left;
  FBtnSplitLeft.Width := 60;
  FBtnSplitLeft.Margins.Right := 6;
  FBtnSplitLeft.Text := '< Split';
  FBtnSplitLeft.Hint := 'Split to the left';
  FBtnSplitLeft.OnClick := HandleSplitLeftClick;

  FBtnSplitUp := TSpeedButton.Create(Self);
  FBtnSplitUp.Parent := BtnRow;
  FBtnSplitUp.Align := TAlignLayout.Left;
  FBtnSplitUp.Width := 60;
  FBtnSplitUp.Margins.Right := 6;
  FBtnSplitUp.Text := '^ Split';
  FBtnSplitUp.Hint := 'Split above';
  FBtnSplitUp.OnClick := HandleSplitUpClick;

  FBtnSplitDown := TSpeedButton.Create(Self);
  FBtnSplitDown.Parent := BtnRow;
  FBtnSplitDown.Align := TAlignLayout.Left;
  FBtnSplitDown.Width := 60;
  FBtnSplitDown.Margins.Right := 6;
  FBtnSplitDown.Text := 'v Split';
  FBtnSplitDown.Hint := 'Split below';
  FBtnSplitDown.OnClick := HandleSplitDownClick;

  FBtnSplitRight := TSpeedButton.Create(Self);
  FBtnSplitRight.Parent := BtnRow;
  FBtnSplitRight.Align := TAlignLayout.Left;
  FBtnSplitRight.Width := 60;
  FBtnSplitRight.Margins.Right := 12;
  FBtnSplitRight.Text := 'Split >';
  FBtnSplitRight.Hint := 'Split to the right';
  FBtnSplitRight.OnClick := HandleSplitRightClick;

  FBtnClose := TSpeedButton.Create(Self);
  FBtnClose.Parent := BtnRow;
  FBtnClose.Align := TAlignLayout.Left;
  FBtnClose.Width := 60;
  FBtnClose.Text := 'x Close';
  FBtnClose.Hint := 'Close this pane';
  FBtnClose.OnClick := HandleCloseClick;
end;

procedure TnbDockingDemoPane.UpdateLabel;
begin
  if FNumberLabel <> nil then
    FNumberLabel.Text := 'Pane #' + IntToStr(FNumber);
end;

procedure TnbDockingDemoPane.HandleBgMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  RequestActivate;
end;

procedure TnbDockingDemoPane.HandleSplitLeftClick(Sender: TObject);
begin
  RequestSplit(sdLeft);
end;

procedure TnbDockingDemoPane.HandleSplitUpClick(Sender: TObject);
begin
  RequestSplit(sdAbove);
end;

procedure TnbDockingDemoPane.HandleSplitDownClick(Sender: TObject);
begin
  RequestSplit(sdBelow);
end;

procedure TnbDockingDemoPane.HandleSplitRightClick(Sender: TObject);
begin
  RequestSplit(sdRight);
end;

procedure TnbDockingDemoPane.HandleCloseClick(Sender: TObject);
begin
  RequestClose;
end;

end.
