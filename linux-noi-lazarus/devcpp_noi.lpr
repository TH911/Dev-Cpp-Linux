program devcpp_noi;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF} app_cli,
  {$IFDEF UNIX}x11_init,{$ENDIF}
  Interfaces, Forms, SysUtils, gdk2, mainform, app_instance;

begin
  if not PrepareInstance then Halt(ExitCode);
  { GNOME must not group a packaged launch with an older source-build window. }
  if ExtractFileDir(ExpandFileName(ParamStr(0))) = '/usr/lib/devcpp-noi' then
    gdk_set_program_class('DevCppNoiInstalled');
  RequireDerivedFormResource := False;
  Application.Initialize;
  Application.CreateForm(TMainForm, MainWindow);
  Application.Run;
end.
