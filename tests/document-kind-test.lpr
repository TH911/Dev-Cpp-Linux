program document_kind_test;
{$mode objfpc}{$H+}
uses Interfaces, Forms, Classes, SysUtils, Types, SynEdit, SynEditFoldedView,
  mainform, app_instance, document_kind;
type TViewEditor=class(TNoiSynEdit);
procedure Check(Value:Boolean;const MessageText:string);
begin if not Value then begin WriteLn(StdErr,'FAIL: ',MessageText);Halt(1);end;end;
var Form:TMainForm;Editor:TSynEdit;Lines:TStringList;Directory,Name:string;I,J:Integer;
const Exts:array[0..6] of string=('in','out','ans','txt','csv','cpp','h');
begin
  Application.Initialize;Check(PrepareInstance,'isolated instance');
  Directory:=GetTempDir(False)+'dev-cpp-kind-'+IntToStr(GetProcessID);ForceDirectories(Directory);
  Lines:=TStringList.Create;
  try
    Lines.Text:='int main() {'+LineEnding+'  return (1);'+LineEnding+'}'+LineEnding;
    for I:=0 to High(Exts) do begin
      Name:=Directory+'/test.'+Exts[I];Lines.SaveToFile(Name);StartupFiles.Clear;StartupFiles.Add(Name);
      Form:=TMainForm.Create(nil);
      try
        Form.Show;for J:=1 to 8 do Application.ProcessMessages;
        Check(Form.ActiveControl is TSynEdit,'loaded file receives editor focus');Editor:=TSynEdit(Form.ActiveControl);
        if I<5 then begin
          Check(Editor.Highlighter=nil,'data file stays plain text: '+Exts[I]);
          Check(not TNoiSynEdit(Editor).CodeFeatures,'data file skips C++ bracket scanning');
          Check(not Editor.Gutter.CodeFoldPart.Visible,'no code-fold UI for data files');
        end else begin
          Check(Editor.Highlighter<>nil,'C/C++ source retains lexer');
          Check(Editor.Gutter.CodeFoldPart.Visible,'source keeps normal code folds');
        end;
        Editor.SelectAll;Application.ProcessMessages;
        Check(not (fncBlockSelection in TViewEditor(Editor).TextView.FoldClasifications[0]),'multiline selection does not create a synthetic fold');
        Check(Editor.Text=Lines.Text,'classification never changes source bytes');
      finally Form.Free;end;
      DeleteFile(Name);
    end;
    Check(IsCodeFile(''),'unnamed source defaults to C++');
    Check(IsCodeFile('source.C'),'uppercase C extension');
    Check(IsCodeFile('source.xpp','cpp;xpp'),'configured source extensions');
    Check(not IsCodeFile('data.in','cpp;in'),'data extension cannot accidentally enable lexer');
    WriteLn('PASS: real source/data documents; source-only lexer/bracket/fold work; no synthetic selection folds; custom extensions');
  finally Lines.Free;RemoveDir(Directory);end;
end.
