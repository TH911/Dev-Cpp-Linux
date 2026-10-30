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
implementation
uses SysUtils, LCLProc, Controls, StdCtrls, Dialogs, ValEdit, Graphics, IniFiles,
  ui_language, language_catalog, input_appearance, shortcut_dialog;

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
  if Item.Name='DynamicRecent' then Exit;
  if (Item.ShortCut<>0) or (Item.Name='CommandSaveAs') or ((Item.Count=0) and Assigned(Item.OnClick)) then begin
    FItems.Add(Item);
    { Configuration identities belong to commands, not their new default key. }
    if Item.Name = 'CommandSaveAs' then FPaths.Add('menu.0.3')
    else if Item.Name = 'CommandSaveAll' then FPaths.Add('menu.0.4')
    else if Item.Name = 'CommandFormat' then FPaths.Add('command.format')
    else FPaths.Add(StableShortcutPath(Item.ShortCut,Path));
    FDefaults.Add(IntToStr(Item.ShortCut));
  end;
  for I := 0 to Item.Count - 1 do Collect(Item.Items[I], Path + '.' + IntToStr(I));
end;
constructor TMenuShortcuts.Create(Root: TMenuItem; const Config: string);
var Ini: TIniFile; I, Value: Integer; ChangedDefaults: Boolean;
begin
  inherited Create;
  FItems := TList.Create; FPaths := TStringList.Create; FDefaults := TStringList.Create;
  Collect(Root, 'menu'); Ini := TIniFile.Create(Config);
  try
    ChangedDefaults := Ini.ReadInteger('Shortcuts', 'DefaultsVersion', 0) < 2;
    if ChangedDefaults then begin
      { Only known old factory values migrate; explicit remaps/disabled keys stay. }
      if Ini.ReadInteger('Shortcuts', 'menu.0.3', -1) = 24659 then
        Ini.WriteInteger('Shortcuts', 'menu.0.3', 0);
      if Ini.ReadInteger('Shortcuts', 'menu.0.4', -1) = 24641 then
        Ini.WriteInteger('Shortcuts', 'menu.0.4', 24659);
      Ini.WriteInteger('Shortcuts', 'DefaultsVersion', 2);
    end;
    for I := 0 to FItems.Count - 1 do begin
      Value := Ini.ReadInteger('Shortcuts', FPaths[I], TMenuItem(FItems[I]).ShortCut);
      if (Value >= 0) and (Value <= High(TShortCut)) then TMenuItem(FItems[I]).ShortCut := Value;
    end;
    for I := 0 to FItems.Count - 1 do
      if (TMenuItem(FItems[I]).Name = 'CommandFormat') and
        not Ini.ValueExists('Shortcuts', FPaths[I]) then begin
        for Value := 0 to FItems.Count - 1 do
          if (Value <> I) and (TMenuItem(FItems[Value]).ShortCut = 24641) then
            TMenuItem(FItems[I]).ShortCut := 0;
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
var Values, Used, Labels: TStringList; I: Integer; Sc: TShortCut; Key: Word;
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
  Values := TStringList.Create;Used := TStringList.Create;Labels:=TStringList.Create;
  try
    for I := 0 to FItems.Count - 1 do begin
      Sc := TMenuItem(FItems[I]).ShortCut;
      { LCL 2.0.6 renders zero as 'Unknown'; the editable disabled value is blank. }
      Labels.Add(CommandLabel(TMenuItem(FItems[I])));
      if Sc=0 then Values.Add('') else Values.Add(ShortCutToText(Sc));
    end;
    while EditShortcutValues(Owner,Labels,Values,FDefaults) do begin
      Used.Clear; Valid := Values.Count = FItems.Count;
      for I := 0 to Values.Count - 1 do begin
        Sc := TextToShortCut(Trim(Values[I]));
        ShortCutToKey(Sc, Key, Shift);
        if (Trim(Values[I]) <> '') and
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
          Sc := TextToShortCut(Trim(Values[I]));
          TMenuItem(FItems[I]).ShortCut := Sc;
          Ini.WriteInteger('Shortcuts', FPaths[I], Sc);
        end;
      finally Ini.Free; end;
      Break;
    end;
  finally Labels.Free;Used.Free; Values.Free; end;
end;
end.
