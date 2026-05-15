unit Unit1;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  nbDocking.Types, nbDocking.Demo,nbDocking.TabHost, FMX.Layouts, nbDocking.PaneHost,
  FMX.StdCtrls, FMX.Controls.Presentation, FMX.Objects, FMX.Memo;

type
  TForm1 = class(TForm)
    DockingPaneHost1: TnbDockingPaneHost;
    Rectangle1: TRectangle;
    StyleBook1: TStyleBook;
    procedure FormCreate(Sender: TObject);
  private
 { Private declarations }

  procedure HandleNeedContent(Sender: TObject;
  var AContent: TnbDockingPaneContent);

procedure DoNeedContent(Sender: TObject;
  var AContent: TnbDockingPaneContent);
  procedure HandlePaneHeaderAction(Sender: TnbDockingPaneContent;
    const AActionId: string);
  function CreateMemoContent(AOwner: TComponent): TnbDockingPaneContent;

  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.fmx}

procedure TForm1.FormCreate(Sender: TObject);
var
  Host: TnbDockingTabHost;
begin
  Host := TnbDockingTabHost.Create(Self);
  Host.Parent := Self;
  Host.Align := TAlignLayout.Client;
  Host.OnContentNeeded := DoNeedContent;

//  Host.AddTab('Server alpha');     (* первый pane подберётся через фабрику *)
//  Host.AddTab('Server beta');
end;

procedure TForm1.HandleNeedContent(Sender: TObject;
  var AContent: TnbDockingPaneContent);
begin
  AContent := CreateMemoContent(TnbDockingPaneHost(Sender));
end;

procedure TForm1.DoNeedContent(Sender: TObject;
  var AContent: TnbDockingPaneContent);
begin
  AContent := CreateMemoContent(TnbDockingTabHost(Sender));
  AContent.AddHeaderAction('mark', '+', HandlePaneHeaderAction, 'Mark');
  AContent.AddHeaderAction('remove-action', 'D', HandlePaneHeaderAction,
    'Remove this button');
end;

function TForm1.CreateMemoContent(AOwner: TComponent): TnbDockingPaneContent;
var
  Memo: TMemo;
begin
  Result := TnbDockingPaneContent.Create(AOwner);

  Memo := TMemo.Create(Result);
  Memo.Parent := Result;
  Memo.Align := TAlignLayout.Client;
  Memo.Lines.Text := 'TMemo smoke test'#13#10
    + 'Type here, split panes, drag tabs, and toggle focus mode.';
end;

procedure TForm1.HandlePaneHeaderAction(Sender: TnbDockingPaneContent;
  const AActionId: string);
begin
  if SameText(AActionId, 'mark') then
    Sender.Caption := Sender.Caption + ' *'
  else if SameText(AActionId, 'remove-action') then
    Sender.RemoveHeaderAction(AActionId);
end;
end.
