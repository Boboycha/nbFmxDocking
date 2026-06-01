unit nbDocking.DesignEditors;

interface

procedure RegisterDockingEditors;

implementation

uses
  Winapi.Windows,
  System.Classes, System.SysUtils, System.Types, System.TypInfo,
  System.Generics.Collections,
  FMX.Types, FMX.Controls,
  FMX.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Graphics,
  Vcl.Buttons,
  DesignIntf, DesignEditors,
  nbDocking.Types,
  nbDocking.PaneHost;

type
  TnbDockingPaneHostEditor = class(TComponentEditor)
  public
    procedure ExecuteVerb(Index: Integer); override;
    function GetVerb(Index: Integer): string; override;
    function GetVerbCount: Integer; override;
  end;

  TnbDockingPaneContentEditor = class(TComponentEditor)
  public
    procedure ExecuteVerb(Index: Integer); override;
    function GetVerb(Index: Integer): string; override;
    function GetVerbCount: Integer; override;
  end;

  TnbDockingHeaderGlyphProperty = class(TStringProperty)
  public
    procedure Edit; override;
    function GetAttributes: TPropertyAttributes; override;
    procedure GetValues(Proc: TGetStrProc); override;
  end;

  TMdl2GlyphPicker = class(TForm)
  private
    FAllValues: TStringList;
    FSearchEdit: TEdit;
    FListBox: TListBox;
    FSelectedValue: string;
    procedure ApplyFilter;
    function CurrentValue: string;
    procedure HandleSearchChange(Sender: TObject);
    procedure HandleListDblClick(Sender: TObject);
    procedure HandleListDrawItem(Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState);
    procedure HandleOkClick(Sender: TObject);
    procedure HandleCancelClick(Sender: TObject);
    procedure SelectValue(const AValue: string);
  public
    constructor CreatePicker(AOwner: TComponent);
    destructor Destroy; override;
    function Execute(const ACurrentValue: string): Boolean;
    property SelectedValue: string read FSelectedValue;
  end;

function PaneCount(AHost: TnbDockingPaneHost): Integer;
var
  I: Integer;
begin
  Result := 0;
  if AHost = nil then
    Exit;

  for I := 0 to AHost.ChildrenCount - 1 do
    if AHost.Children[I] is TnbDockingPaneContent then
      Inc(Result);
end;

function NextPaneCaption(AHost: TnbDockingPaneHost): string;
var
  RootHost: TnbDockingPaneHost;
  MaxNo: Integer;

  function RootHostOf(AStartHost: TnbDockingPaneHost): TnbDockingPaneHost;
  var
    Obj: TFmxObject;
  begin
    Result := AStartHost;
    Obj := AStartHost;
    while Obj <> nil do
    begin
      if Obj is TnbDockingPaneHost then
        Result := TnbDockingPaneHost(Obj);
      Obj := Obj.Parent;
    end;
  end;

  function MaxPaneCaptionNo(AObject: TFmxObject): Integer;
  var
    I, N, ChildMax: Integer;
    S: string;
  begin
    Result := 0;
    if AObject = nil then
      Exit;

    if AObject is TnbDockingPaneContent then
    begin
      S := TnbDockingPaneContent(AObject).Caption;
      if (Copy(S, 1, 5) = 'Pane ')
         and TryStrToInt(Copy(S, 6, MaxInt), N) then
        Result := N;
    end;

    for I := 0 to AObject.ChildrenCount - 1 do
    begin
      ChildMax := MaxPaneCaptionNo(AObject.Children[I]);
      if ChildMax > Result then
        Result := ChildMax;
    end;
  end;

begin
  RootHost := RootHostOf(AHost);
  MaxNo := MaxPaneCaptionNo(RootHost);
  if MaxNo < PaneCount(RootHost) then
    MaxNo := PaneCount(RootHost);
  Result := Format('Pane %d', [MaxNo + 1]);
end;

function ParentHostOf(AContent: TnbDockingPaneContent): TnbDockingPaneHost;
begin
  Result := nil;
  if (AContent <> nil) and (AContent.Parent is TnbDockingPaneHost) then
    Result := TnbDockingPaneHost(AContent.Parent);
end;

function FirstNestedHostOf(AContent: TnbDockingPaneContent): TnbDockingPaneHost;
var
  I: Integer;
begin
  Result := nil;
  if AContent = nil then
    Exit;

  for I := 0 to AContent.ChildrenCount - 1 do
    if AContent.Children[I] is TnbDockingPaneHost then
      Exit(TnbDockingPaneHost(AContent.Children[I]));
end;

function LastPaneInsertIndex(AHost: TnbDockingPaneHost): Integer;
var
  I: Integer;
begin
  Result := 0;
  if AHost = nil then
    Exit;

  Result := AHost.ChildrenCount;
  for I := AHost.ChildrenCount - 1 downto 0 do
    if AHost.Children[I] is TnbDockingPaneContent then
      Exit(AHost.Children[I].Index + 1);
end;

procedure CopyPaneSize(ASource, ATarget: TnbDockingPaneContent);
begin
  if (ASource = nil) or (ATarget = nil) then
    Exit;

  ATarget.Width := ASource.Width;
  ATarget.Height := ASource.Height;
end;

procedure MakeTransparentContainer(AContent: TnbDockingPaneContent);
begin
  if AContent = nil then
    Exit;

  AContent.HeaderVisible := False;
  AContent.Fill.Kind := TBrushKind.None;
  AContent.Stroke.Kind := TBrushKind.None;
  AContent.Stroke.Thickness := 0;
  AContent.Padding.Rect := RectF(0, 0, 0, 0);
  AContent.XRadius := 0;
  AContent.YRadius := 0;
end;

procedure NormalizePaneContainers(AObject: TFmxObject);
var
  I: Integer;
begin
  if AObject = nil then
    Exit;

  if (AObject is TnbDockingPaneContent)
     and (FirstNestedHostOf(TnbDockingPaneContent(AObject)) <> nil) then
    MakeTransparentContainer(TnbDockingPaneContent(AObject));

  for I := 0 to AObject.ChildrenCount - 1 do
    NormalizePaneContainers(AObject.Children[I]);
end;

function CreatePaneContent(ADesigner: IDesigner;
  AHost: TnbDockingPaneHost): TnbDockingPaneContent;
var
  Caption: string;
begin
  Caption := NextPaneCaption(AHost);
  Result := ADesigner.CreateComponent(TnbDockingPaneContent, AHost, 0, 0, 0, 0)
    as TnbDockingPaneContent;
  Result.Caption := Caption;
end;

procedure PlaceChild(AParent, AChild: TFmxObject; AIndex: Integer);
begin
  if (AParent = nil) or (AChild = nil) then
    Exit;

  if AChild.Parent = AParent then
    AChild.Index := AIndex
  else
    AParent.InsertObject(AIndex, AChild);
end;

function InsertPaneContent(ADesigner: IDesigner; AHost: TnbDockingPaneHost;
  AAfter: TnbDockingPaneContent; AOrientation: TPaneOrientation)
  : TnbDockingPaneContent;
var
  InsertIndex: Integer;
  SavedAutoBuild: Boolean;
begin
  Result := nil;
  if (ADesigner = nil) or (AHost = nil) then
    Exit;

  SavedAutoBuild := AHost.AutoBuildDesignChildren;
  if SavedAutoBuild then
    AHost.AutoBuildDesignChildren := False;
  try
    if AAfter <> nil then
      InsertIndex := AAfter.Index + 1
    else
      InsertIndex := LastPaneInsertIndex(AHost);

    AHost.DesignChildrenOrientation := AOrientation;
    Result := CreatePaneContent(ADesigner, AHost);
    PlaceChild(AHost, Result, InsertIndex);
    CopyPaneSize(AAfter, Result);
  finally
    if SavedAutoBuild then
      AHost.AutoBuildDesignChildren := True;
  end;

  if Result <> nil then
    ADesigner.SelectComponent(Result);
  ADesigner.Modified;
end;

procedure MoveUserChildrenToContent(ASource, ATarget: TnbDockingPaneContent;
  AExclude: TFmxObject);
var
  Items: TList<TFmxObject>;
  Child: TFmxObject;
  I: Integer;
begin
  if (ASource = nil) or (ATarget = nil) then
    Exit;

  Items := TList<TFmxObject>.Create;
  try
    for I := 0 to ASource.ChildrenCount - 1 do
    begin
      Child := ASource.Children[I];
      if (Child <> ASource.Header)
         and (Child <> AExclude)
         and ((ASource.Footer = nil) or (Child <> ASource.Footer)) then
        Items.Add(Child);
    end;

    for Child in Items do
      Child.Parent := ATarget;
  finally
    Items.Free;
  end;
end;

function SplitPaneInside(ADesigner: IDesigner; AContent: TnbDockingPaneContent;
  AOrientation: TPaneOrientation): TnbDockingPaneContent;
var
  OuterHost, InnerHost: TnbDockingPaneHost;
  FirstContent: TnbDockingPaneContent;
  SavedCaption: string;
  SavedAutoBuild: Boolean;
begin
  Result := nil;
  if (ADesigner = nil) or (AContent = nil) then
    Exit;

  InnerHost := FirstNestedHostOf(AContent);
  if InnerHost <> nil then
  begin
    MakeTransparentContainer(AContent);
    Exit(InsertPaneContent(ADesigner, InnerHost, nil, AOrientation));
  end;

  SavedCaption := AContent.Caption;
  OuterHost := ParentHostOf(AContent);

  InnerHost := ADesigner.CreateComponent(TnbDockingPaneHost, AContent, 0, 0, 0, 0)
    as TnbDockingPaneHost;
  InnerHost.Align := TAlignLayout.Client;
  if OuterHost <> nil then
  begin
    InnerHost.SplitterSize := OuterHost.SplitterSize;
    InnerHost.SplitterColor := OuterHost.SplitterColor;
    InnerHost.BackgroundColor := OuterHost.BackgroundColor;
  end;

  SavedAutoBuild := InnerHost.AutoBuildDesignChildren;
  if SavedAutoBuild then
    InnerHost.AutoBuildDesignChildren := False;
  try
    InnerHost.DesignChildrenOrientation := AOrientation;
    AContent.AddObject(InnerHost);

    FirstContent := CreatePaneContent(ADesigner, InnerHost);
    FirstContent.Caption := SavedCaption;
    PlaceChild(InnerHost, FirstContent, 0);
    FirstContent.Width := AContent.Width;
    FirstContent.Height := AContent.Height;

    MoveUserChildrenToContent(AContent, FirstContent, InnerHost);

    Result := CreatePaneContent(ADesigner, InnerHost);
    PlaceChild(InnerHost, Result, 1);
    CopyPaneSize(FirstContent, Result);

    MakeTransparentContainer(AContent);
  finally
    if SavedAutoBuild then
      InnerHost.AutoBuildDesignChildren := True;
  end;

  if Result <> nil then
    ADesigner.SelectComponent(Result);
  ADesigner.Modified;
end;

function SplitPaneContent(ADesigner: IDesigner; AContent: TnbDockingPaneContent;
  AOrientation: TPaneOrientation): TnbDockingPaneContent;
var
  Host: TnbDockingPaneHost;
begin
  Result := nil;
  Host := ParentHostOf(AContent);
  if Host = nil then
    Exit;

  if (PaneCount(Host) <= 1) or (Host.DesignChildrenOrientation = AOrientation) then
    Result := InsertPaneContent(ADesigner, Host, AContent, AOrientation)
  else
    Result := SplitPaneInside(ADesigner, AContent, AOrientation);
end;

procedure DeletePaneContent(ADesigner: IDesigner; AContent: TnbDockingPaneContent);
var
  Host: TnbDockingPaneHost;
begin
  if (ADesigner = nil) or (AContent = nil) then
    Exit;

  Host := ParentHostOf(AContent);
  if Host <> nil then
    ADesigner.SelectComponent(Host)
  else
    ADesigner.ClearSelection;

  AContent.Free;
  ADesigner.Modified;
end;

procedure TnbDockingPaneHostEditor.ExecuteVerb(Index: Integer);
var
  Host: TnbDockingPaneHost;
begin
  Host := Component as TnbDockingPaneHost;
  case Index of
    0: InsertPaneContent(Designer, Host, nil, Host.DesignChildrenOrientation);
    1:
      begin
        NormalizePaneContainers(Host);
        Designer.Modified;
      end;
  end;
end;

function TnbDockingPaneHostEditor.GetVerb(Index: Integer): string;
begin
  case Index of
    0: Result := 'Add Pane Content';
    1: Result := 'Normalize Pane Containers';
  else
    Result := inherited GetVerb(Index);
  end;
end;

function TnbDockingPaneHostEditor.GetVerbCount: Integer;
begin
  Result := 2;
end;

procedure TnbDockingPaneContentEditor.ExecuteVerb(Index: Integer);
var
  Content: TnbDockingPaneContent;
  Host: TnbDockingPaneHost;
begin
  Content := Component as TnbDockingPaneContent;
  case Index of
    0: SplitPaneContent(Designer, Content, poHorizontal);
    1: SplitPaneContent(Designer, Content, poVertical);
    2: DeletePaneContent(Designer, Content);
    3:
      begin
        Host := ParentHostOf(Content);
        if Host <> nil then
          Designer.SelectComponent(Host);
      end;
  end;
end;

function TnbDockingPaneContentEditor.GetVerb(Index: Integer): string;
begin
  case Index of
    0: Result := 'Split Pane Right';
    1: Result := 'Split Pane Below';
    2: Result := 'Delete Pane';
    3: Result := 'Select Parent Host';
  else
    Result := inherited GetVerb(Index);
  end;
end;

function TnbDockingPaneContentEditor.GetVerbCount: Integer;
begin
  Result := 4;
end;

{ TnbDockingHeaderGlyphProperty }

function TnbDockingHeaderGlyphProperty.GetAttributes: TPropertyAttributes;
begin
  Result := inherited GetAttributes + [paDialog];
end;

procedure AddHeaderGlyphValues(AValues: TStrings);
begin
  AValues.Add('');
  AValues.Add('plus');
  AValues.Add('close');
  AValues.Add('save');
  AValues.Add('delete');
  AValues.Add('edit');
  AValues.Add('copy');
  AValues.Add('paste');
  AValues.Add('download');
  AValues.Add('refresh');
  AValues.Add('play');
  AValues.Add('back');
  AValues.Add('select');
  AValues.Add('key');
  AValues.Add('server');
  AValues.Add('broadcast');
  AValues.Add('sftp');
  AValues.Add('folder');
  AValues.Add('focus');
  AValues.Add('scripts');
  AValues.Add('theme');
end;

procedure TnbDockingHeaderGlyphProperty.Edit;
var
  Picker: TMdl2GlyphPicker;
begin
  Picker := TMdl2GlyphPicker.CreatePicker(nil);
  try
    if Picker.Execute(GetValue) then
      SetValue(Picker.SelectedValue);
  finally
    Picker.Free;
  end;
end;

procedure TnbDockingHeaderGlyphProperty.GetValues(Proc: TGetStrProc);
var
  I: Integer;
  Values: TStringList;
begin
  Values := TStringList.Create;
  try
    AddHeaderGlyphValues(Values);
    for I := 0 to Values.Count - 1 do
      Proc(Values[I]);
  finally
    Values.Free;
  end;
end;

{ TMdl2GlyphPicker }

constructor TMdl2GlyphPicker.CreatePicker(AOwner: TComponent);
var
  ButtonsPanel: TPanel;
  OkButton, CancelButton: TSpeedButton;
begin
  inherited CreateNew(AOwner);

  Caption := 'Select header glyph';
  BorderStyle := bsSizeable;
  Position := poScreenCenter;
  ClientWidth := 560;
  ClientHeight := 620;
  Constraints.MinWidth := 420;
  Constraints.MinHeight := 360;

  FAllValues := TStringList.Create;
  AddHeaderGlyphValues(FAllValues);

  FSearchEdit := TEdit.Create(Self);
  FSearchEdit.Parent := Self;
  FSearchEdit.Align := alTop;
  FSearchEdit.Height := 28;
  FSearchEdit.Margins.SetBounds(8, 8, 8, 4);
  FSearchEdit.AlignWithMargins := True;
  FSearchEdit.TextHint := 'Search by name or code';
  FSearchEdit.OnChange := HandleSearchChange;

  ButtonsPanel := TPanel.Create(Self);
  ButtonsPanel.Parent := Self;
  ButtonsPanel.Align := alBottom;
  ButtonsPanel.Height := 48;
  ButtonsPanel.BevelOuter := bvNone;

  OkButton := TSpeedButton.Create(Self);
  OkButton.Parent := ButtonsPanel;
  OkButton.Caption := 'OK';
  OkButton.SetBounds(ClientWidth - 178, 10, 76, 28);
  OkButton.Anchors := [akTop, akRight];
  OkButton.OnClick := HandleOkClick;

  CancelButton := TSpeedButton.Create(Self);
  CancelButton.Parent := ButtonsPanel;
  CancelButton.Caption := 'Cancel';
  CancelButton.SetBounds(ClientWidth - 94, 10, 76, 28);
  CancelButton.Anchors := [akTop, akRight];
  CancelButton.OnClick := HandleCancelClick;

  FListBox := TListBox.Create(Self);
  FListBox.Parent := Self;
  FListBox.Align := alClient;
  FListBox.Margins.SetBounds(8, 0, 8, 0);
  FListBox.AlignWithMargins := True;
  FListBox.ItemHeight := 30;
  FListBox.Style := lbOwnerDrawFixed;
  FListBox.OnDblClick := HandleListDblClick;
  FListBox.OnDrawItem := HandleListDrawItem;

  ApplyFilter;
end;

destructor TMdl2GlyphPicker.Destroy;
begin
  FAllValues.Free;
  inherited;
end;

procedure TMdl2GlyphPicker.ApplyFilter;
var
  I: Integer;
  Needle, Value: string;
begin
  Needle := Trim(FSearchEdit.Text);
  FListBox.Items.BeginUpdate;
  try
    FListBox.Items.Clear;
    for I := 0 to FAllValues.Count - 1 do
    begin
      Value := FAllValues[I];
      if (Needle = '') or
        (Pos(UpperCase(Needle), UpperCase(Value)) > 0) then
        FListBox.Items.Add(Value);
    end;

    if FListBox.Items.Count > 0 then
      FListBox.ItemIndex := 0;
  finally
    FListBox.Items.EndUpdate;
  end;
end;

function TMdl2GlyphPicker.CurrentValue: string;
begin
  Result := '';
  if (FListBox.ItemIndex >= 0) and
    (FListBox.ItemIndex < FListBox.Items.Count) then
    Result := FListBox.Items[FListBox.ItemIndex];
end;

function TMdl2GlyphPicker.Execute(const ACurrentValue: string): Boolean;
begin
  SelectValue(ACurrentValue);
  Result := ShowModal = mrOk;
  if Result then
    FSelectedValue := CurrentValue;
end;

procedure TMdl2GlyphPicker.HandleListDblClick(Sender: TObject);
begin
  if CurrentValue <> '' then
    ModalResult := mrOk;
end;

procedure TMdl2GlyphPicker.HandleOkClick(Sender: TObject);
begin
  ModalResult := mrOk;
end;

procedure TMdl2GlyphPicker.HandleCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TMdl2GlyphPicker.HandleListDrawItem(Control: TWinControl;
  Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  Value: string;
  TextRect: TRect;
begin
  Value := FListBox.Items[Index];
  FListBox.Canvas.FillRect(Rect);

  FListBox.Canvas.Font.Assign(Font);
  FListBox.Canvas.Font.Color := clWindowText;
  if odSelected in State then
    FListBox.Canvas.Font.Color := clHighlightText;
  TextRect := Rect;
  TextRect.Left := Rect.Left + 10;
  DrawText(FListBox.Canvas.Handle, PChar(Value), -1, TextRect,
    DT_SINGLELINE or DT_VCENTER or DT_END_ELLIPSIS);
end;

procedure TMdl2GlyphPicker.HandleSearchChange(Sender: TObject);
begin
  ApplyFilter;
end;

procedure TMdl2GlyphPicker.SelectValue(const AValue: string);
var
  I: Integer;
begin
  if AValue = '' then
  begin
    FListBox.ItemIndex := 0;
    Exit;
  end;

  I := FListBox.Items.IndexOf(AValue);
  if I >= 0 then
  begin
    FListBox.ItemIndex := I;
    Exit;
  end;
end;

procedure RegisterDockingEditors;
begin
  RegisterComponentEditor(TnbDockingPaneHost, TnbDockingPaneHostEditor);
  RegisterComponentEditor(TnbDockingPaneContent, TnbDockingPaneContentEditor);
  RegisterPropertyEditor(TypeInfo(string), TDockingPaneHeaderAction, 'Glyph',
    TnbDockingHeaderGlyphProperty);
end;

end.
