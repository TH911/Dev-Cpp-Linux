unit ui_language;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, Dialogs;

type
  TUiLanguage = string;

const
  ulChinese = 'zh';
  ulEnglish = 'en';

procedure InitUiLanguage(const ConfigFileName: string);
function CurrentUiLanguage: TUiLanguage;
procedure SetUiLanguage(ALanguage: TUiLanguage);
procedure ApplyUiLanguage(Root: TComponent);
function UiText(const EnglishText: string): string;
function UiFormat(const EnglishFormat: string; const Args: array of const): string;
function Tr(const EnglishText: string): string;
function TrFormat(const EnglishFormat: string; const Args: array of const): string;
function UiMessageDlg(const AMessage: string; DlgType: TMsgDlgType;
  Buttons: TMsgDlgButtons; HelpCtx: Longint): Integer;
function UiInputQuery(const ACaption, APrompt: string; var Value: string): Boolean;

implementation

uses
  TypInfo, IniFiles, Contnrs, ComCtrls, Forms, Controls, StdCtrls,
  LCLType, Math, translation_catalog, language_catalog, app_version, input_appearance;

type
  TPhrase = class
    English: string;
  end;

  TOriginalText = class
    Target: TComponent;
    PropertyName: string;
    ColumnIndex: Integer;
    Original: string;
    LastApplied: string;
  end;

  TLanguageManager = class(TComponent)
  private
    FEntries: TObjectList;
    procedure TranslateProperty(Target: TComponent; const PropertyName: string;
      ColumnIndex: Integer = -1);
  protected
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Apply(Root: TComponent);
  end;

var
  SelectedLanguage: TUiLanguage = ulChinese;
  LanguageConfigFile: string = '';
  LanguageManager: TLanguageManager = nil;
  ReversePhrases: TStringList = nil;

function UiText(const EnglishText: string): string;
var I: Integer; Phrase: TPhrase;
begin
  Result := EnglishText;
  { Match the original Simplified Chinese Tools menu label. }
  if (SelectedLanguage = ulChinese) and (EnglishText = 'Package Manager') then Exit;
  if SelectedLanguage = ulChinese then Result := TranslateChinese(EnglishText);
  if (Result = EnglishText) and (SelectedLanguage <> ulEnglish) then
    Result := UpstreamUiText(SelectedLanguage, EnglishText);
  if Result <> EnglishText then
  begin
    if ReversePhrases = nil then
    begin
      ReversePhrases := TStringList.Create;
      ReversePhrases.Sorted := True;
      ReversePhrases.CaseSensitive := True;
    end;
    I := ReversePhrases.IndexOf(Result);
    if I < 0 then
    begin
      Phrase := TPhrase.Create;
      Phrase.English := EnglishText;
      ReversePhrases.AddObject(Result, Phrase);
    end;
  end;
end;

function CanonicalUiText(const Text: string): string;
var I: Integer;
begin
  Result := TranslateEnglish(Text);
  if (Result = Text) and (ReversePhrases <> nil) then
  begin
    I := ReversePhrases.IndexOf(Text);
    if I >= 0 then Result := TPhrase(ReversePhrases.Objects[I]).English;
  end;
end;

function UiFormat(const EnglishFormat: string; const Args: array of const): string;
begin
  Result := Format(UiText(EnglishFormat), Args);
end;

function Tr(const EnglishText: string): string;
begin
  Result := UiText(EnglishText);
end;

function TrFormat(const EnglishFormat: string; const Args: array of const): string;
begin
  Result := UiFormat(EnglishFormat, Args);
end;

function UiMessageDlg(const AMessage: string; DlgType: TMsgDlgType;
  Buttons: TMsgDlgButtons; HelpCtx: Longint): Integer;
var
  DialogForm: TForm;
  MessageLabel: TLabel;
  DialogButton: TButton;
  ButtonText: string;
  ButtonKind: TMsgDlgBtn;
  ButtonList: TList;
  PreferredWidth, PreferredHeight, TotalWidth, ButtonHeight,
    ButtonTop, ButtonLeft, ButtonOrdinal, ButtonResult: Integer;
begin
  DialogForm := TForm.CreateNew(nil, 0);
  ButtonList := TList.Create;
  try
    DialogForm.Caption := AppName;
    DialogForm.HelpContext := HelpCtx;
    DialogForm.Position := poScreenCenter;
    DialogForm.BorderStyle := bsDialog;
    DialogForm.ClientWidth := Min(600, Max(320, Screen.Width - 64));
    MessageLabel := TLabel.Create(DialogForm);
    MessageLabel.Parent := DialogForm;
    MessageLabel.AutoSize := False;
    MessageLabel.WordWrap := True;
    MessageLabel.Caption := AMessage;
    MessageLabel.SetBounds(16, 16, DialogForm.ClientWidth - 32, 32);
    PreferredWidth := 0;
    PreferredHeight := 0;
    MessageLabel.GetPreferredSize(PreferredWidth, PreferredHeight);
    MessageLabel.Height := Max(32, PreferredHeight) + 12;
    TotalWidth := 0;
    ButtonHeight := 36;
    for ButtonKind := Low(TMsgDlgBtn) to High(TMsgDlgBtn) do
    begin
      if not (ButtonKind in Buttons) then Continue;
      ButtonResult := mrCancel;
      case ButtonKind of
        mbOK: begin ButtonText := 'OK'; ButtonResult := mrOK; end;
        mbCancel: begin ButtonText := 'Cancel'; ButtonResult := mrCancel; end;
        mbYes: begin ButtonText := 'Yes'; ButtonResult := mrYes; end;
        mbNo: begin ButtonText := 'No'; ButtonResult := mrNo; end;
        mbAbort: begin ButtonText := 'Abort'; ButtonResult := mrAbort; end;
        mbRetry: begin ButtonText := 'Retry'; ButtonResult := mrRetry; end;
        mbIgnore: begin ButtonText := 'Ignore'; ButtonResult := mrIgnore; end;
        mbAll: begin ButtonText := 'All'; ButtonResult := mrAll; end;
        mbNoToAll: begin ButtonText := 'No to All'; ButtonResult := mrNoToAll; end;
        mbYesToAll: begin ButtonText := 'Yes to All'; ButtonResult := mrYesToAll; end;
      else ButtonText := 'Cancel';
      end;
      DialogButton := TButton.Create(DialogForm);
      DialogButton.Parent := DialogForm;
      DialogButton.Caption := UiText(ButtonText);
      DialogButton.ModalResult := ButtonResult;
      DialogButton.Default := ButtonList.Count = 0;
      DialogButton.Cancel := ButtonResult = mrCancel;
      PreferredWidth := 0;
      PreferredHeight := 0;
      DialogButton.GetPreferredSize(PreferredWidth, PreferredHeight);
      DialogButton.Width := Max(90, PreferredWidth + 24);
      ButtonHeight := Max(ButtonHeight, PreferredHeight + 12);
      Inc(TotalWidth, DialogButton.Width + 10);
      ButtonList.Add(DialogButton);
    end;
    if TotalWidth > 0 then Dec(TotalWidth, 10);
    ButtonTop := MessageLabel.Top + MessageLabel.Height + 16;
    ButtonLeft := Max(16, (DialogForm.ClientWidth - TotalWidth) div 2);
    for ButtonOrdinal := 0 to ButtonList.Count - 1 do
    begin
      DialogButton := TButton(ButtonList[ButtonOrdinal]);
      DialogButton.SetBounds(ButtonLeft, ButtonTop, DialogButton.Width, ButtonHeight);
      Inc(ButtonLeft, DialogButton.Width + 10);
    end;
    DialogForm.ClientHeight := ButtonTop + ButtonHeight + 16;
    Result := DialogForm.ShowModal;
  finally
    ButtonList.Free;
    DialogForm.Free;
  end;
end;

function UiInputQuery(const ACaption, APrompt: string; var Value: string): Boolean;
var
  DialogForm: TForm;
  PromptLabel: TLabel;
  ValueEdit: TEdit;
  OkButton, CancelButton: TButton;
  PreferredWidth, PreferredHeight, EditTop, ButtonTop, ButtonHeight: Integer;
begin
  DialogForm := TForm.CreateNew(nil);
  try
    DialogForm.Caption := UiText(ACaption);
    DialogForm.Position := poScreenCenter;
    DialogForm.BorderStyle := bsDialog;
    DialogForm.ClientWidth := 500;
    DialogForm.ClientHeight := 130;
    PromptLabel := TLabel.Create(DialogForm);
    PromptLabel.Parent := DialogForm;
    PromptLabel.AutoSize := False;
    PromptLabel.WordWrap := True;
    PromptLabel.Caption := UiText(APrompt);
    PromptLabel.SetBounds(12, 12, 476, 22);
    PreferredWidth := 0;
    PreferredHeight := 0;
    PromptLabel.GetPreferredSize(PreferredWidth, PreferredHeight);
    PromptLabel.Height := Max(28, PreferredHeight) + 8;
    EditTop := PromptLabel.Top + PromptLabel.Height + 8;
    ValueEdit := TEdit.Create(DialogForm);
    ValueEdit.Parent := DialogForm;
    ValueEdit.Text := Value;
    UseReadableInput(ValueEdit);
    PreferredWidth := 0;
    PreferredHeight := 0;
    ValueEdit.GetPreferredSize(PreferredWidth, PreferredHeight);
    ValueEdit.SetBounds(12, EditTop, 476, Max(32, PreferredHeight + 8));
    ButtonTop := EditTop + ValueEdit.Height + 16;
    OkButton := TButton.Create(DialogForm);
    OkButton.Parent := DialogForm;
    OkButton.Caption := UiText('OK');
    PreferredWidth := 0;
    PreferredHeight := 0;
    OkButton.GetPreferredSize(PreferredWidth, PreferredHeight);
    ButtonHeight := Max(36, PreferredHeight + 12);
    OkButton.SetBounds(310, ButtonTop, Max(90, PreferredWidth + 24), ButtonHeight);
    OkButton.ModalResult := mrOK;
    OkButton.Default := True;
    CancelButton := TButton.Create(DialogForm);
    CancelButton.Parent := DialogForm;
    CancelButton.Caption := UiText('Cancel');
    PreferredWidth := 0;
    PreferredHeight := 0;
    CancelButton.GetPreferredSize(PreferredWidth, PreferredHeight);
    ButtonHeight := Max(ButtonHeight, PreferredHeight + 12);
    OkButton.Height := ButtonHeight;
    CancelButton.SetBounds(404, ButtonTop, Max(90, PreferredWidth + 24), ButtonHeight);
    CancelButton.Left := DialogForm.ClientWidth - CancelButton.Width - 12;
    OkButton.Left := CancelButton.Left - OkButton.Width - 10;
    DialogForm.ClientHeight := ButtonTop + ButtonHeight + 12;
    CancelButton.ModalResult := mrCancel;
    CancelButton.Cancel := True;
    DialogForm.ActiveControl := ValueEdit;
    ValueEdit.SelectAll;
    PrepareInputAppearance(DialogForm);
    Result := DialogForm.ShowModal = mrOK;
    if Result then Value := ValueEdit.Text;
  finally
    DialogForm.Free;
  end;
end;

procedure InitUiLanguage(const ConfigFileName: string);
var
  Ini: TIniFile;
  LanguageName: string;
begin
  LanguageConfigFile := ConfigFileName;
  SelectedLanguage := ulChinese;
  if (ConfigFileName = '') or not FileExists(ConfigFileName) then Exit;
  Ini := TIniFile.Create(ConfigFileName);
  try
    LanguageName := LowerCase(Ini.ReadString('Interface', 'Language', 'zh'));
    SelectedLanguage := ResolveUiLanguage(LanguageName);
  finally
    Ini.Free;
  end;
end;

function CurrentUiLanguage: TUiLanguage;
begin
  Result := SelectedLanguage;
end;

procedure SetUiLanguage(ALanguage: TUiLanguage);
var
  Ini: TIniFile;
  ConfigDirectory: string;
  LanguageName: string;
begin
  SelectedLanguage := ResolveUiLanguage(ALanguage);
  if LanguageConfigFile = '' then Exit;
  ConfigDirectory := ExtractFileDir(LanguageConfigFile);
  if (ConfigDirectory <> '') and not DirectoryExists(ConfigDirectory) then
    if not ForceDirectories(ConfigDirectory) then Exit;
  LanguageName := SelectedLanguage;
  Ini := TIniFile.Create(LanguageConfigFile);
  try
    Ini.WriteString('Interface', 'Language', LanguageName);
  finally
    Ini.Free;
  end;
end;

constructor TLanguageManager.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FEntries := TObjectList.Create(True);
end;

destructor TLanguageManager.Destroy;
begin
  FreeAndNil(FEntries);
  inherited Destroy;
end;

procedure TLanguageManager.Notification(AComponent: TComponent;
  Operation: TOperation);
var
  EntryIndex: Integer;
begin
  inherited Notification(AComponent, Operation);
  if (Operation <> opRemove) or (FEntries = nil) then Exit;
  for EntryIndex := FEntries.Count - 1 downto 0 do
    if TOriginalText(FEntries[EntryIndex]).Target = AComponent then
      FEntries.Delete(EntryIndex);
end;

procedure TLanguageManager.TranslateProperty(Target: TComponent;
  const PropertyName: string; ColumnIndex: Integer);
var
  EntryIndex: Integer;
  Entry: TOriginalText;
  CurrentText, TranslatedText: string;
  PropertyInfo: PPropInfo;
  ListView: TListView;
begin
  ListView := nil;
  PropertyInfo := nil;
  if ColumnIndex >= 0 then
  begin
    if not (Target is TListView) then Exit;
    ListView := TListView(Target);
    if ColumnIndex >= ListView.Columns.Count then Exit;
    CurrentText := ListView.Columns[ColumnIndex].Caption;
  end
  else
  begin
    PropertyInfo := GetPropInfo(Target.ClassInfo, PropertyName);
    if PropertyInfo = nil then Exit;
    if not (PropertyInfo^.PropType^.Kind in
      [tkSString, tkLString, tkAString, tkWString, tkUString]) then Exit;
    CurrentText := GetStrProp(Target, PropertyInfo);
  end;

  Entry := nil;
  for EntryIndex := 0 to FEntries.Count - 1 do
    if (TOriginalText(FEntries[EntryIndex]).Target = Target) and
       (TOriginalText(FEntries[EntryIndex]).PropertyName = PropertyName) and
       (TOriginalText(FEntries[EntryIndex]).ColumnIndex = ColumnIndex) then
    begin
      Entry := TOriginalText(FEntries[EntryIndex]);
      Break;
    end;
  if Entry = nil then
  begin
    { Only cache known interface phrases, never filenames or editor contents. }
    if TranslateChinese(CanonicalUiText(CurrentText)) =
      CanonicalUiText(CurrentText) then
      if not HasUpstreamUiText(CanonicalUiText(CurrentText)) then Exit;
    Entry := TOriginalText.Create;
    Entry.Target := Target;
    Entry.PropertyName := PropertyName;
    Entry.ColumnIndex := ColumnIndex;
    Entry.Original := CanonicalUiText(CurrentText);
    Entry.LastApplied := CurrentText;
    FEntries.Add(Entry);
    Target.FreeNotification(Self);
  end
  else if CurrentText <> Entry.LastApplied then
    Entry.Original := CanonicalUiText(CurrentText);

  TranslatedText := UiText(Entry.Original);
  if ColumnIndex >= 0 then
    ListView.Columns[ColumnIndex].Caption := TranslatedText
  else
    SetStrProp(Target, PropertyInfo, TranslatedText);
  Entry.LastApplied := TranslatedText;
end;

procedure TLanguageManager.Apply(Root: TComponent);
var
  ChildOrdinal, ColumnIndex: Integer;
begin
  if Root = nil then Exit;
  TranslateProperty(Root, 'Caption');
  TranslateProperty(Root, 'Hint');
  if Root is TListView then
    for ColumnIndex := 0 to TListView(Root).Columns.Count - 1 do
      TranslateProperty(Root, 'Caption', ColumnIndex);
  for ChildOrdinal := 0 to Root.ComponentCount - 1 do
    Apply(Root.Components[ChildOrdinal]);
end;

procedure ApplyUiLanguage(Root: TComponent);
begin
  if LanguageManager = nil then LanguageManager := TLanguageManager.Create(nil);
  LanguageManager.Apply(Root);
end;

procedure FreeReversePhrases;
var I: Integer;
begin
  if ReversePhrases = nil then Exit;
  for I := 0 to ReversePhrases.Count - 1 do ReversePhrases.Objects[I].Free;
  FreeAndNil(ReversePhrases);
end;

finalization
  FreeAndNil(LanguageManager);
  FreeReversePhrases;

end.
