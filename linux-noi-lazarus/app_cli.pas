unit app_cli;

{$mode objfpc}{$H+}

interface

implementation

uses app_version;

initialization
  { This unit must initialize before Interfaces: GTK2 otherwise opens DISPLAY
    before the program body, even for a command that only prints its version. }
  if (ParamCount = 1) and (ParamStr(1) = '--version') then
  begin
    WriteLn('Dev-C++ NOI ', AppVersion);
    WriteLn(AppRepositoryUrl);
    Halt(0);
  end;

end.
