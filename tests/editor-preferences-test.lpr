program editor_preferences_test;
{$mode objfpc}{$H+}
uses Interfaces, Forms, Classes, SysUtils, IniFiles, Graphics, SynEdit,
  editor_preferences, editor_themes, cpp_highlighter, classic_gutter, SynGutterLineNumber;
procedure Check(Condition:Boolean;const MessageText:string);
begin if not Condition then raise Exception.Create(MessageText);end;
var P,Q:TEditorPreferences;Ini:TMemIniFile;Editor:TSynEdit;Syntax:TNoiCppSyn;C:TEditorThemeColors;
begin
 Application.Initialize;P:=TEditorPreferences.Create;Q:=TEditorPreferences.Create;Ini:=TMemIniFile.Create('');
 Editor:=TSynEdit.Create(nil);Syntax:=TNoiCppSyn.Create(nil);
 try
  P.DefaultCode:='';P.Snippets.Clear;P.Snippets.Add('empty'#1);P.Save(Ini);Q.Load(Ini);
  Check(Q.DefaultCode='','empty default template must not prevent startup');
  Check(Q.Snippets.ValueFromIndex[0]='','empty snippet must load');
  P.DefaultCode:='// <LF> literal'+LineEnding+'int main(){return 0;}';
  P.Snippets.Clear;P.Snippets.Add('snippet'#1'// <LF>'+LineEnding+'double value=1e5;');
  P.Flags:=P.Flags+[efCustomGutterFont,efZeroStart,efLeadingZeros,efRightMargin]-[efSyntax,efGutterAuto];
  P.GutterFont:='Liberation Mono';P.GutterSize:=11;P.MarginWidth:=96;
  P.Colors.Values['Float.Foreground']:=IntToStr(clPurple);P.Colors.Values['Float.Style']:='3';
  P.Save(Ini);Q.Load(Ini);
  Check(Q.DefaultCode=P.DefaultCode,'default template literal/newline roundtrip');
  Check(Q.Snippets.Text=P.Snippets.Text,'snippet multiline roundtrip');
  Check(Q.Flags=P.Flags,'all behavior flags persist');
  Editor.Lines.Text:='int main(){return 0;}';
  ApplyEditorTheme(Editor,Syntax,Syntax.BracketAttri,Syntax.CharacterAttri,'Classic Plus',C,Syntax.FloatAttri,Syntax.HexAttri,Syntax.OctalAttri);
  Q.Apply(Editor,Syntax);
  Check(Editor.Highlighter=nil,'syntax switch disables actual highlighting');
  Check(Editor.RightEdge=96,'right margin applies');
  Check(Editor.Gutter.Parts.ByClass[TSynGutterLineNumber,0] is TClassicLineNumbers,'real custom-font gutter part');
  Check(TClassicLineNumbers(Editor.Gutter.Parts.ByClass[TSynGutterLineNumber,0]).CustomFont,'custom gutter font applies');
  Check(Syntax.FloatAttri.Foreground=clPurple,'custom token color applies');
  Check(Syntax.FloatAttri.Style=[fsBold,fsItalic],'custom token styles apply');
  P.Flags:=P.Flags+[efSyntax];Q.Assign(P);Q.Apply(Editor,Syntax);
  Check(Editor.Highlighter=Syntax,'syntax switch restores the lexer');
  WriteLn('PASS: editor preference persistence, literal multiline templates, colors, styles, gutter font and live options');
 finally Syntax.Free;Editor.Free;Ini.Free;Q.Free;P.Free;end;
end.
