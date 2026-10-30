program devcpp_noi;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF} app_cli,
  {$IFDEF UNIX}x11_init,{$ENDIF}
  Interfaces, Forms, SysUtils, startup_trace, gdk2, app_version, mainform, app_instance;

{ The NOI Lazarus 2.0.6 GLib binding omits this existing GLib API. }
procedure g_set_application_name(AName:PChar);cdecl;external 'glib-2.0';

begin
  StartupMark('GTK units ready');
  if not PrepareInstance then Halt(ExitCode);
  { GNOME must not group a packaged launch with an older source-build window. }
  if ExtractFileDir(ExpandFileName(ParamStr(0))) = '/usr/lib/dev-cpp' then
    gdk_set_program_class('DevCppInstalled')
  else gdk_set_program_class('DevCppSource');
  RequireDerivedFormResource := False;
  StartupMark('instance ready');
  Application.Initialize;
  Application.Title := AppName;
  g_set_application_name(PChar(AppName));
  StartupMark('application initialized');
  Application.CreateForm(TMainForm, MainWindow);
  StartupMark('form constructed');
  Application.Run;
end.
