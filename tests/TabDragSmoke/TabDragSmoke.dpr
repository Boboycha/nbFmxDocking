program TabDragSmoke;
uses System.SysUtils,System.Classes,System.Types,System.UITypes,
  FMX.Types,FMX.Controls,FMX.Forms,FMX.Layouts,FMX.Objects,
  nbDocking.Types,nbDocking.PaneHost,nbDocking.WindowTitleBar
{$IFDEF MSWINDOWS},Winapi.Windows,Winapi.Messages,FMX.Platform.Win{$ENDIF}
{$IFDEF MACOS},FMX.Platform.Mac,Macapi.AppKit,Macapi.CocoaTypes,Macapi.Foundation{$ENDIF};
type TProbe=class(TForm)
public
  Header:TLayout;Host:TnbDockingPaneHost;Chrome:TnbWindowTitleBar;Timer:TTimer;
  Book:TStyleBook;Phase,Moves,Ends:Integer;Original:TRect;Failed:Boolean;
  constructor Create(AOwner:TComponent);override;
  procedure Tick(Sender:TObject);
  procedure DragMove(Sender:TObject;Index:Integer;const Point:TPointF);
  procedure DragEnd(Sender:TObject;Index:Integer;const Point:TPointF;var Handled:Boolean);
end;
var Output:TextFile;
procedure Log(const S:string);begin Writeln(Output,S);Flush(Output);end;
constructor TProbe.Create(AOwner:TComponent);
var I:Integer;Content:TnbDockingPaneContent;
begin
  inherited CreateNew(AOwner);SetBounds(100,100,800,480);
  Header:=TLayout.Create(Self);Header.Parent:=Self;Header.Align:=TAlignLayout.Top;Header.Height:=36;if FindCmdLineSwitch('tall') then Header.Height:=70;
{$IFDEF MACOS}Header.Padding.Left:=88;{$ENDIF}
  Host:=TnbDockingPaneHost.Create(Self);Host.Parent:=Self;Host.Align:=TAlignLayout.Client;
  Host.TabBarSize:=Header.Height;Host.VisibleTabs:=True;
  for I:=0 to 2 do begin Content:=TnbDockingPaneContent.Create(Host);
    Content.Caption:='Tab '+IntToStr(I);Host.AddTabWithContent(Content.Caption,Content);end;
  Host.OnTabDragMove:=DragMove;Host.OnTabDragEnd:=DragEnd;
  Chrome:=TnbWindowTitleBar.Create(Self);Chrome.TitleControl:=Header;Chrome.DockingHost:=Host;
{$IFDEF MACOS}Chrome.MacUnifiedTitleBar:=True;{$ENDIF}
  Chrome.Apply;
  if (ParamCount>1) and FileExists(ParamStr(2)) then begin
    Book:=TStyleBook.Create(Self);Book.UseStyleManager:=True;StyleBook:=Book;Book.LoadFromFile(ParamStr(2));
  end;
  Timer:=TTimer.Create(Self);Timer.Interval:=700;Timer.OnTimer:=Tick;
end;
procedure TProbe.DragMove(Sender:TObject;Index:Integer;const Point:TPointF);
begin Inc(Moves);Log('TAB DRAG MOVE');end;
procedure TProbe.DragEnd(Sender:TObject;Index:Integer;const Point:TPointF;var Handled:Boolean);
begin Inc(Ends);Log('TAB DRAG END');end;
procedure TProbe.Tick(Sender:TObject);
var Child:TFmxObject;Button:TRectangle;ScreenPoint,Local,Finish:TPointF;Hit:IControl;I:Integer;
{$IFDEF MSWINDOWS}Window:HWND;P:TPoint;Code:LRESULT;{$ENDIF}
{$IFDEF MACOS}W:NSWindow;E:NSEvent;Kind:Integer;P:NSPoint;{$ENDIF}
begin
  Timer.Enabled:=False;
  try
    if Phase=0 then begin
      Host.RefreshTabLayout;Button:=nil;
      for Child in Host.TabBarControl.Children do
        if (Child is TRectangle) and (TRectangle(Child).TagFloat>0) and (Child.Tag=1) then Button:=TRectangle(Child);
      if Button=nil then raise Exception.Create('No tab button');
      ScreenPoint:=Button.LocalToScreen(PointF(Button.Width/2,Button.Height/2));
      Hit:=ObjectAtPoint(ScreenPoint);
      if Hit=nil then Log('HIT none') else Log('HIT '+Hit.GetObject.ClassName+' exact='+BoolToStr(Hit.GetObject=Button,True));
      if (Hit=nil) or (Hit.GetObject<>Button) then Failed:=True;
      Local:=ScreenToClient(ScreenPoint);Finish:=PointF(Header.Padding.Left+30,Local.Y);
      Log(Format('local=%.1f,%.1f size=%d,%d',[Local.X,Local.Y,ClientWidth,ClientHeight]));
      Original:=System.Types.Rect(Left,Top,Left+Width,Top+Height);
{$IFDEF MSWINDOWS}
      Window:=FmxHandleToHWND(Handle);P:=Point(Round(Local.X*Handle.Scale),Round(Local.Y*Handle.Scale));
      Winapi.Windows.ClientToScreen(Window,P);
      Code:=SendMessage(Window,WM_NCHITTEST,0,MakeLParam(P.X,P.Y));Log('NC HIT '+IntToStr(Code));
      if Code<>HTCLIENT then Failed:=True;
      SendMessage(Window,WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(Round(Local.X*Handle.Scale),Round(Local.Y*Handle.Scale)));
      for I:=1 to 4 do SendMessage(Window,WM_MOUSEMOVE,MK_LBUTTON,
        MakeLParam(Round((Local.X+(Finish.X-Local.X)*I/4)*Handle.Scale),Round(Local.Y*Handle.Scale)));
      SendMessage(Window,WM_LBUTTONUP,0,MakeLParam(Round(Finish.X*Handle.Scale),Round(Finish.Y*Handle.Scale)));
{$ENDIF}
{$IFDEF MACOS}
      W:=WindowHandleToPlatform(Handle).Wnd;
      if W.isMovable then raise Exception.Create('Unified titlebar must not start automatic native window dragging');
      Chrome.Enabled:=False;
      if not W.isMovable then raise Exception.Create('Disabling chrome must restore native movability');
      Chrome.Enabled:=True;
      if W.isMovable then raise Exception.Create('Reenabled chrome must suppress automatic native dragging');
      for I:=0 to 5 do begin
        if I=0 then Kind:=NSLeftMouseDown else if I=5 then Kind:=NSLeftMouseUp else Kind:=NSLeftMouseDragged;
        P:=NSMakePoint(Local.X+(Finish.X-Local.X)*I/5,TNSView.Wrap(W.contentView).bounds.size.height-Local.Y);
        E:=TNSEvent.Wrap(TNSEvent.OCClass.mouseEventWithType(Kind,P,0,0,W.windowNumber,nil,I+1,1,1));
        TNSApplication.Wrap(TNSApplication.OCClass.sharedApplication).postEvent(E,False);
      end;
{$ENDIF}
      Phase:=1;Timer.Enabled:=True;Exit;
    end;
    Log(Format('moves=%d ends=%d first=%s frameMoved=%s',[Moves,Ends,Host.TabCaption(0),BoolToStr(System.Types.Rect(Left,Top,Left+Width,Top+Height)<>Original,True)]));
    if (Moves=0) or (Ends<>1) or (System.Types.Rect(Left,Top,Left+Width,Top+Height)<>Original) then Failed:=True;
    if Failed then begin Log('TAB DRAG FAIL');Halt(1);end;
    Log('TAB DRAG PASS');Halt(0);
  except on E:Exception do begin Log(E.ClassName+': '+E.Message);Halt(1);end;end;
end;
{$IFDEF MACOS}
function ProbeState:TApplicationState;begin Result:=TApplicationState.Running;end;
{$ENDIF}
var Form:TProbe;
begin AssignFile(Output,ParamStr(1));Rewrite(Output);
try Application.Initialize;
{$IFDEF MACOS}Application.ApplicationStateQuery:=ProbeState;{$ENDIF}
Form:=TProbe.Create(nil);Application.MainForm:=Form;Form.Show;Application.Run;
finally CloseFile(Output);end;end.
