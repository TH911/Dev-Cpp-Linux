unit language_catalog;

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses Classes, SysUtils;

const UiLanguageCount = 33;

function UiLanguageCode(Index: Integer): string;
function UiLanguageName(Index: Integer): string;
function ResolveUiLanguage(const Code: string): string;
function UpstreamUiText(const Code, EnglishText: string): string;
function HasUpstreamUiText(const EnglishText: string): Boolean;

implementation

uses IniFiles, fgl;

type
  TTextMapData = specialize TFPGMap<string, string>;
  TTextMap = class
  private
    FData: TTextMapData;
    function GetValue(const Key: string): string;
    procedure SetValue(const Key, Value: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure Load(Pairs: TStrings);
    procedure Assign(Source: TTextMap);
    property Values[const Key: string]: string read GetValue write SetValue;
  end;

  TLanguageInfo = record
    Code, Name, FileName: string;
  end;

const
  {$I language_data.inc}

var
  EnglishIds: TTextMap = nil;
  EnglishExactIds: TTextMap = nil;
  ActiveValues: TTextMap = nil;
  ActiveCode: string = '';

constructor TTextMap.Create;
begin
  inherited Create;
  FData := TTextMapData.Create;
  FData.Sorted := True;
end;
destructor TTextMap.Destroy;
begin
  FData.Free;
  inherited Destroy;
end;
function TTextMap.GetValue(const Key: string): string;
var I: Integer;
begin
  I := FData.IndexOf(Key);
  if I < 0 then Result := '' else Result := FData.Data[I];
end;
procedure TTextMap.SetValue(const Key, Value: string);
var I: Integer;
begin
  I := FData.IndexOf(Key);
  if I < 0 then FData.Add(Key, Value) else FData.Data[I] := Value;
end;
procedure TTextMap.Clear;
begin
  FData.Clear;
end;
procedure TTextMap.Load(Pairs: TStrings);
var I: Integer;
begin
  Clear;
  for I := 0 to Pairs.Count - 1 do
    if GetValue(Pairs.Names[I]) = '' then
      SetValue(Pairs.Names[I], Pairs.ValueFromIndex[I]);
end;
procedure TTextMap.Assign(Source: TTextMap);
var I: Integer;
begin
  Clear;
  for I := 0 to Source.FData.Count - 1 do
    SetValue(Source.FData.Keys[I], Source.FData.Data[I]);
end;

function UiLanguageCode(Index: Integer): string;
begin
  if (Index < 0) or (Index >= UiLanguageCount) then Exit('en');
  Result := Languages[Index].Code;
end;

function UiLanguageName(Index: Integer): string;
begin
  if (Index < 0) or (Index >= UiLanguageCount) then Exit('English');
  Result := Languages[Index].Name;
end;

function ResolveUiLanguage(const Code: string): string;
var I: Integer; Value: string;
begin
  Value := StringReplace(Trim(Code), '-', '_', [rfReplaceAll]);
  if Value = '' then Exit('zh');
  if SameText(Value, 'zh_CN') or SameText(Value, 'chinese') then Exit('zh');
  if SameText(Value, 'english') then Exit('en');
  for I := 0 to UiLanguageCount - 1 do
    if SameText(Value, Languages[I].Code) or
      SameText(Value, ChangeFileExt(Languages[I].FileName, '')) or
      SameText(Value, Languages[I].FileName) then Exit(Languages[I].Code);
  Result := 'en';
end;

function NormalizePhrase(const Text: string): string;
var I: Integer;
begin
  Result := '';
  for I := 1 to Length(Text) do
    if not (Text[I] in ['&', '.', ':', #9, #10, #13]) then
      Result := Result + Text[I];
  Result := LowerCase(Trim(Result));
end;

function CatalogPath(const FileName: string): string;
var Folder: string;
begin
  Folder := ExtractFilePath(ExpandFileName(ParamStr(0)));
  Result := Folder + 'languages' + DirectorySeparator + FileName;
  { Unit-test executables live in lib/, next to the source resources. }
  if not FileExists(Result) then
    Result := ExpandFileName(Folder + '..' + DirectorySeparator + 'languages' +
      DirectorySeparator + FileName);
end;

procedure EnsureEnglish;
var Ini: TMemIniFile; Values: TStringList; I, Code: Integer; Key: string;

  procedure Alias(const Phrase: string; Id: Integer);
  begin
    EnglishIds.Values[NormalizePhrase(Phrase)] := IntToStr(Id);
  end;

begin
  if EnglishIds <> nil then Exit;
  EnglishIds := TTextMap.Create;
  EnglishExactIds := TTextMap.Create;
  Values := TStringList.Create;
  Ini := TMemIniFile.Create(CatalogPath('English.lng'));
  try
    Ini.ReadSectionValues('lang', Values);
    for I := 0 to Values.Count - 1 do
      if TryStrToInt(Values.Names[I], Code) then
      begin
        Key := NormalizePhrase(Values.ValueFromIndex[I]);
        if (Key <> '') and (EnglishIds.Values[Key] = '') then
          EnglishIds.Values[Key] := IntToStr(Code);
        if EnglishExactIds.Values[Values.ValueFromIndex[I]] = '' then
          EnglishExactIds.Values[Values.ValueFromIndex[I]] := IntToStr(Code);
      end;
    { Renamed Linux menu entries keep the corresponding original action IDs. }
    Alias('Open project or file', 2001);
    Alias('Open project', 2001);
    Alias('Recent Files / Projects', 2002);
    Alias('Clear Recent', 2003);
    Alias('New Source File', 1003);
    Alias('New project', 27050);
    Alias('Compiler Options / Parameters', 7011);
    Alias('Compiler Parameters', 7011);
    Alias('Parameters', 67001);
    Alias('Language', 38017);
    Alias('Code Completion', 23006);
    Alias('Find Next', 5004);
    Alias('Find Previous', 5027);
    Alias('Project Manager', 5009);
    Alias('Next Tab', 8003);
    Alias('Previous Tab', 8004);
    Alias('Add file to project', 6002);
    Alias('Remove file from project', 6003);
    Alias('Compiler Log', 13003);
    Alias('Start Debugging', 10001);
    Alias('Stop Debugging', 10007);
    Alias('Stop', 10007);
    Alias('Step Into', 10010);
    Alias('Step over', 10003);
    Alias('Editor Theme', 23004);
    Alias('Font (monospace recommended)', 27011);
    Alias('Font size (1-72)', 27012);
    Alias('Tab width (1-16)', 79008);
    Alias('Program arguments', 71002);
    Alias('Execute Parameters', 67001);
    Alias('About dev-cpp-linux', 9001);
  finally
    Ini.Free;
    Values.Free;
  end;
end;

function HasUpstreamUiText(const EnglishText: string): Boolean;
begin
  EnsureEnglish;
  Result := EnglishIds.Values[NormalizePhrase(EnglishText)] <> '';
end;

function FormatSignature(const Text: string): string;
var I: Integer;
begin
  Result := '';
  I := 1;
  while I <= Length(Text) do
  begin
    if Text[I] = '%' then
    begin
      Inc(I);
      if (I <= Length(Text)) and (Text[I] = '%') then begin Inc(I); Continue; end;
      while (I <= Length(Text)) and (Text[I] in ['0'..'9', '.', ':', '-']) do Inc(I);
      if I <= Length(Text) then Result := Result + LowerCase(Text[I]);
    end;
    Inc(I);
  end;
end;

procedure RemapLegacyCatalog(const FileName: string);
var Mapping: TStringList; Converted: TTextMap; Ini: TMemIniFile; I: Integer; Value: string;
begin
  if ActiveValues.Values['1'] <> '' then Exit;
  Mapping := TStringList.Create;
  Converted := TTextMap.Create;
  Ini := TMemIniFile.Create(CatalogPath('legacy_ids.ini'));
  try
    Ini.ReadSectionValues(FileName, Mapping);
    for I := 0 to Mapping.Count - 1 do
    begin
      Value := ActiveValues.Values[Mapping.ValueFromIndex[I]];
      if Value <> '' then Converted.Values[Mapping.Names[I]] := Value;
    end;
    { Unmapped IDs must fall back to English, rather than use an unrelated
      old phrase with the same numeric ID as a new action. }
    ActiveValues.Assign(Converted);
  finally
    Ini.Free; Converted.Free; Mapping.Free;
  end;
end;

function UpstreamUiText(const Code, EnglishText: string): string;
var I: Integer; Id, Value, Selected: string; Ini: TMemIniFile; Pairs: TStringList;
begin
  Result := EnglishText;
  Selected := ResolveUiLanguage(Code);
  if Selected = 'en' then Exit;
  EnsureEnglish;
  Id := EnglishExactIds.Values[EnglishText];
  if Id = '' then Id := EnglishIds.Values[NormalizePhrase(EnglishText)];
  if Id = '' then Exit;
  if ActiveCode <> Selected then
  begin
    if ActiveValues = nil then ActiveValues := TTextMap.Create;
    ActiveValues.Clear;
    for I := 0 to UiLanguageCount - 1 do
      if Languages[I].Code = Selected then
      begin
        Ini := TMemIniFile.Create(CatalogPath(Languages[I].FileName));
        Pairs := TStringList.Create;
        try
          Ini.ReadSectionValues('lang', Pairs);
          ActiveValues.Load(Pairs);
        finally Pairs.Free; Ini.Free; end;
        RemapLegacyCatalog(Languages[I].FileName);
        Break;
      end;
    ActiveCode := Selected;
  end;
  Value := ActiveValues.Values[Id];
  { Never feed a stale Windows translation's incompatible placeholders to Format. }
  if (Value <> '') and (FormatSignature(Value) = FormatSignature(EnglishText)) then
    Result := StringReplace(Value, '<CR>', LineEnding, [rfReplaceAll]);
  if Pos('About dev-cpp-linux', StringReplace(EnglishText, '&', '', [rfReplaceAll])) > 0 then begin
    Result := StringReplace(Result, 'Dev-C++', 'dev-cpp-linux', [rfReplaceAll]);
    Result := StringReplace(Result, 'Dev-Cpp', 'dev-cpp-linux', [rfReplaceAll]);
  end;
end;

finalization
  FreeAndNil(ActiveValues);
  FreeAndNil(EnglishIds);
  FreeAndNil(EnglishExactIds);

end.
