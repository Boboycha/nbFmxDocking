unit DesignTest.MainForm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Objects, nbDocking.Types, nbDocking.PaneHost;

type
  TDesignTestForm = class(TForm)
    Host: TnbDockingPaneHost;
    LeftPane: TnbDockingPaneContent;
    TopPane: TnbDockingPaneContent;
    BottomPane: TnbDockingPaneContent;
    MainPane: TnbDockingPaneContent;
    LeftLabel: TLabel;
    TopLabel: TLabel;
    BottomLabel: TLabel;
    MainLabel: TLabel;
    procedure MainPaneHeaderActions0Execute(Sender: TnbDockingPaneContent;
      const AActionId: string);
  end;

var
  DesignTestForm: TDesignTestForm;

implementation

{$R *.fmx}

procedure TDesignTestForm.MainPaneHeaderActions0Execute(
  Sender: TnbDockingPaneContent; const AActionId: string);
begin
  ShowMessage('Header action: ' + AActionId);
end;

end.
