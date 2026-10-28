unit startup_trace;
{$mode objfpc}{$H+}
interface
procedure StartupMark(const Stage: string);
implementation
uses SysUtils;
var Started: QWord; Enabled: Boolean;
procedure StartupMark(const Stage: string);
begin
  if Enabled then begin
    WriteLn(StdErr, 'dev-cpp-linux startup +', GetTickCount64 - Started, ' ms: ', Stage);
    Flush(StdErr);
  end;
end;
initialization
  Started := GetTickCount64;
  Enabled := GetEnvironmentVariable('DEV_CPP_LINUX_STARTUP_TRACE') = '1';
  StartupMark('runtime ready');
end.
