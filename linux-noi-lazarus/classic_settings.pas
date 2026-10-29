unit classic_settings;
{$mode objfpc}{$H+}
interface
uses Classes, Forms, Menus, LCLType;
type
  TMenuShortcuts = class
  private
    FItems: TList;
    FPaths, FDefaults: TStringList;
    procedure Collect(Item: TMenuItem; const Path: string);
  public
    constructor Create(Root: TMenuItem; const Config: string);
    destructor Destroy; override;
    function Match(Key: Word; Shift: TShiftState; out Suppress: Boolean): TMenuItem;
    procedure Edit(Owner: TComponent; const Config: string);
  end;
function EditSettingValues(Owner: TComponent; const Title: string; Values: TStrings): Boolean;
function EditEnvironment(Owner: TComponent; var Language: string; var WatchFiles, ShowReports: Boolean): Boolean;
implementation
uses SysUtils, LCLProc, Controls, StdCtrls, Dialogs, ValEdit, Graphics, IniFiles,
  ui_language, language_catalog, input_appearance;

type
  TSettingsForm = class(TForm)
  protected
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  end;
procedure TSettingsForm.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_ESCAPE) and (Shift = []) then begin
    ModalResult := mrCancel; Key := 0; Exit;
  end;
  inherited KeyDown(Key, Shift);
end;

function EditSettingValues(Owner: TComponent; const Title: string; Values: TStrings): Boolean;
var D: TForm; Grid: TValueListEditor; B: TButton;
begin
  D := TSettingsForm.CreateNew(Owner);
  D.KeyPreview := True;
  try
    D.Caption := Tr(Title); D.Position := poMainFormCenter;
    D.BorderStyle := bsDialog; D.ClientWidth := 720; D.ClientHeight := 420;
    Grid := TValueListEditor.Create(D); Grid.Parent := D;
    Grid.SetBounds(12, 12, 696, 348); Grid.Strings.Assign(Values);
    Grid.KeyOptions := []; Grid.TitleCaptions.Clear;
    Grid.TitleCaptions.Add(Tr('Command')); Grid.TitleCaptions.Add(Tr('Value'));
    Grid.ColWidths[0] := 350;
    Grid.Color := clWhite; Grid.Font.Color := clDefault;
    B := TButton.Create(D); B.Parent := D; B.SetBounds(508, 378, 90, 30);
    B.Caption := Tr('OK'); B.ModalResult := mrOK; B.Default := True;
    B := TButton.Create(D); B.Parent := D; B.SetBounds(612, 378, 96, 30);
    B.Caption := Tr('Cancel'); B.ModalResult := mrCancel; B.Cancel := True;
    Grid.Col := 1; Grid.Row := 1; D.ActiveControl := Grid;
    PrepareInputAppearance(D);
    Result := D.ShowModal = mrOK;
    if Result then begin Grid.EditorMode := False; Values.Assign(Grid.Strings); end;
  finally D.Free; end;
end;

function EditEnvironment(Owner: TComponent; var Language: string; var WatchFiles, ShowReports: Boolean): Boolean;
var D: TForm; L: TLabel; C: TComboBox; W, R: TCheckBox; B: TButton; I: Integer;
begin
  D := TForm.CreateNew(Owner);
  try
    D.Caption := Tr('Environment Options'); D.Position := poMainFormCenter;
    D.BorderStyle := bsDialog; D.ClientWidth := 490; D.ClientHeight := 244;
    L := TLabel.Create(D); L.Parent := D; L.SetBounds(16, 20, 160, 24); L.Caption := Tr('Language');
    C := TComboBox.Create(D); C.Parent := D; C.SetBounds(180, 16, 290, 30); C.Style := csDropDownList;
    for I := 0 to UiLanguageCount - 1 do begin
      C.Items.Add(UiLanguageName(I)); if UiLanguageCode(I) = Language then C.ItemIndex := I;
    end;
    W := TCheckBox.Create(D); W.Parent := D; W.SetBounds(16, 68, 454, 28);
    W.Caption := Tr('Detect external file changes'); W.Checked := WatchFiles;
    R := TCheckBox.Create(D); R.Parent := D; R.SetBounds(16, 112, 454, 28);
    R.Caption := Tr('Show report window'); R.Checked := ShowReports;
    B := TButton.Create(D); B.Parent := D; B.SetBounds(272, 190, 90, 32);
    B.Caption := Tr('OK'); B.ModalResult := mrOK; B.Default := True;
    B := TButton.Create(D); B.Parent := D; B.SetBounds(378, 190, 96, 32);
    B.Caption := Tr('Cancel'); B.ModalResult := mrCancel; B.Cancel := True;
    PrepareInputAppearance(D); Result := D.ShowModal = mrOK;
    if Result then begin
      Language := UiLanguageCode(C.ItemIndex); WatchFiles := W.Checked; ShowReports := R.Checked;
    end;
  finally D.Free; end;
end;

{$I shortcut_legacy_keys.inc}
function StableShortcutPath(Key: Word; const Fallback: string): string;
var I: Integer;
begin
  for I:=Low(LegacyShortcuts) to High(LegacyShortcuts) do
    if LegacyShortcuts[I].Key=Key then Exit(LegacyShortcuts[I].Path);
  Result:=Fallback;
end;
procedure TMenuShortcuts.Collect(Item: TMenuItem; const Path: string);
var I: Integer;
begin
  if Item.ShortCut <> 0 then begin
    FItems.Add(Item); FPaths.Add(StableShortcutPath(Item.ShortCut,Path)); FDefaults.Add(IntToStr(Item.ShortCut));
  end;
  for I := 0 to Item.Count - 1 do Collect(Item.Items[I], Path + '.' + IntToStr(I));
end;
constructor TMenuShortcuts.Create(Root: TMenuItem; const Config: string);
var Ini: TIniFile; I, Value: Integer;
begin
  inherited Create;
  FItems := TList.Create; FPaths := TStringList.Create; FDefaults := TStringList.Create;
  Collect(Root, 'menu'); Ini := TIniFile.Create(Config);
  try
    for I := 0 to FItems.Count - 1 do begin
      Value := Ini.ReadInteger('Shortcuts', FPaths[I], TMenuItem(FItems[I]).ShortCut);
      if (Value >= 0) and (Value <= High(TShortCut)) then TMenuItem(FItems[I]).ShortCut := Value;
    end;
  finally Ini.Free; end;
end;
destructor TMenuShortcuts.Destroy;
begin
  FDefaults.Free; FPaths.Free; FItems.Free; inherited Destroy;
end;
function TMenuShortcuts.Match(Key: Word; Shift: TShiftState; out Suppress: Boolean): TMenuItem;
var I: Integer; Sc: TShortCut; Item: TMenuItem;
begin
  Result := nil; Suppress := False; Sc := ShortCut(Key, Shift * [ssCtrl, ssAlt, ssShift]);
  for I := 0 to FItems.Count - 1 do begin
    Item := TMenuItem(FItems[I]);
    if (Item.ShortCut <> 0) and (Item.ShortCut = Sc) then begin Result := Item; Exit; end;
    if (Sc = StrToInt(FDefaults[I])) and (Sc <> Item.ShortCut) then Suppress := True;
  end;
end;
procedure TMenuShortcuts.Edit(Owner: TComponent; const Config: string);
var Values, Used: TStringList; I: Integer; Sc: TShortCut; Key: Word;
  Shift: TShiftState; Ini: TIniFile; Valid: Boolean;
  function CommandLabel(Item: TMenuItem): string;
  begin
    Result := '';
    while Item <> nil do begin
      if Item.Caption <> '' then begin
        if Result <> '' then Result := ' > ' + Result;
        Result := StringReplace(Item.Caption, '&', '', [rfReplaceAll]) + Result;
      end;
      Item := Item.Parent;
    end;
  end;

begin
  Values := TStringList.Create; Used := TStringList.Create;
  try
    for I := 0 to FItems.Count - 1 do
      Values.Add(CommandLabel(TMenuItem(FItems[I])) + '=' + ShortCutToText(TMenuItem(FItems[I]).ShortCut));
    while EditSettingValues(Owner, 'Shortcut Options', Values) do begin
      Used.Clear; Valid := Values.Count = FItems.Count;
      for I := 0 to Values.Count - 1 do begin
        Sc := TextToShortCut(Trim(Values.ValueFromIndex[I]));
        ShortCutToKey(Sc, Key, Shift);
        if (Trim(Values.ValueFromIndex[I]) <> '') and
          ((Sc = 0) or (((Shift * [ssCtrl, ssAlt]) = []) and not (Key in [VK_F1..VK_F12]))) then Valid := False;
        if Sc <> 0 then begin
          if Used.IndexOf(IntToStr(Sc)) >= 0 then Valid := False;
          Used.Add(IntToStr(Sc));
        end;
      end;
      if not Valid then begin
        UiMessageDlg(Tr('Use unique Ctrl/Alt or function-key shortcuts; leave a value empty to disable it.'), mtError, [mbOK], 0);
        Continue;
      end;
      Ini := TIniFile.Create(Config);
      try
        for I := 0 to FItems.Count - 1 do begin
          Sc := TextToShortCut(Trim(Values.ValueFromIndex[I]));
          TMenuItem(FItems[I]).ShortCut := Sc;
          Ini.WriteInteger('Shortcuts', FPaths[I], Sc);
        end;
      finally Ini.Free; end;
      Break;
    end;
  finally Used.Free; Values.Free; end;
end;
end.
