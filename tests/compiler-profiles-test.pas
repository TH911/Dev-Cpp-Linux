program compiler_profiles_test;

{$mode objfpc}{$H+}

uses SysUtils, IniFiles, compiler_profiles;

procedure Check(Condition: Boolean; const Message: string);
begin
  if not Condition then raise Exception.Create(Message);
end;

var
  Ini: TMemIniFile;
  Profiles, Reloaded, Working: TCompilerProfiles;
  Index: Integer;
begin
  Ini := TMemIniFile.Create('');
  Profiles := TCompilerProfiles.Create;
  Reloaded := TCompilerProfiles.Create;
  Working := TCompilerProfiles.Create;
  try
    Ini.WriteString('Compiler', 'C', '/opt/custom gcc');
    Ini.WriteString('Compiler', 'Cpp', '/opt/custom g++');
    Ini.WriteString('Compiler', 'CppFlags', '-std=c++20 -DNAME="a b"');
    Ini.WriteString('Compiler', 'LinkerFlags', '-lm');
    Profiles.Load(Ini);
    Check(Profiles.Count = 1, 'legacy compiler should migrate to exactly one profile');
    Check(Profiles[0].CCompiler = '/opt/custom gcc', 'legacy C command lost');
    Check(Profiles[0].CppCompiler = '/opt/custom g++', 'legacy C++ command lost');
    Check(Profiles[0].CppFlags = '-std=c++20 -DNAME="a b"', 'legacy flags must retain quotes');
    Index := Profiles.Add('Debug', Profiles[0]);
    Profiles[Index].CppCompiler := 'clang++';
    Profiles[Index].CppFlags := '-O0 -g -fsanitize=address';
    Profiles[Index].LinkerFlags := '-fsanitize=address';
    Check(Profiles[0].CppCompiler = '/opt/custom g++', 'copied commands must be independent');
    Check(Profiles[0].LinkerFlags = '-lm', 'copied linker flags must be independent');
    Profiles.ActiveIndex := Index;
    Profiles.Save(Ini);
    Reloaded.Load(Ini);
    Check((Reloaded.Count = 2) and (Reloaded.ActiveIndex = 1), 'active profile should survive restart');
    Check(Reloaded[1].CppCompiler = 'clang++', 'second profile command should survive restart');
    Check(Reloaded[0].CppFlags = '-std=c++20 -DNAME="a b"', 'switching profiles must not mix flags');
    Working.Assign(Reloaded);
    Working[0].Name := 'Cancelled rename';
    Working[1].CFlags := '-Werror';
    Working.Delete(0);
    Check(Reloaded.Count = 2, 'cancelled working copy must retain original profile count');
    Check(Reloaded[0].Name = 'Default', 'cancelled rename must not affect originals');
    Check(Reloaded[1].CFlags <> '-Werror', 'cancelled flags must not affect originals');
    Check(Reloaded.UniqueName('Default') = 'Default 2', 'duplicate names should get unique suffixes');
    Reloaded.Delete(0);
    Check((Reloaded.Count = 1) and (Reloaded.ActiveIndex = 0), 'deleting a preceding profile should update active index');
    Reloaded.Save(Ini);
    Check(not Ini.SectionExists('CompilerProfile.1'), 'deleted profile section should be removed');
    Profiles.Load(Ini);
    Check((Profiles.Count = 1) and (Profiles[0].CppCompiler = 'clang++'), 'remaining profile should persist after delete');
    Profiles.Delete(0);
    Check(Profiles.Count = 1, 'last compiler profile cannot be deleted');
    Check(Ini.ReadString('Compiler', 'Cpp', '') = '/opt/custom g++', 'migration should preserve old section');
    Working.EnsureNativePresets;
    Check(Working[Working.Count-3].Name='GCC 64-bit Release','release preset is absent');
    Check(Pos('-g3 -O0',Working[Working.Count-2].CppFlags)>0,'debug preset lacks usable debug flags');
    Check(Working[Working.Count-1].LinkerFlags='-pg','profiling link flag is missing');
    Index:=Working.Count;Working.EnsureNativePresets;
    Check(Working.Count=Index,'native presets must not duplicate');
    WriteLn('compiler profiles: all checks passed');
  finally
    Working.Free;
    Reloaded.Free;
    Profiles.Free;
    Ini.Free;
  end;
end.
