program GdbSessionTest;
{$mode objfpc}{$H+}
uses Classes, SysUtils, BaseUnix, gdb_session;
type
  TObserver = class
    Output, Evaluation, Errors, FileName, Log: string;
    Line, LocationCount: Integer;
    Session: TGdbSession;
    TryBusyActions, BusyActionsAttempted: Boolean;
    procedure OnLog(Sender: TObject; const Text: string);
    procedure OnOutput(Sender: TObject; const Text: string);
    procedure OnError(Sender: TObject; const Text: string);
    procedure OnEvaluation(Sender: TObject; const Text: string);
    procedure OnLocation(Sender: TObject; const AFileName: string; ALine: Integer);
  end;
procedure TObserver.OnLog(Sender: TObject; const Text: string);
begin Log := Log + Text; end;
procedure TObserver.OnOutput(Sender: TObject; const Text: string);
begin Output := Output + Text; end;
procedure TObserver.OnError(Sender: TObject; const Text: string);
begin Errors := Errors + Text; end;
procedure TObserver.OnEvaluation(Sender: TObject; const Text: string);
begin Evaluation := Text; end;
procedure TObserver.OnLocation(Sender: TObject; const AFileName: string; ALine: Integer);
begin
  FileName := AFileName; Line := ALine; Inc(LocationCount);
  if TryBusyActions and Session.ChangingBreakpoint then
  begin
    TryBusyActions := False;
    BusyActionsAttempted := True;
    Session.ContinueExecution;
    Session.StepInto;
    Session.StepOver;
    Session.Evaluate('invalid_expression_that_must_not_be_queued');
  end;
end;
procedure Check(Value: Boolean; const MessageText: string);
begin if not Value then raise Exception.Create(MessageText); end;
var Session: TGdbSession; Observer: TObserver; Arguments,Variables: TStringList;
  Started: QWord; Inferior: LongInt; Source, Executable, OldSource: string;
  P, LocationsBeforeEdit: Integer;
procedure Pump;
begin
  Session.Poll;
  Check(Observer.Errors = '', 'GDB error: ' + Observer.Errors);
  Check(GetTickCount64 - Started < 15000,
    Format('Timed out waiting for GDB (state=%d, changing=%s, source=%s:%d, output=%s).',
      [Ord(Session.State), BoolToStr(Session.ChangingBreakpoint, True),
       Observer.FileName, Observer.Line, Observer.Output]));
  Sleep(5);
end;
procedure WaitStopped;
var PreviousCount: Integer;
begin
  Started := GetTickCount64;
  { GDB can emit ^running and *stopped in one pipe read. Observe the stop event
    rather than requiring a transient state to survive between timer ticks. }
  PreviousCount := Observer.LocationCount;
  repeat Pump until Observer.LocationCount > PreviousCount;
end;
procedure ToggleAfterPending(const FileName: string; Line: Integer);
var Accepted: Boolean;
begin
  Started := GetTickCount64;
  repeat
    Accepted := False;
    try
      Session.ToggleBreakpoint(FileName, Line);
      Accepted := True;
    except
      on E: Exception do
        if E.Message <> 'Wait for the pending debugger command.' then raise;
    end;
    if not Accepted then Pump;
  until Accepted;
end;
procedure WaitEvaluation(const Expected: string);
begin
  Started := GetTickCount64;
  repeat Pump until Observer.Evaluation <> '';
  Check(Observer.Evaluation = Expected, 'Unexpected evaluation: ' + Observer.Evaluation);
  Observer.Evaluation := '';
end;
procedure WaitBreakpointChange;
begin
  Started := GetTickCount64;
  repeat Pump until not Session.ChangingBreakpoint;
end;
begin
  Session := TGdbSession.Create; Observer := TObserver.Create;
  Observer.Session := Session;
  Arguments := TStringList.Create;
  Variables:=TStringList.Create;
  try
    MIVariableRows('^done,variables=[{name="n",type="int",value="7"},{name="s",type="char *",value="\"a}b\""},{name="v",type="vector<int>"}]',Variables);
    Check((Variables.Count=3) and (Variables.Values['n']='7') and (Variables.Values['s']='"a}b"') and (Variables.Values['v']='<vector<int>>'),'MI locals decode scalars, quoted braces and aggregates.');
    Source := ExpandFileName(ParamStr(1)); Executable := ExpandFileName(ParamStr(2));
    P := 1;
    Check(MIDecode('"quoted\" path\\file\n\344\270\255"', P) =
      'quoted" path\file' + #10 + #$E4#$B8#$AD, 'MI C-string decoding failed.');
    Check(MIField('frame={func="line=wrong",fullname="/tmp/a b.c",line="11"}',
      'line') = '11', 'MI fields must ignore field-like text inside quoted strings.');
    Session.OnLog := @Observer.OnLog;
    Session.OnOutput := @Observer.OnOutput;
    Session.OnError := @Observer.OnError;
    Session.OnEvaluation := @Observer.OnEvaluation;
    Session.OnLocation := @Observer.OnLocation;
    Session.ToggleBreakpoint(Source, 12);
    Check(Session.HasBreakpoint(Source, 12), 'Breakpoint not recorded.');
    Session.ToggleBreakpoint(Source, 12);
    Check(not Session.HasBreakpoint(Source, 12), 'Breakpoint not removed.');
    OldSource := Source + '.before-save-as';
    Session.ToggleBreakpoint(OldSource, 11);
    Session.ToggleBreakpoint(Source, 11);
    TGdbBreakpoint(Session.Breakpoints[0]).Number := 'stale-gdb-number';
    Session.RenameBreakpoints('', Source);
    Session.RenameBreakpoints(OldSource, '');
    Check(Session.Breakpoints.Count = 2, 'Empty rename changed breakpoints.');
    Session.RenameBreakpoints(OldSource, Source);
    Check((Session.Breakpoints.Count = 1) and
      Session.HasBreakpoint(Source, 11) and
      not Session.HasBreakpoint(OldSource, 11), 'Save As did not merge renamed breakpoints.');
    Check(TGdbBreakpoint(Session.Breakpoints[0]).Number = '', 'Rename retained a stale GDB breakpoint number.');
    Arguments.Add('space and "quote" and ' + #39 + 'single' + #39 +
      '\backslash;$(touch must-not-exist)' + #10 + 'shell touch must-not-exist');
    Arguments.Add(''); Arguments.Add('last');
    Session.Start(Executable, ExtractFilePath(Executable), Arguments);
    Started := GetTickCount64;
    repeat Pump until Session.State = gsStopped;
    Check((Observer.FileName = Source) and (Observer.Line in [5, 6]),
      'Did not stop at main source line: ' + Observer.FileName + ':' + IntToStr(Observer.Line));
    Session.RenameBreakpoints(Source, OldSource);
    Check(Session.HasBreakpoint(Source, 11) and
      not Session.HasBreakpoint(OldSource, 11), 'Active session allowed breakpoint renaming.');
    while Observer.Line < 7 do begin Session.StepOver; WaitStopped; end;
    Session.Evaluate('value'); WaitEvaluation('7');
    Session.ConsoleCommand('print value'); Started:=GetTickCount64;
    repeat Pump until Pos(' = 7',Observer.Log)>0;
    Session.NextInstruction; WaitStopped;
    Session.StepInstruction; WaitStopped;
    Started := GetTickCount64;
    { Drain the break-insert response before issuing/removing another breakpoint. }
    repeat Pump until TGdbBreakpoint(Session.Breakpoints[0]).Number <> '';
    Session.ContinueExecution;
    Started := GetTickCount64;
    repeat Pump until Pos('ready:', Observer.Output) > 0;
    Check(Pos(Arguments[0], StringReplace(Observer.Output, #13#10, #10,
      [rfReplaceAll])) > 0,
      'Arguments were not passed literally: ' + Observer.Output);
    Check(Pos('argc=4 empty=<> last=<last>', Observer.Output) > 0,
      'Empty argument was not preserved: ' + Observer.Output);
    Check(Session.State = gsRunning, 'Fixture is not running before live breakpoint changes.');
    LocationsBeforeEdit := Observer.LocationCount;
    ToggleAfterPending(Source, 11);
    WaitBreakpointChange;
    Check(not Session.HasBreakpoint(Source, 11), 'Running breakpoint deletion failed.');
    ToggleAfterPending(Source, 11);
    WaitBreakpointChange;
    Started := GetTickCount64;
    repeat Pump until TGdbBreakpoint(Session.Breakpoints[0]).Number <> '';
    Check(Session.State = gsRunning, 'Live breakpoint edit interrupted the program.');
    Check(Observer.LocationCount = LocationsBeforeEdit,
      'Internal breakpoint pause was reported as a user source stop.');
    Session.SendInput('5' + #10);
    Started := GetTickCount64;
    repeat Pump until Session.State = gsStopped;
    Check(Observer.Line = 11, 'Did not stop on the migrated breakpoint reinserted while running.');
    Session.Evaluate('value'); WaitEvaluation('12');
    Session.StepInto; WaitStopped;
    Check(Observer.Line in [2, 3], 'Step into did not enter the source function: ' +
      IntToStr(Observer.Line));
    while Observer.Line < 3 do begin Session.StepOver; WaitStopped; end;
    Session.Evaluate('x'); WaitEvaluation('12');
    Session.StepOut; WaitStopped;
    Check(Observer.Line in [11,12], 'Finish did not return to the caller.');
    Session.ToggleBreakpoint(Source, 11);
    Check(not Session.HasBreakpoint(Source, 11), 'Live breakpoint not removed.');
    Session.ContinueExecution;
    Started := GetTickCount64;
    repeat Pump until Session.State in [gsFinished, gsInactive];
    Session.Poll;
    Check(Pos('value=24', Observer.Output) > 0, 'Program terminal output is missing.');
    { Normal inferior exit also closes GDB and releases the IDE edit lock. }
    Started := GetTickCount64;
    repeat Pump until (Session.State = gsInactive) and not Session.Active;
    Observer.Output := '';
    Session.Start(Executable, ExtractFilePath(Executable), Arguments);
    Started := GetTickCount64;
    repeat Pump until Session.State = gsStopped;
    Session.ContinueExecution; Started := GetTickCount64;
    repeat Pump until Pos('ready:', Observer.Output) > 0;
    Inferior := Session.InferiorPID;
    Check(Inferior > 0, 'Inferior process ID not observed.');
    ToggleAfterPending(Source, 12);
    Check(Session.ChangingBreakpoint, 'Running edit did not enter its interrupt wait.');
    Session.Stop; Started := GetTickCount64;
    Check(not Session.ChangingBreakpoint, 'Stop left a breakpoint edit scheduled for resume.');
    Session.ToggleBreakpoint(Source, 13);
    Check(not Session.ChangingBreakpoint,
      'A gutter click during Stop scheduled another interrupt or resume.');
    Check(not Session.HasBreakpoint(Source, 13), 'Stopping still accepted a breakpoint change.');
    repeat Pump until (Session.State = gsInactive) and not Session.Active;
    Check(fpKill(Inferior, 0) <> 0, 'Stopping left the inferior process alive.');

    { Race a real user breakpoint against the internal SIGINT. Whichever stop
      arrives first, the genuine breakpoint must eventually remain paused. }
    Observer.Output := '';
    ToggleAfterPending(Source, 10);
    Session.Start(Executable, ExtractFilePath(Executable), Arguments);
    Started := GetTickCount64;
    repeat Pump until Session.State = gsStopped;
    Session.ContinueExecution;
    Started := GetTickCount64;
    repeat Pump until Pos('ready:', Observer.Output) > 0;
    Session.SendInput('5' + #10);
    { Let the actual breakpoint stop reach the MI pipe before asking to edit,
      while deliberately not Polling: public state still says running. }
    Sleep(150);
    Observer.TryBusyActions := True;
    ToggleAfterPending(Source, 12);
    WaitBreakpointChange;
    Started := GetTickCount64;
    repeat Pump until Session.State = gsStopped;
    Check(Observer.Line = 10, 'Internal breakpoint edit resumed past a user breakpoint.');
    Check(Observer.BusyActionsAttempted,
      'Fixture did not exercise commands during a real-stop/breakpoint-edit race.');
    Check(Session.HasBreakpoint(Source, 12), 'Breakpoint edit raced with a real stop was lost.');
    for P := 1 to 20 do begin Session.Poll; Sleep(5); end;
    Check(Session.State = gsStopped, 'User breakpoint was automatically resumed after the edit.');
    Session.Stop; Started := GetTickCount64;
    repeat Pump until (Session.State = gsInactive) and not Session.Active;
    Check(not FileExists(ExtractFilePath(Executable) + 'must-not-exist'), 'Arguments invoked a shell.');
    WriteLn('PASS: MI strings, literal argv, breakpoint add/delete while running and paused/Save As migration, source stop, step over/into/finish/instructions, literal GDB console, expression evaluation, PTY stdin/stdout, exit/restart, stop during breakpoint edit, real-stop race and stop cleanup.');
  finally Variables.Free;Arguments.Free; Session.Free; Observer.Free; end;
end.
