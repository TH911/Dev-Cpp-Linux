program document_files_test;

{$mode objfpc}{$H+}{$codepage utf8}

uses Classes, SysUtils, IniFiles, BaseUnix, document_files;

const
  { A typed UTF-8 constant avoids FPC 3.0.4 converting a Unicode literal
    concatenated with a runtime string to the system ANSI code page. }
  Utf8Directory: UTF8String = '中文 path';
  InvalidCharacters: array[0..2] of Char = (#0, #10, #13);

var CheckCount: Integer;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then raise Exception.Create(MessageText);
  Inc(CheckCount);
end;

function PathBytes(const Value: RawByteString): string;
var I: Integer;
begin
  Result := '';
  for I := 1 to Length(Value) do
    Result := Result + IntToHex(Ord(Value[I]), 2) + ' ';
end;

procedure CheckIdentity(const LeftName, RightName, MessageText: string);
var LeftInfo, RightInfo: Stat; LeftStatus, RightStatus: Integer;
begin
  if not SameDocumentPath(LeftName, RightName) then
  begin
    WriteLn(StdErr, 'left path: ', LeftName, ' bytes: ', PathBytes(LeftName));
    WriteLn(StdErr, 'right path: ', RightName, ' bytes: ', PathBytes(RightName));
    WriteLn(StdErr, 'left canonical: ', CanonicalDocumentPath(LeftName));
    WriteLn(StdErr, 'right canonical: ', CanonicalDocumentPath(RightName));
    WriteLn(StdErr, 'right link bytes: ', PathBytes(fpReadLink(RightName)));
    LeftStatus := fpStat(PChar(LeftName), LeftInfo);
    RightStatus := fpStat(PChar(RightName), RightInfo);
    WriteLn(StdErr, 'stat results: ', LeftStatus, ', ', RightStatus);
    if LeftStatus = 0 then
      WriteLn(StdErr, 'left device/inode: ', LeftInfo.st_dev, '/', LeftInfo.st_ino);
    if RightStatus = 0 then
      WriteLn(StdErr, 'right device/inode: ', RightInfo.st_dev, '/', RightInfo.st_ino);
    Check(False, MessageText);
  end;
  Check(True, MessageText);
end;

procedure WriteText(const FileName, Text: string);
var Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.Text := Text;
    Lines.SaveToFile(FileName);
  finally Lines.Free; end;
end;

function ReadText(const FileName: string): string;
var Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FileName);
    Result := Lines.Text;
  finally Lines.Free; end;
end;

var
  TestDir, SourceName, LinkName, HardLinkName, ProjectName, NewName: string;
  ParentLinkName, DanglingLinkName, CreatedName: string;
  Lines: TStringList;
  Initial, Current, Saved, Missing: TFileSnapshot;
  BeforeInfo, AfterInfo: Stat;
  Ini: TMemIniFile;
  Failed: Boolean;
  Search: TSearchRec;
  InvalidIndex: Integer;
begin
  Check(ParamCount = 1, 'pass a disposable test directory');
  TestDir := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));
  ForceDirectories(TestDir + Utf8Directory);
  SourceName := TestDir + Utf8Directory + '/main.cpp';
  LinkName := TestDir + 'main-link.cpp';
  HardLinkName := TestDir + 'main-hard.cpp';
  ProjectName := TestDir + 'sample.dev';
  NewName := TestDir + Utf8Directory + '/renamed.cpp';
  ParentLinkName := TestDir + 'directory-link';
  DanglingLinkName := TestDir + 'new-target-link.cpp';
  CreatedName := TestDir + Utf8Directory + '/created.cpp';
  Check(Copy(SourceName, Length(TestDir) + 1, 6) =
    #$E4#$B8#$AD#$E6#$96#$87, 'Unicode fixture uses actual UTF-8 bytes');
  WriteLn('UTF-8 source path bytes: ', PathBytes(SourceName));
  Lines := TStringList.Create;
  try
    WriteText(SourceName, 'int initial;' + LineEnding);
    LoadDocumentLines(Lines, SourceName, Initial);
    Check(Lines[0] = 'int initial;', 'source load');
    Check(SameFileSnapshot(Initial, CaptureFileSnapshot(SourceName)), 'load snapshot');
    Check(FileSnapshotIsCurrent(SourceName, Initial), 'unchanged file metadata fast path');

    Check(fpSymlink(PChar(Utf8Directory + '/main.cpp'), PChar(LinkName)) = 0, 'create symlink');
    Check(fpLink(PChar(SourceName), PChar(HardLinkName)) = 0, 'create hard link');
    CheckIdentity(SourceName, LinkName, 'symlink identity');
    CheckIdentity(SourceName, HardLinkName, 'Save As hard-link alias identity');
    CheckIdentity(SourceName, TestDir + Utf8Directory + '/../' +
      Utf8Directory + '/main.cpp', 'normalised identity');

    LoadDocumentLines(Lines, LinkName, Current);
    Check(Lines[0] = 'int initial;', 'source symlink loads target content');
    Check(Current.Metadata = CaptureFileSnapshot(SourceName).Metadata,
      'source symlink captures target metadata');
    Check(fpSymlink(PChar(Utf8Directory), PChar(ParentLinkName)) = 0,
      'create directory symlink');
    CheckIdentity(SourceName, ParentLinkName + '/main.cpp', 'parent symlink identity');

    { Saving a new target follows its dangling link without replacing the link. }
    Check(fpSymlink(PChar(Utf8Directory + '/created.cpp'),
      PChar(DanglingLinkName)) = 0, 'create dangling symlink');
    Missing := CaptureFileSnapshot(DanglingLinkName);
    Check(not Missing.Present, 'dangling symlink target is absent');
    AtomicSaveDocumentChecked(Lines, DanglingLinkName, Missing, Saved);
    Check(fpLStat(PChar(DanglingLinkName), AfterInfo) = 0, 'new target link stat');
    Check(FPS_ISLNK(AfterInfo.st_mode), 'new target save preserves symlink');
    Check(ReadText(CreatedName) = 'int initial;' + LineEnding,
      'dangling symlink save creates Unicode target');
    CheckIdentity(CreatedName, DanglingLinkName, 'new target symlink identity');
    Check(Saved.Metadata = CaptureFileSnapshot(CreatedName).Metadata,
      'new target snapshot records destination metadata');

    { Same-sized content changes still invalidate the snapshot. }
    WriteText(SourceName, 'int outside;' + LineEnding);
    Check(not FileSnapshotIsCurrent(SourceName, Initial), 'metadata catches same-sized external edit');
    Current := CaptureFileSnapshot(SourceName);
    Check(not SameFileSnapshot(Initial, Current), 'external content change detection');
    Lines.Text := 'int editor;' + LineEnding;
    Failed := False;
    try
      AtomicSaveDocumentChecked(Lines, SourceName, Initial, Saved);
    except on E: EFCreateError do Failed := True; end;
    Check(Failed, 'stale save refused');
    Check(ReadText(SourceName) = 'int outside;' + LineEnding, 'stale save preserves disk');

    Check(fpChmod(PChar(SourceName), &640) = 0, 'set source mode');
    Check(fpStat(PChar(SourceName), BeforeInfo) = 0, 'initial stat');
    Current := CaptureFileSnapshot(SourceName);
    AtomicSaveDocumentChecked(Lines, LinkName, Current, Saved);
    Check(fpLStat(PChar(LinkName), AfterInfo) = 0, 'link stat');
    Check(FPS_ISLNK(AfterInfo.st_mode), 'save preserves symlink');
    Check(fpStat(PChar(SourceName), AfterInfo) = 0, 'saved stat');
    Check((AfterInfo.st_mode and &777) = &640, 'save preserves source mode');
    Check((AfterInfo.st_uid = BeforeInfo.st_uid) and
      (AfterInfo.st_gid = BeforeInfo.st_gid), 'save preserves ownership');
    Check(ReadText(SourceName) = 'int editor;' + LineEnding, 'symlink save updates target');
    Check(SameFileSnapshot(Saved, CaptureFileSnapshot(SourceName)), 'saved snapshot');

    Check(fpChmod(PChar(SourceName), &440) = 0, 'make source read-only');
    Lines.Text := 'must not replace read-only source' + LineEnding;
    Failed := False;
    try AtomicSaveDocument(Lines, SourceName, Saved);
    except on E: EFCreateError do Failed := True; end;
    Check(Failed, 'read-only save refused');
    Check(ReadText(SourceName) = 'int editor;' + LineEnding, 'read-only source preserved');
    Check(fpChmod(PChar(SourceName), &640) = 0, 'restore source mode');

    { A symlink redirected to a different same-content inode is not the loaded file. }
    Current := CaptureFileSnapshot(LinkName);
    WriteText(NewName, ReadText(SourceName));
    Check(fpUnlink(PChar(LinkName)) = 0, 'remove old symlink');
    Check(fpSymlink(PChar(Utf8Directory + '/renamed.cpp'), PChar(LinkName)) = 0, 'redirect symlink');
    Failed := False;
    try AtomicSaveDocumentChecked(Lines, LinkName, Current, Saved);
    except on E: EFCreateError do Failed := True; end;
    Check(Failed, 'same-content symlink redirection refused');
    Check(ReadText(SourceName) = 'int editor;' + LineEnding, 'original symlink target preserved');
    Check(ReadText(NewName) = 'int editor;' + LineEnding, 'redirected symlink target preserved');

    Missing.Present := False;
    Missing.Signature := '';
    Missing.Metadata := '';
    WriteText(NewName, 'arrived after save dialog' + LineEnding);
    Failed := False;
    try AtomicSaveDocumentChecked(Lines, NewName, Missing, Saved);
    except on E: EFCreateError do Failed := True; end;
    Check(Failed, 'new destination arriving during save refused');
    Check(ReadText(NewName) = 'arrived after save dialog' + LineEnding, 'new destination preserved');

    WriteText(ProjectName, '[Project]' + LineEnding + 'UnitCount=1' + LineEnding +
      'Type=1' + LineEnding + 'CommandLine="argument with spaces"' + LineEnding +
      '[Unit1]' + LineEnding + 'FileName=' + Utf8Directory + '\main.cpp' + LineEnding +
      'Compile=1' + LineEnding);
    Check(ProjectUnitPath(ProjectName, Utf8Directory + '\main.cpp') = SourceName,
      'Windows project separators resolved');
    Check(ProjectUnitPath(ProjectName, SourceName) = SourceName, 'absolute project unit path');
    Check(UpdateProjectFileReference(ProjectName, SourceName, NewName), 'project reference renamed');
    Initial := CaptureFileSnapshot(ProjectName);
    for InvalidIndex := Low(InvalidCharacters) to High(InvalidCharacters) do
    begin
      Failed := False;
      try
        UpdateProjectFileReference(ProjectName, NewName,
          SourceName + InvalidCharacters[InvalidIndex] + '[Injected]');
      except on E: EInOutError do Failed := True; end;
      Check(Failed, 'NUL/CR/LF in project unit path refused');
      Check(SameFileSnapshot(Initial, CaptureFileSnapshot(ProjectName)),
        'path injection does not modify project');
    end;
    Ini := TMemIniFile.Create(ProjectName);
    try
      Check(Ini.ReadString('Unit1', 'FileName', '') = Utf8Directory + '/renamed.cpp', 'relative reference persisted');
      Check(Ini.ReadString('Project', 'CommandLine', '') = '"argument with spaces"', 'unrelated project options preserved');
      Check(Ini.ReadInteger('Project', 'Type', 0) = 1, 'project type preserved');
      for InvalidIndex := Low(InvalidCharacters) to High(InvalidCharacters) do
      begin
        Ini.WriteString('Project', 'CommandLine',
          'value' + InvalidCharacters[InvalidIndex] + '[Injected]');
        Failed := False;
        try WriteProjectIni(Ini, ProjectName, Initial);
        except on E: EInOutError do Failed := True; end;
        Check(Failed, 'NUL/CR/LF in project setting refused');
        Check(SameFileSnapshot(Initial, CaptureFileSnapshot(ProjectName)),
          'setting injection does not modify project');
      end;
    finally Ini.Free; end;

    Initial := CaptureFileSnapshot(ProjectName);
    Check(fpChmod(PChar(ProjectName), &440) = 0, 'make project read-only');
    Failed := False;
    try UpdateProjectFileReference(ProjectName, NewName, SourceName);
    except on E: EFCreateError do Failed := True; end;
    Check(Failed, 'read-only project rename refused');
    Check(SameFileSnapshot(Initial, CaptureFileSnapshot(ProjectName)), 'failed project rename preserves file');
    Check(fpChmod(PChar(ProjectName), &640) = 0, 'restore project mode');
    Check(FindFirst(TestDir + '.devcpp-save-*', faAnyFile, Search) <> 0,
      'failed operations clean temporary files');
    FindClose(Search);
    Check(FindFirst(TestDir + Utf8Directory + '/.devcpp-save-*', faAnyFile, Search) <> 0,
      'nested temporary files cleaned');
    FindClose(Search);
    WriteLn('Checks passed: ', CheckCount);
    WriteLn('PASS: file identity, external changes, atomic save, symlinks, permissions, project rename and failure preservation.');
  finally Lines.Free; end;
end.
