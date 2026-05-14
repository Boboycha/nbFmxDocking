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
  RegisterComponents('nb FMX Docking', [TDockingPaneHost]);
  RegisterComponents('nb FMX Docking', [TDockingTabHost]);
  {$IFDEF DEBUG}
  RegisterComponents('nb FMX Docking', [TDockingDemoPane]);
  {$ENDIF}
end;

end.
