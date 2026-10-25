unit document_files;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, IniFiles;

type
  TFileSnapshot = record
    Present: Boolean;
    Signature: string;
    Metadata: string;
  end;

function CanonicalDocumentPath(const FileName: string): string;
function SameDocumentPath(const LeftName, RightName: string): Boolean;
function CaptureFileSnapshot(const FileName: string): TFileSnapshot;
function SameFileSnapshot(const Left, Right: TFileSnapshot): Boolean;
function FileSnapshotIsCurrent(const FileName: string;
  const Snapshot: TFileSnapshot): Boolean;
procedure LoadDocumentLines(Lines: TStrings; const FileName: string;
  out Snapshot: TFileSnapshot);
procedure AtomicSaveDocument(Lines: TStrings; const FileName: string;
  out Snapshot: TFileSnapshot);
procedure AtomicSaveDocumentChecked(Lines: TStrings; const FileName: string;
  const Expected: TFileSnapshot; out Snapshot: TFileSnapshot);
procedure WriteProjectIni(Ini: TMemIniFile; const FileName: string;
  const Expected: TFileSnapshot);
procedure ValidateProjectPath(const FileName: string);
function ProjectUnitPath(const ProjectName, UnitName: string): string;
function UpdateProjectFileReference(const ProjectName, OldName,
  NewName: string): Boolean;

implementation

uses MD5
  {$IFDEF UNIX}, BaseUnix{$ENDIF};

{$IFDEF UNIX}
function CRealPath(Path, ResolvedPath: PChar): PChar; cdecl;
  external 'c' name 'realpath';
{$ENDIF}

function CanonicalDocumentPath(const FileName: string): string;
{$IFDEF UNIX}
var
  Buffer, LinkName, Parent: string;
  FileInfo: Stat;
  LinkOrdinal: Integer;
{$ENDIF}
begin
  Result := ExpandFileName(FileName);
  {$IFDEF UNIX}
  { Follow the final link even when its destination has not been created yet. }
  for LinkOrdinal := 1 to 40 do
  begin
    if (fpLStat(PChar(Result), FileInfo) <> 0) or
      not FPS_ISLNK(FileInfo.st_mode) then Break;
    LinkName := fpReadLink(Result);
    if LinkName = '' then Break;
    if LinkName[1] = DirectorySeparator then Result := ExpandFileName(LinkName)
    else Result := ExpandFileName(ExtractFilePath(Result) + LinkName);
    if LinkOrdinal = 40 then
      raise EInOutError.Create('Too many symbolic links: ' + FileName);
  end;
  SetLength(Buffer, 4096);
  if CRealPath(PChar(Result), PChar(Buffer)) <> nil then
    Exit(StrPas(PChar(Buffer)));
  Parent := ExtractFileDir(Result);
  if CRealPath(PChar(Parent), PChar(Buffer)) <> nil then
    Result := IncludeTrailingPathDelimiter(StrPas(PChar(Buffer))) +
      ExtractFileName(Result);
  {$ENDIF}
end;

function SameDocumentPath(const LeftName, RightName: string): Boolean;
{$IFDEF UNIX}
var LeftInfo, RightInfo: Stat;
{$ENDIF}
begin
  Result := False;
  if (LeftName = '') or (RightName = '') then Exit;
  Result := CanonicalDocumentPath(LeftName) = CanonicalDocumentPath(RightName);
  {$IFDEF UNIX}
  if not Result and (fpStat(PChar(LeftName), LeftInfo) = 0) and
    (fpStat(PChar(RightName), RightInfo) = 0) then
    Result := (LeftInfo.st_dev = RightInfo.st_dev) and
      (LeftInfo.st_ino = RightInfo.st_ino);
  {$ENDIF}
end;

function StreamSignature(Stream: TStream): string;
var
  Context: TMD5Context;
  Digest: TMD5Digest;
  Buffer: array[0..8191] of Byte;
  Count: LongInt;
begin
  MD5Init(Context);
  Stream.Position := 0;
  repeat
    Count := Stream.Read(Buffer, SizeOf(Buffer));
    if Count > 0 then MD5Update(Context, Buffer, Count);
  until Count = 0;
  MD5Final(Context, Digest);
  Result := MD5Print(Digest);
end;

function FileMetadata(const FileName: string): string;
{$IFDEF UNIX}var Info: Stat;{$ENDIF}
begin
  Result := '';
  {$IFDEF UNIX}
  if fpStat(PChar(FileName), Info) = 0 then
  begin
    Result := IntToStr(Info.st_dev) + ':' + IntToStr(Info.st_ino) + ':' +
      IntToStr(Info.st_size) + ':' + IntToStr(Info.st_mtime) + ':' +
      IntToStr(Info.st_ctime) + ':' + IntToStr(Info.st_mode);
    {$IF DEFINED(LINUX) AND DEFINED(CPUX86_64)}
    Result := Result + ':' + IntToStr(Info.st_mtime_nsec) + ':' +
      IntToStr(Info.st_ctime_nsec);
    {$ENDIF}
  end;
  {$ENDIF}
end;

function FileSnapshotIsCurrent(const FileName: string;
  const Snapshot: TFileSnapshot): Boolean;
begin
  if not Snapshot.Present then Exit(not FileExists(FileName));
  Result := (Snapshot.Metadata <> '') and
    (Snapshot.Metadata = FileMetadata(FileName));
end;

function CaptureFileSnapshot(const FileName: string): TFileSnapshot;
var Stream: TFileStream; BeforeMetadata, AfterMetadata: string;
begin
  Result.Present := FileExists(FileName);
  Result.Signature := '';
  Result.Metadata := '';
  if not Result.Present then Exit;
  BeforeMetadata := FileMetadata(FileName);
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try
    Result.Signature := StreamSignature(Stream);
    AfterMetadata := FileMetadata(FileName);
    if BeforeMetadata = AfterMetadata then Result.Metadata := AfterMetadata;
  finally
    Stream.Free;
  end;
end;

function SameFileSnapshot(const Left, Right: TFileSnapshot): Boolean;
begin
  Result := (Left.Present = Right.Present) and
    (not Left.Present or (Left.Signature = Right.Signature));
end;

procedure LoadDocumentLines(Lines: TStrings; const FileName: string;
  out Snapshot: TFileSnapshot);
var Source: TMemoryStream; BeforeMetadata, AfterMetadata: string;
begin
  BeforeMetadata := FileMetadata(FileName);
  Source := TMemoryStream.Create;
  try
    Source.LoadFromFile(FileName);
    Snapshot.Present := True;
    Snapshot.Signature := StreamSignature(Source);
    Snapshot.Metadata := '';
    AfterMetadata := FileMetadata(FileName);
    if BeforeMetadata = AfterMetadata then Snapshot.Metadata := AfterMetadata;
    Source.Position := 0;
    Lines.LoadFromStream(Source);
  finally
    Source.Free;
  end;
end;

procedure SaveDocumentFile(Lines: TStrings; const FileName: string;
  CheckExpected: Boolean; const Expected: TFileSnapshot;
  out Snapshot: TFileSnapshot);
var
  TargetName, TemporaryName: string;
  CurrentSnapshot: TFileSnapshot;
  {$IFDEF UNIX}FileInfo: Stat; ExistingFile: Boolean;{$ENDIF}
begin
  TargetName := CanonicalDocumentPath(FileName);
  {$IFDEF UNIX}
  ExistingFile := fpStat(PChar(TargetName), FileInfo) = 0;
  if ExistingFile and ((FileInfo.st_mode and &222) = 0) then
    raise EFCreateError.Create('File is read-only: ' + FileName);
  if ExistingFile and (fpAccess(PChar(TargetName), W_OK) <> 0) then
    raise EFCreateError.Create(SysErrorMessage(fpGetErrno));
  {$ENDIF}
  TemporaryName := GetTempFileName(ExtractFilePath(TargetName), '.devcpp-save-');
  try
    Lines.SaveToFile(TemporaryName);
    Snapshot := CaptureFileSnapshot(TemporaryName);
    {$IFDEF UNIX}
    if ExistingFile and
      (fpChown(PChar(TemporaryName), FileInfo.st_uid, FileInfo.st_gid) <> 0) then
      raise EFCreateError.Create(SysErrorMessage(fpGetErrno));
    if ExistingFile and
      (fpChmod(PChar(TemporaryName), FileInfo.st_mode and &777) <> 0) then
      raise EFCreateError.Create(SysErrorMessage(fpGetErrno));
    {$ENDIF}
    if CheckExpected then
    begin
      { Both records describe the target, never the temporary inode. }
      CurrentSnapshot := CaptureFileSnapshot(FileName);
      if not SameFileSnapshot(Expected, CurrentSnapshot) or
        ((Expected.Metadata <> '') and
          (Expected.Metadata <> CurrentSnapshot.Metadata)) then
        raise EFCreateError.Create('File changed while saving: ' + FileName);
    end;
    if CanonicalDocumentPath(FileName) <> TargetName then
      raise EFCreateError.Create('File path changed while saving: ' + FileName);
    if not RenameFile(TemporaryName, TargetName) then
      raise EFCreateError.Create(SysErrorMessage(GetLastOSError));
    TemporaryName := '';
    Snapshot.Metadata := FileMetadata(FileName);
  finally
    if TemporaryName <> '' then DeleteFile(TemporaryName);
  end;
end;

procedure AtomicSaveDocument(Lines: TStrings; const FileName: string;
  out Snapshot: TFileSnapshot);
var Unused: TFileSnapshot;
begin
  Unused.Present := False;
  Unused.Signature := '';
  SaveDocumentFile(Lines, FileName, False, Unused, Snapshot);
end;

procedure AtomicSaveDocumentChecked(Lines: TStrings; const FileName: string;
  const Expected: TFileSnapshot; out Snapshot: TFileSnapshot);
begin
  SaveDocumentFile(Lines, FileName, True, Expected, Snapshot);
end;

procedure WriteProjectIni(Ini: TMemIniFile; const FileName: string;
  const Expected: TFileSnapshot);
var Contents, Sections, Values: TStringList; Saved: TFileSnapshot; I, J, K: Integer;
begin
  ValidateProjectPath(FileName);
  Contents := TStringList.Create;
  Sections := TStringList.Create;
  Values := TStringList.Create;
  try
    Ini.ReadSections(Sections);
    for I := 0 to Sections.Count - 1 do
    begin
      ValidateProjectPath(Sections[I]);
      Values.Clear;
      Ini.ReadSectionValues(Sections[I], Values);
      for J := 0 to Values.Count - 1 do
        for K := 1 to Length(Values[J]) do
          if Values[J][K] in [#0, #10, #13] then
            raise EInOutError.Create('Project values cannot contain line breaks or NUL characters.');
    end;
    Ini.GetStrings(Contents);
    AtomicSaveDocumentChecked(Contents, FileName, Expected, Saved);
  finally
    Values.Free;
    Sections.Free;
    Contents.Free;
  end;
end;

procedure ValidateProjectPath(const FileName: string);
var I: Integer;
begin
  for I := 1 to Length(FileName) do
    if FileName[I] in [#0, #10, #13] then
      raise EInOutError.Create('Project paths cannot contain line breaks or NUL characters.');
end;

function ProjectUnitPath(const ProjectName, UnitName: string): string;
var NormalName: string;
begin
  ValidateProjectPath(ProjectName);
  ValidateProjectPath(UnitName);
  NormalName := StringReplace(UnitName, '\', DirectorySeparator, [rfReplaceAll]);
  if NormalName = '' then Exit('');
  if NormalName[1] = DirectorySeparator then Result := ExpandFileName(NormalName)
  else Result := ExpandFileName(ExtractFilePath(ProjectName) + NormalName);
end;

function UpdateProjectFileReference(const ProjectName, OldName,
  NewName: string): Boolean;
var
  Ini: TMemIniFile;
  UnitCount, UnitOrdinal: Integer;
  UnitSection, StoredName: string;
  Snapshot: TFileSnapshot;
begin
  Result := False;
  if (ProjectName = '') or (OldName = '') or (NewName = '') then Exit;
  ValidateProjectPath(ProjectName);
  ValidateProjectPath(OldName);
  ValidateProjectPath(NewName);
  Snapshot := CaptureFileSnapshot(ProjectName);
  Ini := TMemIniFile.Create(ProjectName);
  try
    UnitCount := Ini.ReadInteger('Project', 'UnitCount', 0);
    if (UnitCount < 0) or (UnitCount > 100000) then
      raise EInOutError.Create('Invalid project unit count.');
    for UnitOrdinal := 1 to UnitCount do
    begin
      UnitSection := 'Unit' + IntToStr(UnitOrdinal);
      StoredName := Ini.ReadString(UnitSection, 'FileName', '');
      if SameDocumentPath(ProjectUnitPath(ProjectName, StoredName), OldName) then
      begin
        Ini.WriteString(UnitSection, 'FileName',
          ExtractRelativePath(ExtractFilePath(ProjectName), ExpandFileName(NewName)));
        Result := True;
      end;
    end;
    if Result then WriteProjectIni(Ini, ProjectName, Snapshot);
  finally
    Ini.Free;
  end;
end;

end.
