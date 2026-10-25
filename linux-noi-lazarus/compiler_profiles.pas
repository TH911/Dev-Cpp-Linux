unit compiler_profiles;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, IniFiles, Contnrs;

type
  TCompilerProfile = class
  public
    Name, CCompiler, CppCompiler, CFlags, CppFlags, LinkerFlags: string;
    constructor Create;
    procedure Assign(Source: TCompilerProfile);
  end;

  TCompilerProfiles = class
  private
    FItems: TObjectList;
    FActiveIndex: Integer;
    function GetCount: Integer;
    function GetItem(Index: Integer): TCompilerProfile;
    procedure SetActiveIndex(Value: Integer);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Load(Ini: TCustomIniFile);
    procedure Save(Ini: TCustomIniFile);
    procedure Assign(Source: TCompilerProfiles);
    function Add(const Name: string; Source: TCompilerProfile = nil): Integer;
    procedure Delete(Index: Integer);
    function UniqueName(const Base: string): string;
    property Count: Integer read GetCount;
    property Items[Index: Integer]: TCompilerProfile read GetItem; default;
    property ActiveIndex: Integer read FActiveIndex write SetActiveIndex;
  end;

implementation

constructor TCompilerProfile.Create;
begin
  inherited Create;
  CCompiler := 'gcc';
  CppCompiler := 'g++';
  CFlags := '-g -O2 -Wall -Wextra';
  CppFlags := '-g -O2 -std=c++14 -Wall -Wextra';
end;

procedure TCompilerProfile.Assign(Source: TCompilerProfile);
begin
  Name := Source.Name;
  CCompiler := Source.CCompiler;
  CppCompiler := Source.CppCompiler;
  CFlags := Source.CFlags;
  CppFlags := Source.CppFlags;
  LinkerFlags := Source.LinkerFlags;
end;

constructor TCompilerProfiles.Create;
begin
  inherited Create;
  FItems := TObjectList.Create(True);
end;

destructor TCompilerProfiles.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

function TCompilerProfiles.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TCompilerProfiles.GetItem(Index: Integer): TCompilerProfile;
begin
  Result := TCompilerProfile(FItems[Index]);
end;

procedure TCompilerProfiles.SetActiveIndex(Value: Integer);
begin
  if (Value >= 0) and (Value < Count) then FActiveIndex := Value;
end;

function TCompilerProfiles.Add(const Name: string; Source: TCompilerProfile): Integer;
var P: TCompilerProfile;
begin
  P := TCompilerProfile.Create;
  if Source <> nil then P.Assign(Source);
  P.Name := Name;
  Result := FItems.Add(P);
end;

procedure TCompilerProfiles.Delete(Index: Integer);
begin
  if (Count <= 1) or (Index < 0) or (Index >= Count) then Exit;
  FItems.Delete(Index);
  if FActiveIndex > Index then Dec(FActiveIndex)
  else if FActiveIndex >= Count then FActiveIndex := Count - 1;
end;

function TCompilerProfiles.UniqueName(const Base: string): string;
var I, Suffix: Integer; Found: Boolean;
begin
  Result := Base;
  Suffix := 1;
  repeat
    Found := False;
    for I := 0 to Count - 1 do
      if SameText(Items[I].Name, Result) then begin Found := True; Break; end;
    if not Found then Exit;
    Inc(Suffix);
    Result := Base + ' ' + IntToStr(Suffix);
  until False;
end;

procedure TCompilerProfiles.Assign(Source: TCompilerProfiles);
var I: Integer;
begin
  FItems.Clear;
  for I := 0 to Source.Count - 1 do Add(Source[I].Name, Source[I]);
  FActiveIndex := Source.ActiveIndex;
end;

procedure TCompilerProfiles.Load(Ini: TCustomIniFile);
var I, ProfileCount: Integer; Section: string; P: TCompilerProfile;

  procedure ReadProfile(const Section: string; P: TCompilerProfile);
  begin
    P.CCompiler := Ini.ReadString(Section, 'C', P.CCompiler);
    P.CppCompiler := Ini.ReadString(Section, 'Cpp', P.CppCompiler);
    P.CFlags := Ini.ReadString(Section, 'CFlags', P.CFlags);
    P.CppFlags := Ini.ReadString(Section, 'CppFlags', P.CppFlags);
    P.LinkerFlags := Ini.ReadString(Section, 'LinkerFlags', P.LinkerFlags);
  end;

begin
  FItems.Clear;
  ProfileCount := Ini.ReadInteger('CompilerProfiles', 'Count', 0);
  if ProfileCount > 128 then ProfileCount := 128;
  for I := 0 to ProfileCount - 1 do
  begin
    Section := 'CompilerProfile.' + IntToStr(I);
    P := Items[Add(UniqueName(Ini.ReadString(Section, 'Name', 'Profile ' + IntToStr(I + 1))))];
    ReadProfile(Section, P);
  end;
  if Count = 0 then
  begin
    P := Items[Add('Default')];
    ReadProfile('Compiler', P);
    { Preserve the previous loader's one-time upgrade of its legacy defaults. }
    if P.CFlags = '-g -Wall -Wextra' then P.CFlags := '-g -O2 -Wall -Wextra';
    if P.CppFlags = '-g -Wall -Wextra' then P.CppFlags := '-g -O2 -std=c++14 -Wall -Wextra';
  end;
  FActiveIndex := 0;
  SetActiveIndex(Ini.ReadInteger('CompilerProfiles', 'Active', 0));
end;

procedure TCompilerProfiles.Save(Ini: TCustomIniFile);
var I, OldCount: Integer; Section: string; P: TCompilerProfile;
begin
  OldCount := Ini.ReadInteger('CompilerProfiles', 'Count', 0);
  if OldCount > 128 then OldCount := 128;
  for I := Count to OldCount - 1 do Ini.EraseSection('CompilerProfile.' + IntToStr(I));
  for I := 0 to Count - 1 do
  begin
    Section := 'CompilerProfile.' + IntToStr(I);
    P := Items[I];
    Ini.WriteString(Section, 'Name', P.Name);
    Ini.WriteString(Section, 'C', P.CCompiler);
    Ini.WriteString(Section, 'Cpp', P.CppCompiler);
    Ini.WriteString(Section, 'CFlags', P.CFlags);
    Ini.WriteString(Section, 'CppFlags', P.CppFlags);
    Ini.WriteString(Section, 'LinkerFlags', P.LinkerFlags);
  end;
  Ini.WriteInteger('CompilerProfiles', 'Count', Count);
  Ini.WriteInteger('CompilerProfiles', 'Active', FActiveIndex);
end;

end.
