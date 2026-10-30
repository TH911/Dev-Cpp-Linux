unit font_match;
{$mode objfpc}{$H+}
interface
uses Classes;
procedure ListFontFamilies(Items:TStrings);
function InstalledFontFamily(const Name: string): Boolean;
implementation
uses SysUtils, Dynlibs;
type
  TCreate = function: Pointer; cdecl;
  TAdd = function(P:Pointer;Field,Value:PChar):LongInt;cdecl;
  TSub = function(Config,P:Pointer;Kind:LongInt):LongInt;cdecl;
  TDefault = procedure(P:Pointer);cdecl;
  TMatch = function(Config,P:Pointer;var Status:LongInt):Pointer;cdecl;
  TGet = function(P:Pointer;Field:PChar;Index:LongInt;var Value:PChar):LongInt;cdecl;
  TDestroy = procedure(P:Pointer);cdecl;
var Lib:TLibHandle=NilHandle;CreatePattern:TCreate;AddString:TAdd;Substitute:TSub;
  Defaults:TDefault;Match:TMatch;GetString:TGet;DestroyPattern:TDestroy;Loaded:Boolean=False;
function InstalledFontFamily(const Name:string):Boolean;
var Pattern,Found:Pointer;Status:LongInt;Family:PChar;
begin
  Result:=False;
  if not Loaded then begin
    Loaded:=True;Lib:=LoadLibrary('libfontconfig.so.1');
    if Lib=NilHandle then Exit;
    Pointer(CreatePattern):=GetProcedureAddress(Lib,'FcPatternCreate');
    Pointer(AddString):=GetProcedureAddress(Lib,'FcPatternAddString');
    Pointer(Substitute):=GetProcedureAddress(Lib,'FcConfigSubstitute');
    Pointer(Defaults):=GetProcedureAddress(Lib,'FcDefaultSubstitute');
    Pointer(Match):=GetProcedureAddress(Lib,'FcFontMatch');
    Pointer(GetString):=GetProcedureAddress(Lib,'FcPatternGetString');
    Pointer(DestroyPattern):=GetProcedureAddress(Lib,'FcPatternDestroy');
  end;
  if not Assigned(CreatePattern) or not Assigned(AddString) or not Assigned(Substitute) or
    not Assigned(Defaults) or not Assigned(Match) or not Assigned(GetString) or not Assigned(DestroyPattern) then Exit;
  Pattern:=CreatePattern();if Pattern=nil then Exit;
  try
    AddString(Pattern,'family',PChar(Name));Substitute(nil,Pattern,0);Defaults(Pattern);
    Found:=Match(nil,Pattern,Status);if Found=nil then Exit;
    try
      Family:=nil;
      if GetString(Found,'family',0,Family)=0 then Result:=SameText(string(Family),Name);
    finally DestroyPattern(Found);end;
  finally DestroyPattern(Pattern);end;
end;
procedure ListFontFamilies(Items:TStrings);
type
  TObjCreate=function:Pointer;cdecl;
  TObjAdd=function(Obj:Pointer;Name:PChar):LongInt;cdecl;
  TList=function(Config,Pattern,Objects:Pointer):Pointer;cdecl;
  TFontSet=record Count,Space:LongInt;Fonts:Pointer;end;
  PFontSet=^TFontSet;
var ObjCreate:TObjCreate;ObjAdd:TObjAdd;List:TList;ObjDestroy,SetDestroy:TDestroy;
  Objects,Pattern:Pointer;FontSet:PFontSet;I:Integer;Family:PChar;Sorted:TStringList;
begin
  InstalledFontFamily('Monospace');
  Sorted:=TStringList.Create;
  try
    Sorted.Sorted:=True;Sorted.Duplicates:=dupIgnore;Sorted.CaseSensitive:=False;
    if Lib<>NilHandle then begin
      Pointer(ObjCreate):=GetProcedureAddress(Lib,'FcObjectSetCreate');
      Pointer(ObjAdd):=GetProcedureAddress(Lib,'FcObjectSetAdd');
      Pointer(List):=GetProcedureAddress(Lib,'FcFontList');
      Pointer(ObjDestroy):=GetProcedureAddress(Lib,'FcObjectSetDestroy');
      Pointer(SetDestroy):=GetProcedureAddress(Lib,'FcFontSetDestroy');
      if Assigned(CreatePattern) and Assigned(DestroyPattern) and Assigned(GetString) and
        Assigned(ObjCreate) and Assigned(ObjAdd) and Assigned(List) and Assigned(ObjDestroy) and Assigned(SetDestroy) then begin
        Objects:=ObjCreate();
        if Objects<>nil then try
          ObjAdd(Objects,'family');Pattern:=CreatePattern();
          if Pattern<>nil then try
            FontSet:=PFontSet(List(nil,Pattern,Objects));
            if FontSet<>nil then try
              for I:=0 to FontSet^.Count-1 do begin
                Family:=nil;
                if GetString(PPointer(PtrUInt(FontSet^.Fonts)+PtrUInt(I)*SizeOf(Pointer))^,'family',0,Family)=0 then
                  Sorted.Add(string(Family));
              end;
            finally SetDestroy(FontSet);end;
          finally DestroyPattern(Pattern);end;
        finally ObjDestroy(Objects);end;
      end;
    end;
    if Sorted.Count=0 then Sorted.Add('Monospace');
    Items.Assign(Sorted);
  finally Sorted.Free;end;
end;

finalization
  if Lib<>NilHandle then UnloadLibrary(Lib);
end.
