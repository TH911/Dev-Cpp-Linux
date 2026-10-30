unit app_paths;
{$mode objfpc}{$H+}
interface
function ApplicationConfigFile(MigrateLegacy: Boolean = False): string;
implementation
uses SysUtils, Classes, BaseUnix;
function ApplicationConfigFile(MigrateLegacy: Boolean): string;
var Folder, OldName: string; Info: Stat; Source, Target: TStream;
  Descriptor, Count: LongInt; Buffer: array[0..8191] of Byte;
begin
  Folder := GetEnvironmentVariable('HOME');
  if Folder = '' then Folder := ExtractFilePath(ParamStr(0))
  else Folder := IncludeTrailingPathDelimiter(Folder) + '.config';
  Result := IncludeTrailingPathDelimiter(Folder) + 'dev-cpp.ini';
  if not MigrateLegacy or FileExists(Result) then Exit;
  OldName := IncludeTrailingPathDelimiter(Folder) + 'dev-cpp-linux.ini';
  if not FileExists(OldName) then
    OldName := IncludeTrailingPathDelimiter(Folder) + 'devcpp-noi.ini';
  if (fpLStat(OldName, Info) <> 0) or not FPS_ISREG(Info.st_mode) or
    (Info.st_uid <> fpGetUID) then Exit;
  { Exclusive creation preserves an existing config, including a symlink.
    Keep the old file intact so older installations remain recoverable. }
  Descriptor := fpOpen(Result, O_WRONLY or O_CREAT or O_EXCL, &600);
  if Descriptor < 0 then Exit;
  Source := nil; Target := THandleStream.Create(Descriptor);
  try
   try
    Source := TFileStream.Create(OldName, fmOpenRead or fmShareDenyNone);
    repeat
      Count := Source.Read(Buffer, SizeOf(Buffer));
      if Count > 0 then Target.WriteBuffer(Buffer, Count);
    until Count = 0;
  except
    fpUnlink(Result);
    raise;
  end;
  finally Source.Free; Target.Free; fpClose(Descriptor); end;
end;
end.
