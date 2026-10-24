unit app_instance;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils;

var
  StartupFiles: TStringList;

function PrepareInstance: Boolean;
procedure ReadInstanceRequests(Files: TStrings; var ActivateWindow: Boolean);

implementation

uses SimpleIPC;

var
  InstanceServer: TSimpleIPCServer = nil;
  InstanceAddress: string;

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
  InstanceAddress := ExpandFileName(CacheDirectory + DirectorySeparator + 'instance.pipe');
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
