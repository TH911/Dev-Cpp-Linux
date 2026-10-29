program editor_actions_test;

{$mode objfpc}{$H+}{$codepage utf8}

uses Interfaces, Forms, Classes, SysUtils, Types, Controls, LCLType, SynEdit,
  SynEditKeyCmds, editor_actions, mainform;

type
  TTestNoiSynEdit = class(TNoiSynEdit)
    procedure Press(Key: Word; Shift: TShiftState);
    procedure ClickForReset;
  end;

procedure TTestNoiSynEdit.Press(Key: Word; Shift: TShiftState);
begin
  KeyDown(Key, Shift);
end;

procedure TTestNoiSynEdit.ClickForReset;
begin
  MouseDown(mbLeft, [], 2, 2);
end;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then raise Exception.Create(MessageText);
end;

var
  Editor: TSynEdit;
  Form: TForm;
  MatchBytes, MatchCount, UndoStep: Integer;
  Original: string;
  RepeatHome: Boolean;
  HomeEditor: TTestNoiSynEdit;
begin
  Application.Initialize;
  Check(FindTextForward('甲Ä ä', 'ä', 1, MaxInt, MatchBytes) = 4,
    'UTF-8 search must return an original byte column');
  Check(MatchBytes = 2, 'UTF-8 match length');
  Check(FindTextForward('甲ẞ ß', 'ß', 1, MaxInt, MatchBytes) = 4,
    'case folding can change the number of bytes');
  Check(MatchBytes = 3, 'selection length must use original bytes after case folding');
  Check(FindTextBackward('甲ẞ ß', 'ß', 1, MaxInt, MatchBytes) = 8,
    'backward UTF-8 search');
  Check(FindTextBackward('one two one', 'one', 1, 8, MatchBytes) = 1,
    'backward search must respect its starting range');
  Check(FindTextForward('one two one', 'one', 2, 8, MatchBytes) = 0,
    'forward wrap range must exclude later starts');
  Check(ReplaceTextMatches('甲ẞ ß', 'ß', 'x', MatchCount) = '甲x x',
    'replacement must consume original UTF-8 bytes');
  Check(MatchCount = 2, 'replacement count');
  Check(ReplaceTextMatches('aa', '', 'x', MatchCount) = 'aa',
    'an empty query must not loop or change text');
  Check(MatchCount = 0, 'empty-query match count');

  Check(FindTextForward('int integer INT int_', 'int',1,20,MatchBytes,True,True)=1,'case-sensitive whole word');
  Check(FindTextForward('integer INT int_', 'int',1,20,MatchBytes,True,True)=0,'whole word rejects suffixes and case changes');
  Check(FindTextForward('integer INT int_', 'int',1,20,MatchBytes,False,True)=9,'whole word can fold case');
  Form := TForm.CreateNew(nil);
  try
    Editor := TSynEdit.Create(Form);
    Editor.Parent := Form;
    Editor.TabWidth := 4;
    Editor.Lines.Text := ' '#9'中文 value' + LineEnding + '    second' +
      LineEnding + #9'  ' + LineEnding + 'plain';
    Editor.LogicalCaretXY := Point(10, 1);
    RepeatHome := False;
    MoveEditorHome(Editor, False, RepeatHome);
    Check(Editor.LogicalCaretXY = Point(3, 1),
      'Home uses the first UTF-8 byte after mixed space/tab indentation');
    Check(Editor.CaretX = 5, 'Home converts tab indentation to a visual caret column');
    MoveEditorHome(Editor, False, RepeatHome);
    Check(Editor.LogicalCaretXY = Point(1, 1), 'second Home moves to column one');
    MoveEditorHome(Editor, False, RepeatHome);
    Check(Editor.LogicalCaretXY = Point(3, 1), 'third Home returns to indentation');
    RepeatHome := False;
    MoveEditorHome(Editor, False, RepeatHome);
    Check(Editor.LogicalCaretXY = Point(3, 1),
      'a reset makes Home stop at indentation even when already there');

    { Reproduce issue #2: a selection reaches the previous line, then Home. }
    Editor.BlockBegin := Point(8, 2);
    Editor.BlockEnd := Point(3, 1);
    Editor.LogicalCaretXY := Point(3, 1);
    RepeatHome := False;
    MoveEditorHome(Editor, False, RepeatHome);
    Check(Editor.LogicalCaretXY = Point(3, 1),
      'Home after upward selection reaches first nonblank rather than column one');
    Check(not Editor.SelAvail, 'plain Home collapses the previous selection');

    Editor.BlockBegin := Point(8, 2);
    Editor.BlockEnd := Point(10, 1);
    Editor.LogicalCaretXY := Point(10, 1);
    RepeatHome := False;
    MoveEditorHome(Editor, True, RepeatHome);
    Check(Editor.LogicalCaretXY = Point(3, 1), 'Shift+Home reaches indentation');
    Check(Editor.BlockEnd = Point(8, 2), 'Shift+Home retains the downward anchor');
    MoveEditorHome(Editor, True, RepeatHome);
    Check(Editor.LogicalCaretXY = Point(1, 1), 'repeated Shift+Home reaches column one');
    Check(Editor.BlockEnd = Point(8, 2), 'repeated Shift+Home retains the original anchor');
    Editor.BlockBegin := Point(3, 1);
    Editor.BlockEnd := Point(8, 2);
    Editor.LogicalCaretXY := Point(8, 2);
    RepeatHome := False;
    MoveEditorHome(Editor, True, RepeatHome);
    Check(Editor.BlockBegin = Point(3, 1), 'Shift+Home retains the upward anchor');
    Check(Editor.LogicalCaretXY = Point(5, 2), 'Shift+Home preserves selection direction');
    Editor.LogicalCaretXY := Point(1, 3);
    RepeatHome := False;
    MoveEditorHome(Editor, False, RepeatHome);
    Check(Editor.LogicalCaretXY = Point(4, 3), 'Home reaches the end of an all-blank line');
    MoveEditorHome(Editor, False, RepeatHome);
    Check(Editor.LogicalCaretXY = Point(1, 3), 'all-blank lines support the Home cycle');
    Editor.LogicalCaretXY := Point(4, 4);
    RepeatHome := False;
    MoveEditorHome(Editor, False, RepeatHome);
    Check(Editor.LogicalCaretXY = Point(1, 4), 'unindented line Home');
    Editor.BlockBegin := Editor.LogicalCaretXY;
    Editor.BlockEnd := Editor.LogicalCaretXY;
    Editor.Lines.Text := '甲 one' + LineEnding + #9 + 'two' + LineEnding + 'three';
    Editor.LogicalCaretXY := Point(1, 1);
    Editor.BlockBegin := Point(1, 1);
    Editor.BlockEnd := Point(1, 3);
    Original := Editor.Lines.Text;
    Editor.ClearUndo;
    Editor.Modified := False;
    CommentEditorLines(Editor, False);
    Check(Editor.Lines[0] = '//甲 one', 'comment first selected line');
    Check(Editor.Lines[1] = '//'#9'two', 'comment second selected line');
    Check(Editor.Lines[2] = 'three', 'end at column one excludes the following line');
    Check(Editor.CanUndo, 'comment must be undoable');
    Editor.Undo;
    Check(Editor.Lines.Text = Original, 'one undo restores all commented lines');
    Check(not Editor.Modified, 'undo to the saved point clears Modified');
    Editor.Redo;
    Check(Editor.Lines[0] = '//甲 one', 'comment redo');
    Editor.LogicalCaretXY := Point(1, 1);
    Editor.BlockBegin := Point(1, 1);
    Editor.BlockEnd := Point(1, 3);
    Editor.ClearUndo;
    Original := Editor.Lines.Text;
    CommentEditorLines(Editor, True);
    Check(Editor.Lines[0] = '甲 one', 'uncomment preserves UTF-8');
    Check(Editor.Lines[1] = #9'two', 'uncomment preserves tabs');
    Editor.Undo;
    Check(Editor.Lines.Text = Original, 'one undo restores all uncommented lines');

    Editor.Lines.Text := 'one' + LineEnding + 'two' + LineEnding + 'three';
    Editor.LogicalCaretXY := Point(1, 1);
    Editor.BlockBegin := Point(1, 1);
    Editor.BlockEnd := Point(1, 3);
    Original := Editor.Lines.Text;
    Editor.ClearUndo;
    MoveEditorLines(Editor, 1);
    Check(Editor.Lines[0] = 'three', 'move a selected block down to the final text line');
    Check(Editor.Lines[1] = 'one', 'move preserves the first selected line');
    Check(Editor.Lines[2] = 'two', 'move preserves the second selected line');
    Editor.Undo;
    Check(Editor.Lines.Text = Original, 'one undo restores the moved block');
    Editor.LogicalCaretXY := Point(1, 3);
    Editor.BlockBegin := Point(1, 3);
    Editor.BlockEnd := Point(1, 3);
    Original := Editor.Lines.Text;
    Editor.ClearUndo;
    DuplicateEditorLine(Editor);
    Check(Editor.Lines[2] = 'three', 'duplicate keeps the original final line');
    Check(Editor.Lines[3] = 'three', 'duplicate appends a final line');
    Editor.Undo;
    Check(Editor.Lines.Text = Original, 'one undo restores a duplicated final line');

    Editor.Lines.Text := '"abc" // comment' + LineEnding + '/* next' + LineEnding + ' */ int i;';
    Check(CppContextAt(Editor, Point(3, 1)) = cecDoubleQuote, 'inside a string');
    Check(CppContextAt(Editor, Point(12, 1)) = cecLineComment, 'inside a line comment');
    Check(CppContextAt(Editor, Point(4, 2)) = cecBlockComment, 'inside a block comment');
    Check(CppContextAt(Editor, Point(9, 3)) = cecCode, 'after a block comment');
    Editor.Lines.Text := '// continued\' + LineEnding + 'still comment';
    Check(CppContextAt(Editor, Point(5, 2)) = cecLineComment,
      'backslash-newline continues a C++ line comment');
    Editor.Lines.Text := 'int n = 1''000; f();';
    Check(CppContextAt(Editor, Point(18, 1)) = cecCode,
      'C++14 digit separators are not character literals');
    Check(CppNumericSeparatorPrefix('0xAB', 5), 'hexadecimal digit separator');
    Check(not CppNumericSeparatorPrefix('u8', 3), 'u8 character literal prefix');

    HomeEditor := TTestNoiSynEdit.Create(Form);
    HomeEditor.Parent := Form;
    HomeEditor.SetBounds(0, 0, 400, 200);
    Form.Show;
    Application.ProcessMessages;
    HomeEditor.Lines.Text := '    alpha' + LineEnding + '    bravo';
    HomeEditor.LogicalCaretXY := Point(10, 1);
    HomeEditor.Press(VK_HOME, []);
    Check(HomeEditor.LogicalCaretXY = Point(5, 1), 'actual Home key reaches indentation');
    HomeEditor.Press(VK_HOME, []);
    Check(HomeEditor.LogicalCaretXY = Point(1, 1), 'actual repeated Home key reaches column one');
    HomeEditor.Press(VK_HOME, []);
    HomeEditor.Press(VK_RIGHT, []);
    HomeEditor.Press(VK_LEFT, []);
    HomeEditor.Press(VK_HOME, []);
    Check(HomeEditor.LogicalCaretXY = Point(5, 1), 'arrow keys reset the actual Home cycle');
    HomeEditor.ClickForReset;
    HomeEditor.LogicalCaretXY := Point(5, 1);
    HomeEditor.Press(VK_HOME, []);
    Check(HomeEditor.LogicalCaretXY = Point(5, 1), 'mouse clicks reset the actual Home cycle');
    HomeEditor.ResetHomeCycle;
    HomeEditor.BlockBegin := Point(10, 2);
    HomeEditor.BlockEnd := Point(10, 1);
    HomeEditor.LogicalCaretXY := Point(10, 1);
    HomeEditor.Press(VK_HOME, [ssShift]);
    Check(HomeEditor.LogicalCaretXY = Point(5, 1), 'actual Shift+Home reaches indentation');
    Check(HomeEditor.BlockEnd = Point(10, 2), 'actual Shift+Home retains its selection anchor');
    HomeEditor.Press(VK_SHIFT, [ssShift]);
    HomeEditor.Press(VK_HOME, [ssShift]);
    Check(HomeEditor.LogicalCaretXY = Point(1, 1), 'actual Shift+Home cycles to column one');
    Check(HomeEditor.BlockEnd = Point(10, 2), 'actual repeated Shift+Home retains its anchor');
    HomeEditor.Options:=HomeEditor.Options-[eoGroupUndo];
    HomeEditor.Text:='baseline';HomeEditor.ClearUndo;
    HomeEditor.LogicalCaretXY:=Point(9,1);
    for UndoStep:=1 to 6000 do begin
      HomeEditor.BeginUndoBlock;
      try HomeEditor.SelText:='x';finally HomeEditor.EndUndoBlock;end;
    end;
    Original:=HomeEditor.Text;
    for UndoStep:=1 to 6000 do begin
      Check(HomeEditor.CanUndo,'history must retain more than 1024 edits');HomeEditor.Undo;
    end;
    Check(HomeEditor.Lines[0]='baseline','6000 undos reach the original source');
    Check(not HomeEditor.CanUndo,'all independent edits undone');
    for UndoStep:=1 to 6000 do begin
      Check(HomeEditor.CanRedo,'redo keeps the same extended history');HomeEditor.Redo;
    end;
    Check(HomeEditor.Text=Original,'6000 redos restore exact source bytes');
    HomeEditor.Undo;HomeEditor.SelText:='y';
    Check(not HomeEditor.CanRedo,'new edit still discards the abandoned redo branch');
    WriteLn('PASS: 6000 independent undo and redo steps retain exact source and branch semantics');
  finally
    Form.Free;
  end;
  WriteLn('PASS: smart Home/Shift+Home selection, UTF-8 search/replacement, comment undo/redo, and C++ pairing contexts.');
end.
