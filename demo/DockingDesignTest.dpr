program DockingDesignTest;

uses
  System.StartUpCopy,
  FMX.Forms,
  DesignTest.MainForm in 'DesignTest.MainForm.pas' {DesignTestForm};

begin
  Application.Initialize;
  Application.CreateForm(TDesignTestForm, DesignTestForm);
  Application.Run;
end.
