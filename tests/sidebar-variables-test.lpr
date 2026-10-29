program sidebar_variables_test;
{$mode objfpc}{$H+}
uses Interfaces,Forms,Classes,SysUtils,ComCtrls,StdCtrls,SynEdit,mainform,app_instance,debugger_panel,gdb_session,ui_language;
procedure Check(Value:Boolean;const S:string);
begin if not Value then begin WriteLn(StdErr,'FAIL: ',S);Halt(1);end;end;
function Panel(Owner:TComponent):TDebuggerPanel;
var I:Integer;
begin
  if Owner is TDebuggerPanel then Exit(TDebuggerPanel(Owner));
  for I:=0 to Owner.ComponentCount-1 do begin Result:=Panel(Owner.Components[I]);if Result<>nil then Exit;end;Result:=nil;
end;
function LocalTree(Owner:TComponent):TTreeView;
var I:Integer;Tree:TTreeView;
begin
  if Owner is TTreeView then begin
    Tree:=TTreeView(Owner);if (Tree.Items.Count>0) and (Tree.Items[0].Text=Tr('Local variables')) then Exit(Tree);
  end;
  for I:=0 to Owner.ComponentCount-1 do begin Result:=LocalTree(Owner.Components[I]);if Result<>nil then Exit;end;Result:=nil;
end;
procedure Dump(Owner:TComponent);
var I:Integer;
begin
  if Owner is TMemo then WriteLn(StdErr,TMemo(Owner).Text);
  for I:=0 to Owner.ComponentCount-1 do Dump(Owner.Components[I]);
end;
var Form:TMainForm;Debugger:TDebuggerPanel;Tree:TTreeView;Started:QWord;I,J:Integer;
  NameText,Stage:string;Code:TStringList;DebugButton:TToolButton;
procedure Pump;
begin
  Application.ProcessMessages;Sleep(5);
  if GetTickCount64-Started>=20000 then begin
    if Debugger<>nil then WriteLn(StdErr,'GDB state: ',Ord(Debugger.Session.State));
    Tree:=LocalTree(Form);if Tree<>nil then for I:=0 to Tree.Items.Count-1 do WriteLn(StdErr,Tree.Items[I].Text);
    Dump(Form);Check(False,'debugger timed out: '+Stage);
  end;
end;
procedure WaitLocal(const Expected:string);
var Found:Boolean;J:Integer;
begin
  Started:=GetTickCount64;
  repeat
    Pump;Tree:=LocalTree(Form);Found:=False;
    if Tree<>nil then for J:=0 to Tree.Items.Count-1 do if Tree.Items[J].Text=Expected then Found:=True;
  until Found;
  Check(Tree.IsVisible,'real sidebar variable tree is visible while stepping');
end;
begin
  Application.Initialize;Check(PrepareInstance,'isolated instance');
  NameText:=GetTempDir(False)+'devcpp-sidebar-'+IntToStr(GetProcessID)+'.cpp';
  Code:=TStringList.Create;Code.Text:='int main() {'+LineEnding+'  int value = 7;'+LineEnding+'  value += 5;'+LineEnding+'  return value;'+LineEnding+'}'+LineEnding;Code.SaveToFile(NameText);
  StartupFiles.Clear;StartupFiles.Add(NameText);Form:=TMainForm.Create(nil);
  try
    Form.Show;Application.ProcessMessages;Check(Panel(Form)=nil,'GDB widgets are deferred at first frame');
    DebugButton:=nil;
    for I:=0 to Form.ComponentCount-1 do
      if (Form.Components[I] is TToolBar) then with TToolBar(Form.Components[I]) do
        for J:=0 to ButtonCount-1 do if Buttons[J].Caption=Tr('Start Debugging') then DebugButton:=Buttons[J];
    Check(DebugButton<>nil,'real Debug toolbar command');DebugButton.Click;
    Stage:='start';Started:=GetTickCount64;
    repeat Pump;Debugger:=Panel(Form);until (Debugger<>nil) and (Debugger.Session.State=gsStopped);
    Stage:='tree';Started:=GetTickCount64;repeat Pump;Tree:=LocalTree(Form);until Tree<>nil;
    Stage:='declaration line';Debugger.Session.StepOver;Started:=GetTickCount64;
    repeat Pump until (Form.ActiveControl is TSynEdit) and (TSynEdit(Form.ActiveControl).CaretY=2) and (Debugger.Session.State=gsStopped);
    Stage:='first initialized value';Debugger.Session.StepOver;WaitLocal('value = 7');
    Stage:='second step';Debugger.Session.StepOver;WaitLocal('value = 12');
    Debugger.Session.Stop;Started:=GetTickCount64;repeat Pump until not Debugger.Session.Active;
    WriteLn('PASS: deferred debugger; F5-equivalent build/start; visible sidebar locals refresh from 7 to 12 during real GDB steps');
  finally Form.Free;Code.Free;DeleteFile(NameText);DeleteFile(ChangeFileExt(NameText,''));end;
end.
