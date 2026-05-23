unit Reg_nbFMXDocking;

interface

procedure Register;

implementation

uses
  System.Classes, System.SysUtils,
  DesignIntf, DesignEditors,
  nbDocking.Types,
  nbDocking.PaneHost,
  nbDocking.TabHost,
  nbDocking.Demo;

const
  PaletteName = 'nb FMX Docking';
  CardCategory = 'nb Docking Card';
  HostCategory = 'nb Docking Host';
  DockingEventsCategory = 'nb Docking Events';

type
  TnbDockingPaneHostEditor = class(TComponentEditor)
  public
    procedure ExecuteVerb(Index: Integer); override;
    function GetVerb(Index: Integer): string; override;
    function GetVerbCount: Integer; override;
  end;

procedure TnbDockingPaneHostEditor.ExecuteVerb(Index: Integer);
var
  Host: TnbDockingPaneHost;
  Content: TnbDockingPaneContent;
  I, PaneCount: Integer;
begin
  if Index <> 0 then
    Exit;

  Host := Component as TnbDockingPaneHost;
  Content := Designer.CreateComponent(TnbDockingPaneContent, Host, 0, 0, 0, 0)
    as TnbDockingPaneContent;
  Content.Parent := Host;

  PaneCount := 0;
  for I := 0 to Host.ChildrenCount - 1 do
    if Host.Children[I] is TnbDockingPaneContent then
      Inc(PaneCount);

  Content.Caption := Format('Pane %d', [PaneCount]);
  Designer.SelectComponent(Content);
  Designer.Modified;
end;

function TnbDockingPaneHostEditor.GetVerb(Index: Integer): string;
begin
  case Index of
    0: Result := 'Add Pane Content';
  else
    Result := inherited GetVerb(Index);
  end;
end;

function TnbDockingPaneHostEditor.GetVerbCount: Integer;
begin
  Result := 1;
end;

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
    'AutoBuildDesignChildren',
    'DesignChildrenOrientation',
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
  RegisterComponentEditor(TnbDockingPaneHost, TnbDockingPaneHostEditor);
end;

end.
