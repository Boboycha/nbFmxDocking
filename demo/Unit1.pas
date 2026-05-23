unit Unit1;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  nbDocking.Types, nbDocking.Demo,nbDocking.TabHost, FMX.Layouts, nbDocking.PaneHost,
  FMX.StdCtrls, FMX.Controls.Presentation, FMX.Objects, FMX.Memo;

type
  TForm1 = class(TForm)
    nbDockingPaneHost1: TnbDockingPaneHost;
    nbDockingPaneContent1: TnbDockingPaneContent;
    nbDockingPaneContent2: TnbDockingPaneContent;
    procedure nbDockingPaneContent1HeaderActions0Execute(
      Sender: TnbDockingPaneContent; const AActionId: string);
  private
 { Private declarations }


  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.fmx}

procedure TForm1.nbDockingPaneContent1HeaderActions0Execute(
  Sender: TnbDockingPaneContent; const AActionId: string);
begin
  ShowMessage( 'ID кнопки: '+AActionId);
end;

end.
