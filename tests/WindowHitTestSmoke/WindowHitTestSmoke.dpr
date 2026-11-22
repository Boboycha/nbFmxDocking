program WindowHitTestSmoke;

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Types,
  Winapi.Windows, Winapi.Messages,
  FMX.Forms, FMX.Platform.Win,
  nbDocking.WindowTitleBar;

const
  Origins: array[0..3] of TPoint = (
    (X: 100; Y: 100), (X: -1200; Y: 100),
    (X: 100; Y: -800), (X: -1200; Y: -800));
  DPIs: array[0..2] of Integer = (96, 144, 192);
var
  Form: TForm;
  Chrome: TnbWindowTitleBar;
  Window: HWND;
  Origin, P: TPoint;
  Bounds, Suggested: TRect;
  PackedPoint: LPARAM;
  Actual: LRESULT;
  Failures, DPI: Integer;
begin
  try
    Application.Initialize;
    Form := TForm.CreateNew(nil);
    try
      Form.SetBounds(100, 100, 800, 480);
      Chrome := TnbWindowTitleBar.Create(Form);
      Chrome.Apply;
      Window := FmxHandleToHWND(Form.Handle);
      Failures := 0;
      for DPI in DPIs do
      for Origin in Origins do
      begin
        if not SetWindowPos(Window, 0, Origin.X, Origin.Y, 800, 480,
          SWP_NOACTIVATE or SWP_NOZORDER) then
          RaiseLastOSError;
        // Exercise FMX's real DPI-change handler without requiring physical monitors.
        GetWindowRect(Window, Suggested);
        SendMessage(Window, WM_DPICHANGED, WPARAM(MakeLong(DPI, DPI)),
          LPARAM(@Suggested));
        if Abs(Form.Handle.Scale - DPI / 96) > 0.01 then
          raise Exception.Create('FMX did not accept the test DPI change');
        GetClientRect(Window, Bounds);
        P := Point(Bounds.Width div 2, Bounds.Height div 2);
        if not Winapi.Windows.ClientToScreen(Window, P) then
          RaiseLastOSError;
        PackedPoint := LPARAM(LongWord(P.X and $FFFF) or
          (LongWord(P.Y and $FFFF) shl 16));
        Actual := SendMessage(Window, WM_NCHITTEST, 0, PackedPoint);
        Writeln(Format('body at screen (%d,%d), scale %.2f: hit=%d, expected=%d',
          [P.X, P.Y, Form.Handle.Scale, Actual, HTCLIENT]));
        if Actual <> HTCLIENT then
          Inc(Failures);
        P := Point(Bounds.Width div 2, Bounds.Height - 1);
        if not Winapi.Windows.ClientToScreen(Window, P) then
          RaiseLastOSError;
        PackedPoint := LPARAM(LongWord(P.X and $FFFF) or
          (LongWord(P.Y and $FFFF) shl 16));
        Actual := SendMessage(Window, WM_NCHITTEST, 0, PackedPoint);
        if Actual <> HTBOTTOM then
          raise Exception.CreateFmt('Bottom resize returned %d instead of HTBOTTOM', [Actual]);
      end;
      if Failures <> 0 then
        raise Exception.CreateFmt('%d client-area hit tests failed', [Failures]);
      Writeln('PASS: client/resize hit tests in four quadrants at 100%, 150%, 200% DPI');
    finally
      Form.Free;
    end;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
