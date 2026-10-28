program devcpp_noi;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF} app_cli,
  {$IFDEF UNIX}x11_init,{$ENDIF}
  Interfaces, Forms, SysUtils, startup_trace, gdk2, mainform, app_instance;

begin
  StartupMark('GTK units ready');
  if not PrepareInstance then Halt(ExitCode);
  { GNOME must not group a packaged launch with an older source-build window. }
  if ExtractFileDir(ExpandFileName(ParamStr(0))) = '/usr/lib/dev-cpp-linux' then
    gdk_set_program_class('DevCppLinuxInstalled')
  else gdk_set_program_class('DevCppLinuxSource');
  RequireDerivedFormResource := False;
  StartupMark('instance ready');
  Application.Initialize;
  StartupMark('application initialized');
  Application.CreateForm(TMainForm, MainWindow);
  StartupMark('form constructed');
  Application.Run;
end.
