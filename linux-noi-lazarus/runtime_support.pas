unit runtime_support;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils;

{ Parse text into argv before execution. Quotes preserve whitespace and empty
  arguments; backslash escapes the next character outside single quotes.
  FPC 3.0.x cannot pass empty argv entries through TProcess, so the terminal
  wrapper uses QuoteShellArgument for every path and parsed argument. }
function ParseRunArguments(const Text: string; Args: TStrings;
  out ErrorText: string): Boolean;
function QuoteShellArgument(const Text: string): string;
function ResolveRunDirectory(const StoredDirectory, ExecutableName: string): string;
function ParseCompilerDiagnostic(const Text, CompileDirectory: string;
  out SourceName: string; out LineNumber, ByteColumn: Integer;
  out Detail: string): Boolean;
function ClampUtf8ByteColumn(const Text: string; Column: Integer): Integer;

implementation

function QuoteShellArgument(const Text: string): string;
begin
  Result := #39 + StringReplace(Text, #39, #39 + #92 + #39 + #39,
    [rfReplaceAll]) + #39;
end;

function ParseRunArguments(const Text: string; Args: TStrings;
  out ErrorText: string): Boolean;
var
  Parsed: TStringList;
  I: Integer;
  Quote: Char;
  Token: string;
  HaveToken: Boolean;
begin
  Result := False;
  ErrorText := '';
  Parsed := TStringList.Create;
  try
    I := 1;
    Quote := #0;
    Token := '';
    HaveToken := False;
    while I <= Length(Text) do
    begin
      if (Text[I] = '\') and (Quote <> '''') then
      begin
        if I = Length(Text) then
        begin
          ErrorText := 'Trailing escape in program arguments.';
          Exit;
        end;
        if (Quote = '"') and not (Text[I + 1] in ['"', '\', '$', '`', #10]) then
          Token := Token + '\'
        else
        begin
          Inc(I);
          if Text[I] <> #10 then Token := Token + Text[I];
        end;
        HaveToken := True;
      end
      else if Quote <> #0 then
      begin
        if Text[I] = Quote then Quote := #0
        else Token := Token + Text[I];
      end
      else if Text[I] in ['''', '"'] then
      begin
        Quote := Text[I];
        HaveToken := True;
      end
      else if Text[I] in [' ', #9, #10, #13] then
      begin
        if HaveToken then Parsed.Add(Token);
        Token := '';
        HaveToken := False;
      end
      else
      begin
        Token := Token + Text[I];
        HaveToken := True;
      end;
      Inc(I);
    end;
    if Quote <> #0 then
    begin
      ErrorText := 'Unterminated quote in program arguments.';
      Exit;
    end;
    if HaveToken then Parsed.Add(Token);
    Args.Assign(Parsed);
    Result := True;
  finally
    Parsed.Free;
  end;
end;

function ResolveRunDirectory(const StoredDirectory, ExecutableName: string): string;
var BaseDirectory: string;
begin
  BaseDirectory := ExtractFilePath(ExpandFileName(ExecutableName));
  if StoredDirectory = '' then Result := BaseDirectory
  else if StoredDirectory[1] = DirectorySeparator then
    Result := ExpandFileName(StoredDirectory)
  else
    Result := ExpandFileName(BaseDirectory + StoredDirectory);
end;

function StripAnsiCodes(const Text: string): string;
var I: Integer;
begin
  Result := '';
  I := 1;
  while I <= Length(Text) do
  begin
    if (Text[I] = #27) and (I < Length(Text)) and (Text[I + 1] = '[') then
    begin
      Inc(I, 2);
      while (I <= Length(Text)) and not (Text[I] in ['@'..'~']) do Inc(I);
      if I <= Length(Text) then Inc(I);
    end
    else
    begin
      Result := Result + Text[I];
      Inc(I);
    end;
  end;
end;

function ReadNumberColon(const Text: string; Start: Integer;
  out Value, AfterColon: Integer): Boolean;
var I: Integer;
begin
  I := Start;
  while (I <= Length(Text)) and (Text[I] in ['0'..'9']) do Inc(I);
  Result := (I > Start) and (I <= Length(Text)) and (Text[I] = ':') and
    TryStrToInt(Copy(Text, Start, I - Start), Value);
  if Result then Result := Value > 0;
  AfterColon := I + 1;
end;

function ParseCompilerDiagnostic(const Text, CompileDirectory: string;
  out SourceName: string; out LineNumber, ByteColumn: Integer;
  out Detail: string): Boolean;
var
  Clean, CandidateName, CandidateDetail, LowerDetail: string;
  I, RowValue, ColumnValue, AfterRow, AfterColumn: Integer;
begin
  Result := False;
  SourceName := '';
  Detail := '';
  LineNumber := 0;
  ByteColumn := 1;
  Clean := StripAnsiCodes(Text);
  { A Linux filename may contain ':' (even ':digits:'). Accept a location
    only when it names an existing source or precedes a diagnostic severity. }
  for I := 2 to Length(Clean) do
    if (Clean[I] = ':') and
      ReadNumberColon(Clean, I + 1, RowValue, AfterRow) then
    begin
      ColumnValue := 1;
      if not ReadNumberColon(Clean, AfterRow, ColumnValue, AfterColumn) then
      begin
        ColumnValue := 1;
        AfterColumn := AfterRow;
      end;
      CandidateName := Copy(Clean, 1, I - 1);
      if (CandidateName <> '') and (CandidateName[1] <> DirectorySeparator) and
        (CandidateName <> '<stdin>') and (CandidateName <> '<command-line>') then
        CandidateName := ExpandFileName(
          IncludeTrailingPathDelimiter(CompileDirectory) + CandidateName);
      CandidateDetail := Trim(Copy(Clean, AfterColumn, MaxInt));
      LowerDetail := LowerCase(CandidateDetail);
      if FileExists(CandidateName) or (Pos('error:', LowerDetail) = 1) or
        (Pos('fatal error:', LowerDetail) = 1) or
        (Pos('warning:', LowerDetail) = 1) or (Pos('note:', LowerDetail) = 1) then
      begin
        SourceName := CandidateName;
        LineNumber := RowValue;
        ByteColumn := ColumnValue;
        Detail := CandidateDetail;
        Result := True;
        if (Pos('error:', LowerDetail) = 1) or
          (Pos('fatal error:', LowerDetail) = 1) or
          (Pos('warning:', LowerDetail) = 1) or (Pos('note:', LowerDetail) = 1) then Exit;
      end;
    end;
end;

function ClampUtf8ByteColumn(const Text: string; Column: Integer): Integer;
begin
  Result := Column;
  if Result < 1 then Result := 1;
  if Result > Length(Text) + 1 then Result := Length(Text) + 1;
  while (Result > 1) and (Result <= Length(Text)) and
    ((Ord(Text[Result]) and $C0) = $80) do Dec(Result);
end;

end.
