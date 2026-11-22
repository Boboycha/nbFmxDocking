program MacTitleBarSmoke;

uses
  System.SysUtils, System.Classes, System.Types,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Layouts, FMX.Platform.Mac,
  Macapi.AppKit, Macapi.Foundation, Macapi.CocoaTypes,
  nbDocking.WindowTitleBar;

type
  TSmokeForm = class(TForm)
  private
    FChrome: TnbWindowTitleBar;
    FButton: TButton;
    FHeader: TLayout;
    FHeaderButton: TButton;
    FHeaderClicks: Integer;
    FTimer: TTimer;
    FClicks, FPhase: Integer;
    procedure Clicked(Sender: TObject);
    procedure HeaderClicked(Sender: TObject);
    procedure Tick(Sender: TObject);
    procedure CheckButtonGeometry;
  public
    constructor Create(AOwner: TComponent); override;
  end;

procedure Log(const S: string);
begin Writeln(ErrOutput, S); Flush(ErrOutput); end;

constructor TSmokeForm.Create(AOwner: TComponent);
var W: NSWindow;
begin
  inherited CreateNew(AOwner);
  Caption := 'Native title bar smoke'; Width := 480; Height := 300;
  Position := TFormPosition.ScreenCenter;
  FButton := TButton.Create(Self); FButton.Parent := Self;
  FButton.Position.Point := PointF(40, 60);
  FButton.Width := 300; FButton.Height := 48;
  FButton.Text := 'Client button click'; FButton.OnClick := Clicked;
  FChrome := TnbWindowTitleBar.Create(Self);
  if FindCmdLineSwitch('unified') then
  begin
    FHeader := TLayout.Create(Self); FHeader.Parent := Self;
    FHeader.Align := TAlignLayout.Top; FHeader.Height := 44;
    FChrome.TitleControl := FHeader; FChrome.MacUnifiedTitleBar := True;
    FHeader.Padding.Left := FChrome.MacSystemButtonsInset;
    FHeaderButton := TButton.Create(Self); FHeaderButton.Parent := FHeader;
    FHeaderButton.Align := TAlignLayout.Left; FHeaderButton.Width := 200;
    FHeaderButton.Margins.Top := 4; FHeaderButton.Margins.Bottom := 4;
    FHeaderButton.Text := 'Document tab'; FHeaderButton.OnClick := HeaderClicked;
  end;
  FChrome.Apply;
  if FindCmdLineSwitch('legacy-overlay') then
  begin
    W := WindowHandleToPlatform(Handle).Wnd;
    W.setStyleMask(W.styleMask or (1 shl 15));
    W.setTitleVisibility(NSWindowTitleHidden);
    W.setTitlebarAppearsTransparent(True);
    W.setMovableByWindowBackground(True);
  end;
  FTimer := TTimer.Create(Self); FTimer.Interval := 700; FTimer.OnTimer := Tick;
end;

procedure TSmokeForm.Clicked(Sender: TObject);
begin Inc(FClicks); Log('CLICK'); end;

procedure TSmokeForm.HeaderClicked(Sender: TObject);
begin Inc(FHeaderClicks); Log('HEADER CLICK'); end;

procedure TSmokeForm.CheckButtonGeometry;
var
  W: NSWindow;
  View, Root: NSView;
  Button: NSButton;
  Content, Bounds, HeaderBounds: NSRect;
  Kind: Integer;
begin
  W := WindowHandleToPlatform(Handle).Wnd;
  View := TNSView.Wrap(W.contentView);
  Root := TNSView.Wrap(View.superview);
  Content := Root.convertRect(View.bounds, View);
  if FHeader <> nil then
    HeaderBounds := Root.convertRect(NSMakeRect(FHeader.AbsoluteRect.Left,
      View.bounds.size.height - FHeader.AbsoluteRect.Bottom,
      FHeader.AbsoluteRect.Width, FHeader.AbsoluteRect.Height), View);
  for Kind := NSWindowCloseButton to NSWindowZoomButton do
  begin
    Button := W.standardWindowButton(Kind);
    if (Button = nil) or Button.isHidden then
      raise Exception.Create('Native window button missing/hidden');
    Bounds := Root.convertRect(Button.bounds, Button);
    Log(Format('geometry mask=%d frameH=%.1f contentY=%.1f contentH=%.1f button=%d y=%.1f h=%.1f',
      [UInt64(W.styleMask),W.frame.size.height,Content.origin.y,Content.size.height,Kind,Bounds.origin.y,Bounds.size.height]));
    if FHeader <> nil then
    begin
      if (Abs((Bounds.origin.y + Bounds.size.height / 2) -
        (HeaderBounds.origin.y + HeaderBounds.size.height / 2)) > 0.5) or
        (Bounds.origin.x + Bounds.size.width > FChrome.MacSystemButtonsInset) then
        raise Exception.Create('Native buttons not centered in reserved header area');
    end
    else if (Bounds.origin.x < Content.origin.x + Content.size.width - 0.5) and
      (Bounds.origin.x + Bounds.size.width > Content.origin.x + 0.5) and
      (Bounds.origin.y < Content.origin.y + Content.size.height - 0.5) and
      (Bounds.origin.y + Bounds.size.height > Content.origin.y + 0.5) then
      raise Exception.Create('Native window button overlaps FMX client content');
  end;
  if FHeader <> nil then Log('Native buttons in reserved unified header PASS')
  else Log('Native buttons outside FMX content PASS');
  if W.isMovableByWindowBackground then
    raise Exception.Create('Background dragging unexpectedly enabled');
  Log('BackgroundDrag=' + BoolToStr(W.isMovableByWindowBackground, True));
end;

procedure TSmokeForm.Tick(Sender: TObject);
var W: NSWindow; B: NSButton; Original, Probe, Actual: NSRect; Kind: Integer;
  procedure PostClick(X, Y: Single);
  var W: NSWindow; P: NSPoint; E: NSEvent; Kind: Integer;
  begin
    Activate;
    BringToFront;
    W := WindowHandleToPlatform(Handle).Wnd;
    P := NSMakePoint(X, TNSView.Wrap(W.contentView).bounds.size.height - Y);
    for Kind := NSLeftMouseDown to NSLeftMouseUp do
    begin
      E := TNSEvent.Wrap(TNSEvent.OCClass.mouseEventWithType(Kind, P, 0, 0,
        W.windowNumber, nil, Kind, 1, 1));
      TNSApplication.Wrap(TNSApplication.OCClass.sharedApplication).postEvent(E, False);
    end;
  end;
begin
  FTimer.Enabled := False;
  try
    if FPhase = 6 then
    begin
      W := WindowHandleToPlatform(Handle).Wnd;
      if W.styleMask and NSFullScreenWindowMask = 0 then
        raise Exception.Create('Native fullscreen entry failed');
      for Kind := NSWindowCloseButton to NSWindowZoomButton do
      begin
        B := W.standardWindowButton(Kind);
        Original := B.frame;
        Probe := Original; Probe.origin.x := Probe.origin.x + 7;
        B.setFrame(Probe);
        try
          FChrome.Apply;
          Actual := B.frame;
          if (Abs(Actual.origin.x - Probe.origin.x) > 0.1) or
            (Abs(Actual.origin.y - Probe.origin.y) > 0.1) then
            raise Exception.Create('Component moved an AppKit-owned fullscreen button');
        finally
          B.setFrame(Original);
        end;
      end;
      Log('Fullscreen native button ownership PASS');
      W.toggleFullScreen(nil);
      FPhase := 7; FTimer.Enabled := True; Exit;
    end;
    if FPhase = 7 then
    begin
      W := WindowHandleToPlatform(Handle).Wnd;
      if W.styleMask and NSFullScreenWindowMask <> 0 then
        raise Exception.Create('Native fullscreen exit failed');
      CheckButtonGeometry;
      Log('Fullscreen exit and restored native button geometry PASS');
      if not FindCmdLineSwitch('manual') then Halt(0);
      Exit;
    end;
    CheckButtonGeometry;
    if FPhase = 0 then
    begin
      FPhase := 1; PostClick(120, 84); FTimer.Enabled := True; Exit;
    end;
    if FPhase = 1 then
    begin
      if FClicks <> 1 then raise Exception.Create('Client button click was lost');
      if FHeader <> nil then
      begin
        FPhase := 2; PostClick(FChrome.MacSystemButtonsInset + 70, 22);
        FTimer.Enabled := True; Exit;
      end;
    end;
    if FPhase <= 2 then
    begin
      if (FHeader <> nil) and (FHeaderClicks <> 1) then
        raise Exception.Create('Header child button click was consumed by drag');
      Width := 680; Height := 420;
      FPhase := 3; FTimer.Enabled := True; Exit;
    end;
    if (FHeader <> nil) and (FPhase = 3) then
    begin
      FPhase := 4;
      PostClick(Width - 60, 22); // Native drag starts only on this empty header area.
      FTimer.Enabled := True; Exit;
    end;
    if (FHeader <> nil) and (FPhase = 4) then
    begin
      if FHeader.Pressed then raise Exception.Create('Header stayed pressed after native drag');
      FPhase := 5; PostClick(120, 84); FTimer.Enabled := True; Exit;
    end;
    if (FHeader <> nil) and (FPhase = 5) and (FClicks <> 2) then
      raise Exception.Create('Client click failed after native header drag');
    if FindCmdLineSwitch('fullscreen') then
    begin
      if FHeader = nil then raise Exception.Create('Use -unified with -fullscreen');
      ShowFullScreenIcon := True;
      WindowHandleToPlatform(Handle).Wnd.toggleFullScreen(nil);
      FPhase := 6; FTimer.Interval := 2500; FTimer.Enabled := True; Exit;
    end;
    Log('PASS: native button geometry, resize, client/header child clicks and drag release');
    if not FindCmdLineSwitch('manual') then Halt(0);
  except
    on E: Exception do begin Log('FAIL: ' + E.Message); Halt(1); end;
  end;
end;
var Form: TSmokeForm;
begin
  Application.Initialize;
  Application.CreateForm(TSmokeForm, Form);
  Application.Run;
end.