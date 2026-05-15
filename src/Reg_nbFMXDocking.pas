unit Reg_nbFMXDocking;

interface

procedure Register;

implementation

uses
  System.Classes,
  nbDocking.PaneHost,
  nbDocking.TabHost,
  nbDocking.Demo;

procedure Register;
begin
  RegisterComponents('nb FMX Docking', [TnbDockingPaneHost]);
  RegisterComponents('nb FMX Docking', [TnbDockingTabHost]);
  {$IFDEF DEBUG}
  RegisterComponents('nb FMX Docking', [TnbDockingDemoPane]);
  {$ENDIF}
end;

end.
