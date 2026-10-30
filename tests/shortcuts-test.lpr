program shortcuts_test;
{$mode objfpc}{$H+}
uses Interfaces, Forms, Classes, SysUtils, Menus, LCLType, IniFiles,
  classic_settings, mainform, app_instance, ui_language;
procedure Check(Value:Boolean; const Detail:string);
begin if not Value then begin WriteLn(StdErr,'FAIL: ',Detail);Halt(1);end;end;
function FindItem(Form:TMainForm;const Caption:string):TMenuItem;
var I:Integer;
begin
  for I:=0 to Form.ComponentCount-1 do
    if (Form.Components[I] is TMenuItem) and
      (TMenuItem(Form.Components[I]).Count=0) and
      (TMenuItem(Form.Components[I]).Caption=Tr(Caption)) then Exit(TMenuItem(Form.Components[I]));
  Result:=nil;
end;
procedure Binding(Form:TMainForm;const Caption:string;Expected:Word);
var Item:TMenuItem;
begin
  Item:=FindItem(Form,Caption);Check(Item<>nil,'command exists '+Caption);
  Check(Item.ShortCut=Expected,'original 5.11 binding '+Caption);
end;
var Form:TMainForm;Root,A,B,C:TMenuItem;Bindings:TMenuShortcuts;
  Ini:TIniFile;Config:string;Suppressed:Boolean;Item:TMenuItem;I,J:Integer;
begin
  Application.Initialize;Check(PrepareInstance,'isolated instance');
  Form:=TMainForm.Create(nil);
  try
    Binding(Form,'&Source File',16462);
    Binding(Form,'&Open project or file...',16463);
    Binding(Form,'&Save',16467);
    Binding(Form,'Save &As...',0);
    Binding(Form,'Save A&ll',24659);
    Binding(Form,'&Close',16471);
    Binding(Form,'Close &All',24663);
    Binding(Form,'&Print...',16464);
    Binding(Form,'E&xit',32883);
    Binding(Form,'&Undo',16474);
    Binding(Form,'&Redo',16473);
    Binding(Form,'Cu&t',16472);
    Binding(Form,'&Copy',16451);
    Binding(Form,'&Paste',16470);
    Binding(Form,'Select &All',16449);
    Binding(Form,'&Find...',16454);
    Binding(Form,'Find &All...',24646);
    Binding(Form,'Find &Next',114);
    Binding(Form,'Find &Previous',8306);
    Binding(Form,'&Replace...',16466);
    Binding(Form,'Replace &All...',24658);
    Binding(Form,'&Go to line...',16455);
    Binding(Form,'Project &Options...',16456);
    Binding(Form,'&Compile',120);
    Binding(Form,'&Run',121);
    Binding(Form,'Compile && Run',122);
    Binding(Form,'R&ebuild All',123);
    Binding(Form,'&Abort Compilation',113);
    Binding(Form,'&Start Debugging',116);
    Binding(Form,'Toggle &Breakpoint',115);
    Binding(Form,'&Next Line',118);
    Binding(Form,'&Step Into',119);
    Binding(Form,'&Stop Debugging',117);
    Binding(Form,'&Full screen mode',16506);
    Binding(Form,'&Next Tab',16393);
    Binding(Form,'&Previous Tab',24585);
    Binding(Form,'Swap &Header/Source',16465);
    Binding(Form,'&Comment',16574);
    Binding(Form,'&Uncomment',16572);
    Binding(Form,'&Toggle Comment',16575);
    Binding(Form,'Toggle &Inline Comment',16570);
    Binding(Form,'&Syntax Check',16504);
    Binding(Form,'&Delete Line',16452);
    Binding(Form,'D&uplicate Line',16453);
    Binding(Form,'Move Selection &Up',24614);
    Binding(Form,'Move Selection &Down',24616);
    Binding(Form,'Code &Completion',16416);
    Binding(Form,'Open Containing &Folder',16450);
    Binding(Form,'Format current file',24641);
    for I:=0 to Form.ComponentCount-1 do
      if (Form.Components[I] is TMenuItem) and (TMenuItem(Form.Components[I]).ShortCut<>0) then
        for J:=I+1 to Form.ComponentCount-1 do
          if Form.Components[J] is TMenuItem then
            Check(TMenuItem(Form.Components[I]).ShortCut<>TMenuItem(Form.Components[J]).ShortCut,'no duplicate default shortcut');
  finally Form.Free;end;
  Config:=GetTempFileName;
  Root:=TMenuItem.Create(nil);
  try
    A:=TMenuItem.Create(Root);A.Name:='CommandSaveAs';Root.Add(A);
    B:=TMenuItem.Create(Root);B.Name:='CommandSaveAll';B.ShortCut:=24659;Root.Add(B);
    C:=TMenuItem.Create(Root);C.Name:='CommandFormat';C.ShortCut:=24641;Root.Add(C);
    Ini:=TIniFile.Create(Config);
    try Ini.WriteInteger('Shortcuts','menu.0.3',24659);Ini.WriteInteger('Shortcuts','menu.0.4',24641);finally Ini.Free;end;
    Bindings:=TMenuShortcuts.Create(Root,Config);
    try
      Check((A.ShortCut=0) and (B.ShortCut=24659) and (C.ShortCut=24641),'old factory values migrate by command');
      Check(Bindings.Match(Ord('S'),[ssCtrl,ssShift],Suppressed)=B,'Save All dispatch');
      Check(Bindings.Match(Ord('A'),[ssCtrl,ssShift],Suppressed)=C,'format dispatch');
    finally Bindings.Free;end;
    Ini:=TIniFile.Create(Config);
    try
      Ini.WriteInteger('Shortcuts','DefaultsVersion',0);
      Ini.WriteInteger('Shortcuts','menu.0.3',24660);Ini.WriteInteger('Shortcuts','menu.0.4',0);
    finally Ini.Free;end;
    Bindings:=TMenuShortcuts.Create(Root,Config);
    try
      Check((A.ShortCut=24660) and (B.ShortCut=0),'custom Save As and disabled Save All retained');
      Item:=Bindings.Match(Ord('S'),[ssCtrl,ssShift],Suppressed);
      Check((Item=nil) and Suppressed,'disabled default cannot fall through to hardcoded handler');
    finally Bindings.Free;end;
    Ini:=TIniFile.Create(Config);
    try Ini.WriteInteger('Shortcuts','menu.0.3',24641);finally Ini.Free;end;
    Bindings:=TMenuShortcuts.Create(Root,Config);
    try Check((A.ShortCut=24641) and (C.ShortCut=0),'format default does not steal a custom assignment');finally Bindings.Free;end;
    WriteLn('PASS: 49 original default actions, unique keys, factory migration and custom/disabled key preservation');
  finally Root.Free;DeleteFile(Config);end;
end.
