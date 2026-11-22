program MacHeaderDoubleClickSmoke;
uses System.SysUtils,System.Classes,System.Types,System.UITypes,
 FMX.Types,FMX.Forms,FMX.Controls,FMX.Layouts,nbDocking.Types,nbDocking.PaneHost,nbDocking.WindowTitleBar,
 FMX.Platform.Mac,Macapi.AppKit,Macapi.CocoaTypes,Macapi.Foundation;
type TProbe=class(TForm)
public
 Host:TnbDockingPaneHost;Header:TLayout;Chrome:TnbWindowTitleBar;Timer:TTimer;
 Phase:Integer;Original:NSRect;
 constructor Create(AOwner:TComponent);override;
 procedure Tick(Sender:TObject);
 procedure DoubleClickHeader;
end;
var LogFile:TextFile;
procedure Log(const S:string);begin Writeln(LogFile,S);Flush(LogFile);end;
function Running:TApplicationState;begin Result:=TApplicationState.Running;end;
constructor TProbe.Create(AOwner:TComponent);
var Content:TnbDockingPaneContent;
begin
 inherited CreateNew(AOwner);SetBounds(100,100,800,480);
 Header:=TLayout.Create(Self);Header.Parent:=Self;Header.Align:=TAlignLayout.Top;Header.Height:=36;Header.Padding.Left:=88;
 Host:=TnbDockingPaneHost.Create(Self);Host.Parent:=Self;Host.Align:=TAlignLayout.Client;
 Host.VisibleTabs:=True;Content:=TnbDockingPaneContent.Create(Host);Host.AddTabWithContent('Test',Content);
 Chrome:=TnbWindowTitleBar.Create(Self);Chrome.TitleControl:=Header;Chrome.DockingHost:=Host;Chrome.MacUnifiedTitleBar:=True;Chrome.Apply;
 Timer:=TTimer.Create(Self);Timer.Interval:=750;Timer.OnTimer:=Tick;
end;
procedure TProbe.DoubleClickHeader;
var W:NSWindow;P:TPointF;E:NSEvent;Kind:Integer;
begin
 P:=Host.TabBarControl.LocalToScreen(PointF(Host.TabBarControl.Width-30,18));
 if (ObjectAtPoint(P)=nil) or (ObjectAtPoint(P).GetObject<>Host.TabBarControl) then raise Exception.Create('Header background is not target');
 P:=ScreenToClient(P);W:=WindowHandleToPlatform(Handle).Wnd;
 for Kind:=NSLeftMouseDown to NSLeftMouseUp do begin
  E:=TNSEvent.Wrap(TNSEvent.OCClass.mouseEventWithType(Kind,
   NSMakePoint(P.X,TNSView.Wrap(W.contentView).bounds.size.height-P.Y),0,0,W.windowNumber,nil,1,2,1));
  TNSApplication.Wrap(TNSApplication.OCClass.sharedApplication).postEvent(E,False);
 end;
end;
procedure TProbe.Tick(Sender:TObject);
var W:NSWindow;R:NSRect;
begin
 Timer.Enabled:=False;
 try
  W:=WindowHandleToPlatform(Handle).Wnd;R:=W.frame;
  Log(Format('phase=%d frame=%.1f,%.1f %.1fx%.1f zoomed=%s',[Phase,R.origin.x,R.origin.y,R.size.width,R.size.height,BoolToStr(W.isZoomed,True)]));
  if Phase=0 then begin Original:=R;DoubleClickHeader;Inc(Phase);Timer.Enabled:=True;Exit;end;
  if Phase=1 then begin
   if (Abs(R.size.width-Original.size.width)<1) and (Abs(R.size.height-Original.size.height)<1) then raise Exception.Create('Double click did not zoom');
   if W.styleMask and NSFullScreenWindowMask<>0 then raise Exception.Create('Zoom entered fullscreen');
   DoubleClickHeader;Inc(Phase);Timer.Enabled:=True;Exit;
  end;
  if (Abs(R.origin.x-Original.origin.x)>1) or (Abs(R.origin.y-Original.origin.y)>1) or
   (Abs(R.size.width-Original.size.width)>1) or (Abs(R.size.height-Original.size.height)>1) then raise Exception.Create('Second double click did not restore');
  Log('DOUBLE CLICK ZOOM RESTORE PASS');Halt(0);
 except on E:Exception do begin Log(E.ClassName+': '+E.Message);Halt(1);end;end;
end;
var Form:TProbe;
begin AssignFile(LogFile,ParamStr(1));Rewrite(LogFile);Application.Initialize;Application.ApplicationStateQuery:=Running;
 Form:=TProbe.Create(nil);Application.MainForm:=Form;Form.Show;Application.Run;end.
