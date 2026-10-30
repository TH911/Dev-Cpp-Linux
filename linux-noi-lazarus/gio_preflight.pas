unit gio_preflight;
{$mode objfpc}{$H+}
interface
procedure PrepareGioAsyncTypes;
implementation
uses Dynlibs,SysUtils,startup_trace;
type
  TGetType=function:PtrUInt;cdecl;
  TClassRef=function(AType:PtrUInt):Pointer;cdecl;
  TClassUnref=procedure(AClass:Pointer);cdecl;
function SetProcessEnvironment(Name,Value:PChar;Overwrite:LongInt):LongInt;
  cdecl;external 'c' name 'setenv';
function GetProcessEnvironment(Name:PChar):PChar;
  cdecl;external 'c' name 'getenv';
var
  Gio:TLibHandle=NilHandle;
  Objects:TLibHandle=NilHandle;
  AsyncClass,TaskClass:Pointer;
  ClassUnref:TClassUnref;
function ProcessEnvironment(const Name:string):string;
var Value:PChar;
begin
  Value:=GetProcessEnvironment(PChar(Name));
  if Value=nil then Result:='' else Result:=string(Value);
end;
procedure PrepareGioAsyncTypes;
var AsyncType,TaskType:TGetType;ClassRef:TClassRef;
begin
  { The port accepts local file paths. Avoid activating GVFS synchronously
    inside GTK2/IBus for those paths; this is process-local and leaves the
    input module enabled. Users can explicitly select another GIO backend. }
  if ProcessEnvironment('GIO_USE_VFS')='' then
    SetProcessEnvironment('GIO_USE_VFS','local',1);
  { Lazarus 2.0.6 GTK2 reads its IM commit string during key filtering. IBus'
    default asynchronous commit arrives later and is lost by that binding.
    Request the module's supported synchronous mode for this application. }
  if ProcessEnvironment('IBUS_ENABLE_SYNC_MODE')='' then
    SetProcessEnvironment('IBUS_ENABLE_SYNC_MODE','1',1);
  { LCL filters keys itself; the GTK2 module's global snooper would consume
    those keys before that custom-control path receives the IM commit. }
  if ProcessEnvironment('IBUS_DISABLE_SNOOPER')='' then
    SetProcessEnvironment('IBUS_DISABLE_SNOOPER','1',1);
  StartupMark('GIO file backend: '+ProcessEnvironment('GIO_USE_VFS'));
  StartupMark('IBus synchronous commit: '+ProcessEnvironment('IBUS_ENABLE_SYNC_MODE'));
  StartupMark('GIO async type preparation begin');
  Gio:=LoadLibrary('libgio-2.0.so.0');
  Objects:=LoadLibrary('libgobject-2.0.so.0');
  if (Gio<>NilHandle) and (Objects<>NilHandle) then begin
    Pointer(AsyncType):=GetProcedureAddress(Gio,'g_simple_async_result_get_type');
    Pointer(TaskType):=GetProcedureAddress(Gio,'g_task_get_type');
    Pointer(ClassRef):=GetProcedureAddress(Objects,'g_type_class_ref');
    Pointer(ClassUnref):=GetProcedureAddress(Objects,'g_type_class_unref');
    { Register and initialize GIO async classes before GTK creates IBus while
      holding GObject's class-initialization lock. A GIO worker otherwise tries
      to register GSimpleAsyncResult under that same lock while GVFS waits for
      its D-Bus reply: the observed 25-second startup stall. Keep both classes
      alive until GTK teardown, including when GVFS is explicitly selected. }
    if Assigned(ClassRef) and Assigned(ClassUnref) then begin
      if Assigned(AsyncType) then AsyncClass:=ClassRef(AsyncType());
      if Assigned(TaskType) then TaskClass:=ClassRef(TaskType());
    end;
  end;
  StartupMark('GIO async type preparation end');
end;
finalization
  if Assigned(ClassUnref) then begin
    if TaskClass<>nil then ClassUnref(TaskClass);
    if AsyncClass<>nil then ClassUnref(AsyncClass);
  end;
  if Objects<>NilHandle then UnloadLibrary(Objects);
  if Gio<>NilHandle then UnloadLibrary(Gio);
end.
