program devcpp_noi;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads, x11_init,{$ENDIF}
  Interfaces, Forms, mainform, app_instance;

begin
  if not PrepareInstance then Halt(ExitCode);
  RequireDerivedFormResource := False;
  Application.Initialize;
  Application.CreateForm(TMainForm, MainWindow);
  Application.Run;
end.
