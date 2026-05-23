unit Reg_nbFMXDocking;

interface

procedure Register;

implementation

uses
  System.Classes,
  DesignIntf,
  nbDocking.Types,
  nbDocking.PaneHost,
  nbDocking.TabHost,
  nbDocking.Demo;

const
  PaletteName = 'nb FMX Docking';
  CardCategory = 'nb Docking Card';
  HostCategory = 'nb Docking Host';
  DockingEventsCategory = 'nb Docking Events';

procedure RegisterPaneContentDesignTime;
begin
  RegisterPropertiesInCategory(CardCategory, TnbDockingPaneContent, [
    'Caption',
    'HeaderVisible',
    'HeaderDragEnabled',
    'AlwaysShowActive',
    'HeaderBgColor',
    'HeaderTextColor'
  ]);

  RegisterPropertiesInCategory(DockingEventsCategory, TnbDockingPaneContent, [
    'OnCloseRequest',
    'OnActivateRequest',
    'OnRenamed',
    'OnHeaderChanged'
  ]);
end;

procedure RegisterPaneHostDesignTime;
begin
  RegisterPropertiesInCategory(HostCategory, TnbDockingPaneHost, [
    'BackgroundColor',
    'AutoMatchBg',
    'SplitterSize',
    'SplitterColor'
  ]);

  RegisterPropertiesInCategory(DockingEventsCategory, TnbDockingPaneHost, [
    'OnContentNeeded',
    'OnActiveLeafChanged',
    'OnContentHeaderChanged',
    'OnHeaderDrag'
  ]);
end;

procedure Register;
begin
  RegisterComponents(PaletteName, [
    TnbDockingPaneContent,
    TnbDockingPaneHost,
    TnbDockingTabHost
  ]);
  {$IFDEF DEBUG}
  RegisterComponents(PaletteName, [TnbDockingDemoPane]);
  {$ENDIF}

  RegisterPaneContentDesignTime;
  RegisterPaneHostDesignTime;
end;

end.
