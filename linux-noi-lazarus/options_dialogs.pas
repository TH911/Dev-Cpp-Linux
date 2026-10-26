unit options_dialogs;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, Forms, Controls, StdCtrls, Dialogs, Spin,
  compiler_profiles;

function EditCompilerProfiles(Owner: TComponent; Profiles: TCompilerProfiles): Boolean;
function EditEditorSettings(Owner: TComponent; var ThemeName, FontName: string;
  var FontSize, TabWidth: Integer): Boolean;

implementation

uses ui_language, editor_themes;

type
  TCompilerProfilesDialog = class(TForm)
  private
    FProfiles: TCompilerProfiles;
    FList: TListBox;
    FName, FC, FCpp, FCFlags, FCppFlags, FLink: TEdit;
    FSelected: Integer;
    FDelete: TButton;
    function StoreSelected: Boolean;
    procedure LoadSelected;
    procedure RefreshList;
    procedure SelectionChanged(Sender: TObject; User: Boolean);
    procedure NewProfile(Sender: TObject);
    procedure CopyProfile(Sender: TObject);
    procedure DeleteProfile(Sender: TObject);
    procedure AcceptProfiles(Sender: TObject);
  public
    constructor CreateProfiles(AOwner: TComponent; Profiles: TCompilerProfiles);
  end;

function LabelAt(Dialog: TForm; const Caption: string; X, Y, Width: Integer): TLabel;
begin
  Result := TLabel.Create(Dialog);
  Result.Parent := Dialog;
  Result.AutoSize := False;
  Result.Caption := Tr(Caption);
  Result.WordWrap := True;
  Result.SetBounds(X, Y, Width, 28);
end;

function ButtonAt(Dialog: TForm; const Caption: string; X, Y, Width: Integer;
  Handler: TNotifyEvent): TButton;
begin
  Result := TButton.Create(Dialog);
  Result.Parent := Dialog;
  Result.Caption := Tr(Caption);
  Result.SetBounds(X, Y, Width, 36);
  Result.OnClick := Handler;
end;

constructor TCompilerProfilesDialog.CreateProfiles(AOwner: TComponent;
  Profiles: TCompilerProfiles);
var Y: Integer; Button: TButton;

  function Field(const Caption: string): TEdit;
  begin
    LabelAt(Self, Caption, 246, Y, 630);
    Result := TEdit.Create(Self);
    Result.Parent := Self;
    Result.SetBounds(246, Y + 28, 630, 34);
    Inc(Y, 72);
  end;

begin
  inherited CreateNew(AOwner, 0);
  FProfiles := Profiles;
  FSelected := Profiles.ActiveIndex;
  Caption := Tr('Compiler Options');
  BorderStyle := bsDialog;
  Position := poMainFormCenter;
  ClientWidth := 890;
  ClientHeight := 500;
  LabelAt(Self, 'Active compiler profile:', 14, 14, 216);
  FList := TListBox.Create(Self);
  FList.Parent := Self;
  FList.SetBounds(14, 46, 216, 356);
  FList.OnSelectionChange := @SelectionChanged;
  ButtonAt(Self, '&New', 14, 412, 66, @NewProfile);
  ButtonAt(Self, '&Copy', 88, 412, 66, @CopyProfile);
  FDelete := ButtonAt(Self, '&Delete', 162, 412, 68, @DeleteProfile);
  Y := 14;
  FName := Field('Profile name:');
  FC := Field('C compiler:');
  FCpp := Field('C++ compiler:');
  FCFlags := Field('C compile flags:');
  FCppFlags := Field('C++ flags (e.g. -std=c++14):');
  FLink := Field('Linux linker flags:');
  Button := ButtonAt(Self, 'OK', 666, 452, 100, @AcceptProfiles);
  Button.Default := True;
  Button := ButtonAt(Self, 'Cancel', 776, 452, 100, nil);
  Button.Cancel := True;
  Button.ModalResult := mrCancel;
  RefreshList;
  LoadSelected;
  ActiveControl := FList;
end;

procedure TCompilerProfilesDialog.RefreshList;
var I: Integer;
begin
  FList.Items.BeginUpdate;
  try
    FList.Items.Clear;
    for I := 0 to FProfiles.Count - 1 do FList.Items.Add(FProfiles[I].Name);
    FList.ItemIndex := FSelected;
    FDelete.Enabled := FProfiles.Count > 1;
  finally FList.Items.EndUpdate; end;
end;

procedure TCompilerProfilesDialog.LoadSelected;
var P: TCompilerProfile;
begin
  if (FSelected < 0) or (FSelected >= FProfiles.Count) then Exit;
  P := FProfiles[FSelected];
  FName.Text := P.Name;
  FC.Text := P.CCompiler;
  FCpp.Text := P.CppCompiler;
  FCFlags.Text := P.CFlags;
  FCppFlags.Text := P.CppFlags;
  FLink.Text := P.LinkerFlags;
end;

function TCompilerProfilesDialog.StoreSelected: Boolean;
var P: TCompilerProfile; I: Integer; ProfileName: string;
begin
  Result := False;
  if (FSelected < 0) or (FSelected >= FProfiles.Count) then Exit;
  ProfileName := Trim(FName.Text);
  if ProfileName = '' then
  begin
    UiMessageDlg(Tr('Profile name cannot be empty.'), mtError, [mbOK], 0);
    FName.SetFocus;
    Exit;
  end;
  for I := 0 to FProfiles.Count - 1 do
    if (I <> FSelected) and SameText(FProfiles[I].Name, ProfileName) then
    begin
      UiMessageDlg(Tr('Profile names must be unique.'), mtError, [mbOK], 0);
      FName.SetFocus;
      Exit;
    end;
  if (Trim(FC.Text) = '') or (Trim(FCpp.Text) = '') then
  begin
    UiMessageDlg(Tr('Compiler command cannot be empty.'), mtError, [mbOK], 0);
    Exit;
  end;
  P := FProfiles[FSelected];
  P.Name := ProfileName;
  P.CCompiler := Trim(FC.Text);
  P.CppCompiler := Trim(FCpp.Text);
  P.CFlags := Trim(FCFlags.Text);
  P.CppFlags := Trim(FCppFlags.Text);
  P.LinkerFlags := Trim(FLink.Text);
  FList.Items[FSelected] := ProfileName;
  Result := True;
end;

procedure TCompilerProfilesDialog.SelectionChanged(Sender: TObject; User: Boolean);
var NewIndex: Integer;
begin
  if not User then Exit;
  NewIndex := FList.ItemIndex;
  if (NewIndex < 0) or (NewIndex = FSelected) then Exit;
  if not StoreSelected then begin FList.ItemIndex := FSelected; Exit; end;
  FSelected := NewIndex;
  LoadSelected;
end;

procedure TCompilerProfilesDialog.NewProfile(Sender: TObject);
begin
  if not StoreSelected then Exit;
  FSelected := FProfiles.Add(FProfiles.UniqueName(Tr('New profile')));
  RefreshList;
  LoadSelected;
  FName.SetFocus;
  FName.SelectAll;
end;

procedure TCompilerProfilesDialog.CopyProfile(Sender: TObject);
begin
  if not StoreSelected then Exit;
  FSelected := FProfiles.Add(FProfiles.UniqueName(FProfiles[FSelected].Name +
    ' ' + Tr('Copy')), FProfiles[FSelected]);
  RefreshList;
  LoadSelected;
  FName.SetFocus;
  FName.SelectAll;
end;

procedure TCompilerProfilesDialog.DeleteProfile(Sender: TObject);
begin
  if FProfiles.Count <= 1 then Exit;
  FProfiles.Delete(FSelected);
  if FSelected >= FProfiles.Count then FSelected := FProfiles.Count - 1;
  RefreshList;
  LoadSelected;
end;

procedure TCompilerProfilesDialog.AcceptProfiles(Sender: TObject);
begin
  if not StoreSelected then Exit;
  FProfiles.ActiveIndex := FSelected;
  ModalResult := mrOK;
end;

function EditCompilerProfiles(Owner: TComponent; Profiles: TCompilerProfiles): Boolean;
var Working: TCompilerProfiles; Dialog: TCompilerProfilesDialog;
begin
  Working := TCompilerProfiles.Create;
  try
    Working.Assign(Profiles);
    Dialog := TCompilerProfilesDialog.CreateProfiles(Owner, Working);
    try
      Result := Dialog.ShowModal = mrOK;
      if Result then Profiles.Assign(Working);
    finally Dialog.Free; end;
  finally Working.Free; end;
end;

function EditEditorSettings(Owner: TComponent; var ThemeName, FontName: string;
  var FontSize, TabWidth: Integer): Boolean;
var
  Dialog: TForm;
  Theme, Font: TComboBox;
  Size, Tabs: TSpinEdit;
  Button: TButton;
  I: Integer;
begin
  Dialog := TForm.CreateNew(Owner, 0);
  try
    Dialog.Caption := Tr('Editor Options');
    Dialog.BorderStyle := bsDialog;
    Dialog.Position := poMainFormCenter;
    Dialog.ClientWidth := 580;
    Dialog.ClientHeight := 350;
    LabelAt(Dialog, 'Editor theme:', 14, 14, 550);
    Theme := TComboBox.Create(Dialog);
    Theme.Parent := Dialog;
    Theme.Style := csDropDownList;
    Theme.SetBounds(14, 42, 550, 34);
    for I := 0 to EditorThemeCount - 1 do Theme.Items.Add(EditorThemeName(I));
    Theme.ItemIndex := EditorThemeIndex(ThemeName);
    LabelAt(Dialog, 'Font (monospace recommended):', 14, 88, 550);
    Font := TComboBox.Create(Dialog);
    Font.Parent := Dialog;
    Font.SetBounds(14, 116, 550, 34);
    Font.Items.Assign(Screen.Fonts);
    Font.Text := FontName;
    LabelAt(Dialog, 'Font size (1-72):', 14, 168, 266);
    Size := TSpinEdit.Create(Dialog);
    Size.Parent := Dialog;
    Size.SetBounds(14, 196, 266, 34);
    Size.MinValue := 1;
    Size.MaxValue := 72;
    Size.Value := FontSize;
    LabelAt(Dialog, 'Tab width (1-16):', 298, 168, 266);
    Tabs := TSpinEdit.Create(Dialog);
    Tabs.Parent := Dialog;
    Tabs.SetBounds(298, 196, 266, 34);
    Tabs.MinValue := 1;
    Tabs.MaxValue := 16;
    Tabs.Value := TabWidth;
    LabelAt(Dialog,
      'Consolas requires an installed font file. If unavailable, a monospace font is used.',
      14, 246, 550).Height := 44;
    Button := ButtonAt(Dialog, 'OK', 354, 300, 100, nil);
    Button.Default := True;
    Button.ModalResult := mrOK;
    Button := ButtonAt(Dialog, 'Cancel', 464, 300, 100, nil);
    Button.Cancel := True;
    Button.ModalResult := mrCancel;
    Dialog.ActiveControl := Theme;
    repeat
      Result := Dialog.ShowModal = mrOK;
      if not Result then Exit;
      if Trim(Font.Text) <> '' then Break;
      UiMessageDlg(Tr('Font name cannot be empty.'), mtError, [mbOK], 0);
    until False;
    ThemeName := EditorThemeName(Theme.ItemIndex);
    FontName := Trim(Font.Text);
    FontSize := Size.Value;
    TabWidth := Tabs.Value;
  finally Dialog.Free; end;
end;

end.
