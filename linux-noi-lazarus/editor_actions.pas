unit editor_actions;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, Types, SynEdit;

type
  TCppEditContext = (cecCode, cecLineComment, cecBlockComment,
    cecSingleQuote, cecDoubleQuote);

{ All search positions and lengths are bytes in the original UTF-8 text, as
  required by SynEdit.LogicalCaretXY. Case folding may change byte lengths. }
function FindTextMatchLengthAt(const Source, Query: string; ByteColumn: Integer): Integer;
function FindTextForward(const Source, Query: string; FirstByte, LastByte: Integer;
  out MatchBytes: Integer): Integer;
function FindTextBackward(const Source, Query: string; FirstByte, LastByte: Integer;
  out MatchBytes: Integer): Integer;
function ReplaceTextMatches(const Source, Query, Replacement: string;
  out MatchCount: Integer): string;
procedure CommentEditorLines(Editor: TSynEdit; Remove: Boolean);
procedure DuplicateEditorLine(Editor: TSynEdit);
procedure MoveEditorLines(Editor: TSynEdit; Delta: Integer);
procedure MoveEditorHome(Editor: TSynEdit; SelectText: Boolean;
  var RepeatHome: Boolean);
function CppNumericSeparatorPrefix(const Source: string; ByteColumn: Integer): Boolean;
function CppContextAt(Editor: TSynEdit; const Caret: TPoint): TCppEditContext;

implementation

uses LazUTF8;

procedure MoveEditorHome(Editor: TSynEdit; SelectText: Boolean;
  var RepeatHome: Boolean);
var
  Caret, Anchor, Target: TPoint;
  LineText: string;
begin
  Caret := Editor.LogicalCaretXY;
  if (Caret.Y < 1) or (Caret.Y > Editor.Lines.Count) then Exit;
  Anchor := Caret;
  if Editor.SelAvail then
    if (Caret.X = Editor.BlockBegin.X) and
      (Caret.Y = Editor.BlockBegin.Y) then Anchor := Editor.BlockEnd
    else Anchor := Editor.BlockBegin;
  LineText := Editor.Lines[Caret.Y - 1];
  Target := Point(1, Caret.Y);
  { Leading spaces and tabs occupy one byte each. LogicalCaretXY uses byte
    columns, so a UTF-8 character after the indentation needs no conversion. }
  while (Target.X <= Length(LineText)) and
    (LineText[Target.X] in [' ', #9]) do Inc(Target.X);
  if RepeatHome and (Caret.X = Target.X) then Target.X := 1;
  Editor.LogicalCaretXY := Target;
  if SelectText then Editor.BlockBegin := Anchor
  else Editor.BlockBegin := Target;
  Editor.BlockEnd := Target;
  Editor.LogicalCaretXY := Target;
  RepeatHome := True;
end;

function NextCharacterByte(const S: string; ByteColumn: Integer): Integer;
begin
  Result := ByteColumn + 1;
  while (Result <= Length(S)) and
    ((Ord(S[Result]) and $C0) = $80) do Inc(Result);
end;

function FindTextMatchLengthAt(const Source, Query: string; ByteColumn: Integer): Integer;
var EndByte, I, QueryCharacters: Integer;
begin
  Result := 0;
  if (Query = '') or (ByteColumn < 1) or (ByteColumn > Length(Source)) then Exit;
  if (Ord(Source[ByteColumn]) and $C0) = $80 then Exit;
  QueryCharacters := UTF8Length(Query);
  EndByte := ByteColumn;
  for I := 1 to QueryCharacters do
  begin
    if EndByte > Length(Source) then Exit;
    EndByte := NextCharacterByte(Source, EndByte);
  end;
  if UTF8LowerCase(Copy(Source, ByteColumn, EndByte - ByteColumn)) =
    UTF8LowerCase(Query) then Result := EndByte - ByteColumn;
end;

function FindTextForward(const Source, Query: string; FirstByte, LastByte: Integer;
  out MatchBytes: Integer): Integer;
var I, N: Integer;
begin
  Result := 0;
  MatchBytes := 0;
  if Query = '' then Exit;
  if FirstByte < 1 then FirstByte := 1;
  if LastByte > Length(Source) then LastByte := Length(Source);
  for I := FirstByte to LastByte do
  begin
    N := FindTextMatchLengthAt(Source, Query, I);
    if N > 0 then
    begin
      MatchBytes := N;
      Exit(I);
    end;
  end;
end;

function FindTextBackward(const Source, Query: string; FirstByte, LastByte: Integer;
  out MatchBytes: Integer): Integer;
var I, N: Integer;
begin
  Result := 0;
  MatchBytes := 0;
  if Query = '' then Exit;
  if FirstByte < 1 then FirstByte := 1;
  if LastByte > Length(Source) then LastByte := Length(Source);
  for I := LastByte downto FirstByte do
  begin
    N := FindTextMatchLengthAt(Source, Query, I);
    if N > 0 then
    begin
      MatchBytes := N;
      Exit(I);
    end;
  end;
end;

function ReplaceTextMatches(const Source, Query, Replacement: string;
  out MatchCount: Integer): string;
var StartByte, MatchByte, MatchBytes: Integer;
begin
  Result := '';
  MatchCount := 0;
  StartByte := 1;
  if Query = '' then Exit(Source);
  repeat
    MatchByte := FindTextForward(Source, Query, StartByte, Length(Source), MatchBytes);
    if MatchByte = 0 then Break;
    Result := Result + Copy(Source, StartByte, MatchByte - StartByte) + Replacement;
    Inc(MatchCount);
    StartByte := MatchByte + MatchBytes;
  until StartByte > Length(Source);
  Result := Result + Copy(Source, StartByte, MaxInt);
end;

procedure CommentEditorLines(Editor: TSynEdit; Remove: Boolean);
var
  FirstRow, LastRow, Row, Column, Delta: Integer;
  HadSelection: Boolean;
  OriginalStart, OriginalEnd, OriginalCaret: TPoint;
  S: string;

  procedure AdjustPoint(var P: TPoint);
  begin
    if P.Y <> Row then Exit;
    if Delta > 0 then
    begin
      if P.X >= Column then Inc(P.X, Delta);
    end
    else if P.X > Column then
    begin
      P.X := P.X + Delta;
      if P.X < Column then P.X := Column;
    end;
  end;

begin
  if (Editor = nil) or Editor.ReadOnly or (Editor.Lines.Count = 0) then Exit;
  HadSelection := Editor.SelAvail;
  OriginalStart := Editor.BlockBegin;
  OriginalEnd := Editor.BlockEnd;
  OriginalCaret := Editor.LogicalCaretXY;
  FirstRow := OriginalCaret.Y;
  LastRow := FirstRow;
  if HadSelection then
  begin
    FirstRow := OriginalStart.Y;
    LastRow := OriginalEnd.Y;
    if (LastRow > FirstRow) and (OriginalEnd.X = 1) then Dec(LastRow);
  end;
  if FirstRow < 1 then FirstRow := 1;
  if LastRow > Editor.Lines.Count then LastRow := Editor.Lines.Count;
  Editor.BeginUndoBlock;
  try
    for Row := FirstRow to LastRow do
    begin
      S := Editor.Lines[Row - 1];
      Column := 1;
      Delta := 2;
      if Remove then
      begin
        while (Column <= Length(S)) and (S[Column] in [' ', #9]) do Inc(Column);
        if Copy(S, Column, 2) <> '//' then Continue;
        Delta := -2;
      end;
      Editor.LogicalCaretXY := Point(Column, Row);
      Editor.BlockBegin := Point(Column, Row);
      if Remove then Editor.BlockEnd := Point(Column + 2, Row)
      else Editor.BlockEnd := Point(Column, Row);
      if Remove then Editor.SelText := '' else Editor.SelText := '//';
      AdjustPoint(OriginalStart);
      AdjustPoint(OriginalEnd);
      AdjustPoint(OriginalCaret);
    end;
    Editor.LogicalCaretXY := OriginalCaret;
    if HadSelection then
    begin
      { Preserve the active end of backward selections as well. }
      if (OriginalCaret.Y = OriginalStart.Y) and
        (OriginalCaret.X = OriginalStart.X) then
      begin
        Editor.BlockBegin := OriginalEnd;
        Editor.BlockEnd := OriginalStart;
      end
      else
      begin
        Editor.BlockBegin := OriginalStart;
        Editor.BlockEnd := OriginalEnd;
      end;
    end
    else
    begin
      Editor.BlockBegin := OriginalCaret;
      Editor.BlockEnd := OriginalCaret;
    end;
  finally
    Editor.EndUndoBlock;
  end;
end;

procedure DuplicateEditorLine(Editor: TSynEdit);
var Row: Integer; P: TPoint; S: string;
begin
  if (Editor = nil) or Editor.ReadOnly or (Editor.Lines.Count = 0) then Exit;
  Row := Editor.CaretY;
  if (Row < 1) or (Row > Editor.Lines.Count) then Exit;
  S := Editor.Lines[Row - 1];
  Editor.BeginUndoBlock;
  try
    if Row < Editor.Lines.Count then
    begin
      P := Point(1, Row + 1);
      S := S + LineEnding;
    end
    else
    begin
      P := Point(Length(S) + 1, Row);
      S := LineEnding + S;
    end;
    Editor.LogicalCaretXY := P;
    Editor.BlockBegin := P;
    Editor.BlockEnd := P;
    Editor.SelText := S;
    { Orwell 5.11 keeps the caret on the original line at column one. }
    Editor.LogicalCaretXY := Point(1, Row);
    Editor.BlockBegin := Point(1, Row);
    Editor.BlockEnd := Point(1, Row);
  finally
    Editor.EndUndoBlock;
  end;
end;

procedure MoveEditorLines(Editor: TSynEdit; Delta: Integer);
var
  FirstRow, LastRow, RangeFirst, RangeLast, Row, I, MovableRows: Integer;
  OriginalStart, OriginalEnd, OriginalCaret, RangeEnd: TPoint;
  Bookmarks: array[1..9] of TPoint;
  HasBookmark: array[1..9] of Boolean;
  HadSelection: Boolean;
  Replacement: string;

  procedure AppendLine(const S: string);
  begin
    if Row > RangeFirst then Replacement := Replacement + LineEnding;
    Replacement := Replacement + S;
    Inc(Row);
  end;

begin
  if (Editor = nil) or Editor.ReadOnly or (Editor.Lines.Count < 2) or
    ((Delta <> -1) and (Delta <> 1)) then Exit;
  OriginalStart := Editor.BlockBegin;
  OriginalEnd := Editor.BlockEnd;
  OriginalCaret := Editor.LogicalCaretXY;
  HadSelection := Editor.SelAvail;
  FirstRow := OriginalCaret.Y;
  LastRow := FirstRow;
  if HadSelection then
  begin
    FirstRow := OriginalStart.Y;
    LastRow := OriginalEnd.Y;
    if (LastRow > FirstRow) and (OriginalEnd.X = 1) then Dec(LastRow);
  end;
  MovableRows := Editor.Lines.Count;
  { A final empty editor row represents the file's trailing newline. }
  if (MovableRows > 1) and (Editor.Lines[MovableRows - 1] = '') then Dec(MovableRows);
  if (FirstRow < 1) or (LastRow > MovableRows) or
    ((Delta < 0) and (FirstRow = 1)) or
    ((Delta > 0) and (LastRow = MovableRows)) then Exit;
  RangeFirst := FirstRow;
  RangeLast := LastRow;
  if Delta < 0 then Dec(RangeFirst) else Inc(RangeLast);
  Replacement := '';
  Row := RangeFirst;
  if Delta > 0 then AppendLine(Editor.Lines[LastRow]);
  for I := FirstRow to LastRow do AppendLine(Editor.Lines[I - 1]);
  if Delta < 0 then AppendLine(Editor.Lines[FirstRow - 2]);
  if RangeLast < Editor.Lines.Count then
  begin
    Replacement := Replacement + LineEnding;
    RangeEnd := Point(1, RangeLast + 1);
  end
  else RangeEnd := Point(Length(Editor.Lines[RangeLast - 1]) + 1, RangeLast);
  for I := 1 to 9 do
    HasBookmark[I] := Editor.GetBookMark(I, Bookmarks[I].X, Bookmarks[I].Y);
  Editor.BeginUndoBlock;
  try
    Editor.LogicalCaretXY := Point(1, RangeFirst);
    Editor.BlockBegin := Point(1, RangeFirst);
    Editor.BlockEnd := RangeEnd;
    Editor.SelText := Replacement;
    for I := 1 to 9 do
      if HasBookmark[I] then
      begin
        if (Bookmarks[I].Y >= FirstRow) and (Bookmarks[I].Y <= LastRow) then
          Inc(Bookmarks[I].Y, Delta)
        else if (Delta < 0) and (Bookmarks[I].Y = FirstRow - 1) then
          Bookmarks[I].Y := LastRow
        else if (Delta > 0) and (Bookmarks[I].Y = LastRow + 1) then
          Bookmarks[I].Y := FirstRow;
        Editor.SetBookMark(I, Bookmarks[I].X, Bookmarks[I].Y);
      end;
    Inc(OriginalCaret.Y, Delta);
    Editor.LogicalCaretXY := OriginalCaret;
    if HadSelection then
    begin
      Inc(OriginalStart.Y, Delta);
      Inc(OriginalEnd.Y, Delta);
      if (OriginalCaret.Y = OriginalStart.Y) and (OriginalCaret.X = OriginalStart.X) then
      begin
        Editor.BlockBegin := OriginalEnd;
        Editor.BlockEnd := OriginalStart;
      end
      else
      begin
        Editor.BlockBegin := OriginalStart;
        Editor.BlockEnd := OriginalEnd;
      end;
    end
    else
    begin
      Editor.BlockBegin := OriginalCaret;
      Editor.BlockEnd := OriginalCaret;
    end;
  finally
    Editor.EndUndoBlock;
  end;
end;

function CppNumericSeparatorPrefix(const Source: string; ByteColumn: Integer): Boolean;
var StartByte: Integer;
begin
  Result := False;
  if (ByteColumn < 2) or (ByteColumn - 1 > Length(Source)) or
    not (Source[ByteColumn - 1] in ['0'..'9', 'a'..'f', 'A'..'F']) then Exit;
  StartByte := ByteColumn - 1;
  while (StartByte > 1) and
    (Source[StartByte - 1] in ['0'..'9', 'a'..'z', 'A'..'Z', '_', '.', '''']) do
    Dec(StartByte);
  Result := Source[StartByte] in ['0'..'9'];
  if (Source[StartByte] = '.') and (StartByte + 1 < ByteColumn) then
    Result := Source[StartByte + 1] in ['0'..'9'];
end;

function CppContextAt(Editor: TSynEdit; const Caret: TPoint): TCppEditContext;
var Row, I, LastColumn: Integer; S: string; Escaped: Boolean;
begin
  Result := cecCode;
  if (Editor = nil) or (Caret.Y < 1) then Exit;
  for Row := 1 to Caret.Y do
  begin
    if Row > Editor.Lines.Count then Break;
    S := Editor.Lines[Row - 1];
    LastColumn := Length(S);
    if Row = Caret.Y then LastColumn := Caret.X - 1;
    if LastColumn > Length(S) then LastColumn := Length(S);
    I := 1;
    Escaped := False;
    while I <= LastColumn do
    begin
      case Result of
        cecCode:
          if (S[I] = '/') and (I < LastColumn) and (S[I + 1] = '/') then
          begin Result := cecLineComment; Inc(I); end
          else if (S[I] = '/') and (I < LastColumn) and (S[I + 1] = '*') then
          begin Result := cecBlockComment; Inc(I); end
          else if (S[I] = '''') and not CppNumericSeparatorPrefix(S, I) then
            Result := cecSingleQuote
          else if S[I] = '"' then Result := cecDoubleQuote;
        cecBlockComment:
          if (S[I] = '*') and (I < LastColumn) and (S[I + 1] = '/') then
          begin Result := cecCode; Inc(I); end;
        cecSingleQuote, cecDoubleQuote:
          if Escaped then Escaped := False
          else if S[I] = '\' then Escaped := True
          else if ((Result = cecSingleQuote) and (S[I] = '''')) or
            ((Result = cecDoubleQuote) and (S[I] = '"')) then Result := cecCode;
      end;
      Inc(I);
    end;
    if Row < Caret.Y then
    begin
      if (Result = cecLineComment) and
        ((S = '') or (S[Length(S)] <> '\')) then Result := cecCode;
      if (Result in [cecSingleQuote, cecDoubleQuote]) and not Escaped then
        Result := cecCode;
    end;
  end;
end;

end.
