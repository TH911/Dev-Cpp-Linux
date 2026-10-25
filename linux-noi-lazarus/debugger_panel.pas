unit debugger_panel;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls,
  gdb_session;

type
  TDebuggerPanel = class(TPanel)
  private
    FSession: TGdbSession;
    FTerminal, FLog: TMemo;
    FInput, FExpression: TEdit;
    FBreakpoints: TListBox;
    FStatus: TLabel;
    FContinue, FInto, FOver, FStop, FEvaluate, FSend: TButton;
    FOnStateChange: TNotifyEvent;
    procedure LogText(Sender: TObject; const AText: string);
    procedure ProgramText(Sender: TObject; const AText: string);
    procedure ErrorText(Sender: TObject; const AText: string);
    procedure EvaluationText(Sender: TObject; const AText: string);
    procedure StateChange(Sender: TObject);
    procedure ContinueClick(Sender: TObject);
    procedure IntoClick(Sender: TObject);
    procedure OverClick(Sender: TObject);
    procedure StopClick(Sender: TObject);
    procedure EvaluateClick(Sender: TObject);
    procedure SendClick(Sender: TObject);
    procedure InputKey(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ExpressionKey(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure Append(Memo: TMemo; const AText: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure RefreshBreakpoints;
    procedure BeginSession;
    procedure FocusExpression;
    property Session: TGdbSession read FSession;
    property OnStateChange: TNotifyEvent read FOnStateChange write FOnStateChange;
  end;

implementation

uses LCLType, Graphics, ui_language;

constructor TDebuggerPanel.Create(AOwner: TComponent);
var Bar, InputBar, EvalBar: TPanel; Pages: TPageControl; Tab: TTabSheet;
  Splitter: TSplitter;

  function Button(ParentControl: TWinControl; const ACaption: string;
    Handler: TNotifyEvent; AWidth: Integer): TButton;
  begin
    Result := TButton.Create(Self); Result.Parent := ParentControl;
    Result.Caption := Tr(ACaption); Result.Align := alLeft;
    Result.Width := AWidth; Result.OnClick := Handler;
    Result.Left := 10000;
  end;

begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  FSession := TGdbSession.Create;
  FSession.OnLog := @LogText; FSession.OnOutput := @ProgramText;
  FSession.OnError := @ErrorText; FSession.OnEvaluation := @EvaluationText;
  FSession.OnState := @StateChange;
  Bar := TPanel.Create(Self); Bar.Parent := Self; Bar.Align := alTop;
  Bar.Height := 32; Bar.BevelOuter := bvNone;
  FContinue := Button(Bar, 'Continue', @ContinueClick, 90);
  FInto := Button(Bar, 'Step into', @IntoClick, 90);
  FOver := Button(Bar, 'Step over', @OverClick, 90);
  FStop := Button(Bar, 'Stop', @StopClick, 70);
  FStatus := TLabel.Create(Self); FStatus.Parent := Bar;
  FStatus.Align := alClient; FStatus.Layout := tlCenter;
  EvalBar := TPanel.Create(Self); EvalBar.Parent := Self; EvalBar.Align := alBottom;
  EvalBar.Height := 30; EvalBar.BevelOuter := bvNone;
  FEvaluate := Button(EvalBar, 'Evaluate expression', @EvaluateClick, 155);
  FExpression := TEdit.Create(Self); FExpression.Parent := EvalBar;
  FExpression.Align := alClient; FExpression.OnKeyDown := @ExpressionKey;
  FExpression.Hint := Tr('Expression evaluated in the current stack frame');
  FExpression.ShowHint := True;
  FBreakpoints := TListBox.Create(Self); FBreakpoints.Parent := Self;
  FBreakpoints.Align := alLeft; FBreakpoints.Width := 225;
  Splitter := TSplitter.Create(Self); Splitter.Parent := Self; Splitter.Align := alLeft;
  Pages := TPageControl.Create(Self); Pages.Parent := Self; Pages.Align := alClient;
  Tab := TTabSheet.Create(Self); Tab.PageControl := Pages; Tab.Caption := Tr('Program input/output');
  InputBar := TPanel.Create(Self); InputBar.Parent := Tab;
  InputBar.Align := alBottom; InputBar.Height := 30; InputBar.BevelOuter := bvNone;
  FSend := Button(InputBar, 'Send input', @SendClick, 110);
  FInput := TEdit.Create(Self); FInput.Parent := InputBar;
  FInput.Align := alClient; FInput.OnKeyDown := @InputKey;
  FTerminal := TMemo.Create(Self); FTerminal.Parent := Tab;
  FTerminal.Align := alClient; FTerminal.ReadOnly := True;
  FTerminal.ScrollBars := ssAutoBoth; FTerminal.WordWrap := False;
  Tab := TTabSheet.Create(Self); Tab.PageControl := Pages; Tab.Caption := Tr('Debugger log');
  FLog := TMemo.Create(Self); FLog.Parent := Tab; FLog.Align := alClient;
  FLog.ReadOnly := True; FLog.ScrollBars := ssAutoBoth; FLog.WordWrap := False;
  StateChange(Self);
end;

destructor TDebuggerPanel.Destroy;
begin
  FSession.OnState := nil; FSession.OnLocation := nil;
  FSession.Free;
  inherited Destroy;
end;

procedure TDebuggerPanel.Append(Memo: TMemo; const AText: string);
var S: string;
begin
  { Bound the visible history independently from the per-tick pipe read limit. }
  S := Memo.Text + AText;
  if Length(S) > 131072 then S := Copy(S, Length(S) - 98303, 98304);
  Memo.Text := S; Memo.SelStart := Length(S);
end;

procedure TDebuggerPanel.LogText(Sender: TObject; const AText: string);
begin Append(FLog, AText); end;

procedure TDebuggerPanel.ProgramText(Sender: TObject; const AText: string);
begin Append(FTerminal, AText); end;

procedure TDebuggerPanel.ErrorText(Sender: TObject; const AText: string);
begin Append(FLog, Tr('Debugger error: ') + AText + LineEnding); end;

procedure TDebuggerPanel.EvaluationText(Sender: TObject; const AText: string);
begin Append(FLog, FExpression.Text + ' = ' + AText + LineEnding);
  FExpression.Hint := AText; FStatus.Caption := FExpression.Text + ' = ' + AText;
end;

procedure TDebuggerPanel.StateChange(Sender: TObject);
const StateNames: array[TGdbState] of string =
  ('Debugger inactive', 'Debugger starting', 'Program running', 'Program paused',
   'Program exited', 'Debugger error');
var Paused: Boolean;
begin
  Paused := FSession.State = gsStopped;
  FContinue.Enabled := Paused; FInto.Enabled := Paused; FOver.Enabled := Paused;
  FEvaluate.Enabled := Paused; FStop.Enabled := FSession.Active;
  FSend.Enabled := FSession.Active;
  FStatus.Caption := Tr(StateNames[FSession.State]);
  if Assigned(FOnStateChange) then FOnStateChange(Self);
end;

procedure TDebuggerPanel.RefreshBreakpoints;
var I: Integer; B: TGdbBreakpoint;
begin
  FBreakpoints.Items.BeginUpdate;
  try
    FBreakpoints.Items.Clear;
    for I := 0 to FSession.Breakpoints.Count - 1 do
    begin
      B := TGdbBreakpoint(FSession.Breakpoints[I]);
      FBreakpoints.Items.Add(ExtractFileName(B.FileName) + ':' + IntToStr(B.Line));
    end;
  finally FBreakpoints.Items.EndUpdate; end;
end;

procedure TDebuggerPanel.BeginSession;
begin FTerminal.Clear; FLog.Clear; end;

procedure TDebuggerPanel.FocusExpression;
begin FExpression.SetFocus; FExpression.SelectAll; end;

procedure TDebuggerPanel.ContinueClick(Sender: TObject);
begin FSession.ContinueExecution; end;
procedure TDebuggerPanel.IntoClick(Sender: TObject);
begin FSession.StepInto; end;
procedure TDebuggerPanel.OverClick(Sender: TObject);
begin FSession.StepOver; end;
procedure TDebuggerPanel.StopClick(Sender: TObject);
begin FSession.Stop; end;
procedure TDebuggerPanel.EvaluateClick(Sender: TObject);
begin FSession.Evaluate(FExpression.Text); end;
procedure TDebuggerPanel.SendClick(Sender: TObject);
begin FSession.SendInput(FInput.Text + #10); FInput.Clear; end;
procedure TDebuggerPanel.InputKey(Sender: TObject; var Key: Word; Shift: TShiftState);
begin if Key = VK_RETURN then begin SendClick(Self); Key := 0; end; end;
procedure TDebuggerPanel.ExpressionKey(Sender: TObject; var Key: Word; Shift: TShiftState);
begin if Key = VK_RETURN then begin EvaluateClick(Self); Key := 0; end; end;

end.
