unit app_cli;

{$mode objfpc}{$H+}

interface

implementation

uses app_version, startup_trace, gio_preflight;

initialization
  { This unit must initialize before Interfaces: GTK2 otherwise opens DISPLAY
    before the program body, even for a command that only prints its version. }
  if (ParamCount = 1) and (ParamStr(1) = '--version') then
  begin
    WriteLn(AppCommand, ' ', AppVersion);
    WriteLn(AppRepositoryUrl);
    Halt(0);
  end;

  if (ParamCount = 1) and (ParamStr(1) = '--help') then
  begin
    WriteLn(AppCommand, ' ', AppVersion);
    WriteLn('Usage: dev-cpp [--new-window | --forward-only] [FILE ...]');
    WriteLn('       dev-cpp --version');
    WriteLn('       dev-cpp --help');
    WriteLn(AppRepositoryUrl);
    Halt(0);
  end;

  PrepareGioAsyncTypes;

end.
