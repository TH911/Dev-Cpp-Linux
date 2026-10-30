unit debugger_panel;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls,
  gdb_session,ImgList;

type
  TDebuggerPanel = class(TPanel)
  private
    FSession: TGdbSession;
    FTerminal, FLog: TMemo;
    FInput: TEdit;
    FExpression, FCommand: TComboBox;
    FStart, FAddWatch, FCPU, FOut, FNextIns, FStepIns: TButton;
    FCPUWindow: TForm;
    FCPUMemo: TMemo;
    FWatched, FWatchQueue, FLocals: TStringList;
    procedure VariablesText(Sender:TObject;const AText:string);
  private
    FCanStart: Boolean;
    FOnStartRequested: TNotifyEvent;
    FStatus: TLabel;
    FContinue, FInto, FOver, FStop: TButton;
    FControls, FCommandBar, FConsoleBar: TPanel;
    FPages: TPageControl;
    FProgramTab, FLogTab: TTabSheet;
    FValues: TListView;
    FSidebar: TTreeView;
    FSidebarNames:TStringList;
    FWatchImages:TImageList;
    procedure DrawWatchItem(Sender:TCustomTreeView;Node:TTreeNode;State:TCustomDrawState;
      Stage:TCustomDrawStage;var PaintImages,DefaultDraw:Boolean);
  private
    FPendingExpression: string;
    FOnStateChange: TNotifyEvent;
    procedure LogText(Sender: TObject; const AText: string);
    procedure ProgramText(Sender: TObject; const AText: string);
    procedure ErrorText(Sender: TObject; const AText: string);
    procedure EvaluationText(Sender: TObject; const AText: string);
    procedure StateChange(Sender: TObject);
    procedure StartClick(Sender: TObject);
    procedure AddWatchClick(Sender: TObject);
    procedure CPUClick(Sender: TObject);
    procedure OutClick(Sender: TObject);
    procedure NextInstructionClick(Sender: TObject);
    procedure StepInstructionClick(Sender: TObject);
    procedure CommandKey(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure NextWatch;
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
    procedure AddWatch(const Expression:string);
    procedure BeginSession;
    procedure FocusExpression;
    procedure SetCanStart(Value: Boolean);
    property OnStartRequested: TNotifyEvent read FOnStartRequested write FOnStartRequested;
    property Session: TGdbSession read FSession;
    property OnStateChange: TNotifyEvent read FOnStateChange write FOnStateChange;
  end;

implementation

uses LCLType, Graphics, Math, ui_language, editor_themes, input_appearance;

constructor TDebuggerPanel.Create(AOwner: TComponent);
var InputBar, EvalBar: TPanel; Splitter: TSplitter;
  Column: TListColumn;
  EvaluateLabel: TLabel; RightPanel:TPanel;

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
    Memo.Font.Name := DefaultEditorFontName;
    Memo.Font.Size := 9;
    Memo.ReadOnly := True;
    Memo.ScrollBars := ssAutoBoth;
    Memo.WordWrap := False;
  end;

begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  Font.Size := 9;
  FLocals:=TStringList.Create;FLocals.NameValueSeparator:=#1;
  FSidebarNames:=TStringList.Create;FSidebarNames.CaseSensitive:=True;
  FWatched:=TStringList.Create;FWatchQueue:=TStringList.Create;FWatched.CaseSensitive:=True;FWatchQueue.CaseSensitive:=True;
  FSession := TGdbSession.Create;
  FSession.OnLog := @LogText;
  FSession.OnOutput := @ProgramText;
  FSession.OnError := @ErrorText;
  FSession.OnEvaluation := @EvaluationText;
  FSession.OnVariables := @VariablesText;
  FSession.OnState := @StateChange;

  { dev-cpp 5.11 keeps debugger commands and evaluation on the left of its
    bottom Debugging sheet, with debugger output to the right. Keep that
    structure while giving the native program terminal a separate page. }
  FControls := TPanel.Create(Self);
  FControls.Parent := Self;
  FControls.Align := alLeft;
  FControls.BevelOuter := bvNone;
  FControls.Width := 586;
  FControls.BorderWidth := 3;
  FCommandBar := TPanel.Create(Self);
  FCommandBar.Parent := FControls;
  FCommandBar.Align := alTop;
  FCommandBar.Height := 58;
  FCommandBar.BevelOuter := bvNone;
  FStart:=Button(FCommandBar,'Debug','Start or continue debugging',@StartClick);
  FAddWatch:=Button(FCommandBar,'Add watch','Add a watched expression',@AddWatchClick);
  FCPU:=Button(FCommandBar,'View CPU window','Registers and machine instructions',@CPUClick);
  FOut:=Button(FCommandBar,'Skip function','Run until the current function returns',@OutClick);
  FNextIns:=Button(FCommandBar,'Next instruction','Step over one machine instruction',@NextInstructionClick);
  FStepIns:=Button(FCommandBar,'Into instruction','Step into one machine instruction',@StepInstructionClick);
  FContinue := Button(FCommandBar, 'Continue', 'Continue execution', @ContinueClick);
  FOver := Button(FCommandBar, 'Next line', 'Next line (F7)', @OverClick);
  FInto := Button(FCommandBar, 'Into line', 'Step into (F8)', @IntoClick);
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
  EvaluateLabel := TLabel.Create(Self);
  EvaluateLabel.Parent := EvalBar;
  EvaluateLabel.AutoSize := False;
  EvaluateLabel.Align := alLeft;
  EvaluateLabel.Width := 64;
  EvaluateLabel.Layout := tlCenter;
  EvaluateLabel.Caption := Tr('Evaluate:');
  FExpression := TComboBox.Create(Self);
  FExpression.Parent := EvalBar;
  FExpression.Align := alClient;
  FExpression.BorderSpacing.Top := 2;
  FExpression.BorderSpacing.Bottom := 3;
  FExpression.OnKeyDown := @ExpressionKey;
  FExpression.Hint := Tr('Press Enter to evaluate the expression in the current stack frame.');
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
  RightPanel:=TPanel.Create(Self);RightPanel.Parent:=Self;RightPanel.Align:=alClient;RightPanel.BevelOuter:=bvNone;
  FConsoleBar:=TPanel.Create(Self);FConsoleBar.Parent:=RightPanel;FConsoleBar.Align:=alTop;FConsoleBar.Height:=28;FConsoleBar.BevelOuter:=bvNone;
  EvaluateLabel:=TLabel.Create(Self);EvaluateLabel.Parent:=FConsoleBar;EvaluateLabel.Align:=alLeft;
  EvaluateLabel.AutoSize:=False;EvaluateLabel.Width:=150;EvaluateLabel.Layout:=tlCenter;EvaluateLabel.Caption:=Tr('Send command to GDB:');
  FCommand:=TComboBox.Create(Self);FCommand.Parent:=FConsoleBar;FCommand.Align:=alClient;FCommand.OnKeyDown:=@CommandKey;
  FPages := TPageControl.Create(Self);
  FPages.Parent := RightPanel;
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
  FInput := TEdit.Create(Self);
  FInput.Parent := InputBar;
  FInput.Align := alClient;
  FInput.OnKeyDown := @InputKey;
  FInput.Hint := Tr('Press Enter to send input to the program.');
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
  FPages.ActivePage := FLogTab;
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
  FLocals.Free;FWatchQueue.Free;FWatched.Free;FSidebarNames.Free;
  inherited Destroy;
end;

procedure TDebuggerPanel.AttachSidebar(ParentControl: TWinControl);
var Bitmap:TBitmap;FileName:string;
begin
  if FSidebar = nil then
  begin
    FSidebar := TTreeView.Create(Self);
    FSidebar.Align := alClient;
    FSidebar.ReadOnly := True;
    FSidebar.BorderStyle := bsNone;
    FSidebar.Name:='DebugWatchView';FSidebar.Color:=clWhite;FSidebar.Indent:=19;
    FSidebar.ScrollBars:=ssAutoBoth;
    FSidebar.Options:=FSidebar.Options-[tvoThemedDraw];
    FSidebar.ShowRoot := True;
    FSidebar.ShowLines:=False;FSidebar.RightClickSelect:=True;
    FSidebar.OnDblClick := @SidebarDoubleClick;
    FSidebar.OnAdvancedCustomDrawItem:=@DrawWatchItem;
    FSidebar.ShowHint := True;
    FSidebar.Hint := Tr('Evaluated expressions are snapshots of the selected stack frame.');
    FWatchImages:=TImageList.Create(Self);FWatchImages.Width:=16;FWatchImages.Height:=16;
    Bitmap:=TBitmap.Create;
    try
      FileName:=ExtractFilePath(ParamStr(0))+'icons/search.bmp';
      if FileExists(FileName) then begin
        Bitmap.LoadFromFile(FileName);FWatchImages.AddMasked(Bitmap,clFuchsia);
      end;
    finally Bitmap.Free;end;
    FSidebar.Images:=FWatchImages;
  end;
  FSidebar.Parent := ParentControl;
  RefreshSidebar;
end;

procedure TDebuggerPanel.LayoutControls(Sender:TObject);
var I,ButtonWidth:Integer;Buttons:array[0..9] of TButton;S:string;Measure:TBitmap;
const Full:array[0..9] of string=('Debug','Add watch','Next line','Continue','Next instruction','Stop','View CPU window','Into line','Skip function','Into instruction');
  Short:array[0..9] of string=('Debug','Watch','Next','Continue','Next instr.','Stop','CPU','Into','Out','Into instr.');
begin
  if FValues=nil then Exit;
  if Sender=Self then FControls.Width:=Min(586,ClientWidth);
  ButtonWidth:=Max(50,(FCommandBar.ClientWidth-16) div 5);
  Buttons[0]:=FStart;Buttons[1]:=FAddWatch;Buttons[2]:=FOver;Buttons[3]:=FContinue;Buttons[4]:=FNextIns;
  Buttons[5]:=FStop;Buttons[6]:=FCPU;Buttons[7]:=FInto;Buttons[8]:=FOut;Buttons[9]:=FStepIns;
  Measure:=TBitmap.Create;
  try
  Measure.Canvas.Font.Assign(Font);
  for I:=0 to 9 do begin
    Buttons[I].SetBounds(2+(I mod 5)*(ButtonWidth+3),2+(I div 5)*28,ButtonWidth,25);
    S:=Tr(Full[I]);if Measure.Canvas.TextWidth(S)>ButtonWidth-10 then S:=Tr(Short[I]);
    Buttons[I].Caption:=S;
  end;
  finally Measure.Free; end;
  FCommandBar.Height:=58;
  FValues.Columns[0].Width:=Max(90,FValues.ClientWidth div 2-4);
  FValues.Columns[1].Width:=Max(90,FValues.ClientWidth div 2-4);
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
begin Append(FLog, AText);if (FCPUWindow<>nil) and FCPUWindow.Visible then Append(FCPUMemo,AText);end;

procedure TDebuggerPanel.ProgramText(Sender: TObject; const AText: string);
begin Append(FTerminal, AText); end;

procedure TDebuggerPanel.ErrorText(Sender: TObject; const AText: string);
var I: Integer;
begin
  Append(FLog, Tr('Debugger error: ') + AText + LineEnding);
  FStatus.Caption := Tr('Debugger error: ') + AText;
  FStatus.Hint := FStatus.Caption;
  FPages.ActivePage := FLogTab;
  if FPendingExpression <> '' then
  begin
    for I:=0 to FValues.Items.Count-1 do
      if FValues.Items[I].Caption=FPendingExpression then
        FValues.Items[I].SubItems[0]:=Tr('Unavailable');
    FPendingExpression := '';
    RefreshSidebar;
    NextWatch;
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
  RefreshSidebar;
  NextWatch;
end;

procedure TDebuggerPanel.StateChange(Sender: TObject);
const StateNames: array[TGdbState] of string =
  ('Debugger inactive', 'Debugger starting', 'Program running', 'Program paused',
   'Program exited', 'Debugger error');
var Paused: Boolean;
begin
  Paused := (FSession.State = gsStopped) and not FSession.ChangingBreakpoint;
  if not FSession.Active then FPendingExpression := '';
  FStart.Enabled := Paused or (FCanStart and not FSession.Active);
  FAddWatch.Enabled:=not FSession.ChangingBreakpoint;
  FCPU.Enabled:=Paused;FOut.Enabled:=Paused;FNextIns.Enabled:=Paused;FStepIns.Enabled:=Paused;
  FCommand.Enabled:=Paused;FExpression.Enabled:=True;
  FPages.ShowTabs:=FSession.Active;
  if not FSession.Active then FPages.ActivePage:=FLogTab;
  if not Paused then begin FWatchQueue.Clear;FLocals.Clear;end;
  FContinue.Enabled := Paused;
  FInto.Enabled := Paused;
  FOver.Enabled := Paused;
  FStop.Enabled := FSession.Active;
  FInput.Enabled := FSession.Active;
  FStatus.Caption := Tr(StateNames[FSession.State]);
  FStatus.Hint := FStatus.Caption;
  RefreshSidebar;
  if Assigned(FOnStateChange) then FOnStateChange(Self);
  if Paused then begin FSession.RequestVariables;FWatchQueue.Assign(FWatched);NextWatch;end;
end;

procedure TDebuggerPanel.RefreshSidebar;
var I,J:Integer;Value:string;Pending:Boolean;
  procedure Row(const Expression,AText:string;NotEvaluated:Boolean);
  var Node:TTreeNode;S:string;
  begin
    if FSidebarNames.IndexOf(Expression)>=0 then Exit;
    S:=AText;if NotEvaluated then S:='Execute to evaluate';
    Node:=FSidebar.Items.Add(nil,Expression+' = '+S);
    Node.Data:=Pointer(PtrInt(FSidebarNames.Count+1));
    Node.ImageIndex:=0;Node.SelectedIndex:=0;
    FSidebarNames.AddObject(Expression,TObject(PtrInt(Ord(NotEvaluated))));
  end;
begin
  if FSidebar = nil then Exit;
  FSidebar.Items.BeginUpdate;
  try
    FSidebar.Items.Clear;
    FSidebarNames.Clear;
    for I:=0 to FWatched.Count-1 do begin
      Value:='';Pending:=True;
      for J:=0 to FValues.Items.Count-1 do if FValues.Items[J].Caption=FWatched[I] then begin
        Value:=FValues.Items[J].SubItems[0];
        Pending:=not FSession.Active or (Value=Tr('Not evaluated')) or (Value=Tr('Unavailable'));Break;
      end;
      Row(FWatched[I],Value,Pending);
    end;
    for I:=0 to FValues.Items.Count-1 do begin
      Value:=FValues.Items[I].SubItems[0];
      Row(FValues.Items[I].Caption,Value,not FSession.Active or (Value=Tr('Unavailable')) or (Value=Tr('Not evaluated')));
    end;
  finally FSidebar.Items.EndUpdate; end;
end;

procedure TDebuggerPanel.DrawWatchItem(Sender:TCustomTreeView;Node:TTreeNode;
  State:TCustomDrawState;Stage:TCustomDrawStage;var PaintImages,DefaultDraw:Boolean);
var Index:Integer;
begin
  if Stage<>cdPrePaint then Exit;
  Index:=PtrInt(Node.Data)-1;
  if cdsSelected in State then Sender.Canvas.Font.Color:=clHighlightText
  else if (Index>=0) and (Index<FSidebarNames.Count) and (FSidebarNames.Objects[Index]<>nil) then
    Sender.Canvas.Font.Color:=clRed
  else Sender.Canvas.Font.Color:=clBlack;
end;

procedure TDebuggerPanel.VariablesText(Sender:TObject;const AText:string);
begin
  MIVariableRows(AText,FLocals);RefreshSidebar;
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
var Node: TTreeNode;Index:Integer;
begin
  Node := FSidebar.Selected;
  if Node=nil then Exit;
  Index:=PtrInt(Node.Data)-1;if (Index<0) or (Index>=FSidebarNames.Count) then Exit;
  FExpression.Text:=FSidebarNames[Index];
  FocusExpression;
end;

procedure TDebuggerPanel.SetCanStart(Value:Boolean);
begin FCanStart:=Value;FStart.Enabled:=((FSession.State=gsStopped) and not FSession.ChangingBreakpoint) or (Value and not FSession.Active);end;
procedure TDebuggerPanel.StartClick(Sender:TObject);
begin
  if FSession.State=gsStopped then FSession.ContinueExecution
  else if Assigned(FOnStartRequested) then FOnStartRequested(Self);
end;
procedure TDebuggerPanel.AddWatchClick(Sender:TObject);
var ExpressionText:string;
begin
  ExpressionText:=FExpression.Text;
  if not UiInputQuery(Tr('Add watch'),Tr('Expression'),ExpressionText) then Exit;
  AddWatch(ExpressionText);
end;
procedure TDebuggerPanel.AddWatch(const Expression:string);
var ExpressionText:string;Item:TListItem;I:Integer;
begin
  ExpressionText:=Expression;
  ExpressionText:=Trim(ExpressionText);if (ExpressionText='') or (FWatched.IndexOf(ExpressionText)>=0) or (FWatched.Count>=64) then Exit;
  FWatched.Add(ExpressionText);FExpression.Text:=ExpressionText;
  Item:=nil;for I:=0 to FValues.Items.Count-1 do if FValues.Items[I].Caption=ExpressionText then Item:=FValues.Items[I];
  if Item=nil then begin Item:=FValues.Items.Add;Item.Caption:=ExpressionText;Item.SubItems.Add(Tr('Not evaluated'));end;
  RefreshSidebar;EvaluateClick(Self);
end;
procedure TDebuggerPanel.NextWatch;
begin
  if (FPendingExpression<>'') or (FWatchQueue.Count=0) or (FSession.State<>gsStopped) or FSession.ChangingBreakpoint then Exit;
  FPendingExpression:=FWatchQueue[0];FWatchQueue.Delete(0);FSession.Evaluate(FPendingExpression);
end;
procedure TDebuggerPanel.OutClick(Sender:TObject);
begin FSession.StepOut;end;
procedure TDebuggerPanel.NextInstructionClick(Sender:TObject);
begin FSession.NextInstruction;end;
procedure TDebuggerPanel.StepInstructionClick(Sender:TObject);
begin FSession.StepInstruction;end;
procedure TDebuggerPanel.CPUClick(Sender:TObject);
begin
  if FSession.State<>gsStopped then Exit;
  if FCPUWindow=nil then begin
    FCPUWindow:=TForm.CreateNew(Self);FCPUWindow.Caption:=Tr('CPU');FCPUWindow.Position:=poMainFormCenter;
    FCPUWindow.SetBounds(100,100,760,460);FCPUMemo:=TMemo.Create(FCPUWindow);FCPUMemo.Parent:=FCPUWindow;FCPUMemo.Align:=alClient;
    FCPUMemo.ReadOnly:=True;FCPUMemo.ScrollBars:=ssAutoBoth;FCPUMemo.Font.Name:=DefaultEditorFontName;UseReadableInput(FCPUMemo);PrepareInputAppearance(FCPUWindow);
  end;
  FCPUMemo.Clear;FCPUWindow.Show;
  FSession.ConsoleCommand('info registers');FSession.ConsoleCommand('x/12i $pc');
end;
procedure TDebuggerPanel.CommandKey(Sender:TObject;var Key:Word;Shift:TShiftState);
begin
  if Key<>VK_RETURN then Exit;Key:=0;
  if Trim(FCommand.Text)='' then Exit;
  if FCommand.Items.IndexOf(FCommand.Text)<0 then FCommand.Items.Add(FCommand.Text);
  FPages.ActivePage:=FLogTab;FSession.ConsoleCommand(FCommand.Text);FCommand.Text:='';
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
  if FExpression.Items.IndexOf(FExpression.Text)<0 then FExpression.Items.Add(FExpression.Text);
  FPendingExpression := Trim(FExpression.Text);
  FSession.Evaluate(FPendingExpression);
end;
procedure TDebuggerPanel.SendClick(Sender: TObject);
begin FSession.SendInput(FInput.Text + #10); FInput.Clear; end;
procedure TDebuggerPanel.InputKey(Sender: TObject; var Key: Word; Shift: TShiftState);
begin if Key = VK_RETURN then begin SendClick(Self); Key := 0; end; end;
procedure TDebuggerPanel.ExpressionKey(Sender: TObject; var Key: Word; Shift: TShiftState);
begin if Key = VK_RETURN then begin EvaluateClick(Self); Key := 0; end; end;

end.
