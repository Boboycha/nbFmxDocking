unit Reg_nbFMXDocking;

interface

procedure Register;

implementation

uses
  System.Classes,
  DesignIntf,
  nbDocking.Types,
  nbDocking.PaneHost,
  nbDocking.Demo,
  nbDocking.DesignEditors;

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
    'AllowResize',
    'MinPaneWidth',
    'MinPaneHeight',
    'AlwaysShowActive',
    'CanClosePane',
    'ShowCloseButton',
    'HeaderBgColor',
    'HeaderTextColor',
    'HeaderActions'
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
    'AutoBuildDesignChildren',
    'DesignChildrenLayoutMode',
    'DesignChildrenOrientation',
    'VisibleTabs',
    'ShowAddButton',
    'TabPosition',
    'TabTextDirection',
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
    TnbDockingPaneHost
  ]);
  {$IFDEF DEBUG}
  RegisterComponents(PaletteName, [TnbDockingDemoPane]);
  {$ENDIF}

  RegisterPaneContentDesignTime;
  RegisterPaneHostDesignTime;
  RegisterDockingEditors;
end;

end.
