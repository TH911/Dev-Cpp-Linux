program classic_layout_test;
{$mode objfpc}{$H+}
uses Interfaces, Forms, Classes, SysUtils, ComCtrls, StdCtrls, Menus,
  Graphics, ImgList, SynEdit, mainform, app_instance, ui_language, source_output, source_navigation;
type
  TTestEdit = class(TSynEdit);
  TExceptionTrap = class
    procedure Failed(Sender: TObject; E: Exception);
  end;
procedure TExceptionTrap.Failed(Sender: TObject; E: Exception);
begin WriteLn(StdErr, E.ClassName, ': ', E.Message); DumpExceptionBackTrace(StdErr); Halt(2); end;
procedure Check(Value: Boolean; const Description: string);
begin if not Value then begin WriteLn(StdErr, 'FAIL: ', Description); Halt(1); end; end;
procedure Settle;
var I: Integer;
begin for I := 1 to 45 do begin Application.ProcessMessages; Sleep(10); end; end;
function FindMenu(Owner: TComponent; const Caption: string): TMenuItem;
var I: Integer;
begin
  if (Owner is TMenuItem) and (TMenuItem(Owner).Caption = Caption) then Exit(TMenuItem(Owner));
  for I := 0 to Owner.ComponentCount - 1 do
  begin Result := FindMenu(Owner.Components[I], Caption); if Result <> nil then Exit; end;
  Result := nil;
end;
procedure CheckMenuGlyph(Form:TMainForm;const Caption,FileName:string);
var Item:TMenuItem;Original,Rendered:TBitmap;X,Y:Integer;Expected:TColor;
begin
  Item:=FindMenu(Form,Tr(Caption));
  Check((Item<>nil) and (Item.ImageIndex>=0),'menu glyph: '+Caption);
  Original:=TBitmap.Create;Rendered:=TBitmap.Create;
  try
    Original.LoadFromFile(ExtractFilePath(ParamStr(0))+'../icons/'+FileName+'.bmp');
    Rendered.SetSize(16,16);Rendered.Canvas.Brush.Color:=clWhite;
    Rendered.Canvas.FillRect(0,0,16,16);
    Form.Menu.Images.Draw(Rendered.Canvas,0,0,Item.ImageIndex,True);
    for Y:=0 to 15 do for X:=0 to 15 do begin
      Expected:=ColorToRGB(Original.Canvas.Pixels[X,Y]);
      if Expected=ColorToRGB(clFuchsia) then Expected:=ColorToRGB(clWhite);
      Check(ColorToRGB(Rendered.Canvas.Pixels[X,Y])=Expected,'original glyph RGB/mask: '+Caption);
    end;
  finally Original.Free;Rendered.Free;end;
end;
var Form: TMainForm; Editor: TSynEdit; I, OriginalCount: Integer;
  ScopeCombo, FunctionCombo: TComboBox; NewButton: TToolButton;
  SymbolList: TStringList; SourceBefore: string; ToolbarCount, ReportCount: Integer;
  Item: TMenuItem; ReportTabs: TPageControl; ExceptionTrap: TExceptionTrap;
begin
  ExceptionTrap := TExceptionTrap.Create;
  Application.Initialize;
  Application.OnException := @ExceptionTrap.Failed;
  Check(PrepareInstance, 'initialize isolated application');
  Form := TMainForm.Create(nil);
  SymbolList := TStringList.Create;
  try
    Form.Show; Settle;
    CheckMenuGlyph(Form,'&Compiler Options...','compopt');
    CheckMenuGlyph(Form,'&Environment Options...','envopt');
    CheckMenuGlyph(Form,'E&ditor Options...','editopt');
    CheckMenuGlyph(Form,'&Shortcut Options...','run');
    CheckMenuGlyph(Form,'Configure &Tools...','tools');
    CheckMenuGlyph(Form,'&Start Debugging','debug');
    NewButton := nil; ToolbarCount := 0; ReportCount := 0;
    for I := 0 to Form.ComponentCount - 1 do
    begin
      if Form.Components[I] is TToolBar then Inc(ToolbarCount);
      if (Form.Components[I] is TPageControl) and (TPageControl(Form.Components[I]).PageCount = 6) then Inc(ReportCount);
      if (Form.Components[I] is TStatusBar) then
        Check(TStatusBar(Form.Components[I]).Panels.Count = 7, 'seven live status panels');
    end;
    for I := 0 to Form.ComponentCount - 1 do
      if Form.Components[I] is TToolBar then
        with TToolBar(Form.Components[I]) do
          for OriginalCount := 0 to ButtonCount - 1 do
            if Buttons[OriginalCount].Caption = Tr('New Source File') then NewButton := Buttons[OriginalCount];
    Check(ToolbarCount = 2, 'two actual toolbar rows');
    Check(ReportCount = 1, 'six report tabs including dedicated results and Close');
    Check(NewButton <> nil, 'native New command found');
    NewButton.Click; Settle;
    Check(Form.ActiveControl is TSynEdit, 'new document receives focus');
    Editor := TSynEdit(Form.ActiveControl);
    Editor.SelectAll; Editor.SelText := 'const char* text="{ }";' + LineEnding + '// { ignored }' + LineEnding;
    Settle; Editor.FoldAll;
    Check(TTestEdit(Editor).TextView.Count = Editor.Lines.Count, 'strings and comments do not create folds');
    Editor.SelectAll; Editor.SelText := 'int before() {' + LineEnding + ' return 1;' + LineEnding + '}' + LineEnding +
      'struct Solver {' + LineEnding + ' void solve() {' + LineEnding + '  int x=0;' + LineEnding +
      ' }' + LineEnding + '};' + LineEnding + 'int main() {' + LineEnding + ' return before();' + LineEnding + '}' + LineEnding;
    SourceBefore := Editor.Text;
    Settle;
    Editor.FoldAll;
    Check(TTestEdit(Editor).TextView.Count < Editor.Lines.Count, 'real C++ blocks fold');
    Editor.UnfoldAll;
    Check(TTestEdit(Editor).TextView.Count = Editor.Lines.Count, 'all source rows return after unfolding');
    Check(Editor.Text = SourceBefore, 'folding never changes source text');
    ScopeCombo := nil; FunctionCombo := nil;
    for I := 0 to Form.ComponentCount - 1 do
      if Form.Components[I] is TComboBox then
      begin
        if TComboBox(Form.Components[I]).Items.IndexOf('(globals)') >= 0 then
        begin ScopeCombo := TComboBox(Form.Components[I]); ScopeCombo.OnDropDown(ScopeCombo); end;
        if TComboBox(Form.Components[I]).Items.IndexOf('main()') >= 0 then FunctionCombo := TComboBox(Form.Components[I]);
      end;
    Check((ScopeCombo <> nil) and (FunctionCombo <> nil), 'source navigation populated from current buffer');
    Check(ScopeCombo.Items.IndexOf('Solver') >= 0, 'class scope indexed');
    FunctionCombo.ItemIndex := FunctionCombo.Items.IndexOf('main()');
    FunctionCombo.OnChange(FunctionCombo);
    Check(Editor.CaretY = 9, 'function selector navigates to its actual source row');
    ScopeCombo.ItemIndex := ScopeCombo.Items.IndexOf('Solver');
    ScopeCombo.OnChange(ScopeCombo);
    Check(FunctionCombo.Items.IndexOf('solve()') >= 0, 'scope filters actual members');
    FunctionCombo.ItemIndex := FunctionCombo.Items.IndexOf('solve()');
    FunctionCombo.OnChange(FunctionCombo);
    Check(Editor.CaretY = 5, 'member selector navigates to class method');
    Check(Pos('&lt;script&gt;', ExportSourceText('<script>&', 'Title', 'html')) > 0, 'HTML export escapes source');
    Check(Pos('\u20013?', ExportSourceText('中', '', 'rtf')) > 0, 'RTF export preserves Unicode');
    Check(Pos('\textbackslash{}', ExportSourceText('\end{document}', '', 'tex')) > 0, 'TeX export treats source as text');
    Item := FindMenu(Form, Tr('Format current file'));
    Check(Item <> nil, 'real AStyle command exists');
    if FileExists('/usr/bin/astyle') then
    begin
      Editor.SetFocus; Editor.SelectAll; Editor.SelText := 'int main(){return 0;}';
      SourceBefore := Editor.Text;
      Item.Click; Settle;
      Check(Editor.Text <> SourceBefore, 'AStyle actually formats current buffer');
      Editor.Undo;
      Check(Editor.Text = SourceBefore, 'formatting is one undoable edit');
    end;
    ReportTabs := nil;
    for I := 0 to Form.ComponentCount - 1 do
      if (Form.Components[I] is TPageControl) and (TPageControl(Form.Components[I]).PageCount = 6) then ReportTabs := TPageControl(Form.Components[I]);
    Check(ReportTabs <> nil, 'report page control');
    ReportTabs.ActivePageIndex := 5;
    ReportTabs.OnChange(ReportTabs); Settle;
    Check(not ReportTabs.Parent.Visible, 'Close tab hides report parent');
    WriteLn('PASS: classic toolbar/report/status layout, lexer-aware folding, source navigation and safe exports');
  finally SymbolList.Free; Form.Free; end;
end.
