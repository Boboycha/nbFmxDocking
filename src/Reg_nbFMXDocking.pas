unit Reg_nbFMXDocking;

(*
  Регистрация компонентов пакета nbFMXDocking в палитре IDE.

  TDockingPaneHost — основной контейнер дерева panes.
  TDockingTabHost  — несколько PaneHost-ов как табы (итерация 2).
  TDockingDemoPane — заглушка для тестов, только в DEBUG.
*)

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
