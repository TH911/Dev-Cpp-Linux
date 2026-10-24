unit x11_init;

{$mode objfpc}{$H+}

interface

implementation

{$IFDEF UNIX}
uses Dynlibs;

type
  TXInitThreadsProc = function: LongInt; cdecl;

var
  X11Library: TLibHandle;
  InitX11Threads: TXInitThreadsProc;

initialization
  { Must run before Interfaces initializes GTK or opens the X display. }
  X11Library := LoadLibrary('libX11.so.6');
  if X11Library <> NilHandle then
  begin
    Pointer(InitX11Threads) := GetProcedureAddress(X11Library, 'XInitThreads');
    if Assigned(InitX11Threads) then InitX11Threads();
    { Keep Xlib loaded for the lifetime of the GTK interface. }
  end;
{$ENDIF}

end.
