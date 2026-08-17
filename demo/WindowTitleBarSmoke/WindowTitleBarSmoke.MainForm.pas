unit WindowTitleBarSmoke.MainForm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Layouts,
  FMX.Objects, FMX.Edit, nbDocking.WindowTitleBar;

type
  TWindowTitleBarSmokeForm = class(TForm)
    RootLayout: TLayout;
    TitleBarLayout: TLayout;
    TitleBackground: TRectangle;
    BrandLabel: TLabel;
    DocumentOneButton: TButton;
    DocumentGroupButton: TButton;
    WindowButtonsLayout: TLayout;
    MinimizeButton: TButton;
    MaximizeButton: TButton;
    CloseButton: TButton;
    ContentLayout: TLayout;
    HeadingLabel: TLabel;
    SampleEdit: TEdit;
    SampleButton: TButton;
    StatusLabel: TLabel;
    WindowTitleBar: TnbWindowTitleBar;
    procedure DocumentButtonClick(Sender: TObject);
    procedure SampleButtonClick(Sender: TObject);
  end;

var
  WindowTitleBarSmokeForm: TWindowTitleBarSmokeForm;

implementation

{$R *.fmx}

procedure TWindowTitleBarSmokeForm.DocumentButtonClick(Sender: TObject);
begin
  StatusLabel.Text := TButton(Sender).Text + ' activated';
end;

procedure TWindowTitleBarSmokeForm.SampleButtonClick(Sender: TObject);
begin
  StatusLabel.Text := 'FMX button works; edit contains: ' + SampleEdit.Text;
end;

end.