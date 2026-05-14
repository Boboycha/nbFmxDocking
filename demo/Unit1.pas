unit Unit1;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  nbDocking.Types, nbDocking.Demo,nbDocking.TabHost, FMX.Layouts, nbDocking.PaneHost,
  FMX.StdCtrls, FMX.Controls.Presentation, FMX.Objects;

type
  TForm1 = class(TForm)
    DockingPaneHost1: TDockingPaneHost;
    Rectangle1: TRectangle;
    StyleBook1: TStyleBook;
    procedure FormCreate(Sender: TObject);
  private
 { Private declarations }

  procedure HandleNeedContent(Sender: TObject;
  var AContent: TDockingPaneContent);

procedure DoNeedContent(Sender: TObject;
  var AContent: TDockingPaneContent);

  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.fmx}

procedure TForm1.FormCreate(Sender: TObject);
var
  Host: TDockingTabHost;
begin
  Host := TDockingTabHost.Create(Self);
  Host.Parent := Self;
  Host.Align := TAlignLayout.Client;
  Host.OnContentNeeded := DoNeedContent;

//  Host.AddTab('Server alpha');     (* первый pane подберётся через фабрику *)
//  Host.AddTab('Server beta');
end;

procedure TForm1.HandleNeedContent(Sender: TObject;
  var AContent: TDockingPaneContent);
begin
  AContent := TDockingPaneContent.Create(TDockingPaneHost(Sender));
end;

procedure TForm1.DoNeedContent(Sender: TObject;
  var AContent: TDockingPaneContent);
begin
  AContent := TDockingPaneContent.Create(TDockingTabHost(Sender));
end;
end.
