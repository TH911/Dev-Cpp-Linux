program runtime_support_test;

{$mode objfpc}{$H+}{$codepage utf8}

uses Classes, SysUtils, Process, runtime_support;

var TestDirectory, ErrorText, SourceName, Detail: string;
    Row, Column: Integer;
    Args, Files: TStringList;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then raise Exception.Create(MessageText);
end;

procedure CheckArguments(const Text: string; const Expected: array of string);
var I: Integer;
begin
  Check(ParseRunArguments(Text, Args, ErrorText), 'Arguments rejected: ' + Text);
  Check(Args.Count = Length(Expected), 'Wrong argument count: ' + Text);
  for I := 0 to High(Expected) do
    Check(Args[I] = Expected[I], Format('Argument %d differs: %s', [I, Text]));
end;

procedure MakeSource(const Name: string);
begin
  Files.Text := 'int main() { return 0; }';
  Files.SaveToFile(TestDirectory + '/' + Name);
end;

procedure CheckShellLiterals(const Values: array of string);
var
  Proc: TProcess;
  Command, Expected, Actual: string;
  I: Integer;
begin
  Command := 'printf ''%s\0''';
  Expected := '';
  for I := 0 to High(Values) do
  begin
    Command := Command + ' ' + QuoteShellArgument(Values[I]);
    Expected := Expected + Values[I] + #0;
  end;
  Proc := TProcess.Create(nil);
  try
    Proc.Executable := '/bin/bash';
    Proc.Parameters.Add('-c');
    Proc.Parameters.Add(Command);
    Proc.Options := [poUsePipes, poWaitOnExit];
    Proc.Execute;
    SetLength(Actual, Proc.Output.NumBytesAvailable);
    if Actual <> '' then Proc.Output.ReadBuffer(Actual[1], Length(Actual));
    Check((Proc.ExitStatus = 0) and (Actual = Expected),
      'Shell wrapper changed literal argv');
  finally
    Proc.Free;
  end;
end;

begin
  Args := TStringList.Create;
  Files := TStringList.Create;
  TestDirectory := GetTempFileName(GetTempDir(False), 'noi-runtime-');
  DeleteFile(TestDirectory);
  ForceDirectories(TestDirectory + '/include');
  try
    CheckArguments('', []);
    CheckArguments('one "two three" ''four five''', ['one', 'two three', 'four five']);
    CheckArguments('"" '''' a""b', ['', '', 'ab']);
    CheckArguments('a\ b "a\"b" ''a\b'' "a\b"', ['a b', 'a"b', 'a\b', 'a\b']);
    CheckArguments('$(touch marker); * > output', ['$(touch', 'marker);', '*', '>', 'output']);
    CheckArguments('"$(touch marker)" "中文 空格"', ['$(touch marker)', '中文 空格']);
    CheckArguments(QuoteShellArgument(''), ['']);
    CheckArguments(QuoteShellArgument('a''b'), ['a''b']);
    CheckArguments(QuoteShellArgument('$(touch marker); `id` * " \ 中文'),
      ['$(touch marker); `id` * " \ 中文']);
    CheckShellLiterals(['before', '', 'after', 'a''b', '中文 空格',
      '$(printf expanded); `printf expanded` * " \']);
    Args.Text := 'preserved';
    Check(not ParseRunArguments('"unfinished', Args, ErrorText), 'Unclosed quote accepted');
    Check(Args[0] = 'preserved', 'Rejected arguments changed the old list');
    Check(not ParseRunArguments('unfinished\', Args, ErrorText), 'Trailing escape accepted');
    Check(ResolveRunDirectory('', '/tmp/project/program') = '/tmp/project/', 'Default run folder');
    Check(ResolveRunDirectory('data', '/tmp/project/program') = '/tmp/project/data', 'Relative run folder');
    Check(ResolveRunDirectory('/tmp/data', '/tmp/project/program') = '/tmp/data', 'Absolute run folder');

    MakeSource('name');
    MakeSource('name:12:part.cpp');
    MakeSource('include/bad.h');
    Check(ParseCompilerDiagnostic('name:12:part.cpp:2:7: error: bad declaration',
      TestDirectory, SourceName, Row, Column, Detail), 'Colon source not parsed');
    Check((SourceName = TestDirectory + '/name:12:part.cpp') and
      (Row = 2) and (Column = 7) and (Detail = 'error: bad declaration'), 'Colon source misparsed');
    Check(ParseCompilerDiagnostic('include/bad.h:12:4: warning: bad header',
      TestDirectory, SourceName, Row, Column, Detail), 'Relative header not parsed');
    Check((SourceName = TestDirectory + '/include/bad.h') and
      (Row = 12) and (Column = 4), 'Relative header was not based on compile directory');
    Check(ParseCompilerDiagnostic(#27'[01minclude/bad.h'#27'[m:5: note: detail',
      TestDirectory, SourceName, Row, Column, Detail), 'Colored diagnostic not parsed');
    Check((SourceName = TestDirectory + '/include/bad.h') and
      (Row = 5) and (Column = 1), 'Colored line-only diagnostic misparsed');
    Check(not ParseCompilerDiagnostic('g++: fatal error: no input files',
      TestDirectory, SourceName, Row, Column, Detail), 'Location-free message parsed as a location');
    Check(ClampUtf8ByteColumn('中x', 2) = 1, 'UTF8 continuation byte used as caret');
    Check(ClampUtf8ByteColumn('中x', 3) = 1, 'UTF8 second continuation byte used as caret');
    Check(ClampUtf8ByteColumn('中x', 4) = 4, 'Valid UTF8 byte column changed');
    Check(ClampUtf8ByteColumn('中x', 100) = 5, 'Column beyond end was not clamped');
    WriteLn('PASS: quoted/empty/literal argv, argument validation, run folders, colon/relative/colored diagnostics, UTF8 byte columns.');
  finally
    DeleteFile(TestDirectory + '/name');
    DeleteFile(TestDirectory + '/name:12:part.cpp');
    DeleteFile(TestDirectory + '/include/bad.h');
    RemoveDir(TestDirectory + '/include');
    RemoveDir(TestDirectory);
    Args.Free;
    Files.Free;
  end;
end.
