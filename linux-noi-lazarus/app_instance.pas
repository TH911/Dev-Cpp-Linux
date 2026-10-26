unit app_instance;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils;

var
  StartupFiles: TStringList;

function PrepareInstance: Boolean;
procedure ReadInstanceRequests(Files: TStrings; var ActivateWindow: Boolean);

implementation

uses SimpleIPC, md5, app_version, BaseUnix;

var
  InstanceServer: TSimpleIPCServer = nil;
  InstanceAddress: string;

procedure IsolateInstanceHandle;
var Search: TSearchRec; Descriptor, Flags: Integer;
  TargetInfo, DescriptorInfo: Stat; Found: Boolean;
begin
  { FPC 3.0.4 SimpleIPC does not mark its FIFO close-on-exec. An editor's
    compiler or terminal could otherwise keep the read end alive after the
    editor exits, making later launches forward into an abandoned pipe. }
  if (fpStat(InstanceAddress, TargetInfo) <> 0) or
    not FPS_ISFIFO(TargetInfo.st_mode) then
    raise EInOutError.Create('Could not identify the IDE instance handle.');
  Found := False;
  if FindFirst('/proc/self/fd/*', faAnyFile, Search) <> 0 then
    raise EInOutError.Create('Could not inspect the IDE instance handle.');
  try
    repeat
      Descriptor := StrToIntDef(Search.Name, -1);
      if Descriptor < 0 then Continue;
      if (fpFStat(Descriptor, DescriptorInfo) <> 0) or
        (DescriptorInfo.st_dev <> TargetInfo.st_dev) or
        (DescriptorInfo.st_ino <> TargetInfo.st_ino) then Continue;
      Flags := fpFcntl(Descriptor, F_GETFD);
      { FD_CLOEXEC is POSIX value 1, not exported by this FPC release. }
      if (Flags < 0) or (fpFcntl(Descriptor, F_SETFD, Flags or 1) < 0) then
        raise EInOutError.Create('Could not isolate the IDE instance handle.');
      Found := True;
    until FindNext(Search) <> 0;
  finally
    FindClose(Search);
  end;
  if not Found then
    raise EInOutError.Create('The IDE instance handle was not found.');
end;

procedure AddPayloadFiles(const Payload: string; Files: TStrings);
var
  ByteOrdinal, NameStart: Integer;
begin
  NameStart := 1;
  for ByteOrdinal := 1 to Length(Payload) do
    if Payload[ByteOrdinal] = #0 then
    begin
      if ByteOrdinal > NameStart then
        Files.Add(Copy(Payload, NameStart, ByteOrdinal - NameStart));
      NameStart := ByteOrdinal + 1;
    end;
end;

function ForwardToExisting(const Payload: string): Boolean;
var
  Client: TSimpleIPCClient;
begin
  Result := False;
  Client := TSimpleIPCClient.Create(nil);
  try
    Client.ServerID := InstanceAddress;
    if not Client.ServerRunning then Exit;
    Client.Connect;
    Client.SendStringMessage(Payload);
    Result := True;
  finally
    Client.Free;
  end;
end;

procedure EnsureInstanceServer;
var
  Client: TSimpleIPCClient;
begin
  if InstanceServer <> nil then Exit;
  Client := TSimpleIPCClient.Create(nil);
  try
    Client.ServerID := InstanceAddress;
    if Client.ServerRunning then Exit;
  finally
    Client.Free;
  end;
  InstanceServer := TSimpleIPCServer.Create(nil);
  try
    InstanceServer.ServerID := InstanceAddress;
    InstanceServer.Global := True;
    InstanceServer.StartServer(False);
    IsolateInstanceHandle;
  except
    FreeAndNil(InstanceServer);
    raise;
  end;
end;

function PrepareInstance: Boolean;
var
  CacheDirectory, Payload, Argument: string;
  ArgumentOrdinal: Integer;
  NewWindow, ForwardOnly: Boolean;
begin
  StartupFiles := TStringList.Create;
  CacheDirectory := GetEnvironmentVariable('XDG_CACHE_HOME');
  if CacheDirectory = '' then
    CacheDirectory := GetEnvironmentVariable('HOME') + DirectorySeparator + '.cache';
  CacheDirectory := IncludeTrailingPathDelimiter(CacheDirectory) + 'devcpp-noi';
  ForceDirectories(CacheDirectory);
  { Separate installed releases and source builds; never activate a stale binary. }
  InstanceAddress := ExpandFileName(CacheDirectory + DirectorySeparator +
    'instance-' + Copy(MD5Print(MD5String(AppVersion + '|' +
      ExpandFileName(ParamStr(0)))), 1, 16) + '.pipe');
  NewWindow := False;
  ForwardOnly := False;
  Payload := '';
  for ArgumentOrdinal := 1 to ParamCount do
  begin
    Argument := ParamStr(ArgumentOrdinal);
    if Argument = '--new-window' then NewWindow := True
    else if Argument = '--forward-only' then ForwardOnly := True
    else
    begin
      Argument := ExpandFileName(Argument);
      StartupFiles.Add(Argument);
      Payload := Payload + Argument + #0;
    end;
  end;
  if Payload = '' then Payload := #0;
  Result := True;
  if not NewWindow and ForwardToExisting(Payload) then
  begin
    ExitCode := 0;
    Exit(False);
  end;
  if ForwardOnly then
  begin
    ExitCode := 3;
    Exit(False);
  end;
  EnsureInstanceServer;
end;

procedure ReadInstanceRequests(Files: TStrings; var ActivateWindow: Boolean);
var
  MessageOrdinal: Integer;
begin
  Files.Clear;
  ActivateWindow := False;
  EnsureInstanceServer;
  if InstanceServer = nil then Exit;
  for MessageOrdinal := 1 to 32 do
  begin
    if not InstanceServer.PeekMessage(0, True) then Break;
    ActivateWindow := True;
    AddPayloadFiles(InstanceServer.StringMessage, Files);
  end;
end;

finalization
  FreeAndNil(InstanceServer);
  FreeAndNil(StartupFiles);

end.
