program brackets_test;
{$mode objfpc}{$H+}{$codepage utf8}
uses Interfaces, Forms, Classes, SysUtils, Types, SynEdit, editor_actions, mainform;
procedure Check(Value:Boolean;const MessageText:string);
begin if not Value then raise Exception.Create(MessageText);end;
var Form:TForm;Editor:TNoiSynEdit;Syntax:TNoiCppSyn;I:Integer;
procedure Ignored(const Source:string);
var Y,X:Integer;Line:string;
begin
 Editor.Lines.Text:=Source;
 for Y:=1 to Editor.Lines.Count do begin
  Line:=Editor.Lines[Y-1];
  for X:=1 to Length(Line) do if Line[X] in ['(',')','[',']','{','}'] then
   Check(Editor.FindMatchingBracketLogical(Point(X,Y),False,False,False,False)=Point(-1,-1),
     'Literal/comment bracket matched: '+Source+' at '+IntToStr(X)+':'+IntToStr(Y));
 end;
end;
begin
 Application.Initialize;Form:=TForm.CreateNew(nil);Editor:=TNoiSynEdit.Create(Form);Editor.Parent:=Form;
 Syntax:=TNoiCppSyn.Create(Form);Editor.Highlighter:=Syntax;
 try
  Ignored('const auto* text = "([]{})";');
  Ignored('const auto* text = "escaped \" ([]{})";');
  Ignored('''('' '')'' ''['' '']'' ''{'' ''}''');
  Ignored('// ([]{} )');Ignored('/* ([]{} ) */');
  Ignored('/*'+LineEnding+'([]{})'+LineEnding+'*/');
  Ignored('// continued\'+LineEnding+'([]{})');
  Ignored('R"tag("([]{})"'+LineEnding+'([]{}))tag"');
  Ignored('u8R"_([{}])_"');
  Editor.Lines.Text:='([{}])';
  for I:=1 to 6 do
   Check(Editor.FindMatchingBracketLogical(Point(I,1),False,False,False,False)=Point(7-I,1),'Nested pair not matched');
  Editor.Lines.Text:='f('+LineEnding+'"wrong)" /* ) */'+LineEnding+');';
  Check(Editor.FindMatchingBracketLogical(Point(2,1),False,False,False,False)=Point(1,3),'Matching must ignore non-code closers');
  Editor.Highlighter:=nil;
  Check(Editor.FindMatchingBracketLogical(Point(1,3),False,False,False,False)=Point(2,1),'Matching must work with syntax disabled');
  Ignored('"([]{})" /* ([]) */');Editor.Highlighter:=Syntax;
  Editor.Lines.Text:='甲()';
  Check(CppBracketMatch(Editor,Point(4,1))=Point(5,1),'UTF-8 logical byte coordinates');
  Editor.Lines.Text:='int n=1''000; f();';I:=Pos('(',Editor.Lines[0]);
  Check(CppBracketMatch(Editor,Point(I,1))=Point(I+1,1),'Digit separators must not hide code');
  Editor.Lines.Text:='f()';
  Check(CppBracketMatch(Editor,Point(3,1))=Point(2,1),'Existing closer belongs to its previous opener');
  Editor.Lines.Text:='")" /* ( */ )';
  Check(CppBracketMatch(Editor,Point(Length(Editor.Lines[0]),1))=Point(-1,-1),'Only a genuine orphan closer may be reused');
  Editor.Lines.Text:='f()';
  Check(Editor.FindMatchingBracketLogical(Point(1,1),True,False,False,False)=Point(3,1),'Neighbor matching');
  Editor.FindMatchingBracketLogical(Point(3,1),False,True,False,False);
  Check(Editor.LogicalCaretXY=Point(2,1),'Move to matching opener');
  Editor.FindMatchingBracketLogical(Point(2,1),False,False,True,False);
  Check(Editor.SelText='()','Select both matched delimiters');
  WriteLn('PASS: code-only matching, comments, ordinary/escaped/character/raw literals, multiline and UTF-8 pairs, orphan ownership and navigation');
 finally Form.Free;end;
end.
