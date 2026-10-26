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
    FStatus: TLabel;
    FContinue, FInto, FOver, FStop, FEvaluate, FSend: TButton;
    FControls, FCommandBar: TPanel;
    FPages: TPageControl;
    FProgramTab, FLogTab: TTabSheet;
    FValues: TListView;
    FSidebar: TTreeView;
    FPendingExpression: string;
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
    procedure ValueDoubleClick(Sender: TObject);
    procedure SidebarDoubleClick(Sender: TObject);
    procedure LayoutControls(Sender: TObject);
    procedure Append(Memo: TMemo; const AText: string);
    procedure RefreshSidebar;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AttachSidebar(ParentControl: TWinControl);
    procedure RefreshBreakpoints;
    procedure BeginSession;
    procedure FocusExpression;
    property Session: TGdbSession read FSession;
    property OnStateChange: TNotifyEvent read FOnStateChange write FOnStateChange;
  end;

implementation

uses LCLType, Graphics, Math, ui_language;

constructor TDebuggerPanel.Create(AOwner: TComponent);
var InputBar, EvalBar: TPanel; Splitter: TSplitter;
  Column: TListColumn;

  function Button(ParentControl: TWinControl; const ACaption, AHint: string;
    Handler: TNotifyEvent): TButton;
  begin
    Result := TButton.Create(Self);
    Result.Parent := ParentControl;
    Result.Caption := Tr(ACaption);
    Result.Hint := Tr(AHint);
    Result.ShowHint := True;
    Result.OnClick := Handler;
  end;

  procedure SetOutputFont(Memo: TMemo);
  begin
    Memo.Font.Name := 'DejaVu Sans Mono';
    Memo.Font.Size := 9;
    Memo.ReadOnly := True;
    Memo.ScrollBars := ssAutoBoth;
    Memo.WordWrap := False;
  end;

begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  Font.Size := 9;
  FSession := TGdbSession.Create;
  FSession.OnLog := @LogText;
  FSession.OnOutput := @ProgramText;
  FSession.OnError := @ErrorText;
  FSession.OnEvaluation := @EvaluationText;
  FSession.OnState := @StateChange;

  { Dev-C++ 5.11 keeps debugger commands and evaluation on the left of its
    bottom Debugging sheet, with debugger output to the right. Keep that
    structure while giving the native program terminal a separate page. }
  FControls := TPanel.Create(Self);
  FControls.Parent := Self;
  FControls.Align := alLeft;
  FControls.BevelOuter := bvNone;
  FControls.Width := 390;
  FControls.BorderWidth := 3;
  FCommandBar := TPanel.Create(Self);
  FCommandBar.Parent := FControls;
  FCommandBar.Align := alTop;
  FCommandBar.Height := 30;
  FCommandBar.BevelOuter := bvNone;
  FContinue := Button(FCommandBar, 'Continue', 'Continue execution', @ContinueClick);
  FOver := Button(FCommandBar, 'Step over', 'Next line (F7)', @OverClick);
  FInto := Button(FCommandBar, 'Step into', 'Step into (F8)', @IntoClick);
  FStop := Button(FCommandBar, 'Stop', 'Stop debugging (F6)', @StopClick);
  FStatus := TLabel.Create(Self);
  FStatus.Parent := FControls;
  FStatus.Align := alBottom;
  FStatus.Height := 20;
  FStatus.AutoSize := False;
  FStatus.Layout := tlCenter;
  FStatus.ShowHint := True;

  EvalBar := TPanel.Create(Self);
  EvalBar.Parent := FControls;
  EvalBar.Align := alTop;
  EvalBar.Height := 30;
  EvalBar.BevelOuter := bvNone;
  FEvaluate := Button(EvalBar, 'Evaluate expression',
    'Expression evaluated in the current stack frame', @EvaluateClick);
  FEvaluate.Align := alRight;
  FEvaluate.Width := 142;
  FEvaluate.BorderSpacing.Left := 4;
  FExpression := TEdit.Create(Self);
  FExpression.Parent := EvalBar;
  FExpression.Align := alClient;
  FExpression.BorderSpacing.Top := 2;
  FExpression.BorderSpacing.Bottom := 3;
  FExpression.OnKeyDown := @ExpressionKey;
  FExpression.Hint := Tr('Expression evaluated in the current stack frame');
  FExpression.ShowHint := True;
  FValues := TListView.Create(Self);
  FValues.Parent := FControls;
  FValues.Align := alClient;
  FValues.ViewStyle := vsReport;
  FValues.ReadOnly := True;
  FValues.RowSelect := True;
  FValues.HideSelection := False;
  FValues.OnDblClick := @ValueDoubleClick;
  Column := FValues.Columns.Add;
  Column.Caption := Tr('Expression');
  Column.Width := 150;
  Column := FValues.Columns.Add;
  Column.Caption := Tr('Value');
  Column.Width := 220;

  Splitter := TSplitter.Create(Self);
  Splitter.Parent := Self;
  Splitter.Align := alLeft;
  Splitter.Width := 4;
  Splitter.MinSize := 220;
  FPages := TPageControl.Create(Self);
  FPages.Parent := Self;
  FPages.Align := alClient;
  FProgramTab := TTabSheet.Create(Self);
  FProgramTab.PageControl := FPages;
  FProgramTab.Caption := Tr('Program input/output');
  InputBar := TPanel.Create(Self);
  InputBar.Parent := FProgramTab;
  InputBar.Align := alBottom;
  InputBar.Height := 30;
  InputBar.BevelOuter := bvNone;
  InputBar.BorderWidth := 2;
  FSend := Button(InputBar, 'Send input', 'Send input to the program', @SendClick);
  FSend.Align := alRight;
  FSend.Width := 100;
  FSend.BorderSpacing.Left := 4;
  FInput := TEdit.Create(Self);
  FInput.Parent := InputBar;
  FInput.Align := alClient;
  FInput.OnKeyDown := @InputKey;
  FInput.Hint := Tr('Program input');
  FInput.ShowHint := True;
  FTerminal := TMemo.Create(Self);
  FTerminal.Parent := FProgramTab;
  FTerminal.Align := alClient;
  SetOutputFont(FTerminal);
  FLogTab := TTabSheet.Create(Self);
  FLogTab.PageControl := FPages;
  FLogTab.Caption := Tr('Debugger log');
  FLog := TMemo.Create(Self);
  FLog.Parent := FLogTab;
  FLog.Align := alClient;
  SetOutputFont(FLog);
  FPages.ActivePage := FProgramTab;
  OnResize := @LayoutControls;
  FControls.OnResize := @LayoutControls;
  LayoutControls(Self);
  StateChange(Self);
end;

destructor TDebuggerPanel.Destroy;
begin
  FSession.OnState := nil;
  FSession.OnLocation := nil;
  FSession.Free;
  inherited Destroy;
end;

procedure TDebuggerPanel.AttachSidebar(ParentControl: TWinControl);
begin
  if FSidebar = nil then
  begin
    FSidebar := TTreeView.Create(Self);
    FSidebar.Align := alClient;
    FSidebar.ReadOnly := True;
    FSidebar.BorderStyle := bsNone;
    FSidebar.ShowRoot := True;
    FSidebar.OnDblClick := @SidebarDoubleClick;
    FSidebar.ShowHint := True;
    FSidebar.Hint := Tr('Evaluated expressions are snapshots of the selected stack frame.');
  end;
  FSidebar.Parent := ParentControl;
  RefreshSidebar;
end;

procedure TDebuggerPanel.LayoutControls(Sender: TObject);
var AvailableWidth, ButtonWidth, I, Columns: Integer;
  Buttons: array[0..3] of TButton;
begin
  if FValues = nil then Exit;
  { The splitter remains usable. On a narrower window, wrap the command
    buttons into two rows instead of clipping their captions. }
  if Sender = Self then
    FControls.Width := Max(240, Min(410, ClientWidth div 2));
  AvailableWidth := Max(1, FCommandBar.ClientWidth - 8);
  Columns := 4;
  if AvailableWidth < 320 then Columns := 2;
  ButtonWidth := (AvailableWidth - (Columns - 1) * 3) div Columns;
  Buttons[0] := FContinue;
  Buttons[1] := FOver;
  Buttons[2] := FInto;
  Buttons[3] := FStop;
  FCommandBar.Height := (4 div Columns) * 28 + 2;
  for I := 0 to 3 do
    Buttons[I].SetBounds(2 + (I mod Columns) * (ButtonWidth + 3),
      1 + (I div Columns) * 28, ButtonWidth, 26);
  FValues.Columns[0].Width := Max(90, FValues.ClientWidth div 2 - 4);
  FValues.Columns[1].Width := Max(90, FValues.ClientWidth div 2 - 4);
end;

procedure TDebuggerPanel.Append(Memo: TMemo; const AText: string);
var S: string;
begin
  S := Memo.Text + AText;
  if Length(S) > 131072 then S := Copy(S, Length(S) - 98303, 98304);
  Memo.Text := S;
  Memo.SelStart := Length(S);
end;

procedure TDebuggerPanel.LogText(Sender: TObject; const AText: string);
begin Append(FLog, AText); end;

procedure TDebuggerPanel.ProgramText(Sender: TObject; const AText: string);
begin Append(FTerminal, AText); end;

procedure TDebuggerPanel.ErrorText(Sender: TObject; const AText: string);
begin
  Append(FLog, Tr('Debugger error: ') + AText + LineEnding);
  FStatus.Caption := Tr('Debugger error: ') + AText;
  FStatus.Hint := FStatus.Caption;
  FPages.ActivePage := FLogTab;
  if FPendingExpression <> '' then
  begin
    FPendingExpression := '';
    FEvaluate.Enabled := FSession.State = gsStopped;
  end;
end;

procedure TDebuggerPanel.EvaluationText(Sender: TObject; const AText: string);
var I: Integer; Item: TListItem; ExpressionText: string;
begin
  ExpressionText := FPendingExpression;
  FPendingExpression := '';
  if ExpressionText = '' then Exit;
  Append(FLog, ExpressionText + ' = ' + AText + LineEnding);
  Item := nil;
  for I := 0 to FValues.Items.Count - 1 do
    if FValues.Items[I].Caption = ExpressionText then
    begin Item := FValues.Items[I]; Break; end;
  if Item = nil then
  begin
    if FValues.Items.Count >= 64 then FValues.Items.Delete(0);
    Item := FValues.Items.Add;
    Item.Caption := ExpressionText;
    Item.SubItems.Add(AText);
  end
  else Item.SubItems[0] := AText;
  FStatus.Caption := ExpressionText + ' = ' + AText;
  FStatus.Hint := FStatus.Caption;
  FEvaluate.Enabled := FSession.State = gsStopped;
  RefreshSidebar;
end;

procedure TDebuggerPanel.StateChange(Sender: TObject);
const StateNames: array[TGdbState] of string =
  ('Debugger inactive', 'Debugger starting', 'Program running', 'Program paused',
   'Program exited', 'Debugger error');
var Paused: Boolean;
begin
  Paused := (FSession.State = gsStopped) and not FSession.ChangingBreakpoint;
  if not FSession.Active then FPendingExpression := '';
  FContinue.Enabled := Paused;
  FInto.Enabled := Paused;
  FOver.Enabled := Paused;
  FEvaluate.Enabled := Paused and (FPendingExpression = '');
  FStop.Enabled := FSession.Active;
  FSend.Enabled := FSession.Active;
  FInput.Enabled := FSession.Active;
  FStatus.Caption := Tr(StateNames[FSession.State]);
  FStatus.Hint := FStatus.Caption;
  RefreshSidebar;
  if Assigned(FOnStateChange) then FOnStateChange(Self);
end;

procedure TDebuggerPanel.RefreshSidebar;
var I: Integer; Root, Entry: TTreeNode; B: TGdbBreakpoint;
begin
  if FSidebar = nil then Exit;
  FSidebar.Items.BeginUpdate;
  try
    FSidebar.Items.Clear;
    Root := FSidebar.Items.Add(nil, Tr('Evaluated expressions'));
    for I := 0 to FValues.Items.Count - 1 do
      FSidebar.Items.AddChild(Root, FValues.Items[I].Caption + ' = ' +
        FValues.Items[I].SubItems[0]);
    Root.Expand(False);
    Root := FSidebar.Items.Add(nil, Tr('Breakpoints'));
    for I := 0 to FSession.Breakpoints.Count - 1 do
    begin
      B := TGdbBreakpoint(FSession.Breakpoints[I]);
      Entry := FSidebar.Items.AddChild(Root,
        ExtractFileName(B.FileName) + ':' + IntToStr(B.Line));
      Entry.Data := B;
    end;
    Root.Expand(False);
  finally FSidebar.Items.EndUpdate; end;
end;

procedure TDebuggerPanel.RefreshBreakpoints;
begin RefreshSidebar; end;

procedure TDebuggerPanel.BeginSession;
begin
  FPendingExpression := '';
  FTerminal.Clear;
  FLog.Clear;
  FValues.Items.Clear;
  FInput.Clear;
  FPages.ActivePage := FProgramTab;
  RefreshSidebar;
end;

procedure TDebuggerPanel.FocusExpression;
begin
  if Parent is TTabSheet then
    if TTabSheet(Parent).PageControl <> nil then
      TTabSheet(Parent).PageControl.ActivePage := TTabSheet(Parent);
  if FExpression.CanFocus then
  begin
    FExpression.SetFocus;
    FExpression.SelectAll;
  end;
end;

procedure TDebuggerPanel.ValueDoubleClick(Sender: TObject);
begin
  if FValues.Selected = nil then Exit;
  FExpression.Text := FValues.Selected.Caption;
  FocusExpression;
end;

procedure TDebuggerPanel.SidebarDoubleClick(Sender: TObject);
var Node: TTreeNode;
begin
  Node := FSidebar.Selected;
  if (Node = nil) or (Node.Parent = nil) or
    (Node.Parent.Index <> 0) or (Node.Index >= FValues.Items.Count) then Exit;
  FExpression.Text := FValues.Items[Node.Index].Caption;
  FocusExpression;
end;

procedure TDebuggerPanel.ContinueClick(Sender: TObject);
begin FSession.ContinueExecution; end;
procedure TDebuggerPanel.IntoClick(Sender: TObject);
begin FSession.StepInto; end;
procedure TDebuggerPanel.OverClick(Sender: TObject);
begin FSession.StepOver; end;
procedure TDebuggerPanel.StopClick(Sender: TObject);
begin FSession.Stop; end;
procedure TDebuggerPanel.EvaluateClick(Sender: TObject);
begin
  if (FSession.State <> gsStopped) or FSession.ChangingBreakpoint or
    (FPendingExpression <> '') or
    (Trim(FExpression.Text) = '') then Exit;
  FPendingExpression := Trim(FExpression.Text);
  FEvaluate.Enabled := False;
  FSession.Evaluate(FPendingExpression);
end;
procedure TDebuggerPanel.SendClick(Sender: TObject);
begin FSession.SendInput(FInput.Text + #10); FInput.Clear; end;
procedure TDebuggerPanel.InputKey(Sender: TObject; var Key: Word; Shift: TShiftState);
begin if Key = VK_RETURN then begin SendClick(Self); Key := 0; end; end;
procedure TDebuggerPanel.ExpressionKey(Sender: TObject; var Key: Word; Shift: TShiftState);
begin if Key = VK_RETURN then begin EvaluateClick(Self); Key := 0; end; end;

end.
