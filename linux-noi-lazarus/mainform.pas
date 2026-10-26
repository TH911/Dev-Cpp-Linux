unit mainform;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StrUtils, Math, Types, Forms, Controls, StdCtrls, ComCtrls, ExtCtrls,
  Menus, Dialogs, IniFiles, Process, Contnrs, LCLType, Graphics, ImgList,
  LazUTF8, SynEdit, SynEditTypes, SynEditKeyCmds, SynEditHighlighter,
  SynHighlighterCpp, SynGutterLineNumber, SynGutterChanges, SynGutterMarks,
  SynEditMarks, SynGutter, editor_actions,
  cppcompletion, ui_language, app_instance, document_files, runtime_support,
  editor_themes, compiler_profiles, options_dialogs,
  gdb_session, debugger_panel, debug_icons, app_version, about_dialog;

type
  TNoiCppSyn = class(TSynCppSyn)
  private
    FCurrentLine: string;
    FBracketAttri, FCharacterAttri: TSynHighlighterAttributes;
  public
    constructor Create(AOwner: TComponent); override;
    property BracketAttri: TSynHighlighterAttributes read FBracketAttri;
    property CharacterAttri: TSynHighlighterAttributes read FCharacterAttri;
    procedure SetLine(const NewValue: string; LineNumber: Integer); override;
    function GetTokenAttribute: TSynHighlighterAttributes; override;
  end;

  TEditorLineClickEvent = procedure(Sender: TObject; Line: Integer) of object;

  TNoiSynEdit = class(TSynEdit)
  private
    FHomeRepeat: Boolean;
    FGutterPress: Boolean;
    FGutterPoint: TPoint;
    FGutterLine: Integer;
    FOnLineClick: TEditorLineClickEvent;
    function BreakpointLineAt(X, Y: Integer): Integer;
  protected
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
  public
    property OnLineClick: TEditorLineClickEvent read FOnLineClick write FOnLineClick;
    procedure ResetHomeCycle;
    procedure MoveHome(SelectText: Boolean);
    function FindMatchingBracketLogical(LogicalStartBracket: TPoint;
      StartIncludeNeighborChars, MoveCaret, SelectBrackets,
      OnlyVisible: Boolean): TPoint; override;
  end;

  TNoiDebugMark = class(TSynEditMark);

  TDocument = class
    Tab: TTabSheet;
    Editor: TSynEdit;
    Syntax: TNoiCppSyn;
    FileName: string;
    UntitledName: string;
    Dirty: Boolean;
    MissingNotified: Boolean;
    DiskSnapshot: TFileSnapshot;
    SeenDiskSnapshot: TFileSnapshot;
    KeepBufferConflict: Boolean;
    DebugReadOnlyApplied: Boolean;
    ReadOnlyBeforeDebug: Boolean;
    ErrorLine: Integer;
    ThemeColors: TEditorThemeColors;
    PreferredColumn: Integer;
  end;

  TMainForm = class(TForm)
  private
    FPages: TPageControl;
    FProjectTree: TTreeView;
    FLeftTabs: TPageControl;
    FLeftDebugTab: TTabSheet;
    FOutput: TMemo;
    FReportTabs: TPageControl;
    FCompilerTab: TTabSheet;
    FLogTab: TTabSheet;
    FCompilerList: TListView;
    FStatus: TStatusBar;
    FMainToolbar: TToolBar;
    FRecentFiles: TStringList;
    FRecentMenu: TMenuItem;
    FRecentMenuDirty: Boolean;
    FUiTimer: TTimer;
    FFullScreen: Boolean;
    FNormalBounds: TRect;
    FNormalWindowState: TWindowState;
    FNormalBorderStyle: TFormBorderStyle;
    FStatusbarItem, FFullScreenItem: TMenuItem;
    FDocs: TObjectList;
    FProjectFiles: TStringList;
    FProjectPath: string;
    FLastExecutable: string;
    FCompileDirectory: string;
    FInvalidExecutables: TStringList;
    FOptionsPath: string;
    FCCompiler: string;
    FCppCompiler: string;
    FCFlags: string;
    FCppFlags: string;
    FLinkerFlags: string;
    FLoading: Boolean;
    FFindText: string;
    FCompletionMemberName: string;
    FCompletionAfterMember: Boolean;
    FCompletionForm: TForm;
    FCompletionList: TListBox;
    FCompletionDoc: TDocument;
    FCompletionKinds: TStringList;
    FTipForm: TPanel;
    FTipPaint: TPaintBox;
    FTipSignatures: TStringList;
    FTipDoc: TDocument;
    FTipSignature: string;
    FTipParamIndex: Integer;
    FHomeAtIndent: Boolean;
    FNewFileNumber: Integer;
    FEditorFontSize: Integer;
    FEditorFontName, FEditorThemeName: string;
    FEditorThemeMenu: TMenuItem;
    FCompilerProfiles: TCompilerProfiles;
    FCompilerProfileCombo: TComboBox;
    FEditorTabWidth: Integer;
    FCompletionDismissed: Boolean;
    FCompileActive: Boolean;
    FCompileCancelRequested: Boolean;
    FFileWatchTimer: TTimer;
    FDocumentDialogs: Integer;
    FInstanceTimer: TTimer;
    FChineseLanguageItem, FEnglishLanguageItem: TMenuItem;
    FDebugger: TDebuggerPanel;
    FDebugImages: TImageList;
    FDebugTab: TTabSheet;
    FDebugTimer: TTimer;
    FDebugFile: string;
    FDebugLine: Integer;
    FDebugBuild: Boolean;
    FLastCompileSucceeded: Boolean;
    function DebuggerActive: Boolean;
    function DebuggerStopped: Boolean;
    procedure InitializeDebugger;
    procedure ShutdownDebugger;
    procedure DebugTick(Sender: TObject);
    procedure DebugLocation(Sender: TObject; const FileName: string; Line: Integer);
    procedure DebugStateChange(Sender: TObject);
    procedure DebugStartClick(Sender: TObject);
    procedure DebugToggleBreakpointClick(Sender: TObject);
    procedure EditorLineClick(Sender: TObject; Line: Integer);
    procedure ToggleSourceBreakpoint(Doc: TDocument; Line: Integer);
    procedure UpdateDebugMarkers(Doc: TDocument);
    procedure DebugContinueClick(Sender: TObject);
    procedure DebugStepIntoClick(Sender: TObject);
    procedure DebugStepOverClick(Sender: TObject);
    procedure DebugStopClick(Sender: TObject);
    procedure DebugEvaluateClick(Sender: TObject);
    function EditorHasFocus: Boolean;
    function CommandAvailable(Handler: TNotifyEvent): Boolean;
    procedure RefreshCommandStates(Sender: TObject);
    procedure LoadRecentPaths;
    procedure SaveRecentPaths;
    procedure RebuildRecentMenu;
    procedure RememberRecentPath(const FileName: string);
    procedure RecentFileClick(Sender: TObject);
    procedure ClearRecentClick(Sender: TObject);
    procedure ToggleBookmarkClick(Sender: TObject);
    procedure GotoBookmarkClick(Sender: TObject);
    procedure StatusbarClick(Sender: TObject);
    procedure FullScreenClick(Sender: TObject);
    procedure FocusCompilerLogClick(Sender: TObject);
    procedure FocusEditorClick(Sender: TObject);
    procedure FormShown(Sender: TObject);
    procedure InstanceTick(Sender: TObject);
    procedure ChineseLanguageClick(Sender: TObject);
    procedure EnglishLanguageClick(Sender: TObject);
    function AddMenu(ParentItem: TMenuItem; const ACaption: string;
      Handler: TNotifyEvent; AShortcut: TShortCut = 0): TMenuItem;
    function CurrentDoc: TDocument;
    function FindDoc(const FileName: string): TDocument;
    function SaveDoc(Doc: TDocument): Boolean;
    function SaveDocument(Doc: TDocument; SaveAs: Boolean): Boolean;
    procedure DisposeDocument(Doc: TDocument);
    procedure RefreshProjectTree;
    function TryCloseProject: Boolean;
    procedure CloseProjectClick(Sender: TObject);
    function SaveAllDocs: Boolean;
    function MayClose(Doc: TDocument): Boolean;
    procedure UpdateTab(Doc: TDocument);
    procedure UpdateStatus;
    procedure EditorChanged(Sender: TObject);
    procedure EditorStatusChanged(Sender: TObject; Changes: TSynStatusChanges);
    procedure EditorSpecialLineColors(Sender: TObject; Line: Integer;
      var Special: Boolean; var FG, BG: TColor);
    procedure FileWatchTick(Sender: TObject);
    procedure EditorClicked(Sender: TObject);
    procedure EditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure EditorKeyPress(Sender: TObject; var Key: Char);
    procedure EditorProcessCommand(Sender: TObject;
      var Command: TSynEditorCommand; var AChar: TUTF8Char; Data: Pointer);
    procedure EditorKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure EditorMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure OpenDroppedFile(const DroppedPath: string);
    procedure FilesDropped(Sender: TObject; const FileNames: array of string);
    procedure EditorFilesDropped(Sender: TObject; X, Y: Integer;
      AFiles: TStrings);
    procedure EditorMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure ShowCompletion(Doc: TDocument; AfterMember: Boolean);
    procedure PopulateCompletion(const Prefix: string);
    procedure CompletionKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure CompletionKeyPress(Sender: TObject; var Key: Char);
    procedure CompletionDoubleClick(Sender: TObject);
    procedure CompletionDrawItem(Control: TWinControl; Index: Integer;
      ARect: TRect; State: TOwnerDrawState);
    procedure HideCompletion;
    procedure EnsureFunctionSignatures(Doc: TDocument);
    procedure UpdateFunctionTip(Doc: TDocument);
    procedure HideFunctionTip;
    procedure FunctionTipPaint(Sender: TObject);
    procedure InsertCompletion;
    procedure PageChanged(Sender: TObject);
    procedure ProjectDoubleClick(Sender: TObject);
    procedure ErrorDoubleClick(Sender: TObject);
    procedure PopulateDiagnostics(const CompilerOutput: string);
    procedure LoadCompilerSettings;
    procedure SaveCompilerProfiles;
    procedure ActivateCompilerProfile(Index: Integer; Persist: Boolean);
    procedure PopulateCompilerProfiles(Combo: TComboBox);
    procedure CompilerProfileChange(Sender: TObject);
    procedure InitializeEditorThemes(ParentMenu: TMenuItem);
    procedure ThemeClick(Sender: TObject);
    procedure ApplyDocumentEditorSettings(Doc: TDocument);
    procedure ApplyAllEditorSettings;
    procedure SaveEditorSettings;
    procedure AddCompilerFlags(Args: TStrings; const FlagText: string);
    procedure CloseQueryHandler(Sender: TObject; var CanClose: Boolean);
    procedure OpenFile(const FileName: string);
    procedure CreateDocument(AssignUntitledName: Boolean);
    procedure OpenProject(const FileName: string);
    procedure NewProjectClick(Sender: TObject);
    procedure AddProjectFileClick(Sender: TObject);
    procedure RemoveProjectFileClick(Sender: TObject);
    procedure ProjectOptionsClick(Sender: TObject);
    procedure ProjectManagerClick(Sender: TObject);
    procedure CompileCurrent(SyntaxOnly, RunAfter: Boolean);
    procedure RunExecutable(const FileName: string; const ProjectFile: string = '');
    procedure ReadRunSettings(const ProjectFile: string; out Arguments, WorkDirectory: string);
    function DocumentBelongsToProject(Doc: TDocument): Boolean;
    procedure ExecuteParametersClick(Sender: TObject);
    procedure NewClick(Sender: TObject);
    procedure OpenClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure SaveAsClick(Sender: TObject);
    procedure OpenFolderClick(Sender: TObject);
    procedure CommentClick(Sender: TObject);
    procedure UncommentClick(Sender: TObject);
    procedure ToggleCommentClick(Sender: TObject);
    procedure InlineCommentClick(Sender: TObject);
    procedure DeleteLineClick(Sender: TObject);
    procedure DuplicateLineClick(Sender: TObject);
    procedure MoveSelectionUpClick(Sender: TObject);
    procedure MoveSelectionDownClick(Sender: TObject);
    procedure SwapHeaderSourceClick(Sender: TObject);
    procedure SaveAllClick(Sender: TObject);
    procedure CloseClick(Sender: TObject);
    procedure ExitClick(Sender: TObject);
    procedure UndoClick(Sender: TObject);
    procedure RedoClick(Sender: TObject);
    procedure CutClick(Sender: TObject);
    procedure CopyClick(Sender: TObject);
    procedure PasteClick(Sender: TObject);
    procedure SelectAllClick(Sender: TObject);
    procedure CompletionClick(Sender: TObject);
    procedure CompilerOptionsClick(Sender: TObject);
    procedure EditorOptionsClick(Sender: TObject);
    procedure FindClick(Sender: TObject);
    procedure FindAllClick(Sender: TObject);
    procedure FindNextClick(Sender: TObject);
    procedure FindPreviousClick(Sender: TObject);
    procedure ReplaceClick(Sender: TObject);
    procedure ReplaceAllClick(Sender: TObject);
    procedure GotoClick(Sender: TObject);
    procedure NextTabClick(Sender: TObject);
    procedure PreviousTabClick(Sender: TObject);
    procedure CloseAllClick(Sender: TObject);
    procedure CompileClick(Sender: TObject);
    procedure AbortCompileClick(Sender: TObject);
    procedure RunClick(Sender: TObject);
    procedure CompileRunClick(Sender: TObject);
    procedure SyntaxClick(Sender: TObject);
    procedure AboutClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  MainWindow: TMainForm;

implementation

{$IFDEF UNIX}
function CompilerGetProcessGroup(Pid: LongInt): LongInt; cdecl;
  external 'c' name 'getpgid';
function CompilerGetSession(Pid: LongInt): LongInt; cdecl;
  external 'c' name 'getsid';
function CompilerSignal(Pid, SignalNumber: LongInt): LongInt; cdecl;
  external 'c' name 'kill';
{$ENDIF}

procedure TNoiCppSyn.SetLine(const NewValue: string; LineNumber: Integer);
begin
  FCurrentLine := NewValue;
  inherited SetLine(NewValue, LineNumber);
end;

function ValidIntegerLiteral(const S: string): Boolean;
var
  I, StartDigits, Base: Integer;
  Suffix: string;
begin
  Result := False;
  I := 1;
  Base := 10;
  if (Length(S) > 1) and (S[1] = '0') then
    if S[2] in ['x', 'X'] then begin Base := 16; I := 3; end
    else if S[2] in ['b', 'B'] then begin Base := 2; I := 3; end
    else Base := 8;
  StartDigits := I;
  while I <= Length(S) do
  begin
    if ((Base = 16) and (S[I] in ['0'..'9', 'a'..'f', 'A'..'F'])) or
       ((Base = 10) and (S[I] in ['0'..'9'])) or
       ((Base = 8) and (S[I] in ['0'..'7'])) or
       ((Base = 2) and (S[I] in ['0', '1'])) then Inc(I)
    else Break;
  end;
  if I = StartDigits then Exit;
  Suffix := Copy(S, I, MaxInt);
  if (Pos('lL', Suffix) > 0) or (Pos('Ll', Suffix) > 0) then Exit;
  Suffix := LowerCase(Suffix);
  Result := (Suffix = '') or (Suffix = 'u') or (Suffix = 'l') or
    (Suffix = 'll') or (Suffix = 'ul') or (Suffix = 'ull') or
    (Suffix = 'lu') or (Suffix = 'llu');
end;

function ValidFloatingLiteral(const S: string): Boolean;
var
  I, Digits, ExponentStart: Integer;
  Hexadecimal, HasPoint, HasExponent: Boolean;

  function MantissaDigit(C: Char): Boolean;
  begin
    Result := (C in ['0'..'9']) or
      (Hexadecimal and (C in ['a'..'f', 'A'..'F']));
  end;

begin
  Result := False;
  I := 1;
  Hexadecimal := (Length(S) > 2) and (S[1] = '0') and (S[2] in ['x', 'X']);
  if Hexadecimal then I := 3;
  Digits := 0;
  while (I <= Length(S)) and MantissaDigit(S[I]) do
  begin Inc(I); Inc(Digits); end;
  HasPoint := (I <= Length(S)) and (S[I] = '.');
  if HasPoint then
  begin
    Inc(I);
    while (I <= Length(S)) and MantissaDigit(S[I]) do
    begin Inc(I); Inc(Digits); end;
  end;
  if Digits = 0 then Exit;
  HasExponent := (I <= Length(S)) and
    (((not Hexadecimal) and (S[I] in ['e', 'E'])) or
      (Hexadecimal and (S[I] in ['p', 'P'])));
  if HasExponent then
  begin
    Inc(I);
    if (I <= Length(S)) and (S[I] in ['+', '-']) then Inc(I);
    ExponentStart := I;
    while (I <= Length(S)) and (S[I] in ['0'..'9']) do Inc(I);
    if I = ExponentStart then Exit;
  end;
  if Hexadecimal and not HasExponent then Exit;
  if not (HasPoint or HasExponent) then Exit;
  if (I <= Length(S)) and (S[I] in ['f', 'F', 'l', 'L']) then Inc(I);
  Result := I > Length(S);
end;

constructor TNoiCppSyn.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FBracketAttri := TSynHighlighterAttributes.Create('Bracket', 'Bracket');
  AddAttribute(FBracketAttri);
  FCharacterAttri := TSynHighlighterAttributes.Create('Character', 'Character');
  AddAttribute(FCharacterAttri);
  SetAttributesOnChange(@DefHighlightChange);
end;

function TNoiCppSyn.GetTokenAttribute: TSynHighlighterAttributes;
const
  NewKeywords = ' alignas alignof char8_t char16_t char32_t concept consteval ' +
    'constexpr constinit decltype final noexcept nullptr override requires ' +
    'static_assert thread_local co_await co_return co_yield import module ';
var
  TokenValue: string;
  StartPos, EndPos: Integer;
  WholeLiteral: string;
begin
  Result := inherited GetTokenAttribute;
  TokenValue := GetToken;
  if (GetTokenID = tkIdentifier) and
    (Pos(' ' + TokenValue + ' ', NewKeywords) > 0) then
    Result := KeyAttri;
  if (TokenValue <> '') and
    (GetTokenPos < Length(FCurrentLine)) then
  begin
    StartPos := GetTokenPos + 1;
    EndPos := StartPos;
    while StartPos > 1 do
      if (FCurrentLine[StartPos - 1] in ['A'..'Z', 'a'..'z', '0'..'9', '_', '.']) or
        ((StartPos > 2) and (FCurrentLine[StartPos - 1] in ['+', '-']) and
          (FCurrentLine[StartPos - 2] in ['e', 'E', 'p', 'P'])) then Dec(StartPos)
      else Break;
    while EndPos <= Length(FCurrentLine) do
      if (FCurrentLine[EndPos] in ['A'..'Z', 'a'..'z', '0'..'9', '_', '.']) or
        ((EndPos > 1) and (FCurrentLine[EndPos] in ['+', '-']) and
          (FCurrentLine[EndPos - 1] in ['e', 'E', 'p', 'P'])) then Inc(EndPos)
      else Break;
    WholeLiteral := Copy(FCurrentLine, StartPos, EndPos - StartPos);
    if (WholeLiteral <> '') and (WholeLiteral[1] in ['0'..'9', '.']) and
      (GetTokenID in [tkNumber, tkIdentifier]) then
    begin
      if ValidIntegerLiteral(WholeLiteral) or ValidFloatingLiteral(WholeLiteral) then
        Result := NumberAttri
      else Result := IdentifierAttri;
    end;
    { GTK2's older lexer can split leading decimal points, hex exponents and
      suffixes. Color only punctuation contained in a complete valid float. }
    if (GetTokenID = tkSymbol) and (Length(TokenValue) = 1) and
      (TokenValue[1] in ['.', '+', '-']) and
      (GetTokenPos + Length(TokenValue) < EndPos) and
      ValidFloatingLiteral(WholeLiteral) then Result := NumberAttri;
  end;
  { Lazarus may emit a quote delimiter as a symbol rather than include it
    in the string token.  Keep the original Classic Plus string/char colors. }
  if Copy(TokenValue, 1, 1) = '"' then
    Result := StringAttri;
  if Copy(TokenValue, 1, 1) = '''' then
    Result := FCharacterAttri;
  if (Length(TokenValue) = 1) and (TokenValue[1] in ['(', ')', '[', ']', '{', '}']) and
    (GetTokenID = tkSymbol) then Result := FBracketAttri;
end;

procedure TNoiSynEdit.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_HOME) and ((Shift * [ssCtrl, ssAlt]) = []) then
  begin
    MoveHome(ssShift in Shift);
    Key := 0;
    Exit;
  end;
  { Modifier transitions alone do not move the caret. In particular, releasing
    and pressing Shift between two Shift+Home strokes must preserve the cycle. }
  if not (Key in [VK_SHIFT, VK_CONTROL, VK_MENU]) then FHomeRepeat := False;
  inherited KeyDown(Key, Shift);
end;

procedure TNoiSynEdit.MoveHome(SelectText: Boolean);
begin
  MoveEditorHome(Self, SelectText, FHomeRepeat);
end;

procedure TNoiSynEdit.ResetHomeCycle;
begin
  FHomeRepeat := False;
end;

procedure TNoiSynEdit.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  FHomeRepeat := False;
  FGutterPress := False;
  if (Button = mbLeft) and ((Shift * [ssCtrl, ssAlt, ssShift]) = []) and
    Assigned(FOnLineClick) then
  begin
    FGutterLine := BreakpointLineAt(X, Y);
    if FGutterLine > 0 then
    begin
      FGutterPress := True;
      FGutterPoint := Point(X, Y);
      SetFocus;
      Exit;
    end;
  end;
  inherited MouseDown(Button, Shift, X, Y);
end;

function TNoiSynEdit.BreakpointLineAt(X, Y: Integer): Integer;
var Index, PartIndex: Integer; Position, Pixel: TPoint;
begin
  Result := 0;
  if not Gutter.Visible or (Y < 0) or (Y >= ClientHeight) then Exit;
  Index := -1;
  for PartIndex := 0 to Gutter.Parts.Count - 1 do
    if Gutter.Parts[PartIndex].Visible and
      (X >= Gutter.Parts[PartIndex].Left) and
      (X < Gutter.Parts[PartIndex].Left + Gutter.Parts[PartIndex].Width) then
    begin
      Index := PartIndex;
      Break;
    end;
  if (Index < 0) or (Index >= Gutter.Parts.Count) then Exit;
  if not ((Gutter.Parts[Index] is TSynGutterMarks) or
    (Gutter.Parts[Index] is TSynGutterLineNumber)) then Exit;
  Position := PixelsToLogicalPos(Point(X, Y));
  if (Position.Y < 1) or (Position.Y > Lines.Count) then Exit;
  Pixel := RowColumnToPixels(LogicalToPhysicalPos(Point(1, Position.Y)));
  if (Y < Pixel.Y) or (Y >= Pixel.Y + LineHeight) then Exit;
  Result := Position.Y;
end;

procedure TNoiSynEdit.MouseUp(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var WasGutterPress: Boolean;
begin
  WasGutterPress := FGutterPress;
  FGutterPress := False;
  if WasGutterPress then
  begin
    if (Button = mbLeft) and ((Shift * [ssCtrl, ssAlt, ssShift]) = []) and
      (Abs(X - FGutterPoint.X) <= 3) and (Abs(Y - FGutterPoint.Y) <= 3) and
      (BreakpointLineAt(X, Y) = FGutterLine) and Assigned(FOnLineClick) then
      FOnLineClick(Self, FGutterLine);
    Exit;
  end;
  inherited MouseUp(Button, Shift, X, Y);
end;

function TNoiSynEdit.FindMatchingBracketLogical(LogicalStartBracket: TPoint;
  StartIncludeNeighborChars, MoveCaret, SelectBrackets,
  OnlyVisible: Boolean): TPoint;
var
  BracketSourceBuffer: string;
begin
  if (LogicalStartBracket.Y >= 1) and
    (LogicalStartBracket.Y <= Lines.Count) then
  begin
    BracketSourceBuffer := Lines[LogicalStartBracket.Y - 1];
    if (LogicalStartBracket.X >= 1) and
      (LogicalStartBracket.X <= Length(BracketSourceBuffer)) and
      (BracketSourceBuffer[LogicalStartBracket.X] in ['"', '''']) then
      Exit(Point(-1, -1));
  end;
  Result := inherited FindMatchingBracketLogical(LogicalStartBracket,
    StartIncludeNeighborChars, MoveCaret, SelectBrackets, OnlyVisible);
end;

function VisualLineLength(const LineText: string; TabSize: Integer): Integer;
var I, Column: Integer;
begin
  Column := 1;
  for I := 1 to Length(LineText) do
    if LineText[I] = #9 then
      Column := ((Column - 1) div TabSize + 1) * TabSize + 1
    else
      Inc(Column);
  Result := Column - 1;
end;

function MemberBaseName(const SourceLine: string; NameEnd: Integer): string;
var
  Cursor, EndOfName, Depth: Integer;
begin
  Result := '';
  Cursor := NameEnd;
  while (Cursor > 0) and (SourceLine[Cursor] in [' ', #9]) do Dec(Cursor);
  while (Cursor > 0) and (SourceLine[Cursor] = ']') do
  begin
    Depth := 1;
    Dec(Cursor);
    while (Cursor > 0) and (Depth > 0) do
    begin
      if SourceLine[Cursor] = ']' then Inc(Depth)
      else if SourceLine[Cursor] = '[' then Dec(Depth);
      Dec(Cursor);
    end;
    if Depth <> 0 then Exit;
    while (Cursor > 0) and (SourceLine[Cursor] in [' ', #9]) do Dec(Cursor);
  end;
  EndOfName := Cursor;
  while (Cursor > 0) and
    (SourceLine[Cursor] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do
    Dec(Cursor);
  Result := Copy(SourceLine, Cursor + 1, EndOfName - Cursor);
end;

function IdentifierAt(const SourceLine: string; Column: Integer): string;
var
  First, Last: Integer;
begin
  Result := '';
  if (Column < 1) or (Column > Length(SourceLine)) then Exit;
  if not (SourceLine[Column] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) then Exit;
  First := Column;
  Last := Column;
  while (First > 1) and
    (SourceLine[First - 1] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do Dec(First);
  while (Last < Length(SourceLine)) and
    (SourceLine[Last + 1] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do Inc(Last);
  Result := Copy(SourceLine, First, Last - First + 1);
end;

function DefinitionInText(const SourceText, Name: string;
  ExcludeRow: Integer; out FoundRow, FoundCol, Score: Integer): Boolean;
var
  SourceLines: TStringList;
  I, P, NextPos, ClosePos, CandidateScore: Integer;
  SourceLine, Prefix: string;
begin
  FoundRow := 0;
  FoundCol := 0;
  Score := 0;
  SourceLines := TStringList.Create;
  try
    SourceLines.Text := SourceText;
    for I := 0 to SourceLines.Count - 1 do
    begin
      if I + 1 = ExcludeRow then Continue;
      SourceLine := SourceLines[I];
      P := 1;
      while P <= Length(SourceLine) - Length(Name) + 1 do
      begin
        if Copy(SourceLine, P, Length(Name)) <> Name then
        begin Inc(P); Continue; end;
        if (P > 1) and
          (SourceLine[P - 1] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
        begin Inc(P); Continue; end;
        NextPos := P + Length(Name);
        if (NextPos <= Length(SourceLine)) and
          (SourceLine[NextPos] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
        begin Inc(P); Continue; end;
        Prefix := Trim(Copy(SourceLine, 1, P - 1));
        if Prefix = '' then begin Inc(P); Continue; end;
        if (Prefix[Length(Prefix)] in ['.', '>']) or
          (Prefix = 'return') then begin Inc(P); Continue; end;
        while (NextPos <= Length(SourceLine)) and
          (SourceLine[NextPos] in [' ', #9]) do Inc(NextPos);
        if (NextPos > Length(SourceLine)) or
          (SourceLine[NextPos] <> '(') then begin Inc(P); Continue; end;
        CandidateScore := 1;
        ClosePos := Pos(')', Copy(SourceLine, NextPos + 1, MaxInt));
        if ClosePos > 0 then
        begin
          if Pos('{', Copy(SourceLine, NextPos + ClosePos, MaxInt)) > 0 then
            CandidateScore := 3
          else if (I + 1 < SourceLines.Count) and
            (Pos('{', Trim(SourceLines[I + 1])) = 1) then
            CandidateScore := 3;
        end;
        if CandidateScore > Score then
        begin
          Score := CandidateScore;
          FoundRow := I + 1;
          FoundCol := P;
        end;
        Inc(P, Length(Name));
      end;
    end;
  finally SourceLines.Free; end;
  Result := Score > 0;
end;

function TabIndentOf(const LineText: string): string;
var
  I, Columns: Integer;
begin
  Columns := 0;
  I := 1;
  while (I <= Length(LineText)) and (LineText[I] in [' ', #9]) do
  begin
    if LineText[I] = #9 then
      Columns := ((Columns div 4) + 1) * 4
    else
      Inc(Columns);
    Inc(I);
  end;
  Result := StringOfChar(#9, (Columns + 3) div 4);
end;

function IsTypeHeader(const Prefix: string): Boolean;
var
  Header: string;
begin
  Header := LowerCase(Trim(Prefix));
  Result := (Header = 'struct') or (Header = 'class') or
    (Header = 'union') or
    (Copy(Header, 1, 7) = 'struct ') or
    (Copy(Header, 1, 6) = 'class ') or
    (Copy(Header, 1, 6) = 'union ') or
    (Copy(Header, 1, 15) = 'typedef struct ');
end;

function IsBracketPair(const Opening, Closing: Char): Boolean;
begin
  Result := ((Opening = '(') and (Closing = ')')) or
    ((Opening = '[') and (Closing = ']')) or
    ((Opening = '{') and (Closing = '}')) or
    ((Opening = '''') and (Closing = '''')) or
    ((Opening = '"') and (Closing = '"'));
end;

function IsIncludePrefix(const Prefix: string): Boolean;
var
  Directive: string;
begin
  Directive := Trim(Prefix);
  Result := False;
  if (Directive = '') or (Directive[1] <> '#') then Exit;
  Result := Trim(Copy(Directive, 2, MaxInt)) = 'include';
end;

function DisplayCommandLine(const ProgramName: string; Args: TStrings): string;
var
  I: Integer;
  Arg: string;
begin
  Result := ProgramName;
  for I := 0 to Args.Count - 1 do
  begin
    Arg := Args[I];
    if (Pos(' ', Arg) > 0) or (Pos(#9, Arg) > 0) then
      Arg := '"' + StringReplace(Arg, '"', '\"', [rfReplaceAll]) + '"';
    Result := Result + ' ' + Arg;
  end;
end;

function TMainForm.AddMenu(ParentItem: TMenuItem; const ACaption: string;
  Handler: TNotifyEvent; AShortcut: TShortCut): TMenuItem;
begin
  Result := TMenuItem.Create(Self);
  Result.Caption := Tr(ACaption);
  Result.ShortCut := AShortcut;
  if Assigned(Handler) then
    Result.OnClick := Handler;
  ParentItem.Add(Result);
end;

constructor TMainForm.Create(AOwner: TComponent);
var
  Bar: TMainMenu;
  FileMenu, EditMenu, SearchMenu, ViewMenu, ProjectMenu,
    ExecuteMenu, ToolsMenu, HelpMenu, LanguageMenu, DebugMenu, BookmarkMenu,
    ToggleBookmarksMenu, GotoBookmarksMenu, BookmarkItem: TMenuItem;
  MainPanel, CenterPanel, BottomPanel: TPanel;
  Toolbar: TToolBar;
  ToolImages: TImageList;
  LeftTabs: TPageControl;
  LeftProjectTab, LeftClassTab: TTabSheet;
  Split: TSplitter;
  Button: TToolButton;
  Bitmap: TBitmap;
  Col: TListColumn;
  ArgIndex, BookmarkIndex: Integer;

  procedure AddTool(const ACaption, IconName: string; Handler: TNotifyEvent);
  var IconPath: string;
  begin
    Button := TToolButton.Create(Toolbar);
    Button.Parent := Toolbar;
    Button.Caption := Tr(ACaption);
    Button.Hint := Tr(ACaption);
    Button.ShowHint := True;
    Button.OnClick := Handler;
    IconPath := ExtractFilePath(ParamStr(0)) + 'icons' + DirectorySeparator + IconName + '.bmp';
    if FileExists(IconPath) then
    begin
      Bitmap := TBitmap.Create;
      try
        Bitmap.LoadFromFile(IconPath);
        Button.ImageIndex := ToolImages.AddMasked(Bitmap, Bitmap.Canvas.Pixels[0, 0]);
      finally Bitmap.Free; end;
    end
    else if IconName <> '' then
    begin
      Bitmap := DebuggerIcon(IconName);
      try
        Button.ImageIndex := ToolImages.AddMasked(Bitmap, clFuchsia);
      finally Bitmap.Free; end;
    end;
  end;

  procedure AddDivider;
  begin
    Button := TToolButton.Create(Toolbar);
    Button.Parent := Toolbar;
    Button.Style := tbsSeparator;
    Button.Width := 8;
  end;

begin
  inherited CreateNew(AOwner, 0);
  Caption := AppName + ' ' + AppVersion;
  Font.Name := 'Sans';
  Font.Size := 9;
  Constraints.MinWidth := 820;
  Constraints.MinHeight := 560;
  Width := Min(1100, Screen.WorkAreaWidth - 32);
  Height := Min(760, Screen.WorkAreaHeight - 40);
  Position := poScreenCenter;
  if FileExists(ExtractFilePath(ParamStr(0)) + 'devcpp.ico') then
    try
      Icon.LoadFromFile(ExtractFilePath(ParamStr(0)) + 'devcpp.ico');
    except
      { The editor remains usable if the window manager cannot load ICO files. }
    end;
  FDocs := TObjectList.Create(True);
  FDebugImages := TImageList.Create(Self);
  FDebugImages.Width := 16;
  FDebugImages.Height := 16;
  for ArgIndex := 0 to 2 do
  begin
    case ArgIndex of
      0: Bitmap := DebuggerIcon('breakpoint');
      1: Bitmap := DebuggerIcon('current');
      else Bitmap := DebuggerIcon('current-breakpoint');
    end;
    try FDebugImages.AddMasked(Bitmap, clFuchsia); finally Bitmap.Free; end;
  end;
  FRecentFiles := TStringList.Create;
  FRecentFiles.CaseSensitive := True;
  FEditorFontSize := 10;
  FEditorTabWidth := 4;
  FProjectFiles := TStringList.Create;
  FProjectFiles.CaseSensitive := True;
  LoadCompilerSettings;
  LoadRecentPaths;
  InitUiLanguage(FOptionsPath);
  OnShow := @FormShown;
  OnCloseQuery := @CloseQueryHandler;
  KeyPreview := True;
  OnKeyDown := @FormKeyDown;
  AllowDropFiles := True;
  OnDropFiles := @FilesDropped;
  Application.OnDropFiles := @FilesDropped;

  Bar := TMainMenu.Create(Self);
  Menu := Bar;
  FileMenu := TMenuItem.Create(Self); FileMenu.Caption := Tr('&File'); Bar.Items.Add(FileMenu);
  AddMenu(FileMenu, '&New Source File', @NewClick, ShortCut(Ord('N'), [ssCtrl]));
  AddMenu(FileMenu, '&Open project or file...', @OpenClick, ShortCut(Ord('O'), [ssCtrl]));
  AddMenu(FileMenu, '-', nil);
  AddMenu(FileMenu, '&Save', @SaveClick, ShortCut(Ord('S'), [ssCtrl]));
  AddMenu(FileMenu, 'Save &As...', @SaveAsClick, ShortCut(Ord('S'), [ssCtrl, ssShift]));
  AddMenu(FileMenu, 'Save A&ll', @SaveAllClick, ShortCut(Ord('A'), [ssCtrl, ssShift]));
  AddMenu(FileMenu, 'Open Containing &Folder', @OpenFolderClick,
    ShortCut(Ord('B'), [ssCtrl]));
  FRecentMenu := AddMenu(FileMenu, 'Recent &Files / Projects', nil);
  RebuildRecentMenu;
  AddMenu(FileMenu, '-', nil);
  AddMenu(FileMenu, '&Close', @CloseClick, ShortCut(Ord('W'), [ssCtrl]));
  AddMenu(FileMenu, 'Close &All', @CloseAllClick,
    ShortCut(Ord('W'), [ssCtrl, ssShift]));
  AddMenu(FileMenu, 'E&xit', @ExitClick);

  EditMenu := TMenuItem.Create(Self); EditMenu.Caption := Tr('&Edit'); Bar.Items.Add(EditMenu);
  AddMenu(EditMenu, '&Undo', @UndoClick, ShortCut(Ord('Z'), [ssCtrl]));
  AddMenu(EditMenu, '&Redo', @RedoClick, ShortCut(Ord('Y'), [ssCtrl]));
  AddMenu(EditMenu, '-', nil);
  AddMenu(EditMenu, 'Cu&t', @CutClick, ShortCut(Ord('X'), [ssCtrl]));
  AddMenu(EditMenu, '&Copy', @CopyClick, ShortCut(Ord('C'), [ssCtrl]));
  AddMenu(EditMenu, '&Paste', @PasteClick, ShortCut(Ord('V'), [ssCtrl]));
  AddMenu(EditMenu, 'Select &All', @SelectAllClick, ShortCut(Ord('A'), [ssCtrl]));
  AddMenu(EditMenu, '-', nil);
  AddMenu(EditMenu, '&Comment', @CommentClick, ShortCut(190, [ssCtrl]));
  AddMenu(EditMenu, '&Uncomment', @UncommentClick, ShortCut(188, [ssCtrl]));
  AddMenu(EditMenu, '&Toggle Comment', @ToggleCommentClick,
    ShortCut(191, [ssCtrl]));
  AddMenu(EditMenu, 'Toggle &Inline Comment', @InlineCommentClick,
    ShortCut(186, [ssCtrl]));
  AddMenu(EditMenu, '&Delete Line', @DeleteLineClick,
    ShortCut(Ord('D'), [ssCtrl]));
  AddMenu(EditMenu, 'D&uplicate Line', @DuplicateLineClick,
    ShortCut(Ord('E'), [ssCtrl]));
  AddMenu(EditMenu, 'Move Selection &Up', @MoveSelectionUpClick,
    ShortCut(VK_UP, [ssCtrl, ssShift]));
  AddMenu(EditMenu, 'Move Selection &Down', @MoveSelectionDownClick,
    ShortCut(VK_DOWN, [ssCtrl, ssShift]));
  AddMenu(EditMenu, 'Code &Completion', @CompletionClick, ShortCut(VK_SPACE, [ssCtrl]));

  SearchMenu := TMenuItem.Create(Self); SearchMenu.Caption := Tr('&Search'); Bar.Items.Add(SearchMenu);
  AddMenu(SearchMenu, '&Find...', @FindClick, ShortCut(Ord('F'), [ssCtrl]));
  AddMenu(SearchMenu, 'Find &All...', @FindAllClick,
    ShortCut(Ord('F'), [ssCtrl, ssShift]));
  AddMenu(SearchMenu, 'Find &Next', @FindNextClick, ShortCut(VK_F3, []));
  AddMenu(SearchMenu, 'Find &Previous', @FindPreviousClick,
    ShortCut(VK_F3, [ssShift]));
  AddMenu(SearchMenu, '&Replace...', @ReplaceClick, ShortCut(Ord('R'), [ssCtrl]));
  AddMenu(SearchMenu, 'Replace &All...', @ReplaceAllClick,
    ShortCut(Ord('R'), [ssCtrl, ssShift]));
  AddMenu(SearchMenu, '&Go to line...', @GotoClick, ShortCut(Ord('G'), [ssCtrl]));
  BookmarkMenu := AddMenu(SearchMenu, '&Bookmarks', nil);
  ToggleBookmarksMenu := AddMenu(BookmarkMenu, '&Toggle Bookmark', nil);
  GotoBookmarksMenu := AddMenu(BookmarkMenu, '&Go to Bookmark', nil);
  for BookmarkIndex := 1 to 9 do
  begin
    BookmarkItem := AddMenu(ToggleBookmarksMenu, Format(Tr('Bookmark &%d'),
      [BookmarkIndex]), @ToggleBookmarkClick,
      ShortCut(Ord('0') + BookmarkIndex, [ssCtrl]));
    BookmarkItem.Tag := BookmarkIndex;
    BookmarkItem := AddMenu(GotoBookmarksMenu, Format(Tr('Bookmark &%d'),
      [BookmarkIndex]), @GotoBookmarkClick,
      ShortCut(Ord('0') + BookmarkIndex, [ssAlt]));
    BookmarkItem.Tag := BookmarkIndex;
  end;

  ViewMenu := TMenuItem.Create(Self); ViewMenu.Caption := Tr('&View'); Bar.Items.Add(ViewMenu);
  AddMenu(ViewMenu, '&Project Manager', @ProjectManagerClick);
  AddMenu(ViewMenu, 'Compiler &Log', @FocusCompilerLogClick,
    ShortCut(Ord('L'), [ssCtrl, ssAlt]));
  AddMenu(ViewMenu, 'Focus &Editor', @FocusEditorClick,
    ShortCut(Ord('E'), [ssCtrl, ssAlt]));
  AddMenu(ViewMenu, '&Next Tab', @NextTabClick, ShortCut(VK_TAB, [ssCtrl]));
  AddMenu(ViewMenu, '&Previous Tab', @PreviousTabClick,
    ShortCut(VK_TAB, [ssCtrl, ssShift]));
  AddMenu(ViewMenu, 'Swap &Header/Source', @SwapHeaderSourceClick,
    ShortCut(Ord('Q'), [ssCtrl]));
  FStatusbarItem := AddMenu(ViewMenu, '&Statusbar', @StatusbarClick);
  FStatusbarItem.Checked := True;
  FFullScreenItem := AddMenu(ViewMenu, '&Full screen mode', @FullScreenClick,
    ShortCut(VK_F11, [ssCtrl]));
  ProjectMenu := TMenuItem.Create(Self); ProjectMenu.Caption := Tr('&Project'); Bar.Items.Add(ProjectMenu);
  AddMenu(ProjectMenu, '&New project...', @NewProjectClick);
  AddMenu(ProjectMenu, '&Open project...', @OpenClick);
  AddMenu(ProjectMenu, '&Close Project', @CloseProjectClick);
  AddMenu(ProjectMenu, '&Add file to project...', @AddProjectFileClick);
  AddMenu(ProjectMenu, '&Remove file from project...', @RemoveProjectFileClick);
  AddMenu(ProjectMenu, 'Project &Options...', @ProjectOptionsClick,
    ShortCut(Ord('H'), [ssCtrl]));

  ExecuteMenu := TMenuItem.Create(Self); ExecuteMenu.Caption := Tr('E&xecute'); Bar.Items.Add(ExecuteMenu);
  AddMenu(ExecuteMenu, '&Compile', @CompileClick, ShortCut(VK_F9, []));
  AddMenu(ExecuteMenu, '&Run', @RunClick, ShortCut(VK_F10, []));
  AddMenu(ExecuteMenu, 'Compile && Run', @CompileRunClick, ShortCut(VK_F11, []));
  AddMenu(ExecuteMenu, 'R&ebuild All', @CompileClick, ShortCut(VK_F12, []));
  AddMenu(ExecuteMenu, '&Abort Compilation', @AbortCompileClick);
  AddMenu(ExecuteMenu, '-', nil);
  AddMenu(ExecuteMenu, '&Syntax Check', @SyntaxClick,
    ShortCut(VK_F9, [ssCtrl]));
  AddMenu(ExecuteMenu, 'Compiler &Parameters...', @CompilerOptionsClick,
    ShortCut(Ord('O'), [ssCtrl, ssAlt]));
  AddMenu(ExecuteMenu, '&Parameters...', @ExecuteParametersClick);
  DebugMenu := TMenuItem.Create(Self);
  DebugMenu.Caption := Tr('&Debug');
  Bar.Items.Add(DebugMenu);
  AddMenu(DebugMenu, '&Start Debugging', @DebugStartClick, ShortCut(VK_F5, []));
  AddMenu(DebugMenu, 'Toggle &Breakpoint', @DebugToggleBreakpointClick,
    ShortCut(VK_F4, []));
  AddMenu(DebugMenu, '&Continue', @DebugContinueClick);
  AddMenu(DebugMenu, '&Next Line', @DebugStepOverClick, ShortCut(VK_F7, []));
  AddMenu(DebugMenu, '&Step Into', @DebugStepIntoClick, ShortCut(VK_F8, []));
  AddMenu(DebugMenu, '&Stop Debugging', @DebugStopClick, ShortCut(VK_F6, []));
  AddMenu(DebugMenu, '&Evaluate Expression', @DebugEvaluateClick);

  ToolsMenu := TMenuItem.Create(Self); ToolsMenu.Caption := Tr('&Tools'); Bar.Items.Add(ToolsMenu);
  AddMenu(ToolsMenu, '&Compiler Options / Parameters...', @CompilerOptionsClick);
  AddMenu(ToolsMenu, 'E&ditor Options...', @EditorOptionsClick);
  InitializeEditorThemes(ToolsMenu);
  LanguageMenu := AddMenu(ToolsMenu, '&Language', nil);
  FChineseLanguageItem := AddMenu(LanguageMenu, 'Chinese', @ChineseLanguageClick);
  FEnglishLanguageItem := AddMenu(LanguageMenu, 'English', @EnglishLanguageClick);
  FChineseLanguageItem.Checked := CurrentUiLanguage = ulChinese;
  FEnglishLanguageItem.Checked := CurrentUiLanguage = ulEnglish;
  HelpMenu := TMenuItem.Create(Self); HelpMenu.Caption := Tr('&Help'); Bar.Items.Add(HelpMenu);
  AddMenu(HelpMenu, '&About Dev-Cpp', @AboutClick);

  ToolImages := TImageList.Create(Self);
  ToolImages.Width := 16;
  ToolImages.Height := 16;
  Toolbar := TToolBar.Create(Self);
  FMainToolbar := Toolbar;
  Toolbar.Parent := Self;
  Toolbar.Align := alTop;
  Toolbar.Height := 28;
  Toolbar.ButtonWidth := 24;
  Toolbar.ButtonHeight := 24;
  Toolbar.Flat := True;
  Toolbar.ShowCaptions := False;
  Toolbar.Images := ToolImages;
  AddTool('New Source File', 'newsrc', @NewClick);
  AddTool('Open', 'opnproj', @OpenClick);
  AddTool('Save', 'save', @SaveClick);
  AddTool('Save All', 'saveall', @SaveAllClick);
  AddTool('Close', 'close', @CloseClick);
  AddDivider;
  AddTool('Undo', 'undo', @UndoClick);
  AddTool('Redo', 'redo', @RedoClick);
  AddTool('Find', 'search', @FindClick);
  AddDivider;
  AddTool('Compile', 'compile', @CompileClick);
  AddTool('Run', 'run', @RunClick);
  AddTool('Compile & Run', 'comprun', @CompileRunClick);
  AddTool('Rebuild All', 'rebuild', @CompileClick);
  AddDivider;
  AddTool('Start Debugging', 'debug', @DebugStartClick);
  AddDivider;
  AddTool('Stop', 'stop-debug', @DebugStopClick);
  AddDivider;
  FCompilerProfileCombo := TComboBox.Create(Self);
  FCompilerProfileCombo.Parent := Toolbar;
  FCompilerProfileCombo.Left := Toolbar.ButtonCount * Toolbar.ButtonWidth + 12;
  FCompilerProfileCombo.Top := 2;
  FCompilerProfileCombo.Width := 230;
  FCompilerProfileCombo.Style := csDropDownList;
  FCompilerProfileCombo.Hint := Tr('Active compiler profile:');
  FCompilerProfileCombo.ShowHint := True;
  PopulateCompilerProfiles(FCompilerProfileCombo);
  FCompilerProfileCombo.OnChange := @CompilerProfileChange;

  FStatus := TStatusBar.Create(Self);
  FStatus.Parent := Self;
  FStatus.Align := alBottom;
  FStatus.SimplePanel := True;
  FStatus.Height := 24;

  MainPanel := TPanel.Create(Self);
  MainPanel.Parent := Self;
  MainPanel.Align := alClient;
  MainPanel.BevelOuter := bvNone;

  LeftTabs := TPageControl.Create(Self);
  FLeftTabs := LeftTabs;
  LeftTabs.Parent := MainPanel;
  LeftTabs.Align := alLeft;
  LeftTabs.Width := 210;
  LeftProjectTab := TTabSheet.Create(LeftTabs);
  LeftProjectTab.PageControl := LeftTabs;
  LeftProjectTab.Caption := Tr('Project');
  LeftClassTab := TTabSheet.Create(LeftTabs);
  LeftClassTab.PageControl := LeftTabs;
  LeftClassTab.Caption := Tr('Classes');
  FLeftDebugTab := TTabSheet.Create(LeftTabs);
  FLeftDebugTab.PageControl := LeftTabs;
  FLeftDebugTab.Caption := Tr('Debug');
  LeftTabs.ActivePage := LeftProjectTab;
  FProjectTree := TTreeView.Create(Self);
  FProjectTree.Parent := LeftProjectTab;
  FProjectTree.Align := alClient;
  FProjectTree.OnDblClick := @ProjectDoubleClick;
  Split := TSplitter.Create(Self); Split.Parent := MainPanel; Split.Align := alLeft;

  CenterPanel := TPanel.Create(Self);
  CenterPanel.Parent := MainPanel;
  CenterPanel.Align := alClient;
  CenterPanel.BevelOuter := bvNone;
  BottomPanel := TPanel.Create(Self);
  BottomPanel.Parent := CenterPanel;
  BottomPanel.Align := alBottom;
  BottomPanel.Height := 220;
  BottomPanel.BevelOuter := bvNone;
  BottomPanel.Constraints.MinHeight := 150;
  BottomPanel.Caption := Tr('');
  FReportTabs := TPageControl.Create(Self);
  FReportTabs.Parent := BottomPanel;
  FReportTabs.Align := alClient;
  FCompilerTab := TTabSheet.Create(FReportTabs);
  FCompilerTab.PageControl := FReportTabs;
  FCompilerTab.Caption := Tr('Compiler');
  FCompilerList := TListView.Create(Self);
  FCompilerList.Parent := FCompilerTab;
  FCompilerList.Align := alClient;
  FCompilerList.ViewStyle := vsReport;
  FCompilerList.ReadOnly := True;
  FCompilerList.RowSelect := True;
  FCompilerList.OnDblClick := @ErrorDoubleClick;
  Col := FCompilerList.Columns.Add; Col.Caption := Tr('Line'); Col.Width := 55;
  Col := FCompilerList.Columns.Add; Col.Caption := Tr('Col'); Col.Width := 45;
  Col := FCompilerList.Columns.Add; Col.Caption := Tr('Unit'); Col.Width := 220;
  Col := FCompilerList.Columns.Add; Col.Caption := Tr('Message'); Col.Width := 650;
  FLogTab := TTabSheet.Create(FReportTabs);
  FLogTab.PageControl := FReportTabs;
  FLogTab.Caption := Tr('Compile log');
  FOutput := TMemo.Create(Self);
  FOutput.Parent := FLogTab;
  FOutput.Align := alClient;
  FOutput.ReadOnly := True;
  FOutput.ScrollBars := ssBoth;
  FOutput.Font.Name := ResolveEditorFontName(FEditorFontName);
  Split := TSplitter.Create(Self); Split.Parent := CenterPanel; Split.Align := alBottom;

  FPages := TPageControl.Create(Self);
  FPages.Parent := CenterPanel;
  FPages.Align := alClient;
  FPages.OnChange := @PageChanged;
  FCompletionForm := TForm.CreateNew(Self, 0);
  FCompletionForm.BorderStyle := bsNone;
  FCompletionForm.FormStyle := fsStayOnTop;
  FCompletionForm.ClientWidth := 320;
  FCompletionForm.ClientHeight := 240;
  FCompletionForm.Color := clWindow;
  FCompletionForm.KeyPreview := True;
  FCompletionForm.OnKeyDown := @CompletionKeyDown;
  FCompletionForm.OnKeyPress := @CompletionKeyPress;
  FCompletionList := TListBox.Create(FCompletionForm);
  FCompletionList.Parent := FCompletionForm;
  FCompletionList.Align := alClient;
  FCompletionList.BorderStyle := bsNone;
  FCompletionList.Style := lbOwnerDrawFixed;
  FCompletionList.ItemHeight := 28;
  FCompletionList.Font.Name := ResolveEditorFontName(FEditorFontName);
  FCompletionList.Font.Size := 10;
  FCompletionList.OnDrawItem := @CompletionDrawItem;
  FCompletionList.OnKeyDown := @CompletionKeyDown;
  FCompletionList.OnKeyPress := @CompletionKeyPress;
  FCompletionList.OnDblClick := @CompletionDoubleClick;
  FCompletionKinds := TStringList.Create;
  FTipSignatures := TStringList.Create;
  FTipSignatures.CaseSensitive := True;
  FTipForm := TPanel.Create(Self);
  FTipForm.Parent := Self;
  FTipForm.Visible := False;
  FTipForm.BevelOuter := bvNone;
  FTipForm.ClientWidth := 220;
  FTipForm.ClientHeight := 32;
  FTipPaint := TPaintBox.Create(FTipForm);
  FTipPaint.Parent := FTipForm;
  FTipPaint.Align := alClient;
  FTipPaint.OnPaint := @FunctionTipPaint;
  FFileWatchTimer := TTimer.Create(Self);
  FFileWatchTimer.Interval := 1000;
  FFileWatchTimer.OnTimer := @FileWatchTick;
  FFileWatchTimer.Enabled := True;
  FInstanceTimer := TTimer.Create(Self);
  FInstanceTimer.Interval := 150;
  FInstanceTimer.OnTimer := @InstanceTick;
  FInstanceTimer.Enabled := True;
  FUiTimer := TTimer.Create(Self);
  FUiTimer.Interval := 100;
  FUiTimer.OnTimer := @RefreshCommandStates;
  FUiTimer.Enabled := True;
  InitializeDebugger;
  if StartupFiles <> nil then
  for ArgIndex := 0 to StartupFiles.Count - 1 do
  begin
    if LowerCase(ExtractFileExt(StartupFiles[ArgIndex])) = '.dev' then
      OpenProject(StartupFiles[ArgIndex])
    else
      OpenFile(StartupFiles[ArgIndex]);
  end;
  UpdateStatus;
  ApplyUiLanguage(Self);
end;

destructor TMainForm.Destroy;
var I: Integer; Doc: TDocument;
begin
  FLoading := True;
  ShutdownDebugger;
  if FUiTimer <> nil then FUiTimer.Enabled := False;
  if FInstanceTimer <> nil then FInstanceTimer.Enabled := False;
  if FFileWatchTimer <> nil then FFileWatchTimer.Enabled := False;
  if FPages <> nil then FPages.OnChange := nil;
  if FDocs <> nil then
    for I := 0 to FDocs.Count - 1 do
    begin
      Doc := TDocument(FDocs[I]);
      Doc.Editor.OnChange := nil;
      Doc.Editor.OnStatusChange := nil;
      Doc.Editor.OnSpecialLineColors := nil;
      Doc.Editor.OnKeyDown := nil;
      Doc.Editor.OnKeyPress := nil;
      Doc.Editor.OnKeyUp := nil;
      TNoiSynEdit(Doc.Editor).OnLineClick := nil;
    end;
  FCompilerProfiles.Free;
  FRecentFiles.Free;
  FInvalidExecutables.Free;
  FTipSignatures.Free;
  FCompletionKinds.Free;
  FProjectFiles.Free;
  FreeAndNil(FDocs);
  inherited Destroy;
end;

function SameHandler(const Left, Right: TNotifyEvent): Boolean;
begin
  Result := Assigned(Left) and Assigned(Right) and
    (TMethod(Left).Code = TMethod(Right).Code) and
    (TMethod(Left).Data = TMethod(Right).Data);
end;

function TMainForm.EditorHasFocus: Boolean;
var Doc: TDocument;
begin
  Doc := CurrentDoc;
  Result := (Doc <> nil) and ((ActiveControl = Doc.Editor) or Doc.Editor.Focused);
end;

function TMainForm.CommandAvailable(Handler: TNotifyEvent): Boolean;
var
  Doc: TDocument;
  NativeEdit: TCustomEdit;
  InEditor, HasSelection, CanWrite: Boolean;

  function IsCommand(Command: TNotifyEvent): Boolean;
  begin Result := SameHandler(Handler, Command); end;

begin
  Result := True;
  if not Assigned(Handler) then Exit;
  Doc := CurrentDoc;
  InEditor := EditorHasFocus;
  NativeEdit := nil;
  if ActiveControl is TCustomEdit then NativeEdit := TCustomEdit(ActiveControl);
  HasSelection := (InEditor and (Doc <> nil) and Doc.Editor.SelAvail) or
    ((NativeEdit <> nil) and (NativeEdit.SelLength > 0));
  CanWrite := not FCompileActive and ((InEditor and (Doc <> nil) and
    not Doc.Editor.ReadOnly) or ((NativeEdit <> nil) and not NativeEdit.ReadOnly));
  if IsCommand(@AbortCompileClick) then Exit(FCompileActive);
  if IsCommand(@DebugStartClick) then
    Exit(not FCompileActive and not DebuggerActive and
      ((Doc <> nil) or (FProjectPath <> '')));
  if IsCommand(@DebugToggleBreakpointClick) then
    Exit(not FCompileActive and InEditor and (not DebuggerActive or
      ((FDebugger.Session.State in [gsStopped, gsRunning]) and
        not FDebugger.Session.ChangingBreakpoint)));
  if IsCommand(@DebugStopClick) then Exit(DebuggerActive);
  if IsCommand(@DebugContinueClick) or IsCommand(@DebugStepIntoClick) or
    IsCommand(@DebugStepOverClick) or IsCommand(@DebugEvaluateClick) then
    Exit(DebuggerStopped and not FCompileActive and
      not FDebugger.Session.ChangingBreakpoint);
  if IsCommand(@ClearRecentClick) then Exit(FRecentFiles.Count > 0);
  if IsCommand(@CopyClick) then Exit(HasSelection);
  if IsCommand(@SelectAllClick) then Exit(InEditor or (NativeEdit <> nil));
  if IsCommand(@CutClick) then Exit(CanWrite and HasSelection);
  if IsCommand(@PasteClick) then Exit(CanWrite);
  if IsCommand(@UndoClick) then
    Exit(CanWrite and ((InEditor and Doc.Editor.CanUndo) or
      ((NativeEdit <> nil) and NativeEdit.CanUndo)));
  if IsCommand(@RedoClick) then Exit(CanWrite and InEditor and Doc.Editor.CanRedo);
  if (FCompileActive or DebuggerActive) and (IsCommand(@NewClick) or IsCommand(@OpenClick) or
    IsCommand(@RecentFileClick) or IsCommand(@SaveClick) or
    IsCommand(@SaveAsClick) or IsCommand(@SaveAllClick) or
    IsCommand(@CloseClick) or IsCommand(@CloseAllClick) or
    IsCommand(@NewProjectClick) or IsCommand(@AddProjectFileClick) or
    IsCommand(@RemoveProjectFileClick) or IsCommand(@ProjectOptionsClick) or
    IsCommand(@CloseProjectClick) or IsCommand(@CompileClick) or
    IsCommand(@SyntaxClick) or IsCommand(@CompileRunClick) or
    IsCommand(@RunClick) or IsCommand(@ExecuteParametersClick) or
    IsCommand(@CompilerOptionsClick) or IsCommand(@ReplaceClick) or
    IsCommand(@ReplaceAllClick) or IsCommand(@CommentClick) or
    IsCommand(@UncommentClick) or IsCommand(@ToggleCommentClick) or
    IsCommand(@InlineCommentClick) or IsCommand(@DeleteLineClick) or
    IsCommand(@DuplicateLineClick) or IsCommand(@MoveSelectionUpClick) or
    IsCommand(@MoveSelectionDownClick)) then Exit(False);
  if IsCommand(@SaveClick) or IsCommand(@SaveAsClick) or
    IsCommand(@CloseClick) or IsCommand(@SwapHeaderSourceClick) or
    IsCommand(@FocusEditorClick) then Exit(Doc <> nil);
  if IsCommand(@SaveAllClick) or IsCommand(@CloseAllClick) then Exit(FDocs.Count > 0);
  if IsCommand(@ProjectOptionsClick) or IsCommand(@AddProjectFileClick) or
    IsCommand(@RemoveProjectFileClick) or IsCommand(@CloseProjectClick) then
    Exit(FProjectPath <> '');
  if IsCommand(@CompileClick) or IsCommand(@CompileRunClick) or
    IsCommand(@RunClick) then Exit((Doc <> nil) or (FProjectPath <> ''));
  if IsCommand(@SyntaxClick) then Exit(Doc <> nil);
  if IsCommand(@CommentClick) or IsCommand(@UncommentClick) or
    IsCommand(@ToggleCommentClick) or IsCommand(@DeleteLineClick) or
    IsCommand(@DuplicateLineClick) or IsCommand(@MoveSelectionUpClick) or
    IsCommand(@MoveSelectionDownClick) or IsCommand(@ReplaceClick) or
    IsCommand(@ReplaceAllClick) then Exit(InEditor and CanWrite);
  if IsCommand(@InlineCommentClick) then Exit(InEditor and CanWrite and HasSelection);
  if IsCommand(@FindClick) or IsCommand(@FindNextClick) or
    IsCommand(@FindPreviousClick) or IsCommand(@GotoClick) or
    IsCommand(@CompletionClick) or IsCommand(@ToggleBookmarkClick) or
    IsCommand(@GotoBookmarkClick) then Exit(InEditor);
  if IsCommand(@FindAllClick) then Exit(FDocs.Count > 0);
  if IsCommand(@NextTabClick) or IsCommand(@PreviousTabClick) then Exit(FDocs.Count > 1);
end;

procedure TMainForm.RefreshCommandStates(Sender: TObject);
var
  I, X, Y: Integer;
  Item: TMenuItem;
  Button: TToolButton;
  Doc: TDocument;
begin
  if (Application.ModalLevel > 0) or FLoading then Exit;
  for I := 0 to FDocs.Count - 1 do
  begin
    Doc := TDocument(FDocs[I]);
    if (FCompileActive or DebuggerActive) and not Doc.DebugReadOnlyApplied then
    begin
      Doc.ReadOnlyBeforeDebug := Doc.Editor.ReadOnly;
      Doc.DebugReadOnlyApplied := True;
      Doc.Editor.ReadOnly := True;
      if (FCompletionForm <> nil) and (FCompletionDoc = Doc) then
        HideCompletion;
    end
    else if not FCompileActive and not DebuggerActive and Doc.DebugReadOnlyApplied then
    begin
      Doc.Editor.ReadOnly := Doc.ReadOnlyBeforeDebug;
      Doc.DebugReadOnlyApplied := False;
    end;
  end;
  if FCompilerProfileCombo <> nil then
    FCompilerProfileCombo.Enabled := not FCompileActive and not DebuggerActive;
  if FRecentMenuDirty then RebuildRecentMenu;
  Doc := CurrentDoc;
  for I := 0 to ComponentCount - 1 do
    if Components[I] is TMenuItem then
    begin
      Item := TMenuItem(Components[I]);
      if Assigned(Item.OnClick) then Item.Enabled := CommandAvailable(Item.OnClick);
      if SameHandler(Item.OnClick, @ToggleBookmarkClick) then
        Item.Checked := (Doc <> nil) and Doc.Editor.GetBookMark(Item.Tag, X, Y);
      if SameHandler(Item.OnClick, @GotoBookmarkClick) then
        Item.Enabled := Item.Enabled and (Doc <> nil) and
          Doc.Editor.GetBookMark(Item.Tag, X, Y);
    end;
  if FMainToolbar <> nil then
    for I := 0 to FMainToolbar.ButtonCount - 1 do
    begin
      Button := FMainToolbar.Buttons[I];
      if Assigned(Button.OnClick) then Button.Enabled := CommandAvailable(Button.OnClick);
    end;
end;

function EncodeHistoryPath(const FileName: string): string;
var I: Integer;
begin
  { INI values cannot safely contain line breaks from valid Unix filenames. }
  Result := 'hex:';
  for I := 1 to Length(FileName) do
    Result := Result + IntToHex(Ord(FileName[I]), 2);
end;

function DecodeHistoryPath(const Value: string): string;
var I, Code: Integer;
begin
  if Copy(Value, 1, 4) <> 'hex:' then Exit(Value);
  Result := '';
  if Odd(Length(Value) - 4) then Exit;
  I := 5;
  while I < Length(Value) do
  begin
    if not TryStrToInt('$' + Copy(Value, I, 2), Code) or (Code = 0) then
      Exit('');
    Result := Result + Chr(Code);
    Inc(I, 2);
  end;
end;

procedure TMainForm.LoadRecentPaths;
var Ini: TIniFile; I: Integer; FileName: string;
begin
  Ini := TIniFile.Create(FOptionsPath);
  try
    for I := 0 to 9 do
    begin
      FileName := DecodeHistoryPath(Ini.ReadString('History', 'File' + IntToStr(I), ''));
      if (FileName <> '') and (FRecentFiles.IndexOf(FileName) < 0) then
        FRecentFiles.Add(FileName);
    end;
  finally Ini.Free; end;
end;

procedure TMainForm.SaveRecentPaths;
var Ini: TIniFile; I: Integer;
begin
  try
    Ini := TIniFile.Create(FOptionsPath);
    try
      Ini.EraseSection('History');
      for I := 0 to FRecentFiles.Count - 1 do
        Ini.WriteString('History', 'File' + IntToStr(I), EncodeHistoryPath(FRecentFiles[I]));
    finally Ini.Free; end;
  except
    on E: Exception do
      if FStatus <> nil then FStatus.SimpleText :=
        Format(Tr('Could not save recent files: %s'), [E.Message]);
  end;
end;

procedure TMainForm.RebuildRecentMenu;
var I: Integer; Item: TMenuItem; LabelText: string;
begin
  if FRecentMenu = nil then Exit;
  FRecentMenuDirty := False;
  FRecentMenu.Clear;
  for I := 0 to FRecentFiles.Count - 1 do
  begin
    LabelText := '&' + IntToStr((I + 1) mod 10) + ' ' +
      StringReplace(FRecentFiles[I], '&', '&&', [rfReplaceAll]);
    Item := AddMenu(FRecentMenu, LabelText, @RecentFileClick);
    Item.Tag := I;
  end;
  if FRecentFiles.Count > 0 then AddMenu(FRecentMenu, '-', nil);
  Item := AddMenu(FRecentMenu, '&Clear History', @ClearRecentClick);
  Item.Enabled := FRecentFiles.Count > 0;
end;

procedure TMainForm.RememberRecentPath(const FileName: string);
var FullName: string; Index: Integer;
begin
  if FileName = '' then Exit;
  FullName := ExpandFileName(FileName);
  Index := FRecentFiles.IndexOf(FullName);
  if Index = 0 then Exit;
  if Index >= 0 then FRecentFiles.Delete(Index);
  FRecentFiles.Insert(0, FullName);
  while FRecentFiles.Count > 10 do FRecentFiles.Delete(FRecentFiles.Count - 1);
  SaveRecentPaths;
  FRecentMenuDirty := True;
end;

procedure TMainForm.RecentFileClick(Sender: TObject);
var Index: Integer; FileName: string;
begin
  if FCompileActive or not (Sender is TMenuItem) then Exit;
  Index := TMenuItem(Sender).Tag;
  if (Index < 0) or (Index >= FRecentFiles.Count) then Exit;
  FileName := FRecentFiles[Index];
  if not FileExists(FileName) then
  begin
    UiMessageDlg(Format(Tr('File not found: %s'), [FileName]), mtInformation, [mbOK], 0);
    FRecentFiles.Delete(Index);
    SaveRecentPaths;
    FRecentMenuDirty := True;
    Exit;
  end;
  OpenDroppedFile(FileName);
end;

procedure TMainForm.ClearRecentClick(Sender: TObject);
begin
  FRecentFiles.Clear;
  SaveRecentPaths;
  FRecentMenuDirty := True;
end;

procedure TMainForm.ToggleBookmarkClick(Sender: TObject);
var Doc: TDocument; X, Y, Number: Integer;
begin
  Doc := CurrentDoc;
  if (Doc = nil) or not EditorHasFocus then Exit;
  if Sender is TMenuItem then Number := TMenuItem(Sender).Tag
  else Exit;
  if Doc.Editor.GetBookMark(Number, X, Y) then Doc.Editor.ClearBookMark(Number)
  else Doc.Editor.SetBookMark(Number, Doc.Editor.CaretX, Doc.Editor.CaretY);
  RefreshCommandStates(Self);
end;

procedure TMainForm.GotoBookmarkClick(Sender: TObject);
var Doc: TDocument;
begin
  Doc := CurrentDoc;
  if (Doc = nil) or not EditorHasFocus or not (Sender is TMenuItem) then Exit;
  Doc.Editor.GotoBookMark(TMenuItem(Sender).Tag);
  Doc.Editor.SetFocus;
  UpdateStatus;
end;

procedure TMainForm.StatusbarClick(Sender: TObject);
begin
  FStatus.Visible := not FStatus.Visible;
  FStatusbarItem.Checked := FStatus.Visible;
end;

procedure TMainForm.FullScreenClick(Sender: TObject);
begin
  if not FFullScreen then
  begin
    FNormalBounds := BoundsRect;
    FNormalWindowState := WindowState;
    FNormalBorderStyle := BorderStyle;
    WindowState := wsNormal;
    BorderStyle := bsNone;
    BoundsRect := Monitor.BoundsRect;
  end
  else
  begin
    BorderStyle := FNormalBorderStyle;
    BoundsRect := FNormalBounds;
    WindowState := FNormalWindowState;
  end;
  FFullScreen := not FFullScreen;
  FFullScreenItem.Checked := FFullScreen;
end;

procedure TMainForm.FocusCompilerLogClick(Sender: TObject);
begin
  HideCompletion;
  HideFunctionTip;
  FReportTabs.ActivePage := FLogTab;
  FOutput.SetFocus;
end;

procedure TMainForm.FocusEditorClick(Sender: TObject);
begin
  if CurrentDoc <> nil then CurrentDoc.Editor.SetFocus;
end;

procedure TMainForm.FormShown(Sender: TObject);
begin
  if (CurrentDoc <> nil) and CurrentDoc.Editor.CanFocus then
    CurrentDoc.Editor.SetFocus;
  RefreshCommandStates(Self);
end;

procedure TMainForm.InstanceTick(Sender: TObject);
var
  RequestedFiles: TStringList;
  RequestOrdinal: Integer;
  ActivateWindow: Boolean;
begin
  if FLoading or FCompileActive or DebuggerActive or (FDocumentDialogs <> 0) or
    (Application.ModalLevel <> 0) or not Enabled or not Visible then Exit;
  FInstanceTimer.Enabled := False;
  RequestedFiles := TStringList.Create;
  try
    ReadInstanceRequests(RequestedFiles, ActivateWindow);
    for RequestOrdinal := 0 to RequestedFiles.Count - 1 do
      OpenDroppedFile(RequestedFiles[RequestOrdinal]);
    if ActivateWindow then
    begin
      if WindowState = wsMinimized then WindowState := wsNormal;
      Show;
      BringToFront;
      if CurrentDoc <> nil then CurrentDoc.Editor.SetFocus;
    end;
  finally
    RequestedFiles.Free;
    FInstanceTimer.Enabled := True;
  end;
end;

procedure TMainForm.ChineseLanguageClick(Sender: TObject);
begin
  SetUiLanguage(ulChinese);
  ApplyUiLanguage(Self);
  FChineseLanguageItem.Checked := True;
  FEnglishLanguageItem.Checked := False;
  FCompletionList.Invalidate;
  if FDebugger <> nil then FDebugger.RefreshBreakpoints;
  UpdateStatus;
end;

procedure TMainForm.EnglishLanguageClick(Sender: TObject);
begin
  SetUiLanguage(ulEnglish);
  ApplyUiLanguage(Self);
  FChineseLanguageItem.Checked := False;
  FEnglishLanguageItem.Checked := True;
  FCompletionList.Invalidate;
  if FDebugger <> nil then FDebugger.RefreshBreakpoints;
  UpdateStatus;
end;

function TMainForm.CurrentDoc: TDocument;
var I: Integer;
begin
  Result := nil;
  if FPages.ActivePage = nil then Exit;
  for I := 0 to FDocs.Count - 1 do
    if TDocument(FDocs[I]).Tab = FPages.ActivePage then
      Exit(TDocument(FDocs[I]));
end;

function TMainForm.FindDoc(const FileName: string): TDocument;
var I: Integer;
begin
  Result := nil;
  for I := 0 to FDocs.Count - 1 do
    if (TDocument(FDocs[I]).FileName <> '') and
       SameDocumentPath(TDocument(FDocs[I]).FileName, FileName) then
      Exit(TDocument(FDocs[I]));
end;

procedure TMainForm.UpdateTab(Doc: TDocument);
begin
  if Doc.FileName = '' then Doc.Tab.Caption := Doc.UntitledName
  else Doc.Tab.Caption := ExtractFileName(Doc.FileName);
  if Doc.Dirty then Doc.Tab.Caption := Doc.Tab.Caption + ' *';
end;

procedure TMainForm.UpdateStatus;
var Doc: TDocument;
begin
  Doc := CurrentDoc;
  if Doc = nil then FStatus.SimpleText := Tr('Ready')
  else FStatus.SimpleText := Format(Tr('%s    Line: %d  Col: %d'), [Doc.FileName, Doc.Editor.CaretY, Doc.Editor.CaretX]);
end;

procedure TMainForm.EditorChanged(Sender: TObject);
var I: Integer;
begin
  if FLoading or (FDocs = nil) then Exit;
  FTipDoc := nil;
  FCompletionDismissed := False;
  for I := 0 to FDocs.Count - 1 do
    if TDocument(FDocs[I]).Editor = Sender then
    begin
      TDocument(FDocs[I]).PreferredColumn := 0;
      TDocument(FDocs[I]).Dirty := TDocument(FDocs[I]).Editor.Modified or
        TDocument(FDocs[I]).KeepBufferConflict;
      TDocument(FDocs[I]).ErrorLine := -1;
      UpdateDebugMarkers(TDocument(FDocs[I]));
      TDocument(FDocs[I]).Editor.Invalidate;
      UpdateTab(TDocument(FDocs[I]));
      Break;
    end;
  UpdateStatus;
end;

procedure TMainForm.EditorStatusChanged(Sender: TObject; Changes: TSynStatusChanges);
var I: Integer; Doc: TDocument;
begin
  { Modified notifications also arrive after Undo/Redo reaches the saved point.
    OnChange alone can run before the undo list updates this state. }
  if FLoading or (FDocs = nil) or not (scModified in Changes) then Exit;
  for I := 0 to FDocs.Count - 1 do
  begin
    Doc := TDocument(FDocs[I]);
    if Doc.Editor <> Sender then Continue;
    Doc.Dirty := Doc.Editor.Modified or Doc.KeepBufferConflict;
    UpdateTab(Doc);
    Break;
  end;
end;

procedure TMainForm.EditorSpecialLineColors(Sender: TObject; Line: Integer;
  var Special: Boolean; var FG, BG: TColor);
var
  DocOrdinal: Integer;
  PaintedDoc: TDocument;
begin
  for DocOrdinal := 0 to FDocs.Count - 1 do
  begin
    PaintedDoc := TDocument(FDocs[DocOrdinal]);
    if PaintedDoc.Editor <> Sender then Continue;
    if (FDebugger <> nil) and
      FDebugger.Session.HasBreakpoint(PaintedDoc.FileName, Line) then
    begin
      Special := True;
      FG := PaintedDoc.ThemeColors.BreakpointForeground;
      BG := PaintedDoc.ThemeColors.BreakpointBackground;
    end;
    if (FDebugLine = Line) and (PaintedDoc.FileName = FDebugFile) then
    begin
      Special := True;
      FG := PaintedDoc.ThemeColors.DebugForeground;
      BG := PaintedDoc.ThemeColors.DebugBackground;
    end;
    if PaintedDoc.ErrorLine = Line then
    begin
      Special := True;
      FG := PaintedDoc.ThemeColors.ErrorForeground;
      BG := PaintedDoc.ThemeColors.ErrorBackground;
    end;
    Exit;
  end;
end;

procedure TMainForm.FileWatchTick(Sender: TObject);
var
  I, Answer: Integer;
  Doc: TDocument;
  CurrentSnapshot: TFileSnapshot;
  Caret: TPoint;
  Lines: TStringList;
begin
  if FLoading or FCompileActive or DebuggerActive or (FDocumentDialogs <> 0) or
    (Application.ModalLevel <> 0) or not Enabled then Exit;
  FFileWatchTimer.Enabled := False;
  Inc(FDocumentDialogs);
  try
    for I := FDocs.Count - 1 downto 0 do
    begin
      Doc := TDocument(FDocs[I]);
      if Doc.FileName = '' then Continue;
      if FileSnapshotIsCurrent(Doc.FileName, Doc.SeenDiskSnapshot) then Continue;
      try
        CurrentSnapshot := CaptureFileSnapshot(Doc.FileName);
      except
        { A transient read/permission error must not discard the buffer. }
        Continue;
      end;
      if SameFileSnapshot(CurrentSnapshot, Doc.SeenDiskSnapshot) then
      begin
        Doc.SeenDiskSnapshot := CurrentSnapshot;
        Continue;
      end;
      Doc.SeenDiskSnapshot := CurrentSnapshot;
      if CurrentSnapshot.Present then
      begin
        Doc.MissingNotified := False;
        if SameFileSnapshot(CurrentSnapshot, Doc.DiskSnapshot) then Continue;
        FPages.ActivePage := Doc.Tab;
        Answer := UiMessageDlg(Format(Tr('%s was modified outside Dev-C++.' + LineEnding +
          'Reload it from disk? Unsaved changes will be lost.'),
          [ExtractFileName(Doc.FileName)]), mtConfirmation, [mbYes, mbNo], 0);
        if Answer = mrYes then
        begin
          Lines := TStringList.Create;
          try
            try
              LoadDocumentLines(Lines, Doc.FileName, CurrentSnapshot);
              Caret := Doc.Editor.LogicalCaretXY;
              FLoading := True;
              try
                Doc.Editor.Lines.Assign(Lines);
                Doc.Editor.ClearUndo;
                Doc.DiskSnapshot := CurrentSnapshot;
                Doc.SeenDiskSnapshot := CurrentSnapshot;
                Doc.Dirty := False;
                Doc.KeepBufferConflict := False;
                Doc.Editor.Modified := False;
                Caret.Y := Max(1, Min(Caret.Y, Doc.Editor.Lines.Count));
                if Doc.Editor.Lines.Count > 0 then
                  Caret.X := Max(1, Min(Caret.X,
                    Length(Doc.Editor.Lines[Caret.Y - 1]) + 1))
                else Caret.X := 1;
                Doc.Editor.LogicalCaretXY := Caret;
              finally
                FLoading := False;
              end;
            except
              on E: Exception do UiMessageDlg(E.Message, mtError, [mbOK], 0);
            end;
          finally
            Lines.Free;
          end;
        end
        else
        begin
          Doc.KeepBufferConflict := True;
          Doc.Dirty := True;
        end;
        UpdateTab(Doc);
        UpdateStatus;
        Continue;
      end;
      if Doc.MissingNotified then Continue;
      Doc.MissingNotified := True;
      Answer := UiMessageDlg(Format(Tr('%s was deleted outside Dev-C++.' + LineEnding +
        'Keep the file in the editor?'), [ExtractFileName(Doc.FileName)]), mtConfirmation, [mbYes, mbNo], 0);
      if Answer <> mrNo then
      begin
        Doc.KeepBufferConflict := True;
        Doc.Dirty := True;
        UpdateTab(Doc);
      end
      else if MayClose(Doc) then DisposeDocument(Doc);
    end;
  finally
    Dec(FDocumentDialogs);
    FFileWatchTimer.Enabled := True;
  end;
end;

procedure TMainForm.EditorClicked(Sender: TObject);
var I: Integer;
begin
  FHomeAtIndent := False;
  HideCompletion;
  FCompletionDismissed := False;
  for I := 0 to FDocs.Count - 1 do
    if TDocument(FDocs[I]).Editor = Sender then
    begin
      TDocument(FDocs[I]).PreferredColumn := 0;
      UpdateFunctionTip(TDocument(FDocs[I]));
      Break;
    end;
end;

procedure TMainForm.EditorKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  Doc: TDocument;
  SourceLine: string;
  Trigger: Char;
  LogicalCol: Integer;
begin
  UpdateStatus;
  Doc := CurrentDoc;
  if (Doc = nil) or (Doc.Editor <> Sender) then Exit;
  if Key = VK_HOME then Doc.PreferredColumn := 0;
  if Key = VK_ESCAPE then HideFunctionTip
  else UpdateFunctionTip(Doc);
  if FCompletionDismissed or (Key = VK_ESCAPE) then Exit;
  if FCompletionForm.Visible and (FCompletionDoc = Doc) then
  begin
    if Key in [VK_UP, VK_DOWN, VK_ESCAPE, VK_RETURN] then Exit;
    ShowCompletion(Doc, FCompletionAfterMember);
    Exit;
  end;
  if (Doc.Editor.CaretY < 1) or (Doc.Editor.CaretY > Doc.Editor.Lines.Count) then Exit;
  SourceLine := Doc.Editor.Lines[Doc.Editor.CaretY - 1];
  LogicalCol := Doc.Editor.LogicalCaretXY.X;
  if (LogicalCol <= 1) or (LogicalCol - 1 > Length(SourceLine)) then Exit;
  Trigger := SourceLine[LogicalCol - 1];
  if not (Trigger in ['.', '>', ':']) then Exit;
  if Trigger in ['>', ':'] then
  begin
    if LogicalCol <= 2 then Exit;
    if (Trigger = '>') and (SourceLine[LogicalCol - 2] <> '-') then Exit;
    if (Trigger = ':') and (SourceLine[LogicalCol - 2] <> ':') then Exit;
  end;
  ShowCompletion(Doc, True);
end;

procedure TMainForm.EditorMouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
var
  I, NewSize: Integer;
begin
  if not (ssCtrl in Shift) or (WheelDelta = 0) then Exit;
  NewSize := FEditorFontSize;
  if WheelDelta > 0 then Inc(NewSize) else Dec(NewSize);
  NewSize := Max(1, Min(72, NewSize));
  if NewSize <> FEditorFontSize then
  begin
    FEditorFontSize := NewSize;
    for I := 0 to FDocs.Count - 1 do
      TDocument(FDocs[I]).Editor.Font.Size := NewSize;
  end;
  Handled := True;
end;

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  Modifiers: TShiftState;

  procedure Dispatch(Handler: TNotifyEvent);
  begin
    if CommandAvailable(Handler) then Handler(Self);
    Key := 0;
  end;

  procedure DispatchBookmark(Number: Integer; Jump: Boolean);
  var I: Integer; Item: TMenuItem;
  begin
    if not EditorHasFocus then Exit;
    for I := 0 to ComponentCount - 1 do
      if Components[I] is TMenuItem then
      begin
        Item := TMenuItem(Components[I]);
        if Item.Tag <> Number then Continue;
        if Jump and SameHandler(Item.OnClick, @GotoBookmarkClick) then
        begin GotoBookmarkClick(Item); Break; end;
        if not Jump and SameHandler(Item.OnClick, @ToggleBookmarkClick) then
        begin ToggleBookmarkClick(Item); Break; end;
      end;
    Key := 0;
  end;

begin
  Modifiers := Shift * [ssCtrl, ssShift, ssAlt];
  if (Key >= Ord('1')) and (Key <= Ord('9')) then
  begin
    if Modifiers = [ssCtrl] then
    begin DispatchBookmark(Key - Ord('0'), False); Exit; end;
    if Modifiers = [ssAlt] then
    begin DispatchBookmark(Key - Ord('0'), True); Exit; end;
  end;
  if Modifiers = [ssCtrl] then
  begin
    case Key of
      Ord('N'): Dispatch(@NewClick);
      Ord('O'): Dispatch(@OpenClick);
      Ord('S'): Dispatch(@SaveClick);
      Ord('W'): Dispatch(@CloseClick);
      Ord('F'): Dispatch(@FindClick);
      Ord('G'): Dispatch(@GotoClick);
      Ord('H'): Dispatch(@ProjectOptionsClick);
      Ord('R'): Dispatch(@ReplaceClick);
      Ord('Q'): Dispatch(@SwapHeaderSourceClick);
      Ord('Y'): Dispatch(@RedoClick);
      Ord('Z'): Dispatch(@UndoClick);
      Ord('X'): Dispatch(@CutClick);
      Ord('C'): Dispatch(@CopyClick);
      Ord('V'): Dispatch(@PasteClick);
      Ord('A'): Dispatch(@SelectAllClick);
      Ord('B'): Dispatch(@OpenFolderClick);
      Ord('D'): Dispatch(@DeleteLineClick);
      Ord('E'): Dispatch(@DuplicateLineClick);
      VK_F9: Dispatch(@SyntaxClick);
      VK_F11: Dispatch(@FullScreenClick);
      VK_SPACE: Dispatch(@CompletionClick);
      47, 191: Dispatch(@ToggleCommentClick);
      59, 186: Dispatch(@InlineCommentClick);
      44, 188: Dispatch(@UncommentClick);
      46, 190: Dispatch(@CommentClick);
      VK_TAB: Dispatch(@NextTabClick);
    end;
  end
  else if Modifiers = [ssCtrl, ssShift] then
  begin
    case Key of
      Ord('S'): Dispatch(@SaveAsClick);
      Ord('W'): Dispatch(@CloseAllClick);
      Ord('A'): Dispatch(@SaveAllClick);
      Ord('X'): Dispatch(@SyntaxClick);
      Ord('R'): Dispatch(@ReplaceAllClick);
      Ord('F'): Dispatch(@FindAllClick);
      VK_TAB: Dispatch(@PreviousTabClick);
      VK_UP: Dispatch(@MoveSelectionUpClick);
      VK_DOWN: Dispatch(@MoveSelectionDownClick);
    end;
  end
  else if Modifiers = [] then
  begin
    case Key of
      VK_F4: Dispatch(@DebugToggleBreakpointClick);
      VK_F5: Dispatch(@DebugStartClick);
      VK_F6: Dispatch(@DebugStopClick);
      VK_F7: Dispatch(@DebugStepOverClick);
      VK_F8: Dispatch(@DebugStepIntoClick);
      VK_F3: Dispatch(@FindNextClick);
      VK_F9: Dispatch(@CompileClick);
      VK_F10: Dispatch(@RunClick);
      VK_F11: Dispatch(@CompileRunClick);
      VK_F12: Dispatch(@CompileClick);
    end;
  end
  else if (Modifiers = [ssShift]) and (Key = VK_F3) then
    Dispatch(@FindPreviousClick)
  else if Modifiers = [ssCtrl, ssAlt] then
    case Key of
      Ord('O'): Dispatch(@CompilerOptionsClick);
      Ord('L'): Dispatch(@FocusCompilerLogClick);
      Ord('E'): Dispatch(@FocusEditorClick);
    end;
end;

procedure TMainForm.OpenDroppedFile(const DroppedPath: string);
begin
  if FCompileActive or DebuggerActive then Exit;
  if not FileExists(DroppedPath) then Exit;
  if LowerCase(ExtractFileExt(DroppedPath)) = '.dev' then
    OpenProject(DroppedPath)
  else
    OpenFile(DroppedPath);
end;

procedure TMainForm.FilesDropped(Sender: TObject;
  const FileNames: array of string);
var
  I: Integer;
begin
  for I := Low(FileNames) to High(FileNames) do
    OpenDroppedFile(FileNames[I]);
end;

procedure TMainForm.EditorFilesDropped(Sender: TObject; X, Y: Integer;
  AFiles: TStrings);
var
  I: Integer;
begin
  for I := 0 to AFiles.Count - 1 do
    OpenDroppedFile(AFiles[I]);
end;

procedure TMainForm.EditorMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  SourceDoc, CandidateDoc, TargetDoc: TDocument;
  ClickPos: TPoint;
  SourceBuffer, SymbolName, HeaderName, HeaderPath, CandidatePath: string;
  TargetPath: string;
  I, StartPos, EndPos, CandidateRow, CandidateCol, CandidateScore: Integer;
  BestRow, BestCol, BestScore: Integer;
  Delimiter: Char;
  HeaderLines: TStringList;

  procedure ConsiderText(const CandidateText, APath: string;
    ADoc: TDocument; ExcludeRow: Integer);
  begin
    if DefinitionInText(CandidateText, SymbolName, ExcludeRow,
      CandidateRow, CandidateCol, CandidateScore) and
      (CandidateScore > BestScore) then
    begin
      BestScore := CandidateScore;
      BestRow := CandidateRow;
      BestCol := CandidateCol;
      TargetPath := APath;
      TargetDoc := ADoc;
    end;
  end;

  procedure ConsiderFile(const APath: string);
  begin
    if (APath = '') or not FileExists(APath) then Exit;
    try
      HeaderLines.LoadFromFile(APath);
      ConsiderText(HeaderLines.Text, APath, nil, 0);
    except
      { A missing or unreadable optional source file must not break the editor. }
    end;
  end;

begin
  if (Button <> mbLeft) or not (ssCtrl in Shift) then Exit;
  SourceDoc := CurrentDoc;
  if (SourceDoc = nil) or (SourceDoc.Editor <> Sender) then Exit;
  ClickPos := SourceDoc.Editor.PixelsToLogicalPos(Point(X, Y));
  if (ClickPos.Y < 1) or (ClickPos.Y > SourceDoc.Editor.Lines.Count) then Exit;
  SourceBuffer := SourceDoc.Editor.Lines[ClickPos.Y - 1];
  if Pos('#include', TrimLeft(SourceBuffer)) = 1 then
  begin
    StartPos := Pos('"', SourceBuffer);
    Delimiter := '"';
    if StartPos = 0 then
    begin
      StartPos := Pos('<', SourceBuffer);
      Delimiter := '>';
    end;
    if StartPos > 0 then
    begin
      EndPos := Pos(Delimiter, Copy(SourceBuffer, StartPos + 1, MaxInt));
      if EndPos > 0 then
      begin
        Inc(EndPos, StartPos);
        if (ClickPos.X >= StartPos) and (ClickPos.X <= EndPos) then
        begin
          HeaderName := Copy(SourceBuffer, StartPos + 1,
            EndPos - StartPos - 1);
          HeaderPath := '';
          if SourceDoc.FileName <> '' then
            HeaderPath := ExtractFilePath(SourceDoc.FileName) + HeaderName;
          if not FileExists(HeaderPath) then
            HeaderPath := '/usr/include/' + HeaderName;
          if not FileExists(HeaderPath) then
            HeaderPath := '/usr/local/include/' + HeaderName;
          if not FileExists(HeaderPath) then
            HeaderPath := '/usr/include/c++/9/' + HeaderName;
          if not FileExists(HeaderPath) then
            HeaderPath := '/usr/include/x86_64-linux-gnu/c++/9/' + HeaderName;
          if FileExists(HeaderPath) then OpenFile(HeaderPath);
          Exit;
        end;
      end;
    end;
  end;
  SymbolName := IdentifierAt(SourceBuffer, ClickPos.X);
  if (SymbolName = '') and (ClickPos.X > 1) then
    SymbolName := IdentifierAt(SourceBuffer, ClickPos.X - 1);
  if SymbolName = '' then Exit;
  HeaderLines := TStringList.Create;
  try
    TargetDoc := nil;
    TargetPath := '';
    BestScore := 0;
    BestRow := 0;
    BestCol := 0;
    ConsiderText(SourceDoc.Editor.Lines.Text, SourceDoc.FileName,
      SourceDoc, ClickPos.Y);
    for I := 0 to FDocs.Count - 1 do
    begin
      CandidateDoc := TDocument(FDocs[I]);
      if CandidateDoc <> SourceDoc then
        ConsiderText(CandidateDoc.Editor.Lines.Text, CandidateDoc.FileName,
          CandidateDoc, 0);
    end;
    for I := 0 to FProjectFiles.Count - 1 do
      if FindDoc(FProjectFiles[I]) = nil then
        ConsiderFile(FProjectFiles[I]);
    for I := 0 to SourceDoc.Editor.Lines.Count - 1 do
    begin
      SourceBuffer := Trim(SourceDoc.Editor.Lines[I]);
      if Pos('#include', SourceBuffer) <> 1 then Continue;
      StartPos := Pos('"', SourceBuffer);
      if StartPos = 0 then Continue;
      EndPos := Pos('"', Copy(SourceBuffer, StartPos + 1, MaxInt));
      if EndPos = 0 then Continue;
      CandidatePath := ExtractFilePath(SourceDoc.FileName) +
        Copy(SourceBuffer, StartPos + 1, EndPos - 1);
      ConsiderFile(CandidatePath);
    end;
    if BestScore = 0 then Exit;
    if TargetDoc = nil then
    begin
      OpenFile(TargetPath);
      TargetDoc := CurrentDoc;
    end
    else
      FPages.ActivePage := TargetDoc.Tab;
    if TargetDoc = nil then Exit;
    TargetDoc.Editor.LogicalCaretXY := Point(BestCol, BestRow);
    if BestRow > 5 then TargetDoc.Editor.TopLine := BestRow - 5;
    TargetDoc.Editor.SetFocus;
    UpdateStatus;
  finally HeaderLines.Free; end;
end;

procedure TMainForm.EditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  Doc: TDocument;
begin
  Doc := CurrentDoc;
  if (Doc = nil) or (Doc.Editor <> Sender) then Exit;
  if Key <> VK_HOME then FHomeAtIndent := False;
  FormKeyDown(Sender, Key, Shift);
  if Key = 0 then Exit;
  if FCompletionForm.Visible and (FCompletionDoc = Doc) and
    (Key in [VK_ESCAPE, VK_RETURN]) then
  begin
    CompletionKeyDown(Sender, Key, Shift);
    Exit;
  end;
  if FCompletionForm.Visible and (FCompletionDoc = Doc) and
    (Key in [VK_UP, VK_DOWN]) and
    ((Shift * [ssCtrl, ssShift, ssAlt]) = []) then
  begin
    if (Key = VK_UP) and (FCompletionList.ItemIndex > 0) then
      FCompletionList.ItemIndex := FCompletionList.ItemIndex - 1
    else if (Key = VK_DOWN) and
      (FCompletionList.ItemIndex < FCompletionList.Items.Count - 1) then
      FCompletionList.ItemIndex := FCompletionList.ItemIndex + 1;
    Key := 0;
    Exit;
  end;
  if (Key <> VK_SPACE) or not (ssCtrl in Shift) then Exit;
  Key := 0;
  ShowCompletion(Doc, False);
end;

procedure TMainForm.EditorProcessCommand(Sender: TObject;
  var Command: TSynEditorCommand; var AChar: TUTF8Char; Data: Pointer);
var
  Doc: TDocument;
  P, SelectionAnchor, TargetPoint: TPoint;
  LineText, Prefix, Suffix, TrimmedPrefix, TrimmedSuffix: string;
  BaseIndent, NewIndent: string;
  StartColumn, EndColumn, TargetRow: Integer;
begin
  Doc := CurrentDoc;
  if (Doc = nil) or (Doc.Editor <> Sender) then Exit;
  { SynEdit invokes this hook before its own ReadOnly check. Our custom
    SelText edits must obey the same lock while navigation stays available. }
  if (Doc.Editor.ReadOnly or FCompileActive or DebuggerActive) and
    ((Command = ecTab) or (Command = ecLineBreak) or
      (Command = ecDeleteLastWord) or (Command = ecDeleteLastChar) or
      (Command = ecDeleteChar)) then
  begin
    { Also skip SynEdit's beautifier hooks, which run before ExecuteCommand. }
    Command := ecNone;
    Exit;
  end;
  if not (Command in [ecUp, ecDown, ecSelUp, ecSelDown]) then
    Doc.PreferredColumn := 0;
  if Doc.Editor.SelAvail and
    not (Command in [ecLineStart, ecSelLineStart, ecUp, ecDown, ecSelUp, ecSelDown]) then Exit;
  if Command = ecTab then
  begin
    Command := ecNone;
    Doc.Editor.SelText := #9;
    Exit;
  end;
  P := Doc.Editor.LogicalCaretXY;
  if (P.Y < 1) or (P.Y > Doc.Editor.Lines.Count) then Exit;
  LineText := Doc.Editor.Lines[P.Y - 1];
  if Command in [ecUp, ecDown, ecSelUp, ecSelDown] then
  begin
    SelectionAnchor := P;
    if Doc.Editor.SelAvail then
      if (P.X = Doc.Editor.BlockBegin.X) and
        (P.Y = Doc.Editor.BlockBegin.Y) then
        SelectionAnchor := Doc.Editor.BlockEnd
      else SelectionAnchor := Doc.Editor.BlockBegin;
    if Doc.PreferredColumn = 0 then
      Doc.PreferredColumn := Doc.Editor.CaretX;
    TargetRow := P.Y;
    if Command in [ecUp, ecSelUp] then Dec(TargetRow) else Inc(TargetRow);
    if (TargetRow >= 1) and (TargetRow <= Doc.Editor.Lines.Count) then
    begin
      Doc.Editor.LogicalCaretXY := Point(1, TargetRow);
      Doc.Editor.CaretX := Min(Doc.PreferredColumn,
        VisualLineLength(Doc.Editor.Lines[TargetRow - 1],
          Doc.Editor.TabWidth) + 1);
      TargetPoint := Doc.Editor.LogicalCaretXY;
      if Command in [ecSelUp, ecSelDown] then
        Doc.Editor.BlockBegin := SelectionAnchor
      else Doc.Editor.BlockBegin := TargetPoint;
      Doc.Editor.BlockEnd := TargetPoint;
      Doc.Editor.LogicalCaretXY := TargetPoint;
    end;
    Command := ecNone;
    Exit;
  end;
  if Command in [ecLineStart, ecSelLineStart] then
  begin
    TNoiSynEdit(Doc.Editor).MoveHome(Command = ecSelLineStart);
    Command := ecNone;
    Exit;
  end;
  if Command = ecLineBreak then
  begin
    Command := ecNone;
    Prefix := Copy(LineText, 1, P.X - 1);
    Suffix := Copy(LineText, P.X, MaxInt);
    TrimmedPrefix := TrimRight(Prefix);
    TrimmedSuffix := TrimLeft(Suffix);
    BaseIndent := TabIndentOf(Prefix);
    NewIndent := BaseIndent;
    if (Length(TrimmedPrefix) > 0) and
      (TrimmedPrefix[Length(TrimmedPrefix)] = '{') then
      NewIndent := NewIndent + #9;
    if (Length(TrimmedPrefix) > 0) and
      (TrimmedPrefix[Length(TrimmedPrefix)] = ':') and
      ((Copy(TrimLeft(TrimmedPrefix), 1, 5) = 'case ') or
       (Copy(TrimLeft(TrimmedPrefix), 1, 5) = 'case'#9) or
       (Copy(TrimLeft(TrimmedPrefix), 1, 8) = 'default:')) then
      NewIndent := NewIndent + #9;
    if (NewIndent <> BaseIndent) and (Length(TrimmedSuffix) > 0) and
      (TrimmedSuffix[1] = '}') then
    begin
      Doc.Editor.SelText := LineEnding + NewIndent + LineEnding + BaseIndent;
      Doc.Editor.LogicalCaretXY := Point(Length(NewIndent) + 1, P.Y + 1);
    end
    else
      Doc.Editor.SelText := LineEnding + NewIndent;
    Exit;
  end;
  if Command = ecDeleteLastWord then
  begin
    if (P.X > 1) and (P.X <= Length(LineText)) and
      (LineText[P.X - 1] = '(') and (LineText[P.X] = ')') then
    begin
      StartColumn := P.X - 1;
      while (StartColumn > 1) and
        (LineText[StartColumn - 1] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do
        Dec(StartColumn);
      Command := ecNone;
      Doc.Editor.BlockBegin := Point(StartColumn, P.Y);
      Doc.Editor.BlockEnd := Point(P.X + 1, P.Y);
      Doc.Editor.SelText := '';
    end;
    Exit;
  end;
  if Command = ecDeleteLastChar then
  begin
    StartColumn := P.X - 1;
    EndColumn := P.X + 1;
  end
  else if Command = ecDeleteChar then
  begin
    StartColumn := P.X;
    EndColumn := P.X + 2;
  end
  else Exit;
  if (StartColumn < 1) or (EndColumn - 1 > Length(LineText)) then Exit;
  if not IsBracketPair(LineText[StartColumn], LineText[StartColumn + 1]) then
    if not ((LineText[StartColumn] = '<') and
      (LineText[StartColumn + 1] = '>') and
      IsIncludePrefix(Copy(LineText, 1, StartColumn - 1))) then Exit;
  if (LineText[StartColumn] = '{') and
    IsTypeHeader(Copy(LineText, 1, StartColumn - 1)) and
    (StartColumn + 2 <= Length(LineText)) and
    (LineText[StartColumn + 2] = ';') then Inc(EndColumn);
  Command := ecNone;
  Doc.Editor.BlockBegin := Point(StartColumn, P.Y);
  Doc.Editor.BlockEnd := Point(EndColumn, P.Y);
  Doc.Editor.SelText := '';
end;

procedure TMainForm.EditorKeyPress(Sender: TObject; var Key: Char);
var
  Doc: TDocument;
  Closing: Char;
  PosBefore: TPoint;
  LineText, SelectedText, ClosingText, IncludePrefix: string;
  Context: TCppEditContext;
  SlashColumn, SlashCount: Integer;
begin
  Doc := CurrentDoc;
  if (Doc = nil) or (Doc.Editor <> Sender) then Exit;
  if Doc.Editor.ReadOnly or FCompileActive or DebuggerActive then
  begin
    Key := #0;
    Exit;
  end;
  if (Key = #27) and FCompletionForm.Visible and
    (FCompletionDoc = Doc) then
  begin
    FCompletionDismissed := True;
    HideCompletion;
    Key := #0;
    Exit;
  end;
  if not (Key in ['(', '[', '{', '<', '''', '"', ')', ']', '}', '>']) then Exit;
  Closing := #0;
  PosBefore := Doc.Editor.LogicalCaretXY;
  if (PosBefore.Y >= 1) and (PosBefore.Y <= Doc.Editor.Lines.Count) then
    LineText := Doc.Editor.Lines[PosBefore.Y - 1]
  else LineText := '';
  Context := CppContextAt(Doc.Editor, PosBefore);
  if not Doc.Editor.SelAvail then
  begin
    if (Key = '''') and (Context = cecCode) and
      CppNumericSeparatorPrefix(LineText, PosBefore.X) then Exit;
    if ((Key = '"') and (Context = cecDoubleQuote)) or
       ((Key = '''') and (Context = cecSingleQuote)) then
    begin
      SlashCount := 0;
      SlashColumn := PosBefore.X - 1;
      while (SlashColumn > 0) and (LineText[SlashColumn] = '\') do
      begin Inc(SlashCount); Dec(SlashColumn); end;
      if (SlashCount mod 2 = 0) and (PosBefore.X <= Length(LineText)) and
        (LineText[PosBefore.X] = Key) then
      begin
        Doc.Editor.LogicalCaretXY := Point(PosBefore.X + 1, PosBefore.Y);
        Key := #0;
        Exit;
      end;
    end;
    { Brackets and quotes typed inside comments/literals are ordinary text. }
    if Context <> cecCode then Exit;
  end;
  case Key of
    '(': Closing := ')';
    '[': Closing := ']';
    '{': Closing := '}';
    '''': Closing := '''';
    '"': Closing := '"';
    '<':
      begin
        IncludePrefix := Trim(Copy(LineText, 1, PosBefore.X - 1));
        if IsIncludePrefix(IncludePrefix) then Closing := '>';
      end;
  end;
  if Closing <> #0 then
  begin
    if (Key in ['''', '"']) and not Doc.Editor.SelAvail then
    begin
      PosBefore := Doc.Editor.LogicalCaretXY;
      if (PosBefore.Y >= 1) and (PosBefore.Y <= Doc.Editor.Lines.Count) then
      begin
        LineText := Doc.Editor.Lines[PosBefore.Y - 1];
        if (PosBefore.X > 1) and (LineText[PosBefore.X - 1] = '\') then Exit;
      end;
    end;
    if Doc.Editor.SelAvail then
    begin
      SelectedText := Doc.Editor.SelText;
      Doc.Editor.SelText := string(Key) + SelectedText + Closing;
      Key := #0;
      Exit;
    end;
    PosBefore := Doc.Editor.LogicalCaretXY;
    if (PosBefore.Y >= 1) and (PosBefore.Y <= Doc.Editor.Lines.Count) then
      LineText := Doc.Editor.Lines[PosBefore.Y - 1]
    else LineText := '';
    ClosingText := Closing;
    if (Key = '{') and IsTypeHeader(Copy(LineText, 1, PosBefore.X - 1)) then
      ClosingText := '};';
    if (PosBefore.X <= Length(LineText)) and
      (LineText[PosBefore.X] = Closing) then
      Doc.Editor.SelText := string(Key)
    else
      Doc.Editor.SelText := string(Key) + ClosingText;
    Doc.Editor.LogicalCaretXY := Point(PosBefore.X + 1, PosBefore.Y);
    Key := #0;
  end
  else if Key in [')', ']', '}', '>'] then
  begin
    if (Doc.Editor.CaretY < 1) or
      (Doc.Editor.CaretY > Doc.Editor.Lines.Count) then Exit;
    LineText := Doc.Editor.Lines[Doc.Editor.CaretY - 1];
    PosBefore := Doc.Editor.LogicalCaretXY;
    if (Key = '>') and
      not IsIncludePrefix(Copy(LineText, 1, Pos('<', LineText) - 1)) then Exit;
    if (PosBefore.X <= Length(LineText)) and
      (LineText[PosBefore.X] = Key) then
    begin
      Doc.Editor.LogicalCaretXY := Point(PosBefore.X + 1, PosBefore.Y);
      Key := #0;
    end;
  end;
end;

procedure TMainForm.ShowCompletion(Doc: TDocument; AfterMember: Boolean);
var
  SourceLine, Prefix: string;
  StartPos, NameEnd, LogicalCol: Integer;
  P: TPoint;
begin
  if (Doc = nil) or Doc.Editor.ReadOnly or FCompileActive or DebuggerActive then
  begin
    HideCompletion;
    Exit;
  end;
  HideFunctionTip;
  FCompletionDoc := Doc;
  Prefix := '';
  FCompletionMemberName := '';
  FCompletionAfterMember := AfterMember;
  if (Doc.Editor.CaretY >= 1) and
    (Doc.Editor.CaretY <= Doc.Editor.Lines.Count) then
  begin
    SourceLine := Doc.Editor.Lines[Doc.Editor.CaretY - 1];
    LogicalCol := Doc.Editor.LogicalCaretXY.X;
    StartPos := LogicalCol - 1;
    while (StartPos >= 1) and (StartPos <= Length(SourceLine)) and
      (SourceLine[StartPos] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do
      Dec(StartPos);
    Prefix := Copy(SourceLine, StartPos + 1, LogicalCol - StartPos - 1);
    NameEnd := 0;
    if (StartPos >= 1) and (StartPos <= Length(SourceLine)) then
    begin
      if SourceLine[StartPos] = '.' then NameEnd := StartPos - 1
      else if (StartPos >= 2) and (SourceLine[StartPos] = '>') and
        (SourceLine[StartPos - 1] = '-') then NameEnd := StartPos - 2
      else if (StartPos >= 2) and (SourceLine[StartPos] = ':') and
        (SourceLine[StartPos - 1] = ':') then NameEnd := StartPos - 2;
    end;
    if NameEnd > 0 then
    begin
      FCompletionAfterMember := True;
      FCompletionMemberName := MemberBaseName(SourceLine, NameEnd);
    end;
  end;
  P := Doc.Editor.RowColumnToPixels(Doc.Editor.CaretXY);
  Inc(P.Y, Doc.Editor.LineHeight + 2);
  P := Doc.Editor.ClientToScreen(P);
  PopulateCompletion(Prefix);
  if FCompletionList.Items.Count = 0 then
  begin HideCompletion; Exit; end;
  FCompletionForm.HandleNeeded;
  FCompletionList.Canvas.Font.Assign(FCompletionList.Font);
  FCompletionList.ItemHeight := FCompletionList.Canvas.TextHeight('Ag') + 2;
  FCompletionForm.ClientHeight :=
    Min(10, FCompletionList.Items.Count) * FCompletionList.ItemHeight + 2;
  if P.X + FCompletionForm.Width > Screen.Width then
    P.X := P.X - FCompletionForm.Width;
  if P.Y + FCompletionForm.Height > Screen.Height then
    P.Y := P.Y - FCompletionForm.Height - Doc.Editor.LineHeight;
  FCompletionForm.Left := P.X;
  FCompletionForm.Top := P.Y;
  FCompletionForm.Show;
  Doc.Editor.SetFocus;
end;

procedure TMainForm.PopulateCompletion(const Prefix: string);
const
  CppWords = 'alignas alignof auto bool break case catch char class const constexpr ' +
    'continue decltype default delete do double else enum explicit extern false ' +
    'float for friend goto if inline int long namespace new nullptr operator ' +
    'private protected public return short signed sizeof static struct switch ' +
    'template this throw true try typedef typename union unsigned using virtual ' +
    'void volatile while include define endif std string vector map set pair ' +
    'size_t begin end push_back emplace_back cout cin endl sort lower_bound';
var
  Doc: TDocument;
  Candidates: TStringList;
  Keywords: TStringList;
  Members: TStringList;
  SourceLine, Candidate: string;
  I, J, StartPos: Integer;

  procedure AddCandidate(const Value, Kind: string);
  var DisplayValue, DisplayKind: string;
  begin
    if (Value <> '') and ((Prefix = '') or
      (Copy(LowerCase(Value), 1, Length(Prefix)) = LowerCase(Prefix))) and
      (Candidates.Count < 600) then
    begin
      DisplayValue := Value;
      DisplayKind := Kind;
      if (Kind = 'function') or (Kind = 'function0') then
      begin
        DisplayValue := FTipSignatures.Values[Value];
        if DisplayValue = '' then DisplayValue := Value + '()';
      end
      else if (Kind = 'symbol') and
        (FTipSignatures.Values[Value] <> '') then
      begin
        DisplayValue := FTipSignatures.Values[Value];
        DisplayKind := 'function';
      end;
      if Length(DisplayValue) > 72 then
        DisplayValue := Copy(DisplayValue, 1, 69) + '...';
      Candidates.Add(DisplayValue);
      FCompletionKinds.Values[DisplayValue] := DisplayKind;
    end;
  end;

begin
  Doc := FCompletionDoc;
  if Doc = nil then Exit;
  Candidates := TStringList.Create;
  Keywords := TStringList.Create;
  Members := TStringList.Create;
  try
    Candidates.Sorted := True;
    Candidates.Duplicates := dupIgnore;
    FCompletionKinds.Clear;
    EnsureFunctionSignatures(Doc);
    if FCompletionAfterMember then
    begin
      if FCompletionMemberName <> '' then
        CollectCppMembers(Doc.Editor.Lines.Text, FCompletionMemberName,
          Members, Doc.FileName);
      for I := 0 to Members.Count - 1 do
        AddCandidate(Members.Names[I], Members.ValueFromIndex[I]);
    end
    else
    begin
      Keywords.Delimiter := ' ';
      Keywords.StrictDelimiter := True;
      Keywords.DelimitedText := CppWords;
      for I := 0 to Keywords.Count - 1 do AddCandidate(Keywords[I], 'keyword');
      for I := 0 to Doc.Editor.Lines.Count - 1 do
      begin
        SourceLine := Doc.Editor.Lines[I];
        J := 1;
        while J <= Length(SourceLine) do
        begin
          if SourceLine[J] in ['A'..'Z', 'a'..'z', '_'] then
          begin
            StartPos := J;
            Inc(J);
            while (J <= Length(SourceLine)) and
              (SourceLine[J] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do Inc(J);
            Candidate := Copy(SourceLine, StartPos, J - StartPos);
            if Length(Candidate) >= 2 then AddCandidate(Candidate, 'symbol');
          end
          else Inc(J);
        end;
        if Candidates.Count >= 600 then Break;
      end;
    end;
    FCompletionList.Items.Assign(Candidates);
    if FCompletionList.Items.Count > 0 then FCompletionList.ItemIndex := 0;
  finally
    Members.Free;
    Keywords.Free;
    Candidates.Free;
  end;
end;

procedure TMainForm.HideCompletion;
begin
  if FCompletionForm.Visible then FCompletionForm.Hide;
end;

procedure TMainForm.EnsureFunctionSignatures(Doc: TDocument);
begin
  if Doc = nil then Exit;
  if FTipDoc = Doc then Exit;
  FTipDoc := Doc;
  CollectCppFunctionSignatures(Doc.Editor.Lines.Text, FTipSignatures,
    Doc.FileName);
end;

procedure TMainForm.HideFunctionTip;
begin
  if FTipForm.Visible then FTipForm.Hide;
end;

procedure TMainForm.UpdateFunctionTip(Doc: TDocument);
var
  SourceBefore, FunctionName, SourceLine, ContextPrefix: string;
  Row, I, J, OpenPos, EndName, Depth, ActiveParam, ContextStart: Integer;
  CaretPos, ScreenPos: TPoint;
begin
  if (Doc = nil) or FCompletionForm.Visible then
  begin
    HideFunctionTip;
    Exit;
  end;
  CaretPos := Doc.Editor.LogicalCaretXY;
  if (CaretPos.Y < 1) or (CaretPos.Y > Doc.Editor.Lines.Count) then
  begin
    HideFunctionTip;
    Exit;
  end;
  SourceBefore := '';
  for Row := Max(1, CaretPos.Y - 5) to CaretPos.Y do
  begin
    SourceLine := Doc.Editor.Lines[Row - 1];
    if Row = CaretPos.Y then SourceLine := Copy(SourceLine, 1, CaretPos.X - 1);
    SourceBefore := SourceBefore + SourceLine + LineEnding;
  end;
  Depth := 0;
  OpenPos := 0;
  for I := Length(SourceBefore) downto 1 do
  begin
    if SourceBefore[I] = ')' then Inc(Depth)
    else if SourceBefore[I] = '(' then
    begin
      if Depth = 0 then
      begin
        OpenPos := I;
        Break;
      end;
      Dec(Depth);
    end;
  end;
  if OpenPos = 0 then
  begin
    HideFunctionTip;
    Exit;
  end;
  J := OpenPos - 1;
  while (J > 0) and (SourceBefore[J] in [' ', #9, #10, #13]) do Dec(J);
  EndName := J;
  while (J > 0) and
    (SourceBefore[J] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do Dec(J);
  FunctionName := Copy(SourceBefore, J + 1, EndName - J);
  ContextStart := J;
  while (ContextStart > 0) and
    not (SourceBefore[ContextStart] in [';', '{', '}', #10, #13]) do
    Dec(ContextStart);
  ContextPrefix := Trim(Copy(SourceBefore, ContextStart + 1,
    J - ContextStart));
  { A type before the name identifies a declaration, not a call. }
  if (ContextPrefix <> '') and
    (Pos('=', ContextPrefix) = 0) and
    (Pos('(', ContextPrefix) = 0) and
    (Pos(',', ContextPrefix) = 0) and
    (Pos('.', ContextPrefix) = 0) and
    (Pos('->', ContextPrefix) = 0) and
    (ContextPrefix <> 'return') and (ContextPrefix <> 'co_return') then
  begin
    HideFunctionTip;
    Exit;
  end;
  if (FunctionName = '') or (FunctionName = 'if') or
    (FunctionName = 'for') or (FunctionName = 'while') or
    (FunctionName = 'switch') then
  begin
    HideFunctionTip;
    Exit;
  end;
  EnsureFunctionSignatures(Doc);
  FTipSignature := FTipSignatures.Values[FunctionName];
  if FTipSignature = '' then
  begin
    HideFunctionTip;
    Exit;
  end;
  ActiveParam := 0;
  Depth := 0;
  for I := OpenPos + 1 to Length(SourceBefore) do
  begin
    if SourceBefore[I] in ['(', '[', '{'] then Inc(Depth)
    else if SourceBefore[I] in [')', ']', '}'] then Dec(Depth)
    else if (SourceBefore[I] = ',') and (Depth = 0) then Inc(ActiveParam);
  end;
  FTipParamIndex := ActiveParam;
  FTipForm.HandleNeeded;
  FTipPaint.Canvas.Font.Name := ResolveEditorFontName(FEditorFontName);
  FTipPaint.Canvas.Font.Size := 10;
  FTipForm.ClientWidth := Min(640, FTipPaint.Canvas.TextWidth(FTipSignature) + 12);
  FTipForm.ClientHeight := FTipPaint.Canvas.TextHeight('Ag') + 6;
  ScreenPos := Doc.Editor.RowColumnToPixels(Doc.Editor.CaretXY);
  Inc(ScreenPos.Y, Doc.Editor.LineHeight + 3);
  ScreenPos := Doc.Editor.ClientToScreen(ScreenPos);
  if ScreenPos.X + FTipForm.Width > Screen.Width then
    ScreenPos.X := Max(0, Screen.Width - FTipForm.Width);
  if ScreenPos.Y + FTipForm.Height > Screen.Height then
    ScreenPos.Y := Max(0, ScreenPos.Y - FTipForm.Height -
      Doc.Editor.LineHeight - 3);
  ScreenPos := ScreenToClient(ScreenPos);
  FTipForm.Left := ScreenPos.X;
  FTipForm.Top := ScreenPos.Y;
  FTipForm.Show;
  FTipForm.BringToFront;
  FTipPaint.Invalidate;
end;

procedure TMainForm.FunctionTipPaint(Sender: TObject);
var
  OpenPos, StartPos, EndPos, I, ParamNumber, XPos: Integer;
  CurrentParam: string;
begin
  FTipPaint.Canvas.Brush.Style := bsSolid;
  FTipPaint.Canvas.Brush.Color := $00E1FFFF;
  FTipPaint.Canvas.FillRect(FTipPaint.ClientRect);
  FTipPaint.Canvas.Pen.Color := clGray;
  FTipPaint.Canvas.Rectangle(0, 0, FTipPaint.Width - 1,
    FTipPaint.Height - 1);
  FTipPaint.Canvas.Brush.Style := bsClear;
  FTipPaint.Canvas.Font.Name := ResolveEditorFontName(FEditorFontName);
  FTipPaint.Canvas.Font.Size := 10;
  FTipPaint.Canvas.Font.Color := clBlack;
  FTipPaint.Canvas.TextOut(6, 3, FTipSignature);
  OpenPos := Pos('(', FTipSignature);
  if OpenPos = 0 then Exit;
  StartPos := OpenPos + 1;
  ParamNumber := 0;
  while ParamNumber < FTipParamIndex do
  begin
    I := Pos(',', Copy(FTipSignature, StartPos, MaxInt));
    if I = 0 then Exit;
    StartPos := StartPos + I;
    Inc(ParamNumber);
  end;
  EndPos := StartPos;
  while (EndPos <= Length(FTipSignature)) and
    not (FTipSignature[EndPos] in [',', ')']) do Inc(EndPos);
  CurrentParam := Copy(FTipSignature, StartPos, EndPos - StartPos);
  if CurrentParam = '' then Exit;
  XPos := 6 + FTipPaint.Canvas.TextWidth(Copy(FTipSignature, 1,
    StartPos - 1));
  FTipPaint.Canvas.Font.Color := clRed;
  FTipPaint.Canvas.TextOut(XPos, 3, CurrentParam);
end;

procedure TMainForm.CompletionDrawItem(Control: TWinControl;
  Index: Integer; ARect: TRect; State: TOwnerDrawState);
var
  KindName: string;
begin
  KindName := FCompletionKinds.Values[FCompletionList.Items[Index]];
  if KindName = '' then KindName := 'symbol';
  if odSelected in State then
  begin
    FCompletionList.Canvas.Brush.Color := clHighlight;
    FCompletionList.Canvas.Font.Color := clHighlightText;
  end
  else
  begin
    FCompletionList.Canvas.Brush.Color := clWindow;
    if (KindName = 'function') or (KindName = 'function0') then
      FCompletionList.Canvas.Font.Color := clGreen
    else if KindName = 'type' then
      FCompletionList.Canvas.Font.Color := clMaroon
    else if KindName = 'variable' then
      FCompletionList.Canvas.Font.Color := clBlue
    else
      FCompletionList.Canvas.Font.Color := clGray;
  end;
  FCompletionList.Canvas.FillRect(ARect);
  if KindName = 'function0' then KindName := 'function';
  FCompletionList.Canvas.TextOut(4, ARect.Top + 1, KindName);
  if not (odSelected in State) then
    FCompletionList.Canvas.Font.Color := clWindowText;
  FCompletionList.Canvas.Font.Style := [fsBold];
  FCompletionList.Canvas.TextOut(100, ARect.Top + 1,
    FCompletionList.Items[Index]);
  FCompletionList.Canvas.Font.Style := [];
end;

procedure TMainForm.InsertCompletion;
var
  Doc: TDocument;
  P: TPoint;
  LineText, Value, Kind: string;
  StartPos, OpenParenPos, NameStart: Integer;
begin
  Doc := FCompletionDoc;
  if (Doc = nil) or (FCompletionList.ItemIndex < 0) then Exit;
  if Doc.Editor.ReadOnly or FCompileActive or DebuggerActive then
  begin
    HideCompletion;
    Exit;
  end;
  Value := FCompletionList.Items[FCompletionList.ItemIndex];
  Kind := FCompletionKinds.Values[Value];
  OpenParenPos := Pos('(', Value);
  if ((Kind = 'function') or (Kind = 'function0')) and
    (OpenParenPos > 0) then
  begin
    Value := Copy(Value, 1, OpenParenPos - 1);
    NameStart := Length(Value);
    while (NameStart > 0) and
      (Value[NameStart] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do Dec(NameStart);
    Value := Copy(Value, NameStart + 1, MaxInt);
  end;
  P := Doc.Editor.LogicalCaretXY;
  LineText := Doc.Editor.Lines[P.Y - 1];
  StartPos := P.X - 1;
  while (StartPos >= 1) and (StartPos <= Length(LineText)) and
    (LineText[StartPos] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do
    Dec(StartPos);
  HideCompletion;
  Doc.Editor.BlockBegin := Point(StartPos + 1, P.Y);
  Doc.Editor.BlockEnd := P;
  if (Kind = 'function') or (Kind = 'function0') then
  begin
    if (P.X > Length(LineText)) or (LineText[P.X] <> '(') then
    begin
      Doc.Editor.SelText := Value + '()';
      if Kind = 'function' then
        Doc.Editor.LogicalCaretXY := Point(StartPos + Length(Value) + 2, P.Y);
    end
    else
      Doc.Editor.SelText := Value;
  end
  else
    Doc.Editor.SelText := Value;
  Doc.Editor.SetFocus;
  UpdateFunctionTip(Doc);
end;

procedure TMainForm.CompletionDoubleClick(Sender: TObject);
begin
  InsertCompletion;
end;

procedure TMainForm.CompletionKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  Doc: TDocument;
  P: TPoint;
  LineText: string;
  DeletedChar: Char;
begin
  Doc := FCompletionDoc;
  if Doc = nil then Exit;
  if Doc.Editor.ReadOnly or FCompileActive or DebuggerActive then
  begin
    HideCompletion;
    Key := 0;
    Exit;
  end;
  if Key = VK_ESCAPE then
  begin
    Key := 0;
    FCompletionDismissed := True;
    HideCompletion;
    Doc.Editor.SetFocus;
  end
  else if Key = VK_RETURN then
  begin
    Key := 0;
    InsertCompletion;
  end
  else if Key = VK_BACK then
  begin
    Key := 0;
    P := Doc.Editor.LogicalCaretXY;
    if P.X <= 1 then Exit;
    LineText := Doc.Editor.Lines[P.Y - 1];
    DeletedChar := LineText[P.X - 1];
    Doc.Editor.BlockBegin := Point(P.X - 1, P.Y);
    Doc.Editor.BlockEnd := P;
    Doc.Editor.SelText := '';
    if DeletedChar in ['.', '>', ':'] then
    begin
      HideCompletion;
      Doc.Editor.SetFocus;
    end
    else ShowCompletion(Doc, FCompletionAfterMember);
  end;
end;

procedure TMainForm.CompletionKeyPress(Sender: TObject; var Key: Char);
var
  Doc: TDocument;
  Typed: Char;
  SelectedKind: string;
begin
  if not FCompletionForm.Visible then begin Key := #0; Exit; end;
  if Key = #27 then
  begin
    Key := #0;
    FCompletionDismissed := True;
    HideCompletion;
    if FCompletionDoc <> nil then FCompletionDoc.Editor.SetFocus;
    Exit;
  end;
  if Key = #13 then
  begin
    Key := #0;
    InsertCompletion;
    Exit;
  end;
  if Key in [#0, #8] then begin Key := #0; Exit; end;
  Doc := FCompletionDoc;
  if Doc = nil then Exit;
  if Doc.Editor.ReadOnly or FCompileActive or DebuggerActive then
  begin
    HideCompletion;
    Key := #0;
    Exit;
  end;
  Typed := Key;
  Key := #0;
  if not (Typed in ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
  begin
    SelectedKind := '';
    if FCompletionList.ItemIndex >= 0 then
    begin
      SelectedKind := FCompletionKinds.Values[
        FCompletionList.Items[FCompletionList.ItemIndex]];
      InsertCompletion;
    end
    else
    begin
      HideCompletion;
      Doc.Editor.SetFocus;
    end;
    if (Typed <> '(') or
      ((SelectedKind <> 'function') and (SelectedKind <> 'function0')) then
      Doc.Editor.SelText := Typed;
    Exit;
  end;
  Doc.Editor.SelText := Typed;
  if FCompletionForm.Visible then
    ShowCompletion(Doc, FCompletionAfterMember)
  else
    Doc.Editor.SetFocus;
end;

procedure TMainForm.PageChanged(Sender: TObject);
begin
  if CurrentDoc <> nil then TNoiSynEdit(CurrentDoc.Editor).ResetHomeCycle;
  FHomeAtIndent := False;
  HideCompletion;
  HideFunctionTip;
  if Visible and (CurrentDoc <> nil) and CurrentDoc.Editor.CanFocus and
    (Application.ModalLevel = 0) then CurrentDoc.Editor.SetFocus;
  UpdateStatus;
end;

procedure TMainForm.CreateDocument(AssignUntitledName: Boolean);
var Doc: TDocument;
begin
  Doc := TDocument.Create;
  Doc.ErrorLine := -1;
  if AssignUntitledName then
  begin
    Inc(FNewFileNumber);
    Doc.UntitledName := 'Untitled' + IntToStr(FNewFileNumber);
  end;
  Doc.Tab := TTabSheet.Create(FPages);
  Doc.Tab.PageControl := FPages;
  Doc.Editor := TNoiSynEdit.Create(Doc.Tab);
  Doc.Editor.Parent := Doc.Tab;
  Doc.Editor.Align := alClient;
  Doc.Editor.Font.Name := ResolveEditorFontName(FEditorFontName);
  Doc.Editor.Font.Size := FEditorFontSize;
  Doc.Editor.Options := (Doc.Editor.Options + [eoTabIndent]) -
    [eoAutoIndent, eoSmartTabs, eoTabsToSpaces, eoTrimTrailingSpaces,
     eoShowSpecialChars, eoScrollPastEol, eoKeepCaretX];
  Doc.Editor.Options2 := Doc.Editor.Options2 + [eoCaretSkipTab];
  Doc.Editor.TabWidth := FEditorTabWidth;
  Doc.Editor.WantTabs := True;
  if FCompileActive or DebuggerActive then
  begin
    Doc.ReadOnlyBeforeDebug := Doc.Editor.ReadOnly;
    Doc.DebugReadOnlyApplied := True;
    Doc.Editor.ReadOnly := True;
  end;
  { Dev-C++ uses Ctrl+1..9 to toggle and Alt+1..9 to jump. }
  Doc.Editor.BookMarkOptions.EnableKeys := False;
  Doc.Editor.BlockIndent := 0;
  Doc.Editor.BlockTabIndent := 1;
  Doc.Editor.RightEdge := 0;
  Doc.Editor.Gutter.Visible := True;
  Doc.Syntax := TNoiCppSyn.Create(Doc.Tab);
  ApplyDocumentEditorSettings(Doc);
  Doc.Editor.Highlighter := Doc.Syntax;
  Doc.Editor.OnChange := @EditorChanged;
  Doc.Editor.OnStatusChange := @EditorStatusChanged;
  Doc.Editor.OnClick := @EditorClicked;
  Doc.Editor.OnKeyDown := @EditorKeyDown;
  Doc.Editor.OnKeyPress := @EditorKeyPress;
  Doc.Editor.OnProcessCommand := @EditorProcessCommand;
  Doc.Editor.OnSpecialLineColors := @EditorSpecialLineColors;
  Doc.Editor.OnKeyUp := @EditorKeyUp;
  Doc.Editor.OnMouseWheel := @EditorMouseWheel;
  Doc.Editor.OnMouseUp := @EditorMouseUp;
  Doc.Editor.OnDropFiles := @EditorFilesDropped;
  TNoiSynEdit(Doc.Editor).OnLineClick := @EditorLineClick;
  FDocs.Add(Doc);
  UpdateTab(Doc);
  FPages.ActivePage := Doc.Tab;
  if Visible then Doc.Editor.SetFocus;
end;

procedure TMainForm.NewClick(Sender: TObject);
begin
  if FCompileActive or (FDocumentDialogs <> 0) then Exit;
  CreateDocument(True);
end;

procedure TMainForm.OpenFile(const FileName: string);
var Doc: TDocument; Tab: TTabSheet;
begin
  if not FileExists(FileName) then
  begin
    UiMessageDlg(Format(Tr('File not found: %s'), [FileName]), mtError, [mbOK], 0);
    Exit;
  end;
  Doc := FindDoc(ExpandFileName(FileName));
  if Doc <> nil then
  begin
    FPages.ActivePage := Doc.Tab;
    RememberRecentPath(Doc.FileName);
    Exit;
  end;
  CreateDocument(False);
  Doc := CurrentDoc;
  FLoading := True;
  try
    try
      LoadDocumentLines(Doc.Editor.Lines, FileName, Doc.DiskSnapshot);
      Doc.SeenDiskSnapshot := Doc.DiskSnapshot;
      Doc.FileName := ExpandFileName(FileName);
      UpdateDebugMarkers(Doc);
      Doc.Dirty := False;
      Doc.Editor.Modified := False;
      UpdateTab(Doc);
      RememberRecentPath(Doc.FileName);
    except
      on E: Exception do
      begin
        Tab := Doc.Tab;
        FDocs.Remove(Doc);
        Tab.Free;
        UiMessageDlg(E.Message, mtError, [mbOK], 0);
      end;
    end;
  finally
    FLoading := False;
  end;
  UpdateStatus;
end;

procedure TMainForm.OpenProject(const FileName: string);
var
  Ini: TIniFile;
  Count, I: Integer;
  StoredPath, FullName, SelectedPath: string;
  Units: TStringList;
begin
  if FCompileActive or (FDocumentDialogs <> 0) then Exit;
  if not FileExists(FileName) then
  begin
    UiMessageDlg(Format(Tr('Project not found: %s'), [FileName]), mtError, [mbOK], 0);
    Exit;
  end;
  SelectedPath := ExpandFileName(FileName);
  Units := TStringList.Create;
  try
    try
      ValidateProjectPath(SelectedPath);
      Ini := TIniFile.Create(SelectedPath);
      try
        if not Ini.SectionExists('Project') then
          raise EInOutError.Create(Tr('The selected file is not a Dev-C++ project.'));
        Count := Ini.ReadInteger('Project', 'UnitCount', 0);
        if (Count < 0) or (Count > 100000) then
          raise EInOutError.Create(Tr('Invalid project unit count.'));
        for I := 1 to Count do
        begin
          StoredPath := Ini.ReadString('Unit' + IntToStr(I), 'FileName', '');
          if StoredPath = '' then Continue;
          FullName := document_files.ProjectUnitPath(SelectedPath, StoredPath);
          Units.Add(FullName);
        end;
      finally
        Ini.Free;
      end;
    except
      on E: Exception do
      begin
        UiMessageDlg(E.Message, mtError, [mbOK], 0);
        Exit;
      end;
    end;
    { Load and validate the new project before asking to close the old one. }
    if (FProjectPath <> '') and not SameDocumentPath(FProjectPath, SelectedPath) then
      if not TryCloseProject then Exit;
    FProjectPath := SelectedPath;
    FProjectFiles.Assign(Units);
    RefreshProjectTree;
    RememberRecentPath(FProjectPath);
    if FProjectFiles.Count > 0 then OpenFile(FProjectFiles[0]);
  finally
    Units.Free;
  end;
end;

procedure TMainForm.RefreshProjectTree;
var Root: TTreeNode; I: Integer;
begin
  FProjectTree.Items.BeginUpdate;
  try
    FProjectTree.Items.Clear;
    if FProjectPath <> '' then
    begin
      Root := FProjectTree.Items.Add(nil, ExtractFileName(FProjectPath));
      for I := 0 to FProjectFiles.Count - 1 do
        FProjectTree.Items.AddChild(Root, ExtractFileName(FProjectFiles[I]));
      Root.Expand(False);
    end;
  finally
    FProjectTree.Items.EndUpdate;
  end;
  if FProjectPath = '' then Caption := AppName + ' ' + AppVersion
  else Caption := ExtractFileName(FProjectPath) + ' - ' + AppName + ' ' + AppVersion;
end;

function TMainForm.TryCloseProject: Boolean;
var
  ClosingDocs: TFPList;
  I, J: Integer;
  Doc: TDocument;
  OldExecutable: string;
begin
  Result := False;
  if FCompileActive then Exit;
  if FProjectPath = '' then Exit(True);
  ClosingDocs := TFPList.Create;
  Inc(FDocumentDialogs);
  try
    for I := 0 to FDocs.Count - 1 do
    begin
      Doc := TDocument(FDocs[I]);
      for J := 0 to FProjectFiles.Count - 1 do
        if SameDocumentPath(Doc.FileName, FProjectFiles[J]) then
        begin
          ClosingDocs.Add(Doc);
          Break;
        end;
    end;
    { A cancelled prompt leaves the project and every tab open. }
    for I := 0 to ClosingDocs.Count - 1 do
      if not MayClose(TDocument(ClosingDocs[I])) then Exit;
    OldExecutable := ChangeFileExt(FProjectPath, '');
    for I := ClosingDocs.Count - 1 downto 0 do
      DisposeDocument(TDocument(ClosingDocs[I]));
    FProjectPath := '';
    FProjectFiles.Clear;
    if FLastExecutable = OldExecutable then FLastExecutable := '';
    RefreshProjectTree;
    UpdateStatus;
    Result := True;
  finally
    Dec(FDocumentDialogs);
    ClosingDocs.Free;
  end;
end;

procedure TMainForm.CloseProjectClick(Sender: TObject);
begin
  if FCompileActive or (FDocumentDialogs <> 0) then Exit;
  TryCloseProject;
end;

procedure TMainForm.NewProjectClick(Sender: TObject);
var
  Dialog: TSaveDialog;
  Ini: TMemIniFile;
  ProjectFilePath: string;
  Snapshot: TFileSnapshot;
begin
  if FCompileActive or (FDocumentDialogs <> 0) then Exit;
  Dialog := TSaveDialog.Create(Self);
  try
    Dialog.Title := Tr('Save');
    Dialog.DefaultExt := 'dev';
    Dialog.Filter := Tr('Dev-C++ project|*.dev');
    Dialog.FileName := 'Project1.dev';
    if not Dialog.Execute then Exit;
    ProjectFilePath := ExpandFileName(Dialog.FileName);
  finally
    Dialog.Free;
  end;
  if FileExists(ProjectFilePath) then
  begin
    UiMessageDlg(Tr('Choose a new project file name.'), mtInformation, [mbOK], 0);
    Exit;
  end;
  try
    ValidateProjectPath(ProjectFilePath);
    Snapshot := CaptureFileSnapshot(ProjectFilePath);
    if Snapshot.Present then
      raise EInOutError.Create(Tr('Choose a new project file name.'));
    Ini := TMemIniFile.Create(ProjectFilePath);
    try
      Ini.WriteString('Project', 'FileName', ExtractFileName(ProjectFilePath));
      Ini.WriteString('Project', 'Name', ChangeFileExt(ExtractFileName(ProjectFilePath), ''));
      Ini.WriteInteger('Project', 'Type', 1);
      Ini.WriteInteger('Project', 'Ver', 2);
      Ini.WriteBool('Project', 'IsCpp', True);
      Ini.WriteInteger('Project', 'UnitCount', 0);
      Ini.WriteString('Project', 'Compiler', '');
      Ini.WriteString('Project', 'CppCompiler', '');
      Ini.WriteString('Project', 'Linker', '');
      WriteProjectIni(Ini, ProjectFilePath, Snapshot);
    finally
      Ini.Free;
    end;
  except
    on E: Exception do
    begin
      UiMessageDlg(E.Message, mtError, [mbOK], 0);
      Exit;
    end;
  end;
  OpenProject(ProjectFilePath);
end;

procedure TMainForm.AddProjectFileClick(Sender: TObject);
var
  Dialog: TOpenDialog;
  Ini: TMemIniFile;
  I, J, UnitCount: Integer;
  SourcePath, UnitSection: string;
  Added, AlreadyPresent: Boolean;
  Snapshot: TFileSnapshot;
begin
  if FCompileActive or (FDocumentDialogs <> 0) then Exit;
  if FProjectPath = '' then
  begin
    UiMessageDlg(Tr('Open or create a project first.'), mtInformation, [mbOK], 0);
    Exit;
  end;
  Dialog := TOpenDialog.Create(Self);
  Added := False;
  try
    try
    Dialog.Title := Tr('Open');
    Dialog.Filter := Tr('C/C++ files|*.c;*.cc;*.cpp;*.cxx;*.h;*.hpp|All files|*');
    Dialog.Options := Dialog.Options + [ofAllowMultiSelect, ofFileMustExist];
    if not Dialog.Execute then Exit;
    Snapshot := CaptureFileSnapshot(FProjectPath);
    Ini := TMemIniFile.Create(FProjectPath);
    try
      UnitCount := Ini.ReadInteger('Project', 'UnitCount', 0);
      if (UnitCount < 0) or (UnitCount > 100000) then
        raise EInOutError.Create(Tr('Invalid project unit count.'));
      Added := False;
      for I := 0 to Dialog.Files.Count - 1 do
      begin
        SourcePath := ExpandFileName(Dialog.Files[I]);
        ValidateProjectPath(SourcePath);
        AlreadyPresent := False;
        for J := 0 to FProjectFiles.Count - 1 do
          if SameDocumentPath(FProjectFiles[J], SourcePath) then
          begin
            AlreadyPresent := True;
            Break;
          end;
        if AlreadyPresent then Continue;
        Inc(UnitCount);
        UnitSection := 'Unit' + IntToStr(UnitCount);
        Ini.WriteString(UnitSection, 'FileName',
          ExtractRelativePath(ExtractFilePath(FProjectPath), SourcePath));
        Ini.WriteBool(UnitSection, 'Compile', True);
        Ini.WriteBool(UnitSection, 'CompileCpp',
          LowerCase(ExtractFileExt(SourcePath)) <> '.c');
        Ini.WriteBool(UnitSection, 'Link', True);
        Added := True;
      end;
      if Added then
      begin
        Ini.WriteInteger('Project', 'UnitCount', UnitCount);
        WriteProjectIni(Ini, FProjectPath, Snapshot);
      end;
    finally
      Ini.Free;
    end;
    except
      on E: Exception do
      begin
        Added := False;
        UiMessageDlg(E.Message, mtError, [mbOK], 0);
      end;
    end;
  finally
    Dialog.Free;
  end;
  if Added then OpenProject(FProjectPath);
end;

procedure TMainForm.RemoveProjectFileClick(Sender: TObject);
var
  Ini: TMemIniFile;
  UnitValues: TStringList;
  Node: TTreeNode;
  UnitCount, UnitIndex, I, J, K: Integer;
  SourcePath, UnitSection: string;
  Snapshot: TFileSnapshot;
begin
  if FCompileActive or (FDocumentDialogs <> 0) then Exit;
  if FProjectPath = '' then Exit;
  Node := FProjectTree.Selected;
  if (Node = nil) or (Node.Parent = nil) or
    (Node.Index < 0) or (Node.Index >= FProjectFiles.Count) then Exit;
  SourcePath := FProjectFiles[Node.Index];
  if UiMessageDlg(Format(Tr('Remove %s from project?'), [ExtractFileName(SourcePath)]),
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  try
    Snapshot := CaptureFileSnapshot(FProjectPath);
    Ini := TMemIniFile.Create(FProjectPath);
    UnitValues := TStringList.Create;
    try
      UnitCount := Ini.ReadInteger('Project', 'UnitCount', 0);
      if (UnitCount < 0) or (UnitCount > 100000) then
        raise EInOutError.Create(Tr('Invalid project unit count.'));
      UnitIndex := 0;
      for I := 1 to UnitCount do
      begin
        UnitSection := 'Unit' + IntToStr(I);
        if SameDocumentPath(document_files.ProjectUnitPath(FProjectPath,
          Ini.ReadString(UnitSection, 'FileName', '')), SourcePath) then
        begin
          UnitIndex := I;
          Break;
        end;
      end;
      if UnitIndex = 0 then Exit;
      for J := UnitIndex to UnitCount - 1 do
      begin
        UnitValues.Clear;
        Ini.ReadSectionValues('Unit' + IntToStr(J + 1), UnitValues);
        UnitSection := 'Unit' + IntToStr(J);
        Ini.EraseSection(UnitSection);
        for K := 0 to UnitValues.Count - 1 do
          Ini.WriteString(UnitSection, UnitValues.Names[K],
            UnitValues.ValueFromIndex[K]);
      end;
      Ini.EraseSection('Unit' + IntToStr(UnitCount));
      Ini.WriteInteger('Project', 'UnitCount', UnitCount - 1);
      WriteProjectIni(Ini, FProjectPath, Snapshot);
    finally
      UnitValues.Free;
      Ini.Free;
    end;
  except
    on E: Exception do
    begin
      UiMessageDlg(E.Message, mtError, [mbOK], 0);
      Exit;
    end;
  end;
  OpenProject(FProjectPath);
end;

procedure TMainForm.ProjectManagerClick(Sender: TObject);
var ProjectTab: TTabSheet;
begin
  ProjectTab := TTabSheet(FProjectTree.Parent);
  ProjectTab.PageControl.ActivePage := ProjectTab;
  FProjectTree.SetFocus;
end;

procedure TMainForm.ProjectOptionsClick(Sender: TObject);
var
  Ini: TMemIniFile;
  CFlags, CppFlags, LinkFlags: string;
  Snapshot: TFileSnapshot;
begin
  if FCompileActive or (FDocumentDialogs <> 0) then Exit;
  if FProjectPath = '' then
  begin
    UiMessageDlg(Tr('Open or create a project first.'), mtInformation, [mbOK], 0);
    Exit;
  end;
  try
    Snapshot := CaptureFileSnapshot(FProjectPath);
    Ini := TMemIniFile.Create(FProjectPath);
    try
      CFlags := Ini.ReadString('Project', 'Compiler', '');
      CppFlags := Ini.ReadString('Project', 'CppCompiler', '');
      LinkFlags := Ini.ReadString('Project', 'Linker', '');
      if not UiInputQuery(Tr('Project Options'), Tr('Additional C flags:'), CFlags) then Exit;
      if not UiInputQuery(Tr('Project Options'), Tr('Additional C++ flags:'), CppFlags) then Exit;
      if not UiInputQuery(Tr('Project Options'), Tr('Additional linker flags:'), LinkFlags) then Exit;
      Ini.WriteString('Project', 'Compiler', CFlags);
      Ini.WriteString('Project', 'CppCompiler', CppFlags);
      Ini.WriteString('Project', 'Linker', LinkFlags);
      WriteProjectIni(Ini, FProjectPath, Snapshot);
    finally
      Ini.Free;
    end;
  except
    on E: Exception do UiMessageDlg(E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TMainForm.ProjectDoubleClick(Sender: TObject);
var Node: TTreeNode; I: Integer;
begin
  if FCompileActive or (FDocumentDialogs <> 0) then Exit;
  Node := FProjectTree.Selected;
  if (Node = nil) or (Node.Parent = nil) then Exit;
  I := Node.Index;
  if (I >= 0) and (I < FProjectFiles.Count) then OpenFile(FProjectFiles[I]);
end;

procedure TMainForm.LoadCompilerSettings;
var Ini: TIniFile;
begin
  FOptionsPath := GetEnvironmentVariable('HOME');
  if FOptionsPath = '' then FOptionsPath := ExtractFilePath(ParamStr(0))
  else FOptionsPath := IncludeTrailingPathDelimiter(FOptionsPath) + '.config';
  FOptionsPath := IncludeTrailingPathDelimiter(FOptionsPath) + 'devcpp-noi.ini';
  FCompilerProfiles := TCompilerProfiles.Create;
  FEditorFontName := DefaultEditorFontName;
  FEditorThemeName := EditorThemeName(0);
  ForceDirectories(ExtractFileDir(FOptionsPath));
  Ini := TIniFile.Create(FOptionsPath);
  try
    FCompilerProfiles.Load(Ini);
    { Persist migration before editing, leaving the legacy [Compiler] intact. }
    FCompilerProfiles.Save(Ini);
    FEditorFontName := Ini.ReadString('Editor', 'FontName', FEditorFontName);
    if Trim(FEditorFontName) = '' then FEditorFontName := DefaultEditorFontName;
    FEditorThemeName := EditorThemeName(EditorThemeIndex(
      Ini.ReadString('Editor', 'Theme', FEditorThemeName)));
    FEditorFontSize := Max(1, Min(72,
      Ini.ReadInteger('Editor', 'FontSize', FEditorFontSize)));
    FEditorTabWidth := Max(1, Min(16,
      Ini.ReadInteger('Editor', 'TabWidth', FEditorTabWidth)));
  finally Ini.Free; end;
  ActivateCompilerProfile(FCompilerProfiles.ActiveIndex, False);
end;

procedure TMainForm.SaveCompilerProfiles;
var Ini: TIniFile;
begin
  Ini := TIniFile.Create(FOptionsPath);
  try FCompilerProfiles.Save(Ini); finally Ini.Free; end;
end;

procedure TMainForm.ActivateCompilerProfile(Index: Integer; Persist: Boolean);
var Profile: TCompilerProfile;
begin
  if (FCompilerProfiles = nil) or (Index < 0) or (Index >= FCompilerProfiles.Count) then Exit;
  FCompilerProfiles.ActiveIndex := Index;
  Profile := FCompilerProfiles[Index];
  FCCompiler := Profile.CCompiler;
  FCppCompiler := Profile.CppCompiler;
  FCFlags := Profile.CFlags;
  FCppFlags := Profile.CppFlags;
  FLinkerFlags := Profile.LinkerFlags;
  if FCompilerProfileCombo <> nil then FCompilerProfileCombo.ItemIndex := Index;
  if Persist then SaveCompilerProfiles;
end;

procedure TMainForm.PopulateCompilerProfiles(Combo: TComboBox);
var I: Integer;
begin
  FCompilerProfileCombo := Combo;
  if (Combo = nil) or (FCompilerProfiles = nil) then Exit;
  Combo.Items.BeginUpdate;
  try
    Combo.Items.Clear;
    for I := 0 to FCompilerProfiles.Count - 1 do Combo.Items.Add(FCompilerProfiles[I].Name);
    Combo.ItemIndex := FCompilerProfiles.ActiveIndex;
  finally Combo.Items.EndUpdate; end;
end;

procedure TMainForm.CompilerProfileChange(Sender: TObject);
begin
  if not (Sender is TComboBox) then Exit;
  if FCompileActive then
  begin
    TComboBox(Sender).ItemIndex := FCompilerProfiles.ActiveIndex;
    Exit;
  end;
  ActivateCompilerProfile(TComboBox(Sender).ItemIndex, True);
end;

procedure TMainForm.InitializeEditorThemes(ParentMenu: TMenuItem);
var I: Integer; Item: TMenuItem;
begin
  if ParentMenu = nil then Exit;
  FEditorThemeMenu := TMenuItem.Create(Self);
  FEditorThemeMenu.Caption := Tr('Editor &Theme');
  ParentMenu.Add(FEditorThemeMenu);
  for I := 0 to EditorThemeCount - 1 do
  begin
    Item := TMenuItem.Create(Self);
    Item.Caption := EditorThemeName(I);
    Item.Tag := I;
    Item.RadioItem := True;
    Item.GroupIndex := 42;
    Item.Checked := I = EditorThemeIndex(FEditorThemeName);
    Item.OnClick := @ThemeClick;
    FEditorThemeMenu.Add(Item);
  end;
end;

procedure TMainForm.ThemeClick(Sender: TObject);
begin
  if not (Sender is TMenuItem) then Exit;
  FEditorThemeName := EditorThemeName(TMenuItem(Sender).Tag);
  ApplyAllEditorSettings;
  SaveEditorSettings;
end;

procedure TMainForm.ApplyDocumentEditorSettings(Doc: TDocument);
begin
  Doc.Editor.Font.Name := ResolveEditorFontName(FEditorFontName);
  Doc.Editor.Font.Size := FEditorFontSize;
  Doc.Editor.Font.Style := [];
  Doc.Editor.TabWidth := FEditorTabWidth;
  Doc.PreferredColumn := 0;
  ApplyEditorTheme(Doc.Editor, Doc.Syntax, Doc.Syntax.BracketAttri,
    Doc.Syntax.CharacterAttri,
    FEditorThemeName, Doc.ThemeColors);
end;

procedure TMainForm.ApplyAllEditorSettings;
var I: Integer;
begin
  for I := 0 to FDocs.Count - 1 do ApplyDocumentEditorSettings(TDocument(FDocs[I]));
  if FOutput <> nil then FOutput.Font.Name := ResolveEditorFontName(FEditorFontName);
  if FCompletionList <> nil then
    FCompletionList.Font.Name := ResolveEditorFontName(FEditorFontName);
  if FEditorThemeMenu <> nil then
    for I := 0 to FEditorThemeMenu.Count - 1 do
      FEditorThemeMenu.Items[I].Checked := FEditorThemeMenu.Items[I].Tag =
        EditorThemeIndex(FEditorThemeName);
end;

procedure TMainForm.SaveEditorSettings;
var Ini: TIniFile;
begin
  Ini := TIniFile.Create(FOptionsPath);
  try
    Ini.WriteString('Editor', 'Theme', FEditorThemeName);
    Ini.WriteString('Editor', 'FontName', FEditorFontName);
    Ini.WriteInteger('Editor', 'FontSize', FEditorFontSize);
    Ini.WriteInteger('Editor', 'TabWidth', FEditorTabWidth);
  finally Ini.Free; end;
end;

procedure TMainForm.AddCompilerFlags(Args: TStrings; const FlagText: string);
var Parts: TStringList; I: Integer; ErrorText: string;
begin
  Parts := TStringList.Create;
  try
    if not ParseRunArguments(FlagText, Parts, ErrorText) then
      raise Exception.Create(Tr(ErrorText));
    for I := 0 to Parts.Count - 1 do
      Args.Add(Parts[I]);
  finally Parts.Free; end;
end;

procedure TMainForm.CompilerOptionsClick(Sender: TObject);
begin
  if FCompileActive then Exit;
  if not EditCompilerProfiles(Self, FCompilerProfiles) then Exit;
  ActivateCompilerProfile(FCompilerProfiles.ActiveIndex, False);
  SaveCompilerProfiles;
  PopulateCompilerProfiles(FCompilerProfileCombo);
end;

procedure TMainForm.EditorOptionsClick(Sender: TObject);
begin
  if not EditEditorSettings(Self, FEditorThemeName, FEditorFontName,
    FEditorFontSize, FEditorTabWidth) then Exit;
  ApplyAllEditorSettings;
  SaveEditorSettings;
end;

procedure TMainForm.PopulateDiagnostics(const CompilerOutput: string);
var
  Rows: TStringList;
  Entry: TListItem;
  I, SourceRow, SourceCol: Integer;
  SourcePath, Detail: string;
begin
  Rows := TStringList.Create;
  try
    Rows.Text := CompilerOutput;
    FCompilerList.Items.BeginUpdate;
    try
      FCompilerList.Items.Clear;
      for I := 0 to Rows.Count - 1 do
        if ParseCompilerDiagnostic(Rows[I], FCompileDirectory,
          SourcePath, SourceRow, SourceCol, Detail) then
        begin
          Entry := FCompilerList.Items.Add;
          Entry.Caption := IntToStr(SourceRow);
          Entry.SubItems.Add(IntToStr(SourceCol));
          Entry.SubItems.Add(SourcePath);
          Entry.SubItems.Add(Detail);
        end;
    finally
      FCompilerList.Items.EndUpdate;
    end;
    if FCompilerList.Items.Count > 0 then FReportTabs.ActivePage := FCompilerTab
    else FReportTabs.ActivePage := FLogTab;
  finally
    Rows.Free;
  end;
end;

procedure TMainForm.ErrorDoubleClick(Sender: TObject);
var
  Entry: TListItem;
  SourceRow, SourceCol, MatchLength, EndColumn: Integer;
  Doc: TDocument;
  SourceText: string;
begin
  Entry := FCompilerList.Selected;
  if (Entry = nil) or (Entry.SubItems.Count < 2) then Exit;
  if not TryStrToInt(Entry.Caption, SourceRow) then Exit;
  if not TryStrToInt(Entry.SubItems[0], SourceCol) then SourceCol := 1;
  if Entry.Data <> nil then
  begin
    Doc := TDocument(Entry.Data);
    if FDocs.IndexOf(Doc) < 0 then Exit;
    if ((Doc.FileName <> '') and (Entry.SubItems[1] <> Doc.FileName)) or
      ((Doc.FileName = '') and (Entry.SubItems[1] <> Doc.UntitledName)) then Exit;
    if Doc.Editor.Lines.Count = 0 then Exit;
    SourceRow := Max(1, Min(SourceRow, Doc.Editor.Lines.Count));
    SourceText := Doc.Editor.Lines[SourceRow - 1];
    SourceCol := ClampUtf8ByteColumn(SourceText, SourceCol);
    MatchLength := Length(FFindText);
    if Entry.SubItems.Count >= 4 then
      MatchLength := Max(0, StrToIntDef(Entry.SubItems[3], MatchLength));
    EndColumn := ClampUtf8ByteColumn(SourceText,
      Min(Length(SourceText) + 1, SourceCol + MatchLength));
    FPages.ActivePage := Doc.Tab;
    Doc.Editor.LogicalCaretXY := Point(EndColumn, SourceRow);
    Doc.Editor.BlockBegin := Point(SourceCol, SourceRow);
    Doc.Editor.BlockEnd := Point(EndColumn, SourceRow);
    Doc.Editor.SetFocus;
    Exit;
  end;
  if not FileExists(Entry.SubItems[1]) then Exit;
  OpenFile(Entry.SubItems[1]);
  Doc := FindDoc(Entry.SubItems[1]);
  if (Doc <> nil) and (Doc.Editor.Lines.Count > 0) then
  begin
    SourceRow := Max(1, Min(SourceRow, Doc.Editor.Lines.Count));
    SourceText := Doc.Editor.Lines[SourceRow - 1];
    { The target GCC 9.3 reports byte columns, as used by LogicalCaretXY.
      Do not turn a Chinese character's byte offset into a second offset. }
    SourceCol := ClampUtf8ByteColumn(SourceText, SourceCol);
    FPages.ActivePage := Doc.Tab;
    Doc.Editor.LogicalCaretXY := Point(SourceCol, SourceRow);
    Doc.Editor.BlockBegin := Point(SourceCol, SourceRow);
    Doc.Editor.BlockEnd := Point(SourceCol, SourceRow);
    Doc.ErrorLine := SourceRow;
    Doc.Editor.Invalidate;
    if SourceRow > 5 then Doc.Editor.TopLine := SourceRow - 5;
    Doc.Editor.SetFocus;
  end;
end;

procedure TMainForm.OpenClick(Sender: TObject);
var Dialog: TOpenDialog;
begin
  if FCompileActive or (FDocumentDialogs <> 0) then Exit;
  Dialog := TOpenDialog.Create(Self);
  try
    Dialog.Title := Tr('Open');
    Dialog.Filter := Tr('Dev-C++ project or C/C++ file|*.dev;*.c;*.cc;*.cpp;*.cxx;*.h;*.hpp|All files|*');
    if Dialog.Execute then
      if LowerCase(ExtractFileExt(Dialog.FileName)) = '.dev' then
        OpenProject(Dialog.FileName)
      else
        OpenFile(Dialog.FileName);
  finally Dialog.Free; end;
end;

function TMainForm.SaveDoc(Doc: TDocument): Boolean;
begin
  Result := SaveDocument(Doc, False);
end;

function TMainForm.SaveDocument(Doc: TDocument; SaveAs: Boolean): Boolean;
var
  Dialog: TSaveDialog;
  SelectedPath, OldName: string;
  ExistingDoc: TDocument;
  CurrentSnapshot, SavedSnapshot: TFileSnapshot;
  I: Integer;
  ExistingIdentity, ProjectMember, ProjectChanged: Boolean;
begin
  Result := False;
  if (Doc = nil) or (FDocs.IndexOf(Doc) < 0) then Exit;
  Inc(FDocumentDialogs);
  try
    try
      OldName := Doc.FileName;
      SelectedPath := OldName;
      if SaveAs or (SelectedPath = '') then
      begin
        Dialog := TSaveDialog.Create(Self);
        try
          Dialog.Title := Tr('Save');
          Dialog.Options := Dialog.Options - [ofOverwritePrompt];
          Dialog.DefaultExt := 'cpp';
          Dialog.Filter := Tr('C/C++ source|*.cpp;*.c;*.h;*.hpp|All files|*');
          if OldName <> '' then Dialog.FileName := OldName
          else Dialog.FileName := Doc.UntitledName;
          if ExtractFileExt(Dialog.FileName) = '' then
            Dialog.FileName := Dialog.FileName + '.cpp';
          if not Dialog.Execute then Exit;
          SelectedPath := ExpandFileName(Dialog.FileName);
        finally
          Dialog.Free;
        end;
      end;
      ExistingDoc := FindDoc(SelectedPath);
      if (ExistingDoc <> nil) and (ExistingDoc <> Doc) then
      begin
        UiMessageDlg(Format(Tr('The file %s is already open in another tab. Close that tab before saving here.'),
          [SelectedPath]), mtError, [mbOK], 0);
        Exit;
      end;
      if (FProjectPath <> '') and SameDocumentPath(SelectedPath, FProjectPath) then
      begin
        UiMessageDlg(Tr('A source file cannot overwrite the active project file.'), mtError, [mbOK], 0);
        Exit;
      end;
      CurrentSnapshot := CaptureFileSnapshot(SelectedPath);
      ExistingIdentity := (OldName <> '') and SameDocumentPath(OldName, SelectedPath);
      if ExistingIdentity and not SameFileSnapshot(CurrentSnapshot, Doc.DiskSnapshot) then
      begin
        if UiMessageDlg(Format(Tr('File %s was changed or removed outside Dev-C++.' + LineEnding +
          'Overwrite the disk version with the editor contents?'), [SelectedPath]),
          mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
      end
      else if CurrentSnapshot.Present and not ExistingIdentity then
        if UiMessageDlg(Format(Tr('File %s already exists. Overwrite?'),
          [SelectedPath]), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;

      ProjectMember := False;
      if (FProjectPath <> '') and (OldName <> '') and (OldName <> SelectedPath) then
        for I := 0 to FProjectFiles.Count - 1 do
          if SameDocumentPath(FProjectFiles[I], OldName) then
          begin
            ProjectMember := True;
            Break;
          end;
      if ProjectMember then ValidateProjectPath(SelectedPath);
      AtomicSaveDocumentChecked(Doc.Editor.Lines, SelectedPath,
        CurrentSnapshot, SavedSnapshot);
      ProjectChanged := False;
      if ProjectMember then
      begin
        try
          if not UpdateProjectFileReference(FProjectPath, OldName, SelectedPath) then
            raise EInOutError.Create(Tr('The project entry changed. Reload the project before renaming this file.'));
        except
          on E: Exception do
          begin
            UiMessageDlg(Format(Tr('The source was saved to %s, but the project could not be updated: %s' + LineEnding +
              'The editor still refers to %s.'), [SelectedPath, E.Message, OldName]),
              mtError, [mbOK], 0);
            Exit;
          end;
        end;
        for I := 0 to FProjectFiles.Count - 1 do
          if SameDocumentPath(FProjectFiles[I], OldName) then
            FProjectFiles[I] := SelectedPath;
        ProjectChanged := True;
      end;
      { Commit the editor identity only after the file and project write succeed. }
      Doc.FileName := SelectedPath;
      if FDebugger <> nil then
      begin
        FDebugger.Session.RenameBreakpoints(OldName, SelectedPath);
        FDebugger.RefreshBreakpoints;
      end;
      Doc.DiskSnapshot := SavedSnapshot;
      Doc.SeenDiskSnapshot := SavedSnapshot;
      Doc.Dirty := False;
      Doc.MissingNotified := False;
      Doc.KeepBufferConflict := False;
      Doc.Editor.Modified := False;
      UpdateTab(Doc);
      if ProjectChanged then RefreshProjectTree;
      RememberRecentPath(Doc.FileName);
      Result := True;
    except
      on E: Exception do UiMessageDlg(E.Message, mtError, [mbOK], 0);
    end;
  finally
    Dec(FDocumentDialogs);
    UpdateStatus;
  end;
end;

function TMainForm.SaveAllDocs: Boolean;
var I: Integer;
begin
  Result := False;
  for I := 0 to FDocs.Count - 1 do
    if TDocument(FDocs[I]).Dirty or TDocument(FDocs[I]).Editor.Modified then
    begin
      FPages.ActivePage := TDocument(FDocs[I]).Tab;
      if not SaveDoc(TDocument(FDocs[I])) then Exit;
    end;
  Result := True;
end;

procedure TMainForm.SaveClick(Sender: TObject);
begin
  if FCompileActive or (FDocumentDialogs <> 0) then Exit;
  SaveDoc(CurrentDoc);
end;

procedure TMainForm.SaveAsClick(Sender: TObject);
begin
  if FCompileActive or (FDocumentDialogs <> 0) then Exit;
  SaveDocument(CurrentDoc, True);
end;

procedure TMainForm.OpenFolderClick(Sender: TObject);
var
  Doc: TDocument;
  Proc: TProcess;
  Folder: string;
begin
  Doc := CurrentDoc;
  if (Doc = nil) or (Doc.FileName = '') then Exit;
  Folder := ExtractFileDir(Doc.FileName);
  if not DirectoryExists(Folder) then Exit;
  if not FileExists('/usr/bin/xdg-open') then Exit;
  Proc := TProcess.Create(nil);
  try
    Proc.Executable := '/usr/bin/xdg-open';
    Proc.Parameters.Add(Folder);
    Proc.Execute;
  finally
    Proc.Free;
  end;
end;

procedure TMainForm.SwapHeaderSourceClick(Sender: TObject);
const
  HeaderExt: array[0..3] of ShortString = ('.h', '.hpp', '.hh', '.hxx');
  SourceExt: array[0..3] of ShortString = ('.cpp', '.cc', '.cxx', '.c');
var
  Doc: TDocument;
  BaseName, ExtName, Candidate: string;
  I: Integer;
begin
  Doc := CurrentDoc;
  if (Doc = nil) or (Doc.FileName = '') then Exit;
  BaseName := ChangeFileExt(Doc.FileName, '');
  ExtName := LowerCase(ExtractFileExt(Doc.FileName));
  if (ExtName = '.h') or (ExtName = '.hpp') or
     (ExtName = '.hh') or (ExtName = '.hxx') then
  begin
    for I := Low(SourceExt) to High(SourceExt) do
    begin
      Candidate := BaseName + SourceExt[I];
      if FileExists(Candidate) then begin OpenFile(Candidate); Exit; end;
    end;
  end
  else
    for I := Low(HeaderExt) to High(HeaderExt) do
    begin
      Candidate := BaseName + HeaderExt[I];
      if FileExists(Candidate) then begin OpenFile(Candidate); Exit; end;
    end;
end;

procedure TMainForm.CommentClick(Sender: TObject);
var Doc: TDocument;
begin
  Doc := CurrentDoc;
  if (Doc = nil) or FCompileActive then Exit;
  CommentEditorLines(Doc.Editor, False);
end;

procedure TMainForm.UncommentClick(Sender: TObject);
var Doc: TDocument;
begin
  Doc := CurrentDoc;
  if (Doc = nil) or FCompileActive then Exit;
  CommentEditorLines(Doc.Editor, True);
end;

procedure TMainForm.ToggleCommentClick(Sender: TObject);
var
  Doc: TDocument;
  FirstRow, LastRow, I, P: Integer;
  S: string;
  AllCommented: Boolean;
begin
  Doc := CurrentDoc;
  if (Doc = nil) or FCompileActive then Exit;
  FirstRow := Doc.Editor.CaretY;
  LastRow := FirstRow;
  if Doc.Editor.SelAvail then
  begin
    FirstRow := Doc.Editor.BlockBegin.Y;
    LastRow := Doc.Editor.BlockEnd.Y;
  end;
  if (LastRow > FirstRow) and (Doc.Editor.BlockEnd.X = 1) then Dec(LastRow);
  AllCommented := True;
  for I := FirstRow - 1 to LastRow - 1 do
  begin
    S := Doc.Editor.Lines[I];
    P := 1;
    while (P <= Length(S)) and (S[P] in [' ', #9]) do Inc(P);
    if (P <= Length(S)) and (Copy(S, P, 2) <> '//') then
      AllCommented := False;
  end;
  if AllCommented then UncommentClick(Sender)
  else CommentClick(Sender);
end;

procedure TMainForm.InlineCommentClick(Sender: TObject);
var
  Doc: TDocument;
  S, Replacement, StartLine, EndLine: string;
  StartPoint, EndPoint: TPoint;
  Wrapped: Boolean;
begin
  Doc := CurrentDoc;
  if (Doc = nil) or FCompileActive or not Doc.Editor.SelAvail then Exit;
  StartPoint := Doc.Editor.BlockBegin;
  EndPoint := Doc.Editor.BlockEnd;
  S := Doc.Editor.SelText;
  StartLine := Doc.Editor.Lines[StartPoint.Y - 1];
  EndLine := Doc.Editor.Lines[EndPoint.Y - 1];
  Wrapped := False;
  if (Length(S) >= 4) and (Copy(S, 1, 2) = '/*') and
    (Copy(S, Length(S) - 1, 2) = '*/') then
    Replacement := Copy(S, 3, Length(S) - 4)
  else if (StartPoint.X > 2) and
    (Copy(StartLine, StartPoint.X - 2, 2) = '/*') and
    (Copy(EndLine, EndPoint.X, 2) = '*/') then
  begin
    Dec(StartPoint.X, 2);
    Inc(EndPoint.X, 2);
    Doc.Editor.BlockBegin := StartPoint;
    Doc.Editor.BlockEnd := EndPoint;
    Replacement := S;
  end
  else
  begin
    Replacement := '/*' + S + '*/';
    Wrapped := True;
  end;
  Doc.Editor.BeginUndoBlock;
  try
    Doc.Editor.SelText := Replacement;
    EndPoint := Doc.Editor.LogicalCaretXY;
    if Wrapped then
    begin
      Inc(StartPoint.X, 2);
      Dec(EndPoint.X, 2);
    end;
    Doc.Editor.BlockBegin := StartPoint;
    Doc.Editor.BlockEnd := EndPoint;
  finally
    Doc.Editor.EndUndoBlock;
  end;
end;

procedure TMainForm.DeleteLineClick(Sender: TObject);
var Doc: TDocument;
begin
  Doc := CurrentDoc;
  if (Doc = nil) or FCompileActive then Exit;
  Doc.Editor.CommandProcessor(ecDeleteLine, #0, nil);
end;

procedure TMainForm.DuplicateLineClick(Sender: TObject);
var Doc: TDocument;
begin
  Doc := CurrentDoc;
  if (Doc = nil) or FCompileActive then Exit;
  DuplicateEditorLine(Doc.Editor);
end;

procedure TMainForm.MoveSelectionUpClick(Sender: TObject);
var Doc: TDocument;
begin
  Doc := CurrentDoc;
  if (Doc = nil) or FCompileActive then Exit;
  MoveEditorLines(Doc.Editor, -1);
end;

procedure TMainForm.MoveSelectionDownClick(Sender: TObject);
var Doc: TDocument;
begin
  Doc := CurrentDoc;
  if (Doc = nil) or FCompileActive then Exit;
  MoveEditorLines(Doc.Editor, 1);
end;

procedure TMainForm.SaveAllClick(Sender: TObject);
begin
  if FCompileActive or (FDocumentDialogs <> 0) then Exit;
  SaveAllDocs;
end;

function TMainForm.MayClose(Doc: TDocument): Boolean;
var Answer: Integer;
begin
  Result := True;
  if Doc = nil then Exit;
  if not Doc.Dirty and not Doc.Editor.Modified then Exit;
  Inc(FDocumentDialogs);
  try
    Answer := UiMessageDlg(Format(Tr('Save changes to %s?'), [Doc.Tab.Caption]),
      mtConfirmation, [mbYes, mbNo, mbCancel], 0);
    if (Answer <> mrYes) and (Answer <> mrNo) then Exit(False);
    if Answer = mrYes then
    begin
      FPages.ActivePage := Doc.Tab;
      Exit(SaveDoc(Doc));
    end;
  finally
    Dec(FDocumentDialogs);
  end;
end;

procedure TMainForm.DisposeDocument(Doc: TDocument);
var Tab: TTabSheet; I: Integer;
begin
  if (Doc = nil) or (FDocs.IndexOf(Doc) < 0) then Exit;
  HideCompletion;
  HideFunctionTip;
  if FCompletionDoc = Doc then FCompletionDoc := nil;
  if FTipDoc = Doc then FTipDoc := nil;
  for I := FCompilerList.Items.Count - 1 downto 0 do
    if FCompilerList.Items[I].Data = Pointer(Doc) then
      FCompilerList.Items[I].Delete;
  Tab := Doc.Tab;
  FDocs.Remove(Doc);
  Tab.Free;
  UpdateStatus;
end;

procedure TMainForm.CloseClick(Sender: TObject);
var Doc: TDocument;
begin
  if FCompileActive or (FDocumentDialogs <> 0) then Exit;
  Doc := CurrentDoc;
  if (Doc = nil) or not MayClose(Doc) then Exit;
  DisposeDocument(Doc);
end;

procedure TMainForm.CloseQueryHandler(Sender: TObject; var CanClose: Boolean);
var I: Integer;
begin
  if FDocumentDialogs <> 0 then
  begin
    CanClose := False;
    Exit;
  end;
  if FCompileActive then
  begin
    FCompileCancelRequested := True;
    CanClose := False;
    Exit;
  end;
  CanClose := True;
  for I := 0 to FDocs.Count - 1 do
    if not MayClose(TDocument(FDocs[I])) then
    begin CanClose := False; Exit; end;
end;

procedure TMainForm.ExitClick(Sender: TObject);
begin Close; end;

procedure TMainForm.UndoClick(Sender: TObject);
begin
  if not CommandAvailable(@UndoClick) then Exit;
  if ActiveControl is TCustomEdit then TCustomEdit(ActiveControl).Undo
  else if EditorHasFocus then CurrentDoc.Editor.Undo;
end;
procedure TMainForm.RedoClick(Sender: TObject);
begin
  if CommandAvailable(@RedoClick) and EditorHasFocus then CurrentDoc.Editor.Redo;
end;
procedure TMainForm.CutClick(Sender: TObject);
begin
  if not CommandAvailable(@CutClick) then Exit;
  if ActiveControl is TCustomEdit then TCustomEdit(ActiveControl).CutToClipboard
  else if EditorHasFocus then CurrentDoc.Editor.CutToClipboard;
end;
procedure TMainForm.CopyClick(Sender: TObject);
begin
  if not CommandAvailable(@CopyClick) then Exit;
  if ActiveControl is TCustomEdit then TCustomEdit(ActiveControl).CopyToClipboard
  else if EditorHasFocus then CurrentDoc.Editor.CopyToClipboard;
end;
procedure TMainForm.PasteClick(Sender: TObject);
begin
  if not CommandAvailable(@PasteClick) then Exit;
  if ActiveControl is TCustomEdit then TCustomEdit(ActiveControl).PasteFromClipboard
  else if EditorHasFocus then CurrentDoc.Editor.PasteFromClipboard;
end;
procedure TMainForm.SelectAllClick(Sender: TObject);
begin
  if ActiveControl is TCustomEdit then TCustomEdit(ActiveControl).SelectAll
  else if EditorHasFocus then CurrentDoc.Editor.SelectAll;
end;

procedure TMainForm.CompletionClick(Sender: TObject);
begin ShowCompletion(CurrentDoc, False); end;

procedure TMainForm.FindClick(Sender: TObject);
var Query: string; Doc: TDocument;
begin
  Query := FFindText;
  Doc := CurrentDoc;
  if Doc = nil then Exit;
  if Doc.Editor.SelAvail and (Pos(#10, Doc.Editor.SelText) = 0) and
    (Pos(#13, Doc.Editor.SelText) = 0) then Query := Doc.Editor.SelText;
  if UiInputQuery(Tr('Find'), Tr('Find:'), Query) and (Query <> '') then
  begin FFindText := Query; FindNextClick(Self); end;
end;

procedure TMainForm.FindNextClick(Sender: TObject);
var
  Doc: TDocument;
  SourceLine: string;
  Pass, Row, Column, StartRow, StartCol, LastRow, FirstByte, LastByte,
    MatchBytes: Integer;
begin
  Doc := CurrentDoc;
  if (Doc = nil) or (FFindText = '') or (Doc.Editor.Lines.Count = 0) then Exit;
  StartRow := Max(1, Min(Doc.Editor.CaretY, Doc.Editor.Lines.Count));
  StartCol := Doc.Editor.LogicalCaretXY.X;
  for Pass := 0 to 1 do
  begin
    if Pass = 0 then LastRow := Doc.Editor.Lines.Count
    else LastRow := StartRow;
    if Pass = 0 then Row := StartRow else Row := 1;
    while Row <= LastRow do
    begin
      SourceLine := Doc.Editor.Lines[Row - 1];
      FirstByte := 1;
      LastByte := Length(SourceLine);
      if (Pass = 0) and (Row = StartRow) then FirstByte := StartCol;
      if (Pass = 1) and (Row = StartRow) then LastByte := StartCol - 1;
      Column := FindTextForward(SourceLine, FFindText, FirstByte, LastByte, MatchBytes);
      if Column > 0 then
      begin
        Doc.Editor.LogicalCaretXY := Point(Column + MatchBytes, Row);
        Doc.Editor.BlockBegin := Point(Column, Row);
        Doc.Editor.BlockEnd := Point(Column + MatchBytes, Row);
        Doc.Editor.SetFocus;
        Exit;
      end;
      Inc(Row);
    end;
  end;
  FStatus.SimpleText := Format(Tr('Text not found: %s'), [FFindText]);
end;

procedure TMainForm.FindAllClick(Sender: TObject);
var
  Query, SourceLine: string;
  Doc: TDocument;
  Entry: TListItem;
  DocIndex, Row, FoundAt, Offset, MatchBytes: Integer;
begin
  if FCompileActive then Exit;
  Query := FFindText;
  Doc := CurrentDoc;
  if (Doc <> nil) and Doc.Editor.SelAvail and
    (Pos(#10, Doc.Editor.SelText) = 0) and
    (Pos(#13, Doc.Editor.SelText) = 0) then Query := Doc.Editor.SelText;
  if not UiInputQuery(Tr('Find All'), Tr('Find:'), Query) or (Query = '') then Exit;
  FFindText := Query;
  FCompilerList.Items.BeginUpdate;
  try
    FCompilerList.Items.Clear;
    for DocIndex := 0 to FDocs.Count - 1 do
    begin
      Doc := TDocument(FDocs[DocIndex]);
      for Row := 0 to Doc.Editor.Lines.Count - 1 do
      begin
        SourceLine := Doc.Editor.Lines[Row];
        Offset := 1;
        while Offset <= Length(SourceLine) do
        begin
          FoundAt := FindTextForward(SourceLine, Query, Offset, Length(SourceLine), MatchBytes);
          if FoundAt = 0 then Break;
          Entry := FCompilerList.Items.Add;
          Entry.Caption := IntToStr(Row + 1);
          Entry.SubItems.Add(IntToStr(FoundAt));
          if Doc.FileName <> '' then Entry.SubItems.Add(Doc.FileName)
          else Entry.SubItems.Add(Doc.UntitledName);
          Entry.SubItems.Add(Trim(SourceLine));
          Entry.SubItems.Add(IntToStr(MatchBytes));
          Entry.Data := Pointer(Doc);
          Offset := FoundAt + MatchBytes;
        end;
      end;
    end;
  finally
    FCompilerList.Items.EndUpdate;
  end;
  FCompilerTab.Caption := Tr('Find results');
  FReportTabs.ActivePage := FCompilerTab;
  FStatus.SimpleText := Format(Tr('%d matches for %s'), [FCompilerList.Items.Count, Query]);
end;

procedure TMainForm.FindPreviousClick(Sender: TObject);
var
  Doc: TDocument;
  SourceLine: string;
  Pass, Row, Column, StartRow, StartCol, FirstByte, LastByte, MatchBytes: Integer;
begin
  Doc := CurrentDoc;
  if (Doc = nil) or (FFindText = '') or (Doc.Editor.Lines.Count = 0) then Exit;
  StartRow := Max(1, Min(Doc.Editor.CaretY, Doc.Editor.Lines.Count));
  StartCol := Doc.Editor.LogicalCaretXY.X;
  if Doc.Editor.SelAvail then
  begin
    StartRow := Doc.Editor.BlockBegin.Y;
    StartCol := Doc.Editor.BlockBegin.X;
  end;
  for Pass := 0 to 1 do
  begin
    if Pass = 0 then Row := StartRow else Row := Doc.Editor.Lines.Count;
    while (Row >= 1) and ((Pass = 0) or (Row >= StartRow)) do
    begin
      SourceLine := Doc.Editor.Lines[Row - 1];
      FirstByte := 1;
      LastByte := Length(SourceLine);
      if (Pass = 0) and (Row = StartRow) then LastByte := StartCol - 1;
      if (Pass = 1) and (Row = StartRow) then FirstByte := StartCol;
      Column := FindTextBackward(SourceLine, FFindText, FirstByte, LastByte, MatchBytes);
      if Column > 0 then
      begin
        Doc.Editor.LogicalCaretXY := Point(Column + MatchBytes, Row);
        Doc.Editor.BlockBegin := Point(Column, Row);
        Doc.Editor.BlockEnd := Point(Column + MatchBytes, Row);
        Doc.Editor.SetFocus;
        Exit;
      end;
      Dec(Row);
    end;
  end;
  FStatus.SimpleText := Format(Tr('Text not found: %s'), [FFindText]);
end;

procedure TMainForm.ReplaceClick(Sender: TObject);
var
  Doc: TDocument;
  Query, Replacement, OriginalText, NewText: string;
  Answer, MatchCount, SelectedBytes: Integer;
  OriginalCaret, OriginalStart, OriginalEnd: TPoint;

  function ClampPoint(P: TPoint): TPoint;
  begin
    if Doc.Editor.Lines.Count = 0 then Exit(Point(1, 1));
    P.Y := Max(1, Min(P.Y, Doc.Editor.Lines.Count));
    P.X := Max(1, Min(P.X, Length(Doc.Editor.Lines[P.Y - 1]) + 1));
    { Do not restore a caret into the middle of a multi-byte character. }
    while (P.X > 1) and (P.X <= Length(Doc.Editor.Lines[P.Y - 1])) and
      ((Ord(Doc.Editor.Lines[P.Y - 1][P.X]) and $C0) = $80) do Dec(P.X);
    Result := P;
  end;

  function SelectionMatches: Boolean;
  begin
    SelectedBytes := Length(Doc.Editor.SelText);
    Result := (SelectedBytes > 0) and
      (FindTextMatchLengthAt(Doc.Editor.SelText, Query, 1) = SelectedBytes);
  end;
begin
  Doc := CurrentDoc;
  if (Doc = nil) or FCompileActive or Doc.Editor.ReadOnly then Exit;
  Query := FFindText;
  if Doc.Editor.SelAvail and (Pos(#10, Doc.Editor.SelText) = 0) and
    (Pos(#13, Doc.Editor.SelText) = 0) then Query := Doc.Editor.SelText;
  if not UiInputQuery(Tr('Replace'), Tr('Find:'), Query) or (Query = '') then Exit;
  Replacement := '';
  if not UiInputQuery(Tr('Replace'), Tr('Replace with:'), Replacement) then Exit;
  FFindText := Query;
  if Sender = nil then Answer := mrYes
  else Answer := UiMessageDlg(Tr('Replace all occurrences?' + LineEnding +
    'Yes: replace all    No: replace next'), mtConfirmation,
    [mbYes, mbNo, mbCancel], 0);
  if Answer = mrCancel then Exit;
  if (FDocs.IndexOf(Doc) < 0) or FCompileActive then Exit;
  if Answer = mrYes then
  begin
    OriginalCaret := Doc.Editor.LogicalCaretXY;
    OriginalStart := Doc.Editor.BlockBegin;
    OriginalEnd := Doc.Editor.BlockEnd;
    Doc.Editor.BeginUndoBlock;
    try
      Doc.Editor.SelectAll;
      OriginalText := Doc.Editor.SelText;
      NewText := ReplaceTextMatches(OriginalText, Query, Replacement, MatchCount);
      if MatchCount > 0 then Doc.Editor.SelText := NewText;
      Doc.Editor.LogicalCaretXY := ClampPoint(OriginalCaret);
      if (OriginalCaret.Y = OriginalStart.Y) and (OriginalCaret.X = OriginalStart.X) then
      begin
        Doc.Editor.BlockBegin := ClampPoint(OriginalEnd);
        Doc.Editor.BlockEnd := ClampPoint(OriginalStart);
      end
      else
      begin
        Doc.Editor.BlockBegin := ClampPoint(OriginalStart);
        Doc.Editor.BlockEnd := ClampPoint(OriginalEnd);
      end;
    finally
      Doc.Editor.EndUndoBlock;
    end;
    Doc.Editor.SetFocus;
  end
  else
  begin
    if not SelectionMatches then FindNextClick(Self);
    if SelectionMatches then
    begin
      Doc.Editor.BeginUndoBlock;
      try
        Doc.Editor.SelText := Replacement;
      finally
        Doc.Editor.EndUndoBlock;
      end;
      FindNextClick(Self);
    end;
  end;
end;

procedure TMainForm.ReplaceAllClick(Sender: TObject);
begin
  ReplaceClick(nil);
end;

procedure TMainForm.GotoClick(Sender: TObject);
var Doc: TDocument; LineInput: string; Row: Integer;
begin
  Doc := CurrentDoc;
  if Doc = nil then Exit;
  LineInput := IntToStr(Doc.Editor.CaretY);
  if not UiInputQuery(Tr('Go to line'), Tr('Line number:'), LineInput) then Exit;
  if not TryStrToInt(LineInput, Row) then Exit;
  if Row < 1 then Exit;
  if Row > Doc.Editor.Lines.Count then Row := Doc.Editor.Lines.Count;
  Doc.Editor.CaretXY := Point(1, Row);
  Doc.Editor.SetFocus;
  UpdateStatus;
end;

procedure TMainForm.NextTabClick(Sender: TObject);
begin
  if FPages.PageCount > 1 then
    FPages.ActivePageIndex := (FPages.ActivePageIndex + 1) mod FPages.PageCount;
end;

procedure TMainForm.PreviousTabClick(Sender: TObject);
begin
  if FPages.PageCount > 1 then
    FPages.ActivePageIndex := (FPages.ActivePageIndex + FPages.PageCount - 1)
      mod FPages.PageCount;
end;

procedure TMainForm.CloseAllClick(Sender: TObject);
var I: Integer;
begin
  if FCompileActive or (FDocumentDialogs <> 0) then Exit;
  Inc(FDocumentDialogs);
  try
    for I := 0 to FDocs.Count - 1 do
      if not MayClose(TDocument(FDocs[I])) then Exit;
    while FDocs.Count > 0 do
      DisposeDocument(TDocument(FDocs[FDocs.Count - 1]));
  finally
    Dec(FDocumentDialogs);
  end;
end;

procedure TMainForm.CompileCurrent(SyntaxOnly, RunAfter: Boolean);
const
  MaxCompileLogBytes = 4 * 1024 * 1024;
var
  Doc: TDocument;
  UseProject, IsCpp, UseSession, LogTruncated, CancelEscalated: Boolean;
  Ini: TIniFile;
  Proc: TProcess;
  Source, CompilerName, OutputFile, BuildOutput, Flags, LinkerFlags,
    ProjectUnitName, ProjectSnapshot, RunTarget, CompileError: string;
  I, N, Available, TargetIndex, SignalNumber, UnitCount: Integer;
  CancelStarted: QWord;
  ErrorItem: TListItem;
  Buffer: array[0..4095] of Byte;
  Chunk, LogText: RawByteString;
  ExecutableStream: TFileStream;

  procedure InvalidateTarget;
  begin
    if OutputFile = '' then Exit;
    if FInvalidExecutables = nil then
    begin
      FInvalidExecutables := TStringList.Create;
      FInvalidExecutables.CaseSensitive := True;
    end;
    if FInvalidExecutables.IndexOf(OutputFile) < 0 then
      FInvalidExecutables.Add(OutputFile);
    if FLastExecutable = OutputFile then FLastExecutable := '';
  end;

  procedure CancelCompiler;
  begin
    if CancelStarted = 0 then
    begin
      CancelStarted := GetTickCount64;
      SignalNumber := 15;
    end
    else if not CancelEscalated and (GetTickCount64 - CancelStarted >= 1000) then
    begin
      CancelEscalated := True;
      SignalNumber := 9;
    end
    else Exit;
    {$IFDEF UNIX}
    { setsid normally execs the compiler. Verify both IDs at the time of the
      signal; never send a group signal to the IDE's inherited process group. }
    if UseSession and
      (CompilerGetProcessGroup(Proc.ProcessID) = LongInt(Proc.ProcessID)) and
      (CompilerGetSession(Proc.ProcessID) = LongInt(Proc.ProcessID)) then
      CompilerSignal(-LongInt(Proc.ProcessID), SignalNumber)
    else
      CompilerSignal(LongInt(Proc.ProcessID), SignalNumber);
    {$ELSE}
    Proc.Terminate(1);
    {$ENDIF}
  end;

  procedure WaitForCompiler(Timeout: QWord);
  var StartedAt: QWord;
  begin
    StartedAt := GetTickCount64;
    while Proc.Running and (GetTickCount64 - StartedAt < Timeout) do Sleep(10);
  end;

begin
  FLastCompileSucceeded := False;
  if FCompileActive or DebuggerActive or (Application.ModalLevel > 0) then Exit;
  Doc := CurrentDoc;
  if (Doc = nil) and (FProjectPath = '') then Exit;
  if (Doc <> nil) and ((Doc.FileName = '') or Doc.Dirty or Doc.Editor.Modified) then
    if not SaveDoc(Doc) then Exit;
  UseProject := DocumentBelongsToProject(Doc);
  if UseProject and not SaveAllDocs then Exit;
  { All modal save operations finish before establishing this compile snapshot. }
  ProjectSnapshot := '';
  if UseProject then ProjectSnapshot := FProjectPath;
  OutputFile := '';
  BuildOutput := '';
  RunTarget := '';
  CompileError := '';
  Proc := TProcess.Create(nil);
  try
    try
      Proc.Options := [poUsePipes, poStderrToOutPut];
      LinkerFlags := '';
      if UseProject then
      begin
        Ini := TIniFile.Create(ProjectSnapshot);
        try
          if Ini.ReadInteger('Project', 'Type', 1) <> 1 then
            raise Exception.Create(Tr('Only console projects are currently supported.'));
          IsCpp := Ini.ReadBool('Project', 'IsCpp', False);
          for I := 0 to FProjectFiles.Count - 1 do
            if (LowerCase(ExtractFileExt(FProjectFiles[I])) = '.cpp') or
               (LowerCase(ExtractFileExt(FProjectFiles[I])) = '.cc') or
               (LowerCase(ExtractFileExt(FProjectFiles[I])) = '.cxx') then
              IsCpp := True;
          if IsCpp then CompilerName := FCppCompiler else CompilerName := FCCompiler;
          Proc.CurrentDirectory := ExtractFilePath(ProjectSnapshot);
          UnitCount := Ini.ReadInteger('Project', 'UnitCount', 0);
          if (UnitCount < 0) or (UnitCount > 100000) then
            raise Exception.Create(Tr('Invalid project unit count.'));
          for I := 1 to UnitCount do
          begin
            if not Ini.ReadBool('Unit' + IntToStr(I), 'Compile', True) then Continue;
            ProjectUnitName := Ini.ReadString('Unit' + IntToStr(I), 'FileName', '');
            if ProjectUnitName = '' then Continue;
            Source := ProjectUnitPath(ProjectSnapshot, ProjectUnitName);
            if (LowerCase(ExtractFileExt(Source)) <> '.c') and
               (LowerCase(ExtractFileExt(Source)) <> '.cc') and
               (LowerCase(ExtractFileExt(Source)) <> '.cpp') and
               (LowerCase(ExtractFileExt(Source)) <> '.cxx') then Continue;
            Proc.Parameters.Add(Source);
          end;
          if Proc.Parameters.Count = 0 then
            raise Exception.Create(Tr('Project has no C/C++ sources.'));
          OutputFile := ChangeFileExt(ProjectSnapshot, '');
          Flags := Ini.ReadString('Project', 'CppCompiler', '');
          if not IsCpp then Flags := Ini.ReadString('Project', 'Compiler', '');
          LinkerFlags := Ini.ReadString('Project', 'Linker', '');
          AddCompilerFlags(Proc.Parameters, Flags);
        finally Ini.Free; end;
      end
      else
      begin
        Source := Doc.FileName;
        if LowerCase(ExtractFileExt(Source)) = '.c' then IsCpp := False
        else if (LowerCase(ExtractFileExt(Source)) = '.cpp') or
                (LowerCase(ExtractFileExt(Source)) = '.cc') or
                (LowerCase(ExtractFileExt(Source)) = '.cxx') then IsCpp := True
        else
          raise Exception.Create(Tr('Open a C/C++ source file to compile.'));
        if IsCpp then CompilerName := FCppCompiler else CompilerName := FCCompiler;
        Proc.CurrentDirectory := ExtractFilePath(Source);
        Proc.Parameters.Add(Source);
        OutputFile := ChangeFileExt(Source, '');
      end;
      if Pos('/', CompilerName) > 0 then Proc.Executable := CompilerName
      else Proc.Executable := '/usr/bin/' + CompilerName;
      if IsCpp then AddCompilerFlags(Proc.Parameters, FCppFlags)
      else AddCompilerFlags(Proc.Parameters, FCFlags);
      if SyntaxOnly then Proc.Parameters.Add('-fsyntax-only')
      else
      begin
        { Linking over a running executable produces ETXTBSY on Linux. Keeping
          the previous target intact also prevents publishing a partial link. }
        BuildOutput := GetTempFileName(ExtractFilePath(OutputFile), '.devcpp-build-');
        Proc.Parameters.Add('-o');
        Proc.Parameters.Add(BuildOutput);
        AddCompilerFlags(Proc.Parameters, Trim(LinkerFlags + ' ' + FLinkerFlags));
      end;
      if FDebugBuild and not SyntaxOnly then
      begin
        { A final -g/-O setting overrides release profile flags. Strip must be
          removed because it otherwise discards the source/variable symbols. }
        for I := Proc.Parameters.Count - 1 downto 0 do
          if (Proc.Parameters[I] = '-s') or
            (Proc.Parameters[I] = '-Wl,-s') or
            (Proc.Parameters[I] = '-Wl,--strip-all') then Proc.Parameters.Delete(I);
        Proc.Parameters.Add('-g3');
        Proc.Parameters.Add('-O0');
        Proc.Parameters.Add('-fno-omit-frame-pointer');
      end;
      FCompileDirectory := ExpandFileName(Proc.CurrentDirectory);
      FOutput.Clear;
      for I := 0 to FDocs.Count - 1 do
      begin
        TDocument(FDocs[I]).ErrorLine := -1;
        TDocument(FDocs[I]).Editor.Invalidate;
      end;
      FCompilerList.Items.Clear;
      FCompilerTab.Caption := Tr('Compiler');
      FReportTabs.ActivePage := FLogTab;
      FOutput.Lines.Add(DisplayCommandLine(CompilerName, Proc.Parameters));
      UseSession := False;
      {$IFDEF UNIX}
      UseSession := FileExists('/usr/bin/setsid');
      if UseSession then
      begin
        Proc.Parameters.Insert(0, Proc.Executable);
        Proc.Executable := '/usr/bin/setsid';
      end;
      {$ENDIF}
      CancelStarted := 0;
      CancelEscalated := False;
      LogTruncated := False;
      LogText := '';
      FCompileCancelRequested := False;
      FCompileActive := True;
      if not SyntaxOnly then InvalidateTarget;
      FStatus.SimpleText := Tr('Compiling...');
      RefreshCommandStates(Self);
      Application.ProcessMessages;
      Proc.Execute;
      repeat
        if FCompileCancelRequested and Proc.Running then CancelCompiler;
        Available := Proc.Output.NumBytesAvailable;
        if Available > SizeOf(Buffer) then Available := SizeOf(Buffer);
        if Available > 0 then
        begin
          N := Proc.Output.Read(Buffer, Available);
          if N > 0 then
          begin
            if Length(LogText) + N > MaxCompileLogBytes then
            begin
              N := Max(0, MaxCompileLogBytes - Length(LogText));
              LogTruncated := True;
            end;
            SetLength(Chunk, N);
            if N > 0 then
            begin
              Move(Buffer[0], Chunk[1], N);
              LogText := LogText + Chunk;
            end;
          end;
        end
        else if Proc.Running then Sleep(10);
        Application.ProcessMessages;
      until (not Proc.Running) and (Proc.Output.NumBytesAvailable = 0);
      FOutput.Text := FOutput.Text + string(LogText);
      if LogTruncated then
        FOutput.Lines.Add(Tr('Compiler output exceeded 4 MiB and was truncated.'));
      PopulateDiagnostics(string(LogText));
      if FCompileCancelRequested then
      begin
        InvalidateTarget;
        FStatus.SimpleText := Tr('Compilation aborted');
        FOutput.Lines.Add(Tr('Compilation aborted.'));
      end
      else if Proc.ExitStatus = 0 then
      begin
        if not SyntaxOnly then
        begin
          if not FileExists(BuildOutput) then
            raise Exception.Create(Tr('The compiler did not produce an executable.'));
          ExecutableStream := TFileStream.Create(BuildOutput, fmOpenRead or fmShareDenyNone);
          try
            if ExecutableStream.Size = 0 then
              raise Exception.Create(Tr('The compiler did not produce an executable.'));
          finally ExecutableStream.Free; end;
          if not RenameFile(BuildOutput, OutputFile) then
            raise Exception.Create(Tr('Could not replace the compiled executable.'));
          BuildOutput := '';
          FLastExecutable := OutputFile;
          FLastCompileSucceeded := True;
          if FInvalidExecutables <> nil then
          begin
            TargetIndex := FInvalidExecutables.IndexOf(OutputFile);
            if TargetIndex >= 0 then FInvalidExecutables.Delete(TargetIndex);
          end;
          if RunAfter then RunTarget := OutputFile;
        end;
        FStatus.SimpleText := Tr('Compilation successful');
        FOutput.Lines.Add(Tr('Compilation successful.'));
      end
      else
      begin
        InvalidateTarget;
        FStatus.SimpleText := Tr('Compilation failed');
        if Pos('unrecognized option ''--stack=', string(LogText)) > 0 then
          FOutput.Lines.Add(Tr('The --stack linker option is for Windows. Remove it in Execute > Compiler Parameters.'));
        FOutput.Lines.Add(Format(Tr('Compilation failed (exit %d).'), [Proc.ExitStatus]));
        ErrorItem := nil;
        for I := 0 to FCompilerList.Items.Count - 1 do
          if (FCompilerList.Items[I].SubItems.Count >= 3) and
            (Pos('error:', LowerCase(FCompilerList.Items[I].SubItems[2])) > 0) then
          begin ErrorItem := FCompilerList.Items[I]; Break; end;
        if (ErrorItem = nil) and (FCompilerList.Items.Count > 0) then
          ErrorItem := FCompilerList.Items[0];
        if ErrorItem <> nil then
        begin
          ErrorItem.Selected := True;
          ErrorDoubleClick(Self);
        end;
      end;
    except
      on E: Exception do
      begin
        InvalidateTarget;
        CompileError := Format(Tr('Compile failed: %s'), [E.Message]);
        FStatus.SimpleText := Tr('Compilation failed');
        FOutput.Lines.Add(CompileError);
      end;
    end;
  finally
    if Proc.Running then
    begin
      CancelStarted := 0;
      CancelCompiler;
      WaitForCompiler(1000);
      if Proc.Running then
      begin
        CancelStarted := GetTickCount64 - 1000;
        CancelCompiler;
        WaitForCompiler(1000);
      end;
    end;
    Proc.Free;
    if BuildOutput <> '' then DeleteFile(BuildOutput);
    FCompileActive := False;
    FCompileCancelRequested := False;
    RefreshCommandStates(Self);
  end;
  if CompileError <> '' then
    UiMessageDlg(CompileError, mtError, [mbOK], 0)
  else if RunTarget <> '' then
    RunExecutable(RunTarget, ProjectSnapshot);
end;

function TMainForm.DocumentBelongsToProject(Doc: TDocument): Boolean;
var I: Integer;
begin
  Result := False;
  if FProjectPath = '' then Exit;
  if Doc = nil then Exit(True);
  for I := 0 to FProjectFiles.Count - 1 do
    if SameDocumentPath(Doc.FileName, FProjectFiles[I]) then Exit(True);
end;

procedure TMainForm.ReadRunSettings(const ProjectFile: string;
  out Arguments, WorkDirectory: string);
var Ini: TIniFile;
begin
  if ProjectFile <> '' then
  begin
    Ini := TIniFile.Create(ProjectFile);
    try
      Arguments := Ini.ReadString('Project', 'CommandLine', '');
      WorkDirectory := Ini.ReadString('Project', 'RunWorkingDirectory', '');
    finally Ini.Free; end;
  end
  else
  begin
    Ini := TIniFile.Create(FOptionsPath);
    try
      Arguments := Ini.ReadString('Run', 'Parameters', '');
      WorkDirectory := Ini.ReadString('Run', 'WorkingDirectory', '');
    finally Ini.Free; end;
  end;
end;

procedure TMainForm.ExecuteParametersClick(Sender: TObject);
var
  Doc: TDocument;
  ProjectFile, Arguments, WorkDirectory, ErrorText, ExecutableName: string;
  Args: TStringList;
  Ini: TIniFile;
  ProjectIni: TMemIniFile;
  ProjectSnapshot: TFileSnapshot;
begin
  if FCompileActive or (Application.ModalLevel > 0) then Exit;
  Doc := CurrentDoc;
  ProjectFile := '';
  ExecutableName := '';
  if DocumentBelongsToProject(Doc) then
  begin
    ProjectFile := FProjectPath;
    ExecutableName := ChangeFileExt(ProjectFile, '');
  end
  else if (Doc <> nil) and (Doc.FileName <> '') then
    ExecutableName := ChangeFileExt(Doc.FileName, '');
  Args := TStringList.Create;
  try
    try
      if ProjectFile <> '' then
      begin
        ProjectSnapshot := CaptureFileSnapshot(ProjectFile);
        if not ProjectSnapshot.Present then
          raise Exception.Create(Format(Tr('Project not found: %s'), [ProjectFile]));
      end;
      ReadRunSettings(ProjectFile, Arguments, WorkDirectory);
      if not UiInputQuery(Tr('Execute Parameters'), Tr('Program arguments:'), Arguments) then Exit;
      if not ParseRunArguments(Arguments, Args, ErrorText) then
      begin
        UiMessageDlg(Tr(ErrorText), mtError, [mbOK], 0);
        Exit;
      end;
      if not UiInputQuery(Tr('Execute Parameters'),
        Tr('Working directory (empty = program folder):'), WorkDirectory) then Exit;
      WorkDirectory := Trim(WorkDirectory);
      if (WorkDirectory <> '') and (ExecutableName <> '') and
        not DirectoryExists(ResolveRunDirectory(WorkDirectory, ExecutableName)) then
      begin
        UiMessageDlg(Tr('The working directory does not exist.'), mtError, [mbOK], 0);
        Exit;
      end;
      { Reopen after the modal dialogs so other settings written meanwhile
        cannot be replaced by an older TIniFile snapshot. }
      if ProjectFile <> '' then
      begin
        ProjectIni := TMemIniFile.Create(ProjectFile);
        try
          ProjectIni.WriteString('Project', 'CommandLine', Arguments);
          ProjectIni.WriteString('Project', 'RunWorkingDirectory', WorkDirectory);
          WriteProjectIni(ProjectIni, ProjectFile, ProjectSnapshot);
        finally ProjectIni.Free; end;
      end
      else
      begin
        Ini := TIniFile.Create(FOptionsPath);
        try
          Ini.WriteString('Run', 'Parameters', Arguments);
          Ini.WriteString('Run', 'WorkingDirectory', WorkDirectory);
        finally Ini.Free; end;
      end;
    except
      on E: Exception do
        UiMessageDlg(Format(Tr('Could not save execution parameters: %s'), [E.Message]),
          mtError, [mbOK], 0);
    end;
  finally
    Args.Free;
  end;
end;

procedure TMainForm.RunExecutable(const FileName: string; const ProjectFile: string);
var
  Proc: TProcess;
  Args: TStringList;
  PauserPath, Arguments, WorkDirectory, ErrorText, RunCommand: string;
  I: Integer;
begin
  if FCompileActive then Exit;
  if (FileName = '') or not FileExists(FileName) or
    ((FInvalidExecutables <> nil) and (FInvalidExecutables.IndexOf(FileName) >= 0)) then
  begin
    UiMessageDlg(Tr('Compile the program first.'), mtInformation, [mbOK], 0);
    Exit;
  end;
  Proc := TProcess.Create(nil);
  Args := TStringList.Create;
  try
    try
      ReadRunSettings(ProjectFile, Arguments, WorkDirectory);
      if not ParseRunArguments(Arguments, Args, ErrorText) then
        raise Exception.Create(Tr(ErrorText));
      PauserPath := ExtractFilePath(ParamStr(0)) + 'console-pauser.sh';
      if not FileExists(PauserPath) then
        raise Exception.Create(Tr('Missing console-pauser.sh beside the application.'));
      if FileExists('/usr/bin/gnome-terminal') then
        Proc.Executable := '/usr/bin/gnome-terminal'
      else
        Proc.Executable := '/usr/bin/xterm';
      Proc.CurrentDirectory := ResolveRunDirectory(WorkDirectory, FileName);
      if not DirectoryExists(Proc.CurrentDirectory) then
        raise Exception.Create(Tr('The working directory does not exist.'));
      if Proc.Executable = '/usr/bin/gnome-terminal' then
      begin
        Proc.Parameters.Add('--title=' + ExtractFileName(FileName));
        Proc.Parameters.Add('--working-directory=' + Proc.CurrentDirectory);
        Proc.Parameters.Add('--');
      end
      else
      begin
        Proc.Parameters.Add('-T');
        Proc.Parameters.Add(ExtractFileName(FileName));
        Proc.Parameters.Add('-e');
      end;
      { FPC 3.0.x TProcess turns an empty parameter into nil, truncating argv.
        Pass one nonempty command with every argument quoted as a shell literal. }
      RunCommand := 'exec ' + QuoteShellArgument('/bin/bash') + ' ' +
        QuoteShellArgument(PauserPath) + ' ' +
        QuoteShellArgument(ExpandFileName(FileName));
      for I := 0 to Args.Count - 1 do
        RunCommand := RunCommand + ' ' + QuoteShellArgument(Args[I]);
      Proc.Parameters.Add('/bin/bash');
      Proc.Parameters.Add('-c');
      Proc.Parameters.Add(RunCommand);
      Proc.Execute;
    except
      on E: Exception do
        UiMessageDlg(Format(Tr('Run failed: %s'), [E.Message]), mtError, [mbOK], 0);
    end;
  finally
    Args.Free;
    Proc.Free;
  end;
end;

procedure TMainForm.CompileClick(Sender: TObject);
begin CompileCurrent(False, False); end;
procedure TMainForm.AbortCompileClick(Sender: TObject);
begin if FCompileActive then FCompileCancelRequested := True; end;
procedure TMainForm.SyntaxClick(Sender: TObject);
begin CompileCurrent(True, False); end;
procedure TMainForm.CompileRunClick(Sender: TObject);
begin CompileCurrent(False, True); end;
procedure TMainForm.RunClick(Sender: TObject);
var Doc: TDocument; FileName, ProjectFile: string;
begin
  if FCompileActive or (Application.ModalLevel > 0) then Exit;
  Doc := CurrentDoc;
  ProjectFile := '';
  FileName := '';
  if DocumentBelongsToProject(Doc) then
  begin
    ProjectFile := FProjectPath;
    FileName := ChangeFileExt(ProjectFile, '');
  end
  else if (Doc <> nil) and (Doc.FileName <> '') then
    FileName := ChangeFileExt(Doc.FileName, '');
  RunExecutable(FileName, ProjectFile);
end;

function TMainForm.DebuggerActive: Boolean;
begin
  Result := (FDebugger <> nil) and FDebugger.Session.Active;
end;

function TMainForm.DebuggerStopped: Boolean;
begin
  Result := (FDebugger <> nil) and (FDebugger.Session.State = gsStopped);
end;

procedure TMainForm.InitializeDebugger;
begin
  if FDebugger <> nil then Exit;
  if FDebugTab = nil then
  begin
    FDebugTab := TTabSheet.Create(Self);
    FDebugTab.PageControl := FReportTabs;
    FDebugTab.Caption := Tr('Debug');
  end;
  FDebugger := TDebuggerPanel.Create(Self);
  FDebugger.Parent := FDebugTab; FDebugger.Align := alClient;
  FDebugger.AttachSidebar(FLeftDebugTab);
  FDebugger.Session.OnLocation := @DebugLocation;
  FDebugger.OnStateChange := @DebugStateChange;
  FDebugTimer := TTimer.Create(Self);
  FDebugTimer.Interval := 40; FDebugTimer.OnTimer := @DebugTick;
  FDebugTimer.Enabled := True;
end;

procedure TMainForm.ShutdownDebugger;
begin
  FreeAndNil(FDebugTimer);
  if FDebugger <> nil then FDebugger.OnStateChange := nil;
  FreeAndNil(FDebugger);
end;

procedure TMainForm.DebugTick(Sender: TObject);
begin
  if FDebugger <> nil then FDebugger.Session.Poll;
end;

procedure TMainForm.DebugStateChange(Sender: TObject);
var I: Integer;
begin
  if not DebuggerStopped then begin FDebugLine := 0; FDebugFile := ''; end;
  if FDocs <> nil then
    for I := 0 to FDocs.Count - 1 do
    begin
      UpdateDebugMarkers(TDocument(FDocs[I]));
      TDocument(FDocs[I]).Editor.Invalidate;
    end;
  RefreshCommandStates(Self);
end;

procedure TMainForm.DebugLocation(Sender: TObject; const FileName: string; Line: Integer);
var Doc: TDocument;
begin
  if not FileExists(FileName) then Exit;
  OpenFile(FileName);
  Doc := FindDoc(FileName);
  if Doc = nil then Exit;
  FDebugFile := Doc.FileName; FDebugLine := Line;
  UpdateDebugMarkers(Doc);
  FPages.ActivePage := Doc.Tab;
  Doc.Editor.CaretY := EnsureRange(Line, 1, Max(1, Doc.Editor.Lines.Count));
  Doc.Editor.CaretX := 1;
  Doc.Editor.TopLine := Max(1, Line - 5);
  Doc.Editor.Invalidate;
  Doc.Editor.SetFocus;
  UpdateStatus;
end;

procedure TMainForm.DebugStartClick(Sender: TObject);
var Doc: TDocument; ProjectFile, Arguments, WorkDirectory, ErrorText: string;
  Args: TStringList;
begin
  if FCompileActive or DebuggerActive or (Application.ModalLevel > 0) then Exit;
  InitializeDebugger;
  Doc := CurrentDoc; ProjectFile := '';
  if DocumentBelongsToProject(Doc) then ProjectFile := FProjectPath;
  FDebugBuild := True;
  try CompileCurrent(False, False); finally FDebugBuild := False; end;
  if not FLastCompileSucceeded then Exit;
  Args := TStringList.Create;
  try
    try
      ReadRunSettings(ProjectFile, Arguments, WorkDirectory);
      if not ParseRunArguments(Arguments, Args, ErrorText) then
        raise Exception.Create(Tr(ErrorText));
      WorkDirectory := ResolveRunDirectory(WorkDirectory, FLastExecutable);
      if not DirectoryExists(WorkDirectory) then
        raise Exception.Create(Tr('The working directory does not exist.'));
      FReportTabs.ActivePage := FDebugTab;
      FLeftTabs.ActivePage := FLeftDebugTab;
      FDebugger.BeginSession;
      FDebugger.Session.Start(FLastExecutable, WorkDirectory, Args);
    except
      on E: Exception do UiMessageDlg(Tr('Debug failed: ') + E.Message,
        mtError, [mbOK], 0);
    end;
  finally Args.Free; end;
end;

procedure TMainForm.DebugToggleBreakpointClick(Sender: TObject);
var Doc: TDocument;
begin
  Doc := CurrentDoc;
  if Doc = nil then Exit;
  ToggleSourceBreakpoint(Doc, Doc.Editor.CaretY);
end;

procedure TMainForm.EditorLineClick(Sender: TObject; Line: Integer);
var I: Integer; Doc: TDocument;
begin
  if FDocs = nil then Exit;
  HideCompletion;
  HideFunctionTip;
  for I := 0 to FDocs.Count - 1 do
  begin
    Doc := TDocument(FDocs[I]);
    if Doc.Editor = Sender then
    begin
      ToggleSourceBreakpoint(Doc, Line);
      Exit;
    end;
  end;
end;

procedure TMainForm.ToggleSourceBreakpoint(Doc: TDocument; Line: Integer);
begin
  if (Doc = nil) or FCompileActive or (Application.ModalLevel > 0) or
    (Line < 1) or (Line > Doc.Editor.Lines.Count) then Exit;
  if DebuggerActive and not (FDebugger.Session.State in [gsStopped, gsRunning]) then
  begin
    FStatus.SimpleText := Tr('Pause the program before changing breakpoints.');
    Exit;
  end;
  if (Doc.FileName = '') and not SaveDoc(Doc) then Exit;
  InitializeDebugger;
  try
    FDebugger.Session.ToggleBreakpoint(Doc.FileName, Line);
    FDebugger.RefreshBreakpoints;
    UpdateDebugMarkers(Doc);
    Doc.Editor.Invalidate;
  except on E: Exception do FStatus.SimpleText := Tr(E.Message); end;
end;

procedure TMainForm.UpdateDebugMarkers(Doc: TDocument);
var I, Image: Integer; Mark: TSynEditMark; B: TGdbBreakpoint;
begin
  if (Doc = nil) or (FDebugImages = nil) then Exit;
  for I := Doc.Editor.Marks.Count - 1 downto 0 do
    if Doc.Editor.Marks[I] is TNoiDebugMark then Doc.Editor.Marks[I].Free;
  if (FDebugger = nil) or (Doc.FileName = '') then Exit;
  for I := 0 to FDebugger.Session.Breakpoints.Count - 1 do
  begin
    B := TGdbBreakpoint(FDebugger.Session.Breakpoints[I]);
    if (B.FileName <> Doc.FileName) or (B.Line < 1) or
      (B.Line > Doc.Editor.Lines.Count) then Continue;
    Image := 0;
    if (FDebugFile = Doc.FileName) and (FDebugLine = B.Line) then Image := 2;
    Mark := TNoiDebugMark.Create(Doc.Editor);
    Mark.Line := B.Line;
    Mark.Column := 1;
    Mark.BookmarkNumber := -1;
    Mark.InternalImage := False;
    Mark.ImageList := FDebugImages;
    Mark.ImageIndex := Image;
    Mark.Visible := True;
    Doc.Editor.Marks.Add(Mark);
  end;
  if (FDebugFile = Doc.FileName) and (FDebugLine > 0) and
    not FDebugger.Session.HasBreakpoint(Doc.FileName, FDebugLine) then
  begin
    Mark := TNoiDebugMark.Create(Doc.Editor);
    Mark.Line := FDebugLine;
    Mark.Column := 1;
    Mark.BookmarkNumber := -1;
    Mark.InternalImage := False;
    Mark.ImageList := FDebugImages;
    Mark.ImageIndex := 1;
    Mark.Visible := True;
    Doc.Editor.Marks.Add(Mark);
  end;
  Doc.Editor.InvalidateGutter;
end;

procedure TMainForm.DebugContinueClick(Sender: TObject);
begin if FDebugger <> nil then FDebugger.Session.ContinueExecution; end;
procedure TMainForm.DebugStepIntoClick(Sender: TObject);
begin if FDebugger <> nil then FDebugger.Session.StepInto; end;
procedure TMainForm.DebugStepOverClick(Sender: TObject);
begin if FDebugger <> nil then FDebugger.Session.StepOver; end;
procedure TMainForm.DebugStopClick(Sender: TObject);
begin if FDebugger <> nil then FDebugger.Session.Stop; end;
procedure TMainForm.DebugEvaluateClick(Sender: TObject);
begin
  if FDebugger = nil then Exit;
  FReportTabs.ActivePage := FDebugTab; FDebugger.FocusExpression;
end;

procedure TMainForm.AboutClick(Sender: TObject);
begin
  ShowAboutDialog(Self);
end;

end.
