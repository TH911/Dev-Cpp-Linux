program sidebar_variables_test;
{$mode objfpc}{$H+}
uses Interfaces,Forms,Classes,SysUtils,Controls,ComCtrls,StdCtrls,Graphics,SynEdit,mainform,app_instance,debugger_panel,gdb_session,ui_language,sidebar_tabs,classic_chrome,Gtk2,Pango;
procedure Check(Value:Boolean;const S:string);
begin if not Value then begin WriteLn(StdErr,'FAIL: ',S);Halt(1);end;end;
function NativeLabel(Control:TStaticText):PGtkWidget;
begin Result:=gtk_bin_get_child(PGtkBin(gtk_bin_get_child(PGtkBin(Control.Handle))));end;
procedure TextSize(Control:TStaticText;out W,H:Integer);
begin pango_layout_get_pixel_size(gtk_label_get_layout(PGtkLabel(NativeLabel(Control))),@W,@H);end;
procedure CheckSidebarTabs;
var Window:TForm;Header:TSidebarTabs;I,J,W,H,Total,Size:Integer;
  Labels:array[0..2] of TStaticText;RightArrow:TSidebarArrow;Allocation:TGtkAllocation;
begin
  Window:=TForm.Create(nil);
  try
    Window.SetBounds(0,0,500,160);
    Header:=TSidebarTabs.Create(Window);Header.Parent:=Window;Header.Align:=alTop;
    for I:=0 to Header.ControlCount-1 do begin
      if Header.Controls[I] is TStaticText then
        Labels[Header.Controls[I].Tag]:=TStaticText(Header.Controls[I]);
      if (Header.Controls[I] is TSidebarArrow) and (Header.Controls[I].Tag=1) then
        RightArrow:=TSidebarArrow(Header.Controls[I]);
    end;
    Window.Show;Application.ProcessMessages;
    Check(Labels[0].Visible and Labels[1].Visible and not Labels[2].Visible,
      'Project/Classes never exposes the Debug tab, even with spare width');
    for Size:=9 to 18 do begin
      Header.Font.Size:=Size;
      for J:=0 to 1 do begin
        if J=0 then begin Labels[0].Caption:='Project';Labels[1].Caption:='Classes';Labels[2].Caption:='Debug';end
        else begin Labels[0].Caption:='项目管理';Labels[1].Caption:='查看类';Labels[2].Caption:='调试';end;
        Total:=0;
        for I:=0 to 2 do begin
          TextSize(Labels[I],W,H);Inc(Total,W+12);
        end;
        { Leave the last tab partially exposed. A partially exposed tab must
          not stop the right arrow before its caption is fully reachable. }
        Window.Width:=Total-1;Header.ActiveIndex:=0;Header.FirstVisible:=0;
        Header.Repaint;Application.ProcessMessages;
        RightArrow.Click;Application.ProcessMessages;
        Check(Header.FirstVisible>0,'right arrow scrolls past a partly visible Debug tab');
        RightArrow.Click;RightArrow.Click;Application.ProcessMessages;
        Check(Labels[2].Visible,'Debug remains reachable after right scrolling');
        for I:=0 to 2 do if Labels[I].Visible then begin
          TextSize(Labels[I],W,H);Allocation:=NativeLabel(Labels[I])^.allocation;
          Check(Allocation.height>=H,'native sidebar label fits rendered font height');
          Check(Labels[I].Top+Labels[I].Height<=Header.ClientHeight,'caption stays inside sidebar header');
        end;
        Check(Allocation.width>=W,'Debug caption is fully exposed');
        Header.ActiveIndex:=0;Header.ActiveIndex:=2;Application.ProcessMessages;
        TextSize(Labels[2],W,H);
        Check(Labels[2].Visible and (Labels[2].Width>=W),'selecting Debug reveals its complete caption');
      end;
    end;
    WriteLn('PASS: sidebar arrows reveal partially exposed Debug; native caption heights at 9–18 pt in English and Chinese');
  finally Window.Free;end;
end;
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
    Tree:=TTreeView(Owner);if Tree.Name='DebugWatchView' then Exit(Tree);
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
  Header:TSidebarTabs;DebugLabel:TStaticText;
  PaintImages,DefaultDraw:Boolean;
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
  Application.Initialize;ConfigureClassicChrome;CheckSidebarTabs;Check(PrepareInstance,'isolated instance');
  NameText:=GetTempDir(False)+'devcpp-sidebar-'+IntToStr(GetProcessID)+'.cpp';
  Code:=TStringList.Create;Code.Text:='int main() {'+LineEnding+'  int value = 7;'+LineEnding+'  value += 5;'+LineEnding+'  return value;'+LineEnding+'}'+LineEnding;Code.SaveToFile(NameText);
  StartupFiles.Clear;StartupFiles.Add(NameText);Form:=TMainForm.Create(nil);
  try
    Form.Show;Application.ProcessMessages;Check(Panel(Form)=nil,'GDB widgets are deferred at first frame');
    Header:=nil;DebugLabel:=nil;
    for I:=0 to Form.ComponentCount-1 do
      if Form.Components[I] is TSidebarTabs then Header:=TSidebarTabs(Form.Components[I]);
    Check(Header<>nil,'real sidebar header exists');
    for I:=0 to Header.ControlCount-1 do
      if (Header.Controls[I] is TSidebarArrow) and (Header.Controls[I].Tag=1) then
        TSidebarArrow(Header.Controls[I]).Click;
    for I:=0 to Header.ControlCount-1 do
      if (Header.Controls[I] is TStaticText) and (Header.Controls[I].Tag=2) then
        DebugLabel:=TStaticText(Header.Controls[I]);
    Check((DebugLabel<>nil) and DebugLabel.IsVisible,'scroll exposes the real Debug label');
    DebugLabel.OnClick(DebugLabel);Application.ProcessMessages;
    Debugger:=Panel(Form);Tree:=LocalTree(Form);
    Check((Debugger<>nil) and (Tree<>nil) and Tree.IsVisible,'clicking Debug opens its real sidebar variables panel');
    Check(not Debugger.Session.Active,'opening the Debug panel does not start GDB');
    Check(Tree.Items.Count=0,'an empty watch list has no synthetic group headings');
    Check(Tree.ScrollBars=ssAutoBoth,'empty watch list hides unnecessary scrollbars');
    Debugger.AddWatch('value');Debugger.AddWatch('C');Application.ProcessMessages;
    Check((Tree.Items.Count=2) and (Tree.Items[0].Parent=nil) and (Tree.Items[1].Parent=nil),'watch entries are flat original-style rows');
    Check(Tree.Items[1].Text='C = Execute to evaluate','original pending-watch caption');
    Check((Tree.Images<>nil) and (Tree.Items[1].ImageIndex=0),'original watch icon attached');
    PaintImages:=True;DefaultDraw:=True;
    Tree.OnAdvancedCustomDrawItem(Tree,Tree.Items[1],[],cdPrePaint,PaintImages,DefaultDraw);
    Check(Tree.Canvas.Font.Color=clRed,'original pending-watch red text');
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
