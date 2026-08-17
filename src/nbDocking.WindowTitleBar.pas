unit nbDocking.WindowTitleBar;

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Platform, FMX.StdCtrls, FMX.Objects,
  FMX.Graphics,
  nbDocking.PaneHost
{$IFDEF MSWINDOWS}, Winapi.Windows, Winapi.Messages, Winapi.Dwmapi {$ENDIF};

type
  /// <summary>
  /// Компонент для реализации кастомного заголовка окна с поддержкой
  /// нативных функций ОС (Snap Layouts, DWM Shadows, High DPI).
  /// </summary>
  TnbWindowTitleBar = class(TComponent)
  private
    FForm: TCommonCustomForm;
    FTitleControl: TControl; // Панель, выполняющая роль заголовка (Drag)
    FDockingHost: TnbDockingPaneHost;
    FSystemButtons: TControl; // Контейнер с кнопками (Close, Max, Min)
    FMaxButton: TControl; // Ссылка на кнопку развертывания (для Snap Layouts)
    FCloseButton: TControl;
    FMinButton: TControl;
    FEnabled: Boolean;

{$IFDEF MSWINDOWS}
    FSubclassInstalled: Boolean;
    FDebugMode: Boolean;
    FOldWndProc: NativeUInt;
    FWindowHandle: HWND;
    function WindowProc(HWND: HWND; uMsg: UINT; wParam: wParam; lParam: lParam)
      : LRESULT; stdcall;
    procedure InstallSubclass;
    procedure RemoveSubclass;
    procedure UpdateDwmMargins;
    function ScreenToLogical(const AScreenPoint: TPoint): TPointF;
    function HitTest(const AScreenPoint: TPoint): LRESULT;
    function PtInControl(const AControl: TControl;
      const PFormLogical: TPointF): Boolean;
    function HasInteractiveControlAt(const P: TPointF;
      AParent: TControl): Boolean;
    procedure DebugLog(const Msg: string);
    function IsValidWindow(HWND: HWND): Boolean;
{$ENDIF}
{$IFDEF MACOS}
    procedure SetupMacWindow;
{$ENDIF}
{$IFDEF LINUX}
    FLinuxHandlersInstalled: Boolean;
    FLinuxDragging: Boolean;
    FLinuxDragMouseOrigin: TPointF;
    FLinuxDragFormOrigin: TPointF;
    FLinuxOriginalBorderStyle: TFmxFormBorderStyle;
    FLinuxMaximized: Boolean;
    FLinuxRestoreBounds: TRectF;
    FLinuxResizeActive: Boolean;
    FLinuxResizeEdge: Integer;
    FLinuxResizeMouseOrigin: TPointF;
    FLinuxResizeFormOrigin: TRectF;
    FLinuxResizeHandles: array[0..7] of TRectangle;
    FPreviousTitleMouseDown: TMouseEvent;
    FPreviousTitleMouseMove: TMouseMoveEvent;
    FPreviousTitleMouseUp: TMouseEvent;
    FPreviousTitleDblClick: TNotifyEvent;
    FPreviousMinClick: TNotifyEvent;
    FPreviousMaxClick: TNotifyEvent;
    FPreviousCloseClick: TNotifyEvent;
    procedure SetupLinuxWindow;
    procedure RemoveLinuxHandlers;
    procedure CreateLinuxResizeHandles;
    procedure FreeLinuxResizeHandles;
    procedure LinuxResizeMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure LinuxResizeMouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Single);
    procedure LinuxResizeMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    function LinuxMouseScreenPoint: TPointF;
    procedure LinuxTitleMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure LinuxTitleMouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Single);
    procedure LinuxTitleMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure LinuxTitleDblClick(Sender: TObject);
    procedure LinuxMinClick(Sender: TObject);
    procedure LinuxMaxClick(Sender: TObject);
    procedure LinuxCloseClick(Sender: TObject);
{$ENDIF}
    procedure SetEnabled(const Value: Boolean);

    procedure SetTitleControl(const Value: TControl);
    procedure SetDockingHost(const Value: TnbDockingPaneHost);
    function EffectiveTitleControl: TControl;
    procedure SetSystemButtons(const Value: TControl);
    procedure SetMaxButton(const Value: TControl);
    procedure SetMinButton(const Value: TControl);
    procedure SetCloseButton(const Value: TControl);

  protected
    procedure Loaded; override;
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); override;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    /// <summary>
    /// Применяет настройки к окну-владельцу. Вызывать после создания всех контролов.
    /// </summary>
    procedure Apply;

{$IFDEF MSWINDOWS}
    property DebugMode: Boolean read FDebugMode write FDebugMode;
{$ENDIF}
  published
    property Enabled: Boolean read FEnabled write SetEnabled default True;
    property TitleControl: TControl read FTitleControl write SetTitleControl;
    property DockingHost: TnbDockingPaneHost read FDockingHost write SetDockingHost;
    property SystemButtons: TControl read FSystemButtons write SetSystemButtons;
    property MaxButton: TControl read FMaxButton write SetMaxButton;
    property MinButton: TControl read FMinButton write SetMinButton;
    property CloseButton: TControl read FCloseButton write SetCloseButton;
  end;

procedure Register;

implementation

{$IFDEF MSWINDOWS}

uses
  Winapi.ShellAPI, Winapi.CommCtrl, FMX.Platform.Win, Winapi.UxTheme;

// Определяем свою структуру монитора
type
  PMonitorInfo = ^TMonitorInfo;

  TMonitorInfo = record
    cbSize: DWORD;
    rcMonitor: TRect;
    rcWork: TRect;
    dwFlags: DWORD;
  end;

  // Импортируем необходимые функции Windows API
function MonitorFromWindow(HWND: HWND; dwFlags: DWORD): HMONITOR; stdcall;
  external 'user32.dll';

function GetMonitorInfoW(HMONITOR: HMONITOR; var lpmi: TMonitorInfo): BOOL;
  stdcall; external 'user32.dll';

const
  kResizeBorderThickness = 8;
  MONITOR_DEFAULTTONEAREST = 2;
{$ENDIF}
{$IFDEF MACOS}

uses
  Macapi.AppKit, Macapi.Foundation, Macapi.CocoaTypes, Macapi.ObjectiveC,
  FMX.Platform.Mac, FMX.Helpers.Mac;
{$ENDIF}
{ TnbWindowTitleBar }

constructor TnbWindowTitleBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FEnabled := True;
{$IFDEF MSWINDOWS}
  FDebugMode := False;
  FOldWndProc := 0;
  FWindowHandle := 0;
{$ENDIF}
{$IFDEF LINUX}
  FLinuxOriginalBorderStyle := TFmxFormBorderStyle.Sizeable;
{$ENDIF}
  if AOwner is TCommonCustomForm then
    FForm := TCommonCustomForm(AOwner);
end;

destructor TnbWindowTitleBar.Destroy;
begin
  if not(csDesigning in ComponentState) then
  begin
{$IFDEF MSWINDOWS}
    RemoveSubclass;
{$ENDIF}
  end;
  inherited;
end;

procedure TnbWindowTitleBar.Loaded;
begin
  inherited;
  if (FForm <> nil) and (not(csDesigning in ComponentState)) and FEnabled then
    Apply;
end;

procedure TnbWindowTitleBar.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited;
  if Operation = opRemove then
  begin
    if AComponent = FTitleControl then
      FTitleControl := nil;
    if AComponent = FDockingHost then
      FDockingHost := nil;
    if AComponent = FMaxButton then
      FMaxButton := nil;
    if AComponent = FMinButton then
      FMinButton := nil;
    if AComponent = FCloseButton then
      FCloseButton := nil;
    if AComponent = FSystemButtons then
      FSystemButtons := nil;
  end;
end;

procedure TnbWindowTitleBar.Apply;
{$IFDEF MSWINDOWS}
var
  h: HWND;
{$ENDIF}
begin
  if (FForm = nil) or (csDesigning in ComponentState) then
    Exit;

  if FSystemButtons <> nil then
  begin
{$IF Defined(MSWINDOWS) or Defined(LINUX)}
    FSystemButtons.Visible := True;
{$ELSE}
    FSystemButtons.Visible := False;
{$ENDIF}
  end;

{$IFDEF MSWINDOWS}
  DebugLog('Apply called');

  InstallSubclass;
  UpdateDwmMargins;

  h := FmxHandleToHWND(FForm.Handle);
  if h <> 0 then
  begin
    DebugLog('HWND: ' + IntToHex(h, 8));
    SetWindowPos(h, 0, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or
      SWP_FRAMECHANGED or SWP_NOACTIVATE);
  end
  else
    DebugLog('HWND is 0!');
{$ENDIF}
{$IFDEF MACOS}
  SetupMacWindow;
{$ENDIF}
{$IFDEF LINUX}
  SetupLinuxWindow;
{$ENDIF}
end;

procedure TnbWindowTitleBar.SetEnabled(const Value: Boolean);
{$IFDEF MSWINDOWS}
var
  h: HWND;
{$ENDIF}
begin
  if FEnabled = Value then
    Exit;

  FEnabled := Value;

  if (FForm = nil) or (csDesigning in ComponentState) then
    Exit;

  if FEnabled then
    Apply
  else
  begin
{$IFDEF MSWINDOWS}
    RemoveSubclass;
    h := FmxHandleToHWND(FForm.Handle);
    if h <> 0 then
      SetWindowPos(h, 0, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or
        SWP_FRAMECHANGED or SWP_NOACTIVATE);
{$ENDIF}
{$IFDEF LINUX}
    RemoveLinuxHandlers;
    FForm.BorderStyle := FLinuxOriginalBorderStyle;
    if FSystemButtons <> nil then
      FSystemButtons.Visible := False;
{$ENDIF}
  end;
end;

procedure TnbWindowTitleBar.SetTitleControl(const Value: TControl);
begin
  if FTitleControl = Value then
    Exit;
  FTitleControl := Value;
  if FTitleControl <> nil then
    FTitleControl.FreeNotification(Self);
end;

procedure TnbWindowTitleBar.SetDockingHost(const Value: TnbDockingPaneHost);
begin
  if FDockingHost = Value then
    Exit;
  FDockingHost := Value;
  if FDockingHost <> nil then
    FDockingHost.FreeNotification(Self);
end;

function TnbWindowTitleBar.EffectiveTitleControl: TControl;
begin
  if FDockingHost <> nil then
    Result := FDockingHost.TabBarControl
  else
    Result := FTitleControl;
end;
procedure TnbWindowTitleBar.SetSystemButtons(const Value: TControl);
begin
  if FSystemButtons = Value then
    Exit;
  FSystemButtons := Value;
  if FSystemButtons <> nil then
    FSystemButtons.FreeNotification(Self);
end;

procedure TnbWindowTitleBar.SetMaxButton(const Value: TControl);
begin
  if FMaxButton = Value then
    Exit;
  FMaxButton := Value;
  if FMaxButton <> nil then
    FMaxButton.FreeNotification(Self);
end;

procedure TnbWindowTitleBar.SetMinButton(const Value: TControl);
begin
  if FMinButton = Value then
    Exit;
  FMinButton := Value;
  if FMinButton <> nil then
    FMinButton.FreeNotification(Self);
end;

procedure TnbWindowTitleBar.SetCloseButton(const Value: TControl);
begin
  if FCloseButton = Value then
    Exit;
  FCloseButton := Value;
  if FCloseButton <> nil then
    FCloseButton.FreeNotification(Self);
end;

{$IFDEF MSWINDOWS}

procedure TnbWindowTitleBar.DebugLog(const Msg: string);
begin
  if FDebugMode then
    OutputDebugString(PChar('TnbWindowTitleBar: ' + Msg));
end;

function WindowProcCallback(HWND: HWND; uMsg: UINT; wParam: wParam;
  lParam: lParam): LRESULT; stdcall;
var
  Obj: TnbWindowTitleBar;
begin
  Obj := TnbWindowTitleBar(GetProp(HWND, 'TnbWindowTitleBar_Obj'));
  if Assigned(Obj) and (Obj.FWindowHandle = HWND) then
    Result := Obj.WindowProc(HWND, uMsg, wParam, lParam)
  else
    Result := DefWindowProc(HWND, uMsg, wParam, lParam);
end;

function TnbWindowTitleBar.IsValidWindow(HWND: HWND): Boolean;
begin
  Result := (HWND <> 0) and IsWindow(HWND);
end;

procedure TnbWindowTitleBar.InstallSubclass;
var
  h: HWND;
begin
  if FSubclassInstalled or (FForm = nil) then
  begin
    DebugLog('InstallSubclass: Already installed or no form');
    Exit;
  end;

  h := FmxHandleToHWND(FForm.Handle);
  if h = 0 then
  begin
    DebugLog('InstallSubclass: HWND is 0');
    Exit;
  end;

  if not IsValidWindow(h) then
  begin
    DebugLog('InstallSubclass: Invalid window handle');
    Exit;
  end;

  DebugLog('Installing window proc for HWND: ' + IntToHex(h, 8));

  InitCommonControls;

  try
    FOldWndProc := GetWindowLongPtr(h, GWLP_WNDPROC);
    FWindowHandle := h;

    SetProp(h, 'TnbWindowTitleBar_Obj', THandle(Self));
    SetWindowLongPtr(h, GWLP_WNDPROC, LONG_PTR(@WindowProcCallback));

    FSubclassInstalled := True;
    DebugLog('Window proc installed successfully. OldWndProc: ' +
      IntToHex(FOldWndProc, 8));
  except
    on E: Exception do
    begin
      DebugLog('Error installing window proc: ' + E.Message);
      FSubclassInstalled := False;
      FOldWndProc := 0;
      FWindowHandle := 0;
    end;
  end;
end;

procedure TnbWindowTitleBar.RemoveSubclass;
var
  h: HWND;
begin
  if not FSubclassInstalled then
  begin
    DebugLog('RemoveSubclass: Not installed');
    Exit;
  end;

  h := FWindowHandle;

  if IsValidWindow(h) then
  begin
    DebugLog('Removing window proc from HWND: ' + IntToHex(h, 8));

    try
      if FOldWndProc <> 0 then
      begin
        SetWindowLongPtr(h, GWLP_WNDPROC, FOldWndProc);
        DebugLog('Old window proc restored: ' + IntToHex(FOldWndProc, 8));
      end;

      RemoveProp(h, 'TnbWindowTitleBar_Obj');
    except
      on E: Exception do
        DebugLog('Error removing subclass: ' + E.Message);
    end;
  end
  else
  begin
    DebugLog('RemoveSubclass: Window handle is invalid');
  end;

  FSubclassInstalled := False;
  FOldWndProc := 0;
  FWindowHandle := 0;
end;

procedure TnbWindowTitleBar.UpdateDwmMargins;
var
  Mgns: MARGINS;
  h: HWND;
begin
  if FForm = nil then
    Exit;

  h := FmxHandleToHWND(FForm.Handle);
  if h = 0 then
    Exit;

  Mgns.cxLeftWidth := 0;
  Mgns.cxRightWidth := 0;
  Mgns.cyTopHeight := 0;
  Mgns.cyBottomHeight := 1;

  if DwmExtendFrameIntoClientArea(h, Mgns) = S_OK then
    DebugLog('DWM margins updated successfully')
  else
    DebugLog('Failed to update DWM margins');
end;

function TnbWindowTitleBar.ScreenToLogical(const AScreenPoint: TPoint): TPointF;
var
  ScreenService: IFMXScreenService;
  Scale: Single;
  WinRect: TRect;
  h: HWND;
  LocalP: TPoint;
begin
  h := FmxHandleToHWND(FForm.Handle);
  GetWindowRect(h, WinRect);

  LocalP.X := AScreenPoint.X - WinRect.Left;
  LocalP.Y := AScreenPoint.Y - WinRect.Top;

  if TPlatformServices.Current.SupportsPlatformService(IFMXScreenService,
    ScreenService) then
    Scale := ScreenService.GetScreenScale
  else
    Scale := 1.0;

  Result.X := LocalP.X / Scale;
  Result.Y := LocalP.Y / Scale;
end;

function TnbWindowTitleBar.PtInControl(const AControl: TControl;
  const PFormLogical: TPointF): Boolean;
begin
  Result := (AControl <> nil) and AControl.Visible and AControl.Enabled and
    AControl.AbsoluteRect.Contains(PFormLogical);
end;

function TnbWindowTitleBar.HasInteractiveControlAt(const P: TPointF;
  AParent: TControl): Boolean;
var
  I: Integer;
  ChildControl: TControl;
begin
  Result := False;

  if not Assigned(AParent) then
    Exit;

  // Проходим по ВСЕМ детям рекурсивно
  for I := 0 to AParent.ChildrenCount - 1 do
  begin
    if AParent.Children[I] is TControl then
    begin
      ChildControl := TControl(AParent.Children[I]);

      // Проверяем: видимый, включенный, HitTest=True, точка внутри
      if ChildControl.Visible and ChildControl.Enabled and
        ChildControl.HitTest and ChildControl.AbsoluteRect.Contains(P) then
      begin
        DebugLog(Format('  Found interactive control: %s',
          [ChildControl.Name]));
        Exit(True);
      end;

      // Рекурсия для детей этого контрола
      if ChildControl.ChildrenCount > 0 then
      begin
        if HasInteractiveControlAt(P, ChildControl) then
          Exit(True);
      end;
    end;
  end;
end;

function TnbWindowTitleBar.HitTest(const AScreenPoint: TPoint): LRESULT;
var
  P: TPointF;
  h: HWND;
  IsMaximized: Boolean;
  ResizeZone: Single;
begin
  if not Assigned(FForm) then
    Exit(HTCLIENT);

  h := FmxHandleToHWND(FForm.Handle);
  IsMaximized := IsZoomed(h);
  P := ScreenToLogical(AScreenPoint);

  DebugLog(Format('HitTest: Screen(%d,%d) -> Logical(%.1f,%.1f)',
    [AScreenPoint.X, AScreenPoint.Y, P.X, P.Y]));

  // 1) Системные кнопки - МАКСИМАЛЬНЫЙ приоритет
  if PtInControl(FCloseButton, P) then
  begin
    DebugLog('  -> HTCLOSE');
    Exit(HTCLOSE);
  end;

  if PtInControl(FMaxButton, P) then
  begin
    DebugLog('  -> HTMAXBUTTON');
    Exit(HTMAXBUTTON);
  end;

  if PtInControl(FMinButton, P) then
  begin
    DebugLog('  -> HTMINBUTTON');
    Exit(HTMINBUTTON);
  end;

  // 2) Resize границы (только если не максимизировано)
  if not IsMaximized then
  begin
    ResizeZone := kResizeBorderThickness;

    // Углы
    if (P.Y < ResizeZone) and (P.X < ResizeZone) then
    begin
      DebugLog('  -> HTTOPLEFT');
      Exit(HTTOPLEFT);
    end;
    if (P.Y < ResizeZone) and (P.X > FForm.ClientWidth - ResizeZone) then
    begin
      DebugLog('  -> HTTOPRIGHT');
      Exit(HTTOPRIGHT);
    end;
    if (P.Y > FForm.ClientHeight - ResizeZone) and (P.X < ResizeZone) then
    begin
      DebugLog('  -> HTBOTTOMLEFT');
      Exit(HTBOTTOMLEFT);
    end;
    if (P.Y > FForm.ClientHeight - ResizeZone) and
      (P.X > FForm.ClientWidth - ResizeZone) then
    begin
      DebugLog('  -> HTBOTTOMRIGHT');
      Exit(HTBOTTOMRIGHT);
    end;

    // Стороны
    if P.Y < ResizeZone then
    begin
      DebugLog('  -> HTTOP');
      Exit(HTTOP);
    end;
    if P.Y > FForm.ClientHeight - ResizeZone then
    begin
      DebugLog('  -> HTBOTTOM');
      Exit(HTBOTTOM);
    end;
    if P.X < ResizeZone then
    begin
      DebugLog('  -> HTLEFT');
      Exit(HTLEFT);
    end;
    if P.X > FForm.ClientWidth - ResizeZone then
    begin
      DebugLog('  -> HTRIGHT');
      Exit(HTRIGHT);
    end;
  end;

  // 3) ГЛАВНАЯ ЛОГИКА - TitleControl
  if (EffectiveTitleControl <> nil) and PtInControl(EffectiveTitleControl, P) then
  begin
    // Есть ли в этой точке интерактивный контрол?
    if HasInteractiveControlAt(P, EffectiveTitleControl) then
    begin
      DebugLog('  -> HTCLIENT (interactive control)');
      Exit(HTCLIENT); // FMX обработает клик/событие
    end
    else
    begin
      DebugLog('  -> HTCAPTION (empty title area)');
      Exit(HTCAPTION); // Пустая область - тащим окно
    end;
  end;

  DebugLog('  -> HTCLIENT (default)');
  Result := HTCLIENT;
end;

function TnbWindowTitleBar.WindowProc(HWND: HWND; uMsg: UINT; wParam: wParam;
  lParam: lParam): LRESULT; stdcall;
var
  Params: PNCCalcSizeParams;
  DwmResult: LRESULT;
  MonInfo: TMonitorInfo;
  HMONITOR: Winapi.Windows.HMONITOR;
  Pt: TPoint;
  OldWndProc: NativeUInt;
begin
  try
    DebugLog(Format('WindowProc: Msg=%d (0x%x)', [uMsg, uMsg]));

    case uMsg of
      WM_NCCALCSIZE:
        begin
          DebugLog('WM_NCCALCSIZE received');
          if wParam = 1 then
          begin
            Params := PNCCalcSizeParams(lParam);

            if IsZoomed(HWND) then
            begin
              MonInfo.cbSize := SizeOf(TMonitorInfo);
              HMONITOR := MonitorFromWindow(HWND, MONITOR_DEFAULTTONEAREST);
              if GetMonitorInfoW(HMONITOR, MonInfo) then
              begin
                Params.rgrc[0] := MonInfo.rcWork;
                DebugLog('WM_NCCALCSIZE: Adjusted for maximized window');
              end;
            end;

            Result := 0;
            Exit;
          end;
        end;

      WM_NCHITTEST:
        begin
          DebugLog('WM_NCHITTEST received');
          Pt.X := LOWORD(lParam);
          Pt.Y := HIWORD(lParam);

          var
          P := ScreenToLogical(Pt);

          // 1) СНАЧАЛА проверяем системные кнопки (НАИВЫСШИЙ приоритет!)
          if PtInControl(FCloseButton, P) then
          begin
            DebugLog('  -> HTCLOSE');
            Result := HTCLOSE;
            Exit; // Сразу выходим! НЕ даем DWM переопределить!
          end;

          if PtInControl(FMaxButton, P) then
          begin
            DebugLog('  -> HTMAXBUTTON');
            Result := HTMAXBUTTON;
            Exit; // Сразу выходим!
          end;

          if PtInControl(FMinButton, P) then
          begin
            DebugLog('  -> HTMINBUTTON');
            Result := HTMINBUTTON;
            Exit; // Сразу выходим!
          end;

          // 2) Теперь проверяем интерактивные контролы на TitleControl
          if (EffectiveTitleControl <> nil) and PtInControl(EffectiveTitleControl, P) then
          begin
            if HasInteractiveControlAt(P, EffectiveTitleControl) then
            begin
              DebugLog('  Interactive control - passing to FMX');

              if (FOldWndProc <> 0) and
                (FOldWndProc <> ULONG_PTR(@WindowProcCallback)) then
              begin
                if (FOldWndProc and $3) = 0 then
                  Result := CallWindowProc(Pointer(FOldWndProc), HWND, uMsg,
                    wParam, lParam)
                else
                  Result := DefWindowProc(HWND, uMsg, wParam, lParam);
              end
              else
                Result := DefWindowProc(HWND, uMsg, wParam, lParam);

              Exit; // Выходим, не вызываем DWM
            end;
          end;

          // 3) Остальное - resize зоны, пустая область заголовка
          Result := HitTest(Pt);
          DebugLog(Format('WM_NCHITTEST -> Result: %d', [Result]));

          // DWM вызываем только для HTCLIENT
          if Result = HTCLIENT then
          begin
            if DwmDefWindowProc(HWND, uMsg, wParam, lParam, DwmResult) then
            begin
              DebugLog(Format('DWM handled: %d', [DwmResult]));
              Result := DwmResult;
            end;
          end;
          Exit;
        end;

      WM_NCMOUSEMOVE:
        begin
          DebugLog(Format('WM_NCMOUSEMOVE: wParam=%d', [wParam]));
          // Просто пропускаем дальше для обновления hover состояний
        end;

      WM_NCLBUTTONDOWN:
        begin
          DebugLog(Format('WM_NCLBUTTONDOWN: wParam=%d', [wParam]));

          if wParam = HTCAPTION then
          begin
            SendMessage(HWND, WM_SYSCOMMAND, SC_MOVE or HTCAPTION, 0);
            Result := 0;
            Exit;
          end;

          if (wParam = HTCLOSE) or (wParam = HTMAXBUTTON) or
            (wParam = HTMINBUTTON) then
          begin
            Result := 0;
            Exit;
          end;
        end;

      WM_NCLBUTTONUP:
        begin
          DebugLog(Format('WM_NCLBUTTONUP: wParam=%d', [wParam]));

          if wParam = HTCLOSE then
          begin
            DebugLog('Closing window');
            SendMessage(HWND, WM_SYSCOMMAND, SC_CLOSE, 0);
            Result := 0;
            Exit;
          end;

          if wParam = HTMAXBUTTON then
          begin
            if IsZoomed(HWND) then
            begin
              DebugLog('Restoring window');
              SendMessage(HWND, WM_SYSCOMMAND, SC_RESTORE, 0)
            end
            else
            begin
              DebugLog('Maximizing window');
              SendMessage(HWND, WM_SYSCOMMAND, SC_MAXIMIZE, 0);
            end;
            Result := 0;
            Exit;
          end;

          if wParam = HTMINBUTTON then
          begin
            DebugLog('Minimizing window');
            SendMessage(HWND, WM_SYSCOMMAND, SC_MINIMIZE, 0);
            Result := 0;
            Exit;
          end;
        end;

      WM_NCLBUTTONDBLCLK:
        begin
          DebugLog(Format('WM_NCLBUTTONDBLCLK: wParam=%d', [wParam]));
          if wParam = HTCAPTION then
          begin
            if IsZoomed(HWND) then
              SendMessage(HWND, WM_SYSCOMMAND, SC_RESTORE, 0)
            else
              SendMessage(HWND, WM_SYSCOMMAND, SC_MAXIMIZE, 0);
            Result := 0;
            Exit;
          end;
        end;

      WM_NCRBUTTONDOWN:
        begin
          DebugLog(Format('WM_NCRBUTTONDOWN: wParam=%d', [wParam]));
        end;

      WM_WINDOWPOSCHANGED:
        begin
          DebugLog('WM_WINDOWPOSCHANGED received');
        end;

      WM_DESTROY:
        begin
          OldWndProc := FOldWndProc;
          DebugLog('WM_DESTROY received');
          RemoveSubclass;
          if OldWndProc <> 0 then
            Result := CallWindowProc(Pointer(OldWndProc), HWND, uMsg,
              wParam, lParam)
          else
            Result := DefWindowProc(HWND, uMsg, wParam, lParam);
          Exit;
        end;
    end;

    if (FOldWndProc <> 0) and (FOldWndProc <> ULONG_PTR(@WindowProcCallback))
    then
    begin
      try
        if (FOldWndProc and $3) = 0 then
        begin
          Result := CallWindowProc(Pointer(FOldWndProc), HWND, uMsg,
            wParam, lParam);
        end
        else
        begin
          DebugLog('Warning: FOldWndProc is misaligned: ' +
            IntToHex(FOldWndProc, 8));
          Result := DefWindowProc(HWND, uMsg, wParam, lParam);
        end;
      except
        on E: Exception do
        begin
          DebugLog('Exception in CallWindowProc: ' + E.Message + ' at uMsg: ' +
            IntToStr(uMsg));
          Result := DefWindowProc(HWND, uMsg, wParam, lParam);
        end;
      end;
    end
    else
    begin
      Result := DefWindowProc(HWND, uMsg, wParam, lParam);
    end;
  except
    on E: Exception do
    begin
      DebugLog('Exception in WindowProc: ' + E.Message + ' at uMsg: ' +
        IntToStr(uMsg));
      Result := DefWindowProc(HWND, uMsg, wParam, lParam);
    end;
  end;
end;
{$ENDIF}
{$IFDEF LINUX}

type
  TnbTitleControlAccess = class(TControl);

function TnbWindowTitleBar.LinuxMouseScreenPoint: TPointF;
var
  MouseService: IFMXMouseService;
begin
  Result := TPointF.Zero;
  if TPlatformServices.Current.SupportsPlatformService(IFMXMouseService,
    MouseService) then
    Result := MouseService.GetMousePos;
end;

procedure TnbWindowTitleBar.SetupLinuxWindow;
var
  Title: TControl;
begin
  if FLinuxHandlersInstalled or (FForm = nil) then
    Exit;
  Title := EffectiveTitleControl;
  if Title = nil then
    Exit;

  FLinuxOriginalBorderStyle := FForm.BorderStyle;
  FForm.BorderStyle := TFmxFormBorderStyle.None;

  FPreviousTitleMouseDown := Title.OnMouseDown;
  FPreviousTitleMouseMove := Title.OnMouseMove;
  FPreviousTitleMouseUp := Title.OnMouseUp;
  FPreviousTitleDblClick := Title.OnDblClick;
  Title.OnMouseDown := LinuxTitleMouseDown;
  Title.OnMouseMove := LinuxTitleMouseMove;
  Title.OnMouseUp := LinuxTitleMouseUp;
  Title.OnDblClick := LinuxTitleDblClick;

  if FMinButton <> nil then
  begin
    FPreviousMinClick := FMinButton.OnClick;
    FMinButton.OnClick := LinuxMinClick;
  end;
  if FMaxButton <> nil then
  begin
    FPreviousMaxClick := FMaxButton.OnClick;
    FMaxButton.OnClick := LinuxMaxClick;
  end;
  if FCloseButton <> nil then
  begin
    FPreviousCloseClick := FCloseButton.OnClick;
    FCloseButton.OnClick := LinuxCloseClick;
  end;
  CreateLinuxResizeHandles;
  FLinuxHandlersInstalled := True;
end;

procedure TnbWindowTitleBar.RemoveLinuxHandlers;
var
  Title: TControl;
begin
  if not FLinuxHandlersInstalled then
    Exit;
  Title := EffectiveTitleControl;
  if Title <> nil then
  begin
    Title.OnMouseDown := FPreviousTitleMouseDown;
    Title.OnMouseMove := FPreviousTitleMouseMove;
    Title.OnMouseUp := FPreviousTitleMouseUp;
    Title.OnDblClick := FPreviousTitleDblClick;
  end;
  if FMinButton <> nil then
    FMinButton.OnClick := FPreviousMinClick;
  if FMaxButton <> nil then
    FMaxButton.OnClick := FPreviousMaxClick;
  if FCloseButton <> nil then
    FCloseButton.OnClick := FPreviousCloseClick;
  FLinuxDragging := False;
  FLinuxResizeActive := False;
  FreeLinuxResizeHandles;
  FLinuxHandlersInstalled := False;
end;

procedure TnbWindowTitleBar.CreateLinuxResizeHandles;
const
  ResizeSize = 6;
  CornerSize = 10;
  Edges: array[0..7] of Integer = (1, 2, 4, 8, 5, 6, 9, 10);
  Cursors: array[0..7] of TCursor = (crSizeWE, crSizeWE, crSizeNS, crSizeNS,
    crSizeNWSE, crSizeNESW, crSizeNESW, crSizeNWSE);
var
  I: Integer;
  Handle: TRectangle;
begin
  if FForm = nil then Exit;
  for I := 0 to High(FLinuxResizeHandles) do
  begin
    Handle := TRectangle.Create(Self);
    FLinuxResizeHandles[I] := Handle;
    Handle.Parent := FForm;
    Handle.Stored := False;
    Handle.Locked := True;
    Handle.Fill.Kind := TBrushKind.None;
    Handle.Stroke.Kind := TBrushKind.None;
    Handle.HitTest := True;
    Handle.Tag := Edges[I];
    Handle.Cursor := Cursors[I];
    Handle.OnMouseDown := LinuxResizeMouseDown;
    Handle.OnMouseMove := LinuxResizeMouseMove;
    Handle.OnMouseUp := LinuxResizeMouseUp;
    case I of
      0:
        begin
          Handle.SetBounds(0, CornerSize, ResizeSize,
            Max(0, FForm.ClientHeight - CornerSize * 2));
          Handle.Anchors := [TAnchorKind.akLeft, TAnchorKind.akTop,
            TAnchorKind.akBottom];
        end;
      1:
        begin
          Handle.SetBounds(FForm.ClientWidth - ResizeSize, CornerSize,
            ResizeSize, Max(0, FForm.ClientHeight - CornerSize * 2));
          Handle.Anchors := [TAnchorKind.akRight, TAnchorKind.akTop,
            TAnchorKind.akBottom];
        end;
      2:
        begin
          Handle.SetBounds(CornerSize, 0,
            Max(0, FForm.ClientWidth - CornerSize * 2), ResizeSize);
          Handle.Anchors := [TAnchorKind.akLeft, TAnchorKind.akTop,
            TAnchorKind.akRight];
        end;
      3:
        begin
          Handle.SetBounds(CornerSize, FForm.ClientHeight - ResizeSize,
            Max(0, FForm.ClientWidth - CornerSize * 2), ResizeSize);
          Handle.Anchors := [TAnchorKind.akLeft, TAnchorKind.akRight,
            TAnchorKind.akBottom];
        end;
      4:
        begin
          Handle.SetBounds(0, 0, CornerSize, CornerSize);
          Handle.Anchors := [TAnchorKind.akLeft, TAnchorKind.akTop];
        end;
      5:
        begin
          Handle.SetBounds(FForm.ClientWidth - CornerSize, 0,
            CornerSize, CornerSize);
          Handle.Anchors := [TAnchorKind.akRight, TAnchorKind.akTop];
        end;
      6:
        begin
          Handle.SetBounds(0, FForm.ClientHeight - CornerSize,
            CornerSize, CornerSize);
          Handle.Anchors := [TAnchorKind.akLeft, TAnchorKind.akBottom];
        end;
      7:
        begin
          Handle.SetBounds(FForm.ClientWidth - CornerSize,
            FForm.ClientHeight - CornerSize, CornerSize, CornerSize);
          Handle.Anchors := [TAnchorKind.akRight, TAnchorKind.akBottom];
        end;
    end;
    Handle.BringToFront;
  end;
end;

procedure TnbWindowTitleBar.FreeLinuxResizeHandles;
var
  I: Integer;
begin
  for I := 0 to High(FLinuxResizeHandles) do
    FreeAndNil(FLinuxResizeHandles[I]);
end;

procedure TnbWindowTitleBar.LinuxResizeMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  if (Button <> TMouseButton.mbLeft) or (FForm = nil) or FLinuxMaximized
    or not (Sender is TControl) then Exit;
  FLinuxResizeActive := True;
  FLinuxResizeEdge := TControl(Sender).Tag;
  FLinuxResizeMouseOrigin := LinuxMouseScreenPoint;
  FLinuxResizeFormOrigin := FForm.BoundsF;
  TnbTitleControlAccess(TControl(Sender)).Capture;
end;

procedure TnbWindowTitleBar.LinuxResizeMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Single);
var
  MousePoint: TPointF;
  Bounds: TRectF;
  DX, DY, MinWidth, MinHeight: Single;
begin
  if not FLinuxResizeActive or (FForm = nil) then Exit;
  MousePoint := LinuxMouseScreenPoint;
  DX := MousePoint.X - FLinuxResizeMouseOrigin.X;
  DY := MousePoint.Y - FLinuxResizeMouseOrigin.Y;
  Bounds := FLinuxResizeFormOrigin;

  if (FLinuxResizeEdge and 1) <> 0 then Bounds.Left := Bounds.Left + DX;
  if (FLinuxResizeEdge and 2) <> 0 then Bounds.Right := Bounds.Right + DX;
  if (FLinuxResizeEdge and 4) <> 0 then Bounds.Top := Bounds.Top + DY;
  if (FLinuxResizeEdge and 8) <> 0 then Bounds.Bottom := Bounds.Bottom + DY;

  MinWidth := FForm.Constraints.MinWidth;
  MinHeight := FForm.Constraints.MinHeight;
  if MinWidth <= 0 then MinWidth := 320;
  if MinHeight <= 0 then MinHeight := 240;
  if Bounds.Width < MinWidth then
  begin
    if (FLinuxResizeEdge and 1) <> 0 then
      Bounds.Left := Bounds.Right - MinWidth
    else
      Bounds.Right := Bounds.Left + MinWidth;
  end;
  if Bounds.Height < MinHeight then
  begin
    if (FLinuxResizeEdge and 4) <> 0 then
      Bounds.Top := Bounds.Bottom - MinHeight
    else
      Bounds.Bottom := Bounds.Top + MinHeight;
  end;
  FForm.SetBoundsF(Bounds);
end;

procedure TnbWindowTitleBar.LinuxResizeMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  if Button <> TMouseButton.mbLeft then Exit;
  FLinuxResizeActive := False;
  if Sender is TControl then
    TnbTitleControlAccess(TControl(Sender)).ReleaseCapture;
end;
procedure TnbWindowTitleBar.LinuxTitleMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  Title: TControl;
begin
  if Assigned(FPreviousTitleMouseDown) then
    FPreviousTitleMouseDown(Sender, Button, Shift, X, Y);
  if (Button <> TMouseButton.mbLeft) or (FForm = nil) then
    Exit;
  Title := EffectiveTitleControl;
  if Title = nil then
    Exit;
  FLinuxDragging := True;
  FLinuxDragMouseOrigin := LinuxMouseScreenPoint;
  FLinuxDragFormOrigin := PointF(FForm.Left, FForm.Top);
  TnbTitleControlAccess(Title).Capture;
end;

procedure TnbWindowTitleBar.LinuxTitleMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Single);
var
  MousePoint: TPointF;
begin
  if Assigned(FPreviousTitleMouseMove) then
    FPreviousTitleMouseMove(Sender, Shift, X, Y);
  if not FLinuxDragging or (FForm = nil) then
    Exit;
  MousePoint := LinuxMouseScreenPoint;
  FForm.Left := Round(FLinuxDragFormOrigin.X + MousePoint.X -
    FLinuxDragMouseOrigin.X);
  FForm.Top := Round(FLinuxDragFormOrigin.Y + MousePoint.Y -
    FLinuxDragMouseOrigin.Y);
end;

procedure TnbWindowTitleBar.LinuxTitleMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  Title: TControl;
begin
  if Assigned(FPreviousTitleMouseUp) then
    FPreviousTitleMouseUp(Sender, Button, Shift, X, Y);
  if Button <> TMouseButton.mbLeft then
    Exit;
  FLinuxDragging := False;
  Title := EffectiveTitleControl;
  if Title <> nil then
    TnbTitleControlAccess(Title).ReleaseCapture;
end;

procedure TnbWindowTitleBar.LinuxTitleDblClick(Sender: TObject);
begin
  if Assigned(FPreviousTitleDblClick) then
    FPreviousTitleDblClick(Sender);
  LinuxMaxClick(Sender);
end;

procedure TnbWindowTitleBar.LinuxMinClick(Sender: TObject);
begin
  if Assigned(FPreviousMinClick) then
    FPreviousMinClick(Sender);
  if FForm <> nil then
    FForm.WindowState := TWindowState.wsMinimized;
end;

procedure TnbWindowTitleBar.LinuxMaxClick(Sender: TObject);
var
  DisplayService: IFMXMultiDisplayService;
  Display: TDisplay;
  WorkArea: TRectF;
begin
  if Assigned(FPreviousMaxClick) then
    FPreviousMaxClick(Sender);
  if FForm = nil then
    Exit;

  if FLinuxMaximized then
  begin
    FForm.SetBoundsF(FLinuxRestoreBounds);
    FLinuxMaximized := False;
    Exit;
  end;

  FLinuxRestoreBounds := FForm.BoundsF;
  if TPlatformServices.Current.SupportsPlatformService(
    IFMXMultiDisplayService, DisplayService) then
  begin
    Display := DisplayService.DisplayFromWindow(FForm.Handle);
    WorkArea := Display.Workarea;
  end
  else
    WorkArea := RectF(0, 0, Screen.Width, Screen.Height);
  FForm.SetBoundsF(WorkArea);
  FLinuxMaximized := True;
end;

procedure TnbWindowTitleBar.LinuxCloseClick(Sender: TObject);
var
  FormToClose: TCommonCustomForm;
begin
  if Assigned(FPreviousCloseClick) then
    FPreviousCloseClick(Sender);
  FormToClose := FForm;
  if FormToClose <> nil then
    TThread.ForceQueue(nil, TThreadProcedure(
      procedure
      begin
        FormToClose.Close;
      end));
end;

{$ENDIF}
{$IFDEF MACOS}

procedure TnbWindowTitleBar.SetupMacWindow;
var
  Wnd: NSWindow;
  WinHandle: TMacWindowHandle;
begin
  WinHandle := WindowHandleToPlatform(FForm.Handle);
  if WinHandle = nil then
    Exit;

  Wnd := WinHandle.Wnd;

  Wnd.setTitleVisibility(NSWindowTitleHidden);
  Wnd.setTitlebarAppearsTransparent(True);
  Wnd.setStyleMask(Wnd.styleMask or NSFullSizeContentViewWindowMask);
  Wnd.setMovableByWindowBackground(True);
end;
{$ENDIF}

procedure Register;
begin
  RegisterComponents('nb FMX Docking', [TnbWindowTitleBar]);
end;

end.
