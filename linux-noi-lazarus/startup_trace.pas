unit startup_trace;
{$mode objfpc}{$H+}
interface
procedure StartupMark(const Stage: string);
function StartupReport: string;
implementation
uses SysUtils, Classes;
var Started: QWord; Enabled: Boolean; Marks:TStringList;
procedure StartupMark(const Stage: string);
var Entry:string;
begin
  Entry:='dev-cpp startup +'+IntToStr(GetTickCount64-Started)+' ms: '+Stage;
  Marks.Add(Entry);
  if Enabled then begin WriteLn(StdErr,Entry);Flush(StdErr);end;
end;
function StartupReport:string;
begin Result:=Marks.Text;end;
initialization
  Started:=GetTickCount64;Marks:=TStringList.Create;
  Enabled:=(GetEnvironmentVariable('DEV_CPP_STARTUP_TRACE')='1') or
    (GetEnvironmentVariable('DEV_CPP_LINUX_STARTUP_TRACE')='1');
  StartupMark('runtime ready');
finalization
  Marks.Free;
end.
