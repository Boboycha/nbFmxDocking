program WindowTitleBarSmoke;

uses
  System.StartUpCopy,
  FMX.Forms,
  WindowTitleBarSmoke.MainForm in 'WindowTitleBarSmoke.MainForm.pas' {WindowTitleBarSmokeForm};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TWindowTitleBarSmokeForm, WindowTitleBarSmokeForm);
  Application.Run;
end.