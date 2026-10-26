unit gdb_session;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, Process, Contnrs;

type
  TGdbState = (gsInactive, gsStarting, gsRunning, gsStopped, gsFinished, gsError);
  TGdbTextEvent = procedure(Sender: TObject; const Text: string) of object;
  TGdbLocationEvent = procedure(Sender: TObject; const FileName: string;
    Line: Integer) of object;
  TBreakpointEditPhase = (beNone, beWaitingStop, beReady, beChanging, beResuming);
  TGdbBreakpoint = class
    FileName, Number: string;
    Line: Integer;
  end;
  TGdbSession = class
  private
    FProcess: TProcess;
    FQueue, FBreakpoints: TObjectList;
    FPending: TObject;
    FToken: Integer;
    FBuffer: RawByteString;
    FState: TGdbState;
    FMaster, FSlave: LongInt;
    FInferiorPID: LongInt;
    FStopAt: QWord;
    FStopping: Boolean;
    FBreakpointEdit: TBreakpointEditPhase;
    FBreakpointFile, FBreakpointStopRecord, FBreakpointOldNumber: string;
    FBreakpointLine: Integer;
    FBreakpointResume: Boolean;
    FBreakpointStarted: QWord;
    FOnLog, FOnOutput, FOnError, FOnEvaluation: TGdbTextEvent;
    FOnLocation: TGdbLocationEvent;
    FOnState: TNotifyEvent;
    procedure SetState(Value: TGdbState);
    procedure Queue(const Command: string; Purpose: Integer = 0;
      Breakpoint: TGdbBreakpoint = nil);
    procedure SendNext;
    procedure HandleLine(const S: string);
    procedure CloseResources;
    procedure Fail(const S: string);
    procedure ApplyBreakpointToggle(const FileName: string; Line: Integer);
    procedure AdvanceBreakpointEdit;
    procedure CompleteBreakpointEdit;
    procedure AbortBreakpointEdit(const MessageText: string);
    procedure ShowStoppedLocation(const RecordText: string);
    procedure NotifyBreakpointChange;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start(const Executable, WorkDirectory: string; Arguments: TStrings);
    procedure Poll;
    procedure Stop;
    procedure ContinueExecution;
    procedure StepInto;
    procedure StepOver;
    procedure Evaluate(const Expression: string);
    procedure SendInput(const Text: string);
    procedure ToggleBreakpoint(const FileName: string; Line: Integer);
    procedure RenameBreakpoints(const OldName, NewName: string);
    function HasBreakpoint(const FileName: string; Line: Integer): Boolean;
    function Active: Boolean;
    function ChangingBreakpoint: Boolean;
    property State: TGdbState read FState;
    property Breakpoints: TObjectList read FBreakpoints;
    property InferiorPID: LongInt read FInferiorPID;
    property OnLog: TGdbTextEvent read FOnLog write FOnLog;
    property OnOutput: TGdbTextEvent read FOnOutput write FOnOutput;
    property OnError: TGdbTextEvent read FOnError write FOnError;
    property OnEvaluation: TGdbTextEvent read FOnEvaluation write FOnEvaluation;
    property OnLocation: TGdbLocationEvent read FOnLocation write FOnLocation;
    property OnState: TNotifyEvent read FOnState write FOnState;
  end;

function MIQuote(const S: string): string;
function MIField(const RecordText, Name: string): string;
function MIDecode(const S: string; var Position: Integer): string;

implementation

uses BaseUnix;

type
  TGdbCommand = class
    Text: string;
    Token, Purpose: Integer;
    Breakpoint: TGdbBreakpoint;
  end;

const
  { POSIX fcntl descriptor flag; FPC 3.0.4 BaseUnix does not export its name. }
  GdbCloseOnExec = 1;
  cpStartup = 1;
  cpBreakpoint = 2;
  cpEvaluate = 3;
  cpBreakpointInterrupt = 4;
  cpBreakpointDelete = 5;
  cpBreakpointResume = 6;

function OpenPTY(var Master, Slave: LongInt; Name: PChar;
  Termios, WinSize: Pointer): LongInt; cdecl; external 'util' name 'openpty';

function MIQuote(const S: string): string;
var C: Char;
begin
  Result := '"';
  for C in S do
    case C of
      '"', '\': Result := Result + '\' + C;
      #10: Result := Result + '\n';
      #13: Result := Result + '\r';
      #9: Result := Result + '\t';
      else Result := Result + C;
    end;
  Result := Result + '"';
end;

function MIDecode(const S: string; var Position: Integer): string;
var C: Char; Code, Count: Integer;
begin
  Result := '';
  if (Position > Length(S)) or (S[Position] <> '"') then Exit;
  Inc(Position);
  while Position <= Length(S) do
  begin
    C := S[Position]; Inc(Position);
    if C = '"' then Exit;
    if (C = '\') and (Position <= Length(S)) then
    begin
      C := S[Position]; Inc(Position);
      case C of
        'n': C := #10;
        'r': C := #13;
        't': C := #9;
        'b': C := #8;
        'f': C := #12;
        'v': C := #11;
        '0'..'7': begin
          Code := Ord(C) - Ord('0'); Count := 1;
          while (Count < 3) and (Position <= Length(S)) and
            (S[Position] in ['0'..'7']) do
          begin
            Code := Code * 8 + Ord(S[Position]) - Ord('0');
            Inc(Position); Inc(Count);
          end;
          C := Chr(Code and 255);
        end;
      end;
    end;
    Result := Result + C;
  end;
end;

{ Locate a named MI result, respecting strings and nested tuples. The first
  matching field is sufficient for frame.fullname/line and bkpt.number. }
function MIField(const RecordText, Name: string): string;
var P, Start: Integer; Key: string;
begin
  Result := ''; P := 1;
  while P <= Length(RecordText) do
  begin
    if RecordText[P] = '"' then begin MIDecode(RecordText, P); Continue; end;
    if RecordText[P] in ['A'..'Z', 'a'..'z', '_', '-'] then
    begin
      Start := P;
      while (P <= Length(RecordText)) and
        (RecordText[P] in ['A'..'Z', 'a'..'z', '0'..'9', '_', '-']) do Inc(P);
      Key := Copy(RecordText, Start, P - Start);
      if (P <= Length(RecordText)) and (RecordText[P] = '=') then
      begin
        Inc(P);
        if (Key = Name) and (P <= Length(RecordText)) and
          (RecordText[P] = '"') then Exit(MIDecode(RecordText, P));
      end;
    end
    else Inc(P);
  end;
end;

constructor TGdbSession.Create;
begin
  inherited Create;
  FMaster := -1; FSlave := -1;
  FQueue := TObjectList.Create(True);
  FBreakpoints := TObjectList.Create(True);
end;

destructor TGdbSession.Destroy;
var Started: QWord;
begin
  if Assigned(FProcess) and FProcess.Running then
  begin
    if FInferiorPID > 0 then fpKill(FInferiorPID, SIGKILL);
    { gdb kills its attached inferior when it receives SIGTERM. }
    FProcess.Terminate(0);
    Started := GetTickCount64;
    while FProcess.Running and (GetTickCount64 - Started < 500) do Sleep(5);
    if FProcess.Running then fpKill(FProcess.ProcessID, SIGKILL);
  end;
  CloseResources;
  FQueue.Free; FBreakpoints.Free;
  inherited Destroy;
end;

procedure TGdbSession.SetState(Value: TGdbState);
begin
  if FState = Value then Exit;
  FState := Value;
  if Assigned(FOnState) then FOnState(Self);
end;

function TGdbSession.Active: Boolean;
begin
  Result := Assigned(FProcess) and FProcess.Running;
end;

function TGdbSession.ChangingBreakpoint: Boolean;
begin
  Result := FBreakpointEdit <> beNone;
end;

procedure TGdbSession.CloseResources;
var I: Integer;
begin
  FreeAndNil(FProcess);
  FreeAndNil(FPending);
  FQueue.Clear; FBuffer := '';
  if FMaster >= 0 then fpClose(FMaster);
  if FSlave >= 0 then fpClose(FSlave);
  FMaster := -1; FSlave := -1;
  FStopping := False; FStopAt := 0;
  FBreakpointEdit := beNone;
  FBreakpointFile := ''; FBreakpointStopRecord := ''; FBreakpointOldNumber := '';
  FBreakpointResume := False; FBreakpointStarted := 0;
  FInferiorPID := 0;
  for I := 0 to FBreakpoints.Count - 1 do
    TGdbBreakpoint(FBreakpoints[I]).Number := '';
end;

procedure TGdbSession.Fail(const S: string);
begin
  if Assigned(FOnError) then FOnError(Self, S);
  SetState(gsError);
end;

procedure TGdbSession.Queue(const Command: string; Purpose: Integer;
  Breakpoint: TGdbBreakpoint);
var Item: TGdbCommand;
begin
  Item := TGdbCommand.Create;
  Item.Text := Command; Item.Purpose := Purpose; Item.Breakpoint := Breakpoint;
  FQueue.Add(Item);
end;

procedure TGdbSession.SendNext;
var Item: TGdbCommand; S: RawByteString;
begin
  if not Active or FStopping or Assigned(FPending) or (FQueue.Count = 0) then Exit;
  Item := TGdbCommand(FQueue.Extract(FQueue[0]));
  Inc(FToken); Item.Token := FToken; FPending := Item;
  S := IntToStr(Item.Token) + Item.Text + #10;
  try FProcess.Input.WriteBuffer(S[1], Length(S));
  except on E: Exception do begin Fail(E.Message); Stop; end; end;
end;

procedure TGdbSession.NotifyBreakpointChange;
begin
  { The panel already uses this notification to refresh its state snapshot.
    A live edit can change breakpoint marks without changing public run state. }
  if Assigned(FOnState) then FOnState(Self);
end;

procedure TGdbSession.ShowStoppedLocation(const RecordText: string);
var FileName: string; LineNo: Integer;
begin
  FileName := MIField(RecordText, 'fullname');
  if FileName = '' then FileName := MIField(RecordText, 'file');
  LineNo := StrToIntDef(MIField(RecordText, 'line'), 0);
  if Assigned(FOnLocation) and (FileName <> '') and (LineNo > 0) then
    FOnLocation(Self, FileName, LineNo);
end;

procedure TGdbSession.AbortBreakpointEdit(const MessageText: string);
var StopRecord: string;
begin
  StopRecord := FBreakpointStopRecord;
  FBreakpointEdit := beNone;
  FBreakpointResume := False; FBreakpointStopRecord := '';
  { Once an internal interrupt really stopped the target, a failed edit must
    leave it visibly paused. Never resume after an error or an uncertain stop. }
  if (StopRecord <> '') and not FStopping then
  begin
    SetState(gsStopped);
    ShowStoppedLocation(StopRecord);
  end;
  if (MessageText <> '') and Assigned(FOnError) then FOnError(Self, MessageText);
  NotifyBreakpointChange;
end;

procedure TGdbSession.CompleteBreakpointEdit;
begin
  if FBreakpointEdit <> beChanging then Exit;
  if FBreakpointResume and Active and not FStopping then
  begin
    FBreakpointEdit := beResuming;
    Queue('-exec-continue', cpBreakpointResume);
  end
  else
  begin
    FBreakpointEdit := beNone;
    FBreakpointStopRecord := '';
  end;
  NotifyBreakpointChange;
end;

procedure TGdbSession.AdvanceBreakpointEdit;
begin
  if (FBreakpointEdit <> beReady) or Assigned(FPending) or
    (FQueue.Count <> 0) or not Active or FStopping then Exit;
  FBreakpointEdit := beChanging;
  ApplyBreakpointToggle(FBreakpointFile, FBreakpointLine);
  NotifyBreakpointChange;
  if FQueue.Count = 0 then CompleteBreakpointEdit;
  SendNext;
end;

procedure TGdbSession.Start(const Executable, WorkDirectory: string; Arguments: TStrings);
var Name: array[0..255] of Char; I: Integer; S: string; B: TGdbBreakpoint;
begin
  if Active then raise Exception.Create('A debugging session is already active.');
  CloseResources;
  if not FileExists(Executable) then raise Exception.Create('Compile the program before debugging.');
  if OpenPTY(FMaster, FSlave, @Name[0], nil, nil) <> 0 then
    raise Exception.Create('Unable to create the debugger program terminal.');
  fpFcntl(FMaster, F_SETFL, fpFcntl(FMaster, F_GETFL) or O_NONBLOCK);
  fpFcntl(FMaster, F_SETFD, GdbCloseOnExec);
  fpFcntl(FSlave, F_SETFD, GdbCloseOnExec);
  FProcess := TProcess.Create(nil);
  FProcess.Executable := 'gdb';
  FProcess.Parameters.Add('--quiet');
  FProcess.Parameters.Add('--nx');
  FProcess.Parameters.Add('--interpreter=mi2');
  FProcess.Options := [poUsePipes, poStderrToOutPut];
  FProcess.CurrentDirectory := WorkDirectory;
  try
    FProcess.Execute;
    SetState(gsStarting);
    Queue('-gdb-set pagination off', cpStartup);
    Queue('-gdb-set confirm off', cpStartup);
    Queue('-gdb-set mi-async on', cpStartup);
    Queue('-inferior-tty-set ' + MIQuote(StrPas(Name)), cpStartup);
    Queue('-file-exec-and-symbols ' + MIQuote(Executable), cpStartup);
    { GDB 9's -exec-arguments retains MI quoting in the stored command line,
      while startup-with-shell=off splits spaces without recognizing quotes.
      Give GDB one explicitly MI-decoded set-args command containing separately
      POSIX-quoted argv entries. Quotes, substitutions and metacharacters remain
      literal data in GDB's standard Unix inferior launcher. }
    S := 'set args';
    if Assigned(Arguments) then
      for I := 0 to Arguments.Count - 1 do
        S := S + ' ' + #39 + StringReplace(Arguments[I], #39,
          #39 + '\' + #39 + #39, [rfReplaceAll]) + #39;
    Queue('-interpreter-exec console ' + MIQuote(S), cpStartup);
    for I := 0 to FBreakpoints.Count - 1 do
    begin
      B := TGdbBreakpoint(FBreakpoints[I]);
      Queue('-break-insert ' + MIQuote(B.FileName + ':' + IntToStr(B.Line)), cpBreakpoint, B);
    end;
    { Stop at main even without a user breakpoint; then users can step/evaluate. }
    Queue('-break-insert -t main', cpStartup);
    Queue('-exec-run', cpStartup);
    SendNext;
  except
    on E: Exception do
    begin
      if Active then FProcess.Terminate(1);
      CloseResources;
      SetState(gsError);
      raise;
    end;
  end;
end;

procedure TGdbSession.HandleLine(const S: string);
var P, T: Integer; Kind: Char; Body, Value, StopFile: string;
  Item: TGdbCommand;
begin
  if S = '' then Exit;
  P := 1;
  while (P <= Length(S)) and (S[P] in ['0'..'9']) do Inc(P);
  T := StrToIntDef(Copy(S, 1, P - 1), -1);
  if P > Length(S) then Exit;
  Kind := S[P]; Inc(P); Body := Copy(S, P, MaxInt);
  if Kind in ['~', '&', '@'] then
  begin
    Value := MIDecode(S, P);
    if (Kind = '@') and Assigned(FOnOutput) then FOnOutput(Self, Value)
    else if Assigned(FOnLog) then FOnLog(Self, Value);
  end
  else if (Kind = '*') and (Pos('running', Body) = 1) then
  begin
    if FBreakpointEdit = beResuming then FBreakpointStopRecord := '';
    SetState(gsRunning);
  end
  else if (Kind = '=') and (Pos('thread-group-started,', Body) = 1) then
    FInferiorPID := StrToIntDef(MIField(Body, 'pid'), 0)
  else if (Kind = '=') and (Pos('thread-group-exited,', Body) = 1) then
    FInferiorPID := 0
  else if (Kind = '*') and (Pos('stopped', Body) = 1) then
  begin
    Value := MIField(Body, 'reason');
    if Pos('exited', Value) = 1 then
    begin
      SetState(gsFinished);
      if Assigned(FOnLog) then FOnLog(Self, Value + ' ' + MIField(Body, 'exit-code') + LineEnding);
      { The IDE must regain editable documents after a normal program exit. }
      Stop;
    end
    else if not FStopping then
    begin
      if FBreakpointEdit = beWaitingStop then
      begin
        FBreakpointEdit := beReady;
        FBreakpointStopRecord := Body;
        { GDB reports our -exec-interrupt as SIGINT. A breakpoint, watchpoint,
          other signal or stop at an existing source breakpoint belongs to the
          user and must remain paused after the edit, even in this race. }
        StopFile := MIField(Body, 'fullname');
        if StopFile = '' then StopFile := MIField(Body, 'file');
        FBreakpointResume := (Value = 'signal-received') and
          (MIField(Body, 'signal-name') = 'SIGINT') and
          not HasBreakpoint(StopFile, StrToIntDef(MIField(Body, 'line'), 0));
      end
      else FBreakpointResume := False;
      if not ((FBreakpointEdit = beReady) and FBreakpointResume) then
      begin
        SetState(gsStopped);
        if Assigned(FOnLog) then FOnLog(Self, Value + LineEnding);
        ShowStoppedLocation(Body);
      end;
      AdvanceBreakpointEdit;
    end;
  end
  else if (Kind = '^') and Assigned(FPending) and
    (TGdbCommand(FPending).Token = T) then
  begin
    Item := TGdbCommand(FPending); FPending := nil;
    try
      if Pos('error', Body) = 1 then
      begin
        Value := MIField(Body, 'msg');
        if Item.Purpose = cpStartup then begin Fail(Value); Stop; end
        else if (Item.Purpose = cpBreakpointInterrupt) and
          (FBreakpointEdit = beReady) and not FBreakpointResume and
          (Pos('not running', LowerCase(Value)) > 0) then
          AdvanceBreakpointEdit
        else if FBreakpointEdit <> beNone then AbortBreakpointEdit(Value)
        else if Assigned(FOnError) then FOnError(Self, Value);
      end
      else if Item.Purpose = cpBreakpoint then
      begin
        Item.Breakpoint.Number := MIField(Body, 'number');
        CompleteBreakpointEdit;
      end
      else if Item.Purpose = cpBreakpointDelete then CompleteBreakpointEdit
      else if Item.Purpose = cpBreakpointInterrupt then AdvanceBreakpointEdit
      else if Item.Purpose = cpBreakpointResume then
      begin
        FBreakpointEdit := beNone;
        FBreakpointResume := False; FBreakpointStopRecord := '';
        NotifyBreakpointChange;
      end
      else if (Item.Purpose = cpEvaluate) and Assigned(FOnEvaluation) then
        FOnEvaluation(Self, MIField(Body, 'value'));
    finally Item.Free; end;
    SendNext;
  end;
end;

procedure TGdbSession.Poll;
const MaxBytesPerTick = 65536;
var Buffer: array[0..4095] of Byte; N, Limit, P: Integer; Chunk: RawByteString;
begin
  if not Assigned(FProcess) then Exit;
  Limit := MaxBytesPerTick;
  while (FProcess.Output.NumBytesAvailable > 0) and (Limit > 0) do
  begin
    N := FProcess.Output.NumBytesAvailable;
    if N > SizeOf(Buffer) then N := SizeOf(Buffer);
    N := FProcess.Output.Read(Buffer, N); if N <= 0 then Break;
    Dec(Limit, N); SetString(Chunk, PChar(@Buffer[0]), N);
    FBuffer := FBuffer + Chunk;
    P := Pos(#10, FBuffer);
    while P > 0 do
    begin
      HandleLine(TrimRight(Copy(FBuffer, 1, P - 1)));
      Delete(FBuffer, 1, P); P := Pos(#10, FBuffer);
    end;
    if Length(FBuffer) > 1048576 then begin FBuffer := ''; Fail('GDB response exceeded 1 MiB.'); Stop; end;
  end;
  AdvanceBreakpointEdit;
  if (FBreakpointEdit <> beNone) and
    (GetTickCount64 - FBreakpointStarted > 10000) then
    AbortBreakpointEdit('Timed out changing a running program breakpoint.');
  Limit := MaxBytesPerTick;
  if FMaster >= 0 then
    repeat
      N := fpRead(FMaster, Buffer, SizeOf(Buffer));
      if N > 0 then
      begin
        Dec(Limit, N); SetString(Chunk, PChar(@Buffer[0]), N);
        if Assigned(FOnOutput) then FOnOutput(Self, Chunk);
      end;
    until (N <= 0) or (Limit <= 0);
  if FStopping and FProcess.Running and (GetTickCount64 - FStopAt >= 1000) then
  begin
    if FInferiorPID > 0 then fpKill(FInferiorPID, SIGKILL);
    FProcess.Terminate(0);
    if GetTickCount64 - FStopAt >= 2000 then fpKill(FProcess.ProcessID, SIGKILL);
  end;
  if not FProcess.Running then
  begin
    CloseResources;
    if FState <> gsError then SetState(gsInactive);
  end;
end;

procedure TGdbSession.Stop;
var S: RawByteString;
begin
  if not Active or FStopping then Exit;
  FStopping := True; FStopAt := GetTickCount64;
  FBreakpointEdit := beNone; FBreakpointResume := False;
  FBreakpointStopRecord := '';
  FQueue.Clear;
  S := '-gdb-exit' + #10;
  try FProcess.Input.WriteBuffer(S[1], Length(S)); except end;
end;

procedure TGdbSession.ContinueExecution;
begin
  if (FState <> gsStopped) or ChangingBreakpoint or FStopping then Exit;
  Queue('-exec-continue'); SendNext;
end;

procedure TGdbSession.StepInto;
begin
  if (FState <> gsStopped) or ChangingBreakpoint or FStopping then Exit;
  Queue('-exec-step'); SendNext;
end;

procedure TGdbSession.StepOver;
begin
  if (FState <> gsStopped) or ChangingBreakpoint or FStopping then Exit;
  Queue('-exec-next'); SendNext;
end;

procedure TGdbSession.Evaluate(const Expression: string);
begin
  if (FState <> gsStopped) or ChangingBreakpoint or FStopping or
    (Trim(Expression) = '') then Exit;
  Queue('-data-evaluate-expression ' + MIQuote(Expression), cpEvaluate); SendNext;
end;

procedure TGdbSession.SendInput(const Text: string);
var S: RawByteString; N: LongInt;
begin
  if (FMaster < 0) or not Active or (Text = '') then Exit;
  S := Text;
  N := fpWrite(FMaster, S[1], Length(S));
  if N <> Length(S) then
    if Assigned(FOnError) then FOnError(Self, 'Program input buffer is full; resend the remaining input.');
end;

procedure TGdbSession.RenameBreakpoints(const OldName, NewName: string);
var I, J: Integer; OldPath, NewPath: string; B, Other: TGdbBreakpoint;
begin
  if Active or (OldName = '') or (NewName = '') then Exit;
  OldPath := ExpandFileName(OldName);
  NewPath := ExpandFileName(NewName);
  { An exited process can still have unread replies referring to these objects.
    Release its pending commands before merging breakpoint records. }
  CloseResources;
  for I := 0 to FBreakpoints.Count - 1 do
  begin
    B := TGdbBreakpoint(FBreakpoints[I]);
    if B.FileName = OldPath then B.FileName := NewPath;
  end;
  for I := FBreakpoints.Count - 1 downto 0 do
  begin
    B := TGdbBreakpoint(FBreakpoints[I]);
    if B.FileName <> NewPath then Continue;
    for J := 0 to I - 1 do
    begin
      Other := TGdbBreakpoint(FBreakpoints[J]);
      if (Other.FileName = NewPath) and (Other.Line = B.Line) then
      begin
        FBreakpoints.Delete(I);
        Break;
      end;
    end;
  end;
end;

function TGdbSession.HasBreakpoint(const FileName: string; Line: Integer): Boolean;
var I: Integer; B: TGdbBreakpoint;
begin
  for I := 0 to FBreakpoints.Count - 1 do
  begin
    B := TGdbBreakpoint(FBreakpoints[I]);
    if (B.FileName = ExpandFileName(FileName)) and (B.Line = Line) then Exit(True);
  end;
  Result := False;
end;

procedure TGdbSession.ToggleBreakpoint(const FileName: string; Line: Integer);
begin
  if FStopping then Exit;
  if (FileName = '') or (Line < 1) then Exit;
  if Active and not (FState in [gsStopped, gsRunning]) then
    raise Exception.Create('Pause at a breakpoint before changing breakpoints.');
  if Assigned(FPending) or (FQueue.Count > 0) or (FBreakpointEdit <> beNone) then
    raise Exception.Create('Wait for the pending debugger command.');
  if Active and (FState = gsRunning) then
  begin
    { Native Linux GDB 9 cannot reliably patch code while a thread is running.
      Interrupt asynchronously, wait for its actual stop, make one edit, then
      resume only if the stop was ours. The public state stays running during
      that short internal pause, avoiding editor jumps and false step controls. }
    FBreakpointFile := ExpandFileName(FileName); FBreakpointLine := Line;
    FBreakpointEdit := beWaitingStop; FBreakpointResume := False;
    FBreakpointStopRecord := ''; FBreakpointStarted := GetTickCount64;
    Queue('-exec-interrupt --all', cpBreakpointInterrupt);
    SendNext;
    Exit;
  end;
  ApplyBreakpointToggle(FileName, Line);
  SendNext;
end;

procedure TGdbSession.ApplyBreakpointToggle(const FileName: string; Line: Integer);
var I: Integer; B: TGdbBreakpoint;
begin
  for I := 0 to FBreakpoints.Count - 1 do
  begin
    B := TGdbBreakpoint(FBreakpoints[I]);
    if (B.FileName = ExpandFileName(FileName)) and (B.Line = Line) then
    begin
      FBreakpointOldNumber := B.Number;
      if Active and (B.Number <> '') then Queue('-break-delete ' + B.Number, cpBreakpointDelete);
      FBreakpoints.Delete(I); Exit;
    end;
  end;
  B := TGdbBreakpoint.Create;
  B.FileName := ExpandFileName(FileName); B.Line := Line;
  FBreakpoints.Add(B);
  if Active then Queue('-break-insert ' + MIQuote(B.FileName + ':' + IntToStr(Line)), cpBreakpoint, B);
end;

end.
