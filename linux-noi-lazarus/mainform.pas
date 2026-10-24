unit mainform;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StrUtils, Math, Types, Forms, Controls, StdCtrls, ComCtrls, ExtCtrls,
  Menus, Dialogs, IniFiles, Process, Contnrs, LCLType, Graphics, ImgList,
  LazUTF8, SynEdit, SynEditTypes, SynEditKeyCmds, SynEditHighlighter,
  SynHighlighterCpp, SynGutterLineNumber, SynGutterChanges,
  cppcompletion, ui_language, app_instance;

type
  TNoiCppSyn = class(TSynCppSyn)
  private
    FCurrentLine: string;
  public
    procedure SetLine(const NewValue: string; LineNumber: Integer); override;
    function GetTokenAttribute: TSynHighlighterAttributes; override;
  end;

  TNoiSynEdit = class(TSynEdit)
  private
    FHomeRepeat: Boolean;
  protected
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
  public
    procedure ResetHomeCycle;
    function FindMatchingBracketLogical(LogicalStartBracket: TPoint;
      StartIncludeNeighborChars, MoveCaret, SelectBrackets,
      OnlyVisible: Boolean): TPoint; override;
  end;

  TDocument = class
    Tab: TTabSheet;
    Editor: TSynEdit;
    Syntax: TNoiCppSyn;
    FileName: string;
    UntitledName: string;
    Dirty: Boolean;
    MissingNotified: Boolean;
    ErrorLine: Integer;
    PreferredColumn: Integer;
  end;

  TMainForm = class(TForm)
  private
    FPages: TPageControl;
    FProjectTree: TTreeView;
    FOutput: TMemo;
    FReportTabs: TPageControl;
    FCompilerTab: TTabSheet;
    FLogTab: TTabSheet;
    FCompilerList: TListView;
    FStatus: TStatusBar;
    FDocs: TObjectList;
    FProjectFiles: TStringList;
    FProjectPath: string;
    FLastExecutable: string;
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
    FEditorTabWidth: Integer;
    FCompletionDismissed: Boolean;
    FCompileActive: Boolean;
    FCompileCancelRequested: Boolean;
    FFileWatchTimer: TTimer;
    FInstanceTimer: TTimer;
    FChineseLanguageItem, FEnglishLanguageItem: TMenuItem;
    procedure InstanceTick(Sender: TObject);
    procedure ChineseLanguageClick(Sender: TObject);
    procedure EnglishLanguageClick(Sender: TObject);
    function AddMenu(ParentItem: TMenuItem; const ACaption: string;
      Handler: TNotifyEvent; AShortcut: TShortCut = 0): TMenuItem;
    function CurrentDoc: TDocument;
    function FindDoc(const FileName: string): TDocument;
    function SaveDoc(Doc: TDocument): Boolean;
    function SaveAllDocs: Boolean;
    function MayClose(Doc: TDocument): Boolean;
    procedure UpdateTab(Doc: TDocument);
    procedure UpdateStatus;
    procedure EditorChanged(Sender: TObject);
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
    procedure RunExecutable(const FileName: string);
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
    while (StartPos > 1) and
      (FCurrentLine[StartPos - 1] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do
      Dec(StartPos);
    while (EndPos <= Length(FCurrentLine)) and
      (FCurrentLine[EndPos] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do Inc(EndPos);
    WholeLiteral := Copy(FCurrentLine, StartPos, EndPos - StartPos);
    if (WholeLiteral <> '') and (WholeLiteral[1] in ['0'..'9']) and
      (GetTokenID in [tkNumber, tkIdentifier]) then
    begin
      { Float/exponent tokens retain the native C++ highlighter behavior. }
      if Pos('.', TokenValue) = 0 then
        if ValidIntegerLiteral(WholeLiteral) then Result := NumberAttri
        else Result := IdentifierAttri;
    end;
  end;
  { Lazarus may emit a quote delimiter as a symbol rather than include it
    in the string token.  Keep the original Classic Plus string/char colors. }
  if Copy(TokenValue, 1, 1) = '"' then
    Result := StringAttri;
  if Copy(TokenValue, 1, 1) = '''' then
    Result := IdentifierAttri;
end;

procedure TNoiSynEdit.KeyDown(var Key: Word; Shift: TShiftState);
var
  HomePoint: TPoint;
  HomeLine: string;
  PreviousColumn: Integer;
begin
  if Key <> VK_HOME then FHomeRepeat := False;
  if (Key = VK_HOME) and ((Shift * [ssCtrl, ssShift, ssAlt]) = []) then
  begin
    HomePoint := LogicalCaretXY;
    if (HomePoint.Y >= 1) and (HomePoint.Y <= Lines.Count) then
    begin
      HomeLine := Lines[HomePoint.Y - 1];
      PreviousColumn := HomePoint.X;
      HomePoint.X := 1;
      while (HomePoint.X <= Length(HomeLine)) and
        (HomeLine[HomePoint.X] in [' ', #9]) do Inc(HomePoint.X);
      if FHomeRepeat and not SelAvail and
        (PreviousColumn = HomePoint.X) then HomePoint.X := 1;
      BlockBegin := HomePoint;
      BlockEnd := HomePoint;
      LogicalCaretXY := HomePoint;
      FHomeRepeat := True;
    end;
    Key := 0;
    Exit;
  end;
  inherited KeyDown(Key, Shift);
end;

procedure TNoiSynEdit.ResetHomeCycle;
begin
  FHomeRepeat := False;
end;

procedure TNoiSynEdit.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  FHomeRepeat := False;
  inherited MouseDown(Button, Shift, X, Y);
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
    ExecuteMenu, ToolsMenu, HelpMenu, LanguageMenu: TMenuItem;
  MainPanel, CenterPanel, BottomPanel: TPanel;
  Toolbar: TToolBar;
  ToolImages: TImageList;
  LeftTabs: TPageControl;
  LeftProjectTab, LeftClassTab, LeftDebugTab: TTabSheet;
  Split: TSplitter;
  Button: TToolButton;
  Bitmap: TBitmap;
  Col: TListColumn;
  ArgIndex: Integer;

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
  Caption := Tr('Dev-C++');
  Width := 1100;
  Height := 730;
  Position := poScreenCenter;
  if FileExists(ExtractFilePath(ParamStr(0)) + 'devcpp.ico') then
    try
      Icon.LoadFromFile(ExtractFilePath(ParamStr(0)) + 'devcpp.ico');
    except
      { The editor remains usable if the window manager cannot load ICO files. }
    end;
  FDocs := TObjectList.Create(True);
  FEditorFontSize := 10;
  FEditorTabWidth := 4;
  FProjectFiles := TStringList.Create;
  FProjectFiles.CaseSensitive := True;
  LoadCompilerSettings;
  InitUiLanguage(FOptionsPath);
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

  ViewMenu := TMenuItem.Create(Self); ViewMenu.Caption := Tr('&View'); Bar.Items.Add(ViewMenu);
  AddMenu(ViewMenu, '&Project Manager', @ProjectManagerClick);
  AddMenu(ViewMenu, '&Next Tab', @NextTabClick, ShortCut(VK_TAB, [ssCtrl]));
  AddMenu(ViewMenu, '&Previous Tab', @PreviousTabClick,
    ShortCut(VK_TAB, [ssCtrl, ssShift]));
  AddMenu(ViewMenu, 'Swap &Header/Source', @SwapHeaderSourceClick,
    ShortCut(Ord('Q'), [ssCtrl]));
  ProjectMenu := TMenuItem.Create(Self); ProjectMenu.Caption := Tr('&Project'); Bar.Items.Add(ProjectMenu);
  AddMenu(ProjectMenu, '&New project...', @NewProjectClick);
  AddMenu(ProjectMenu, '&Open project...', @OpenClick);
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

  ToolsMenu := TMenuItem.Create(Self); ToolsMenu.Caption := Tr('&Tools'); Bar.Items.Add(ToolsMenu);
  AddMenu(ToolsMenu, '&Compiler Options / Parameters...', @CompilerOptionsClick);
  AddMenu(ToolsMenu, 'E&ditor Options...', @EditorOptionsClick);
  LanguageMenu := AddMenu(ToolsMenu, '&Language', nil);
  FChineseLanguageItem := AddMenu(LanguageMenu, 'Chinese', @ChineseLanguageClick);
  FEnglishLanguageItem := AddMenu(LanguageMenu, 'English', @EnglishLanguageClick);
  FChineseLanguageItem.Checked := CurrentUiLanguage = ulChinese;
  FEnglishLanguageItem.Checked := CurrentUiLanguage = ulEnglish;
  HelpMenu := TMenuItem.Create(Self); HelpMenu.Caption := Tr('&Help'); Bar.Items.Add(HelpMenu);
  AddMenu(HelpMenu, '&About Dev-C++', @AboutClick);

  ToolImages := TImageList.Create(Self);
  ToolImages.Width := 16;
  ToolImages.Height := 16;
  Toolbar := TToolBar.Create(Self);
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

  FStatus := TStatusBar.Create(Self);
  FStatus.Parent := Self;
  FStatus.Align := alBottom;
  FStatus.SimplePanel := True;
  FStatus.Height := 32;

  MainPanel := TPanel.Create(Self);
  MainPanel.Parent := Self;
  MainPanel.Align := alClient;
  MainPanel.BevelOuter := bvNone;

  LeftTabs := TPageControl.Create(Self);
  LeftTabs.Parent := MainPanel;
  LeftTabs.Align := alLeft;
  LeftTabs.Width := 193;
  LeftProjectTab := TTabSheet.Create(LeftTabs);
  LeftProjectTab.PageControl := LeftTabs;
  LeftProjectTab.Caption := Tr('Project');
  LeftClassTab := TTabSheet.Create(LeftTabs);
  LeftClassTab.PageControl := LeftTabs;
  LeftClassTab.Caption := Tr('Classes');
  LeftDebugTab := TTabSheet.Create(LeftTabs);
  LeftDebugTab.PageControl := LeftTabs;
  LeftDebugTab.Caption := Tr('Debug');
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
  BottomPanel.Height := 183;
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
  FOutput.Font.Name := 'Courier New';
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
  FCompletionList.Font.Name := 'Courier New';
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
begin
  if FInstanceTimer <> nil then FInstanceTimer.Enabled := False;
  FTipSignatures.Free;
  FCompletionKinds.Free;
  FProjectFiles.Free;
  FDocs.Free;
  inherited Destroy;
end;

procedure TMainForm.InstanceTick(Sender: TObject);
var
  RequestedFiles: TStringList;
  RequestOrdinal: Integer;
  ActivateWindow: Boolean;
begin
  if FLoading or FCompileActive or not Enabled or not Visible then Exit;
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
  UpdateStatus;
end;

procedure TMainForm.EnglishLanguageClick(Sender: TObject);
begin
  SetUiLanguage(ulEnglish);
  ApplyUiLanguage(Self);
  FChineseLanguageItem.Checked := False;
  FEnglishLanguageItem.Checked := True;
  FCompletionList.Invalidate;
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
       (TDocument(FDocs[I]).FileName = FileName) then
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
  if FLoading then Exit;
  FTipDoc := nil;
  FCompletionDismissed := False;
  for I := 0 to FDocs.Count - 1 do
    if TDocument(FDocs[I]).Editor = Sender then
    begin
      TDocument(FDocs[I]).PreferredColumn := 0;
      TDocument(FDocs[I]).Dirty := True;
      TDocument(FDocs[I]).ErrorLine := -1;
      TDocument(FDocs[I]).Editor.Invalidate;
      UpdateTab(TDocument(FDocs[I]));
      Break;
    end;
  UpdateStatus;
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
    if PaintedDoc.ErrorLine = Line then
    begin
      Special := True;
      FG := clWhite;
      BG := clMaroon;
    end;
    Exit;
  end;
end;

procedure TMainForm.FileWatchTick(Sender: TObject);
var
  I, Answer: Integer;
  Doc: TDocument;
  Tab: TTabSheet;
begin
  if FLoading or FCompileActive then Exit;
  FFileWatchTimer.Enabled := False;
  try
    for I := FDocs.Count - 1 downto 0 do
    begin
      Doc := TDocument(FDocs[I]);
      if Doc.FileName = '' then Continue;
      if FileExists(Doc.FileName) then
      begin
        Doc.MissingNotified := False;
        Continue;
      end;
      if Doc.MissingNotified then Continue;
      Doc.MissingNotified := True;
      Answer := UiMessageDlg(Format(Tr('%s was deleted outside Dev-C++.' + LineEnding +
        'Keep the file in the editor?'), [ExtractFileName(Doc.FileName)]), mtConfirmation, [mbYes, mbNo], 0);
      if Answer = mrYes then
      begin
        Doc.Dirty := True;
        UpdateTab(Doc);
      end
      else
      begin
        HideCompletion;
        HideFunctionTip;
        if FCompletionDoc = Doc then FCompletionDoc := nil;
        if FTipDoc = Doc then FTipDoc := nil;
        Tab := Doc.Tab;
        FDocs.Remove(Doc);
        Tab.Free;
        UpdateStatus;
      end;
    end;
  finally
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
begin
  Modifiers := Shift * [ssCtrl, ssShift, ssAlt];
  if Modifiers = [ssCtrl] then
  begin
    case Key of
      Ord('N'): NewClick(Self);
      Ord('O'): OpenClick(Self);
      Ord('S'): SaveClick(Self);
      Ord('W'): CloseClick(Self);
      Ord('F'): FindClick(Self);
      Ord('G'): GotoClick(Self);
      Ord('H'): ProjectOptionsClick(Self);
      Ord('R'): ReplaceClick(Self);
      Ord('Q'): SwapHeaderSourceClick(Self);
      Ord('Y'): RedoClick(Self);
      Ord('Z'): UndoClick(Self);
      Ord('X'): CutClick(Self);
      Ord('C'): CopyClick(Self);
      Ord('V'): PasteClick(Self);
      Ord('A'): SelectAllClick(Self);
      Ord('B'): OpenFolderClick(Self);
      Ord('D'): DeleteLineClick(Self);
      Ord('E'): DuplicateLineClick(Self);
      VK_F9: SyntaxClick(Self);
      VK_SPACE: CompletionClick(Self);
      47, 191: ToggleCommentClick(Self);
      59, 186: InlineCommentClick(Self);
      44, 188: UncommentClick(Self);
      46, 190: CommentClick(Self);
      VK_TAB: NextTabClick(Self);
    else Exit;
    end;
    Key := 0;
  end
  else if Modifiers = [ssCtrl, ssShift] then
  begin
    if Key = Ord('S') then
    begin
      SaveAsClick(Self);
      Key := 0;
    end;
    if Key = Ord('W') then
    begin
      CloseAllClick(Self);
      Key := 0;
    end;
    if Key = Ord('A') then
    begin
      SaveAllClick(Self);
      Key := 0;
    end;
    if Key = Ord('X') then
    begin
      SyntaxClick(Self);
      Key := 0;
    end;
    if Key = Ord('R') then
    begin
      ReplaceAllClick(Self);
      Key := 0;
    end;
    if Key = Ord('F') then
    begin
      FindAllClick(Self);
      Key := 0;
    end;
    if Key = VK_TAB then
    begin
      PreviousTabClick(Self);
      Key := 0;
    end;
  end
  else if Modifiers = [] then
  begin
    case Key of
      VK_F3: FindNextClick(Self);
      VK_F9: CompileClick(Self);
      VK_F10: RunClick(Self);
      VK_F11: CompileRunClick(Self);
      VK_F12: CompileClick(Self);
    else Exit;
    end;
    Key := 0;
  end
  else if (Modifiers = [ssShift]) and (Key = VK_F3) then
  begin
    FindPreviousClick(Self);
    Key := 0;
  end
  else if (Modifiers = [ssCtrl, ssAlt]) and (Key = Ord('O')) then
  begin
    CompilerOptionsClick(Self);
    Key := 0;
  end;
end;

procedure TMainForm.OpenDroppedFile(const DroppedPath: string);
begin
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
  P: TPoint;
  S: string;
  FirstColumn: Integer;
begin
  Doc := CurrentDoc;
  if (Doc = nil) or (Doc.Editor <> Sender) then Exit;
  if Key <> VK_HOME then FHomeAtIndent := False;
  if (Key = VK_HOME) and
    ((Shift * [ssCtrl, ssShift, ssAlt]) = []) then
  begin
    P := Doc.Editor.LogicalCaretXY;
    S := Doc.Editor.Lines[P.Y - 1];
    FirstColumn := 1;
    while (FirstColumn <= Length(S)) and
      (S[FirstColumn] in [' ', #9]) do Inc(FirstColumn);
    Doc.Editor.LogicalCaretXY := Point(FirstColumn, P.Y);
    Doc.Editor.BlockBegin := Doc.Editor.LogicalCaretXY;
    Doc.Editor.BlockEnd := Doc.Editor.LogicalCaretXY;
    Doc.PreferredColumn := 0;
    FHomeAtIndent := True;
    Key := 0;
    Exit;
  end;
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
  StartColumn, EndColumn, TargetRow, FirstTextColumn: Integer;
begin
  Doc := CurrentDoc;
  if (Doc = nil) or (Doc.Editor <> Sender) then Exit;
  if not (Command in [ecUp, ecDown, ecSelUp, ecSelDown]) then
    Doc.PreferredColumn := 0;
  if Doc.Editor.SelAvail and
    not (Command in [ecLineStart, ecUp, ecDown, ecSelUp, ecSelDown]) then Exit;
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
  if Command = ecLineStart then
  begin
    FirstTextColumn := 1;
    while (FirstTextColumn <= Length(LineText)) and
      (LineText[FirstTextColumn] in [' ', #9]) do Inc(FirstTextColumn);
    Command := ecNone;
    Doc.Editor.LogicalCaretXY := Point(FirstTextColumn, P.Y);
    Doc.Editor.BlockBegin := Doc.Editor.LogicalCaretXY;
    Doc.Editor.BlockEnd := Doc.Editor.LogicalCaretXY;
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
begin
  Doc := CurrentDoc;
  if (Doc = nil) or (Doc.Editor <> Sender) then Exit;
  if (Key = #27) and FCompletionForm.Visible and
    (FCompletionDoc = Doc) then
  begin
    FCompletionDismissed := True;
    HideCompletion;
    Key := #0;
    Exit;
  end;
  Closing := #0;
  PosBefore := Doc.Editor.LogicalCaretXY;
  if (PosBefore.Y >= 1) and (PosBefore.Y <= Doc.Editor.Lines.Count) then
    LineText := Doc.Editor.Lines[PosBefore.Y - 1]
  else LineText := '';
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
  if Doc = nil then Exit;
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
  FTipPaint.Canvas.Font.Name := 'Courier New';
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
  FTipPaint.Canvas.Font.Name := 'Courier New';
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
  Doc.Editor.Font.Name := 'Consolas';
  Doc.Editor.Font.Size := FEditorFontSize;
  Doc.Editor.Options := (Doc.Editor.Options + [eoTabIndent]) -
    [eoAutoIndent, eoSmartTabs, eoTabsToSpaces, eoTrimTrailingSpaces,
     eoShowSpecialChars, eoScrollPastEol, eoKeepCaretX];
  Doc.Editor.Options2 := Doc.Editor.Options2 + [eoCaretSkipTab];
  Doc.Editor.TabWidth := FEditorTabWidth;
  Doc.Editor.WantTabs := True;
  Doc.Editor.BlockIndent := 0;
  Doc.Editor.BlockTabIndent := 1;
  Doc.Editor.RightEdge := 0;
  Doc.Editor.Color := clWhite;
  Doc.Editor.Font.Color := clBlack;
  Doc.Editor.LineHighlightColor.Background := $FFFFCC;
  Doc.Editor.BracketMatchColor.Background := clRed;
  Doc.Editor.BracketMatchColor.Foreground := clWhite;
  Doc.Editor.SelectedColor.Background := clNavy;
  Doc.Editor.SelectedColor.Foreground := clWhite;
  Doc.Editor.Gutter.Visible := True;
  { Win32 clBtnFace, independent of the GTK theme on NOI Linux. }
  Doc.Editor.Gutter.Color := $00F0F0F0;
  if Doc.Editor.Gutter.Parts.ByClass[TSynGutterLineNumber, 0] = nil then
    TSynGutterLineNumber.Create(Doc.Editor.Gutter.Parts);
  if Doc.Editor.Gutter.Parts.ByClass[TSynGutterLineNumber, 0] <> nil then
    Doc.Editor.Gutter.Parts.ByClass[TSynGutterLineNumber, 0].MarkupInfo.Foreground := clBlack;
  if Doc.Editor.Gutter.Parts.ByClass[TSynGutterChanges, 0] <> nil then
    Doc.Editor.Gutter.Parts.ByClass[TSynGutterChanges, 0].Visible := False;
  Doc.Syntax := TNoiCppSyn.Create(Doc.Tab);
  Doc.Syntax.AsmAttri.Foreground := clBlue;
  { Classic Plus uses Win32 clHighlight for comments.  GTK's clHighlight
    follows the orange Ubuntu theme, so use the Windows blue explicitly. }
  Doc.Syntax.CommentAttri.Foreground := $00D77800;
  Doc.Syntax.CommentAttri.Style := [fsItalic];
  Doc.Syntax.DirecAttri.Foreground := clGreen;
  Doc.Syntax.IdentifierAttri.Foreground := clBlack;
  Doc.Syntax.InvalidAttri.Foreground := clBlack;
  Doc.Syntax.KeyAttri.Foreground := clBlack;
  Doc.Syntax.KeyAttri.Style := [fsBold];
  Doc.Syntax.NumberAttri.Foreground := clPurple;
  Doc.Syntax.SpaceAttri.Foreground := clBlack;
  Doc.Syntax.SpaceAttri.Background := clWhite;
  Doc.Syntax.StringAttri.Foreground := clBlue;
  Doc.Syntax.StringAttri.Style := [fsBold];
  Doc.Syntax.SymbolAttri.Foreground := clRed;
  Doc.Syntax.SymbolAttri.Style := [fsBold];
  Doc.Editor.Highlighter := Doc.Syntax;
  Doc.Editor.OnChange := @EditorChanged;
  Doc.Editor.OnClick := @EditorClicked;
  Doc.Editor.OnKeyDown := @EditorKeyDown;
  Doc.Editor.OnKeyPress := @EditorKeyPress;
  Doc.Editor.OnProcessCommand := @EditorProcessCommand;
  Doc.Editor.OnSpecialLineColors := @EditorSpecialLineColors;
  Doc.Editor.OnKeyUp := @EditorKeyUp;
  Doc.Editor.OnMouseWheel := @EditorMouseWheel;
  Doc.Editor.OnMouseUp := @EditorMouseUp;
  Doc.Editor.OnDropFiles := @EditorFilesDropped;
  FDocs.Add(Doc);
  UpdateTab(Doc);
  FPages.ActivePage := Doc.Tab;
  if Visible then Doc.Editor.SetFocus;
end;

procedure TMainForm.NewClick(Sender: TObject);
begin
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
    Exit;
  end;
  CreateDocument(False);
  Doc := CurrentDoc;
  FLoading := True;
  try
    try
      Doc.Editor.Lines.LoadFromFile(FileName);
      Doc.FileName := ExpandFileName(FileName);
      Doc.Dirty := False;
      Doc.Editor.Modified := False;
      UpdateTab(Doc);
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
var Ini: TIniFile; Count, I: Integer; ProjectUnitPath, FullName: string; Root: TTreeNode;
begin
  if not FileExists(FileName) then
  begin
    UiMessageDlg(Format(Tr('Project not found: %s'), [FileName]), mtError, [mbOK], 0);
    Exit;
  end;
  FProjectPath := ExpandFileName(FileName);
  FProjectFiles.Clear;
  FProjectTree.Items.Clear;
  Ini := TIniFile.Create(FProjectPath);
  try
    Count := Ini.ReadInteger('Project', 'UnitCount', 0);
    Root := FProjectTree.Items.Add(nil, ExtractFileName(FProjectPath));
    for I := 1 to Count do
    begin
      ProjectUnitPath := Ini.ReadString('Unit' + IntToStr(I), 'FileName', '');
      if ProjectUnitPath = '' then Continue;
      ProjectUnitPath := StringReplace(ProjectUnitPath, '\', DirectorySeparator, [rfReplaceAll]);
      FullName := ExpandFileName(ExtractFilePath(FProjectPath) + ProjectUnitPath);
      FProjectFiles.Add(FullName);
      FProjectTree.Items.AddChild(Root, ExtractFileName(FullName));
    end;
    Root.Expand(False);
  finally
    Ini.Free;
  end;
  Caption := ExtractFileName(FProjectPath) + ' - Dev-C++';
  if FProjectFiles.Count > 0 then OpenFile(FProjectFiles[0]);
end;

procedure TMainForm.NewProjectClick(Sender: TObject);
var
  Dialog: TSaveDialog;
  Ini: TIniFile;
  ProjectFilePath: string;
begin
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
  Ini := TIniFile.Create(ProjectFilePath);
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
  finally
    Ini.Free;
  end;
  OpenProject(ProjectFilePath);
end;

procedure TMainForm.AddProjectFileClick(Sender: TObject);
var
  Dialog: TOpenDialog;
  Ini: TIniFile;
  I, UnitCount: Integer;
  SourcePath, UnitSection: string;
  Added: Boolean;
begin
  if FProjectPath = '' then
  begin
    UiMessageDlg(Tr('Open or create a project first.'), mtInformation, [mbOK], 0);
    Exit;
  end;
  Dialog := TOpenDialog.Create(Self);
  try
    Dialog.Title := Tr('Open');
    Dialog.Filter := Tr('C/C++ files|*.c;*.cc;*.cpp;*.cxx;*.h;*.hpp|All files|*');
    Dialog.Options := Dialog.Options + [ofAllowMultiSelect];
    if not Dialog.Execute then Exit;
    Ini := TIniFile.Create(FProjectPath);
    try
      UnitCount := Ini.ReadInteger('Project', 'UnitCount', 0);
      Added := False;
      for I := 0 to Dialog.Files.Count - 1 do
      begin
        SourcePath := ExpandFileName(Dialog.Files[I]);
        if FProjectFiles.IndexOf(SourcePath) >= 0 then Continue;
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
      if Added then Ini.WriteInteger('Project', 'UnitCount', UnitCount);
    finally
      Ini.Free;
    end;
  finally
    Dialog.Free;
  end;
  if Added then OpenProject(FProjectPath);
end;

procedure TMainForm.RemoveProjectFileClick(Sender: TObject);
var
  Ini: TIniFile;
  UnitValues: TStringList;
  Node: TTreeNode;
  UnitCount, UnitIndex, I, J, K: Integer;
  SourcePath, UnitSection: string;
begin
  if FProjectPath = '' then Exit;
  Node := FProjectTree.Selected;
  if (Node = nil) or (Node.Parent = nil) or
    (Node.Index < 0) or (Node.Index >= FProjectFiles.Count) then Exit;
  SourcePath := FProjectFiles[Node.Index];
  if UiMessageDlg(Format(Tr('Remove %s from project?'), [ExtractFileName(SourcePath)]),
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  Ini := TIniFile.Create(FProjectPath);
  UnitValues := TStringList.Create;
  try
    UnitCount := Ini.ReadInteger('Project', 'UnitCount', 0);
    UnitIndex := 0;
    for I := 1 to UnitCount do
    begin
      UnitSection := 'Unit' + IntToStr(I);
      if ExpandFileName(ExtractFilePath(FProjectPath) +
        StringReplace(Ini.ReadString(UnitSection, 'FileName', ''), '\',
          DirectorySeparator, [rfReplaceAll])) = SourcePath then
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
  finally
    UnitValues.Free;
    Ini.Free;
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
  Ini: TIniFile;
  CFlags, CppFlags, LinkFlags: string;
begin
  if FProjectPath = '' then
  begin
    UiMessageDlg(Tr('Open or create a project first.'), mtInformation, [mbOK], 0);
    Exit;
  end;
  Ini := TIniFile.Create(FProjectPath);
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
  finally
    Ini.Free;
  end;
end;

procedure TMainForm.ProjectDoubleClick(Sender: TObject);
var Node: TTreeNode; I: Integer;
begin
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
  FCCompiler := 'gcc';
  FCppCompiler := 'g++';
  FCFlags := '-g -O2 -Wall -Wextra';
  FCppFlags := '-g -O2 -std=c++14 -Wall -Wextra';
  FLinkerFlags := '';
  ForceDirectories(ExtractFileDir(FOptionsPath));
  Ini := TIniFile.Create(FOptionsPath);
  try
    FCCompiler := Ini.ReadString('Compiler', 'C', FCCompiler);
    FCppCompiler := Ini.ReadString('Compiler', 'Cpp', FCppCompiler);
    FCFlags := Ini.ReadString('Compiler', 'CFlags', FCFlags);
    FCppFlags := Ini.ReadString('Compiler', 'CppFlags', FCppFlags);
    if FCppFlags = '-g -Wall -Wextra' then
      FCppFlags := '-g -O2 -std=c++14 -Wall -Wextra';
    if FCFlags = '-g -Wall -Wextra' then
      FCFlags := '-g -O2 -Wall -Wextra';
    FLinkerFlags := Ini.ReadString('Compiler', 'LinkerFlags', FLinkerFlags);
    FEditorFontSize := Max(1, Min(72,
      Ini.ReadInteger('Editor', 'FontSize', FEditorFontSize)));
    FEditorTabWidth := Max(1, Min(16,
      Ini.ReadInteger('Editor', 'TabWidth', FEditorTabWidth)));
  finally Ini.Free; end;
end;

procedure TMainForm.AddCompilerFlags(Args: TStrings; const FlagText: string);
var Parts: TStringList; I: Integer;
begin
  Parts := TStringList.Create;
  try
    Parts.Delimiter := ' ';
    Parts.QuoteChar := '"';
    Parts.StrictDelimiter := False;
    Parts.DelimitedText := Trim(FlagText);
    for I := 0 to Parts.Count - 1 do
      if Parts[I] <> '' then Args.Add(Parts[I]);
  finally Parts.Free; end;
end;

procedure TMainForm.CompilerOptionsClick(Sender: TObject);
var
  Dialog: TForm;
  CEdit, CppEdit, CFlagsEdit, CppFlagsEdit, LinkEdit: TEdit;
  OkButton, CancelButton: TButton;
  Ini: TIniFile;
  NextFieldTop, PreferredWidth, PreferredHeight, ButtonTop, ButtonHeight: Integer;

  function AddField(const LabelText, FieldValue: string; Y: Integer): TEdit;
  var LabelControl: TLabel; FieldWidth, FieldHeight: Integer;
  begin
    LabelControl := TLabel.Create(Dialog);
    LabelControl.Parent := Dialog;
    LabelControl.AutoSize := False;
    LabelControl.WordWrap := True;
    LabelControl.Caption := Tr(LabelText);
    LabelControl.SetBounds(12, NextFieldTop, Dialog.ClientWidth - 24, 28);
    FieldWidth := 0;
    FieldHeight := 0;
    LabelControl.GetPreferredSize(FieldWidth, FieldHeight);
    LabelControl.Height := Max(28, FieldHeight) + 8;
    Result := TEdit.Create(Dialog);
    Result.Parent := Dialog;
    Result.Text := FieldValue;
    FieldWidth := 0;
    FieldHeight := 0;
    Result.GetPreferredSize(FieldWidth, FieldHeight);
    Result.SetBounds(12, NextFieldTop + LabelControl.Height + 4,
      Dialog.ClientWidth - 24, Max(32, FieldHeight + 8));
    NextFieldTop := Result.Top + Result.Height + 12;
  end;

begin
  Dialog := TForm.CreateNew(Self, 0);
  try
    Dialog.Caption := Tr('Compiler Options');
    Dialog.BorderStyle := bsDialog;
    Dialog.Position := poMainFormCenter;
    Dialog.ClientWidth := 712;
    Dialog.ClientHeight := 266;
    NextFieldTop := 14;
    CEdit := AddField('C compiler:', FCCompiler, 14);
    CppEdit := AddField('C++ compiler:', FCppCompiler, 54);
    CFlagsEdit := AddField('C compile flags:', FCFlags, 94);
    CppFlagsEdit := AddField('C++ flags (e.g. -std=c++14):', FCppFlags, 134);
    LinkEdit := AddField('Linux linker flags:', FLinkerFlags, 174);
    ButtonTop := NextFieldTop + 8;
    OkButton := TButton.Create(Dialog);
    OkButton.Parent := Dialog;
    OkButton.Caption := Tr('OK');
    OkButton.ModalResult := mrOK;
    OkButton.Default := True;
    PreferredWidth := 0;
    PreferredHeight := 0;
    OkButton.GetPreferredSize(PreferredWidth, PreferredHeight);
    ButtonHeight := Max(36, PreferredHeight + 12);
    OkButton.SetBounds(528, ButtonTop, Max(90, PreferredWidth + 24), ButtonHeight);
    CancelButton := TButton.Create(Dialog);
    CancelButton.Parent := Dialog;
    CancelButton.Caption := Tr('Cancel');
    CancelButton.ModalResult := mrCancel;
    CancelButton.Cancel := True;
    PreferredWidth := 0;
    PreferredHeight := 0;
    CancelButton.GetPreferredSize(PreferredWidth, PreferredHeight);
    ButtonHeight := Max(ButtonHeight, PreferredHeight + 12);
    OkButton.Height := ButtonHeight;
    CancelButton.SetBounds(618, ButtonTop, Max(90, PreferredWidth + 24), ButtonHeight);
    CancelButton.Left := Dialog.ClientWidth - CancelButton.Width - 12;
    OkButton.Left := CancelButton.Left - OkButton.Width - 10;
    Dialog.ClientHeight := ButtonTop + ButtonHeight + 12;
    if Dialog.ShowModal <> mrOK then Exit;
    if (Trim(CEdit.Text) = '') or (Trim(CppEdit.Text) = '') then
    begin UiMessageDlg(Tr('Compiler command cannot be empty.'), mtError, [mbOK], 0); Exit; end;
    FCCompiler := Trim(CEdit.Text);
    FCppCompiler := Trim(CppEdit.Text);
    FCFlags := Trim(CFlagsEdit.Text);
    FCppFlags := Trim(CppFlagsEdit.Text);
    FLinkerFlags := Trim(LinkEdit.Text);
    ForceDirectories(ExtractFileDir(FOptionsPath));
    Ini := TIniFile.Create(FOptionsPath);
    try
      Ini.WriteString('Compiler', 'C', FCCompiler);
      Ini.WriteString('Compiler', 'Cpp', FCppCompiler);
      Ini.WriteString('Compiler', 'CFlags', FCFlags);
      Ini.WriteString('Compiler', 'CppFlags', FCppFlags);
      Ini.WriteString('Compiler', 'LinkerFlags', FLinkerFlags);
    finally Ini.Free; end;
  finally Dialog.Free; end;
end;

procedure TMainForm.EditorOptionsClick(Sender: TObject);
var
  SizeInput, WidthInput: string;
  NewFontSize, NewTabWidth, I: Integer;
  Ini: TIniFile;
begin
  SizeInput := IntToStr(FEditorFontSize);
  WidthInput := IntToStr(FEditorTabWidth);
  if not UiInputQuery(Tr('Editor Options'), Tr('Font size (1-72):'), SizeInput) then Exit;
  if not UiInputQuery(Tr('Editor Options'), Tr('Tab width (1-16):'), WidthInput) then Exit;
  if not TryStrToInt(SizeInput, NewFontSize) or
    not TryStrToInt(WidthInput, NewTabWidth) or
    (NewFontSize < 1) or (NewFontSize > 72) or
    (NewTabWidth < 1) or (NewTabWidth > 16) then
  begin
    UiMessageDlg(Tr('Enter a valid font size and tab width.'), mtError, [mbOK], 0);
    Exit;
  end;
  FEditorFontSize := NewFontSize;
  FEditorTabWidth := NewTabWidth;
  for I := 0 to FDocs.Count - 1 do
  begin
    TDocument(FDocs[I]).Editor.Font.Size := FEditorFontSize;
    TDocument(FDocs[I]).Editor.TabWidth := FEditorTabWidth;
    TDocument(FDocs[I]).PreferredColumn := 0;
  end;
  Ini := TIniFile.Create(FOptionsPath);
  try
    Ini.WriteInteger('Editor', 'FontSize', FEditorFontSize);
    Ini.WriteInteger('Editor', 'TabWidth', FEditorTabWidth);
  finally
    Ini.Free;
  end;
end;

procedure TMainForm.PopulateDiagnostics(const CompilerOutput: string);
var
  Rows: TStringList;
  Entry: TListItem;
  I, P1, P2, P3, SourceRow, SourceCol: Integer;
  SourceLine, SourcePath, Detail: string;
begin
  Rows := TStringList.Create;
  try
    Rows.Text := CompilerOutput;
    FCompilerList.Items.BeginUpdate;
    try
      FCompilerList.Items.Clear;
      for I := 0 to Rows.Count - 1 do
      begin
        SourceLine := Rows[I];
        P1 := Pos(':', SourceLine);
        if P1 = 0 then Continue;
        P2 := PosEx(':', SourceLine, P1 + 1);
        if (P2 = 0) or not TryStrToInt(Copy(SourceLine, P1 + 1, P2 - P1 - 1), SourceRow) then Continue;
        P3 := PosEx(':', SourceLine, P2 + 1);
        SourceCol := 1;
        if (P3 > 0) and TryStrToInt(Copy(SourceLine, P2 + 1, P3 - P2 - 1), SourceCol) then
          Detail := Trim(Copy(SourceLine, P3 + 1, MaxInt))
        else
          Detail := Trim(Copy(SourceLine, P2 + 1, MaxInt));
        SourcePath := Copy(SourceLine, 1, P1 - 1);
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
var Entry: TListItem; SourceRow, SourceCol: Integer; Doc: TDocument;
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
    FPages.ActivePage := Doc.Tab;
    Doc.Editor.LogicalCaretXY := Point(SourceCol, SourceRow);
    Doc.Editor.BlockBegin := Point(SourceCol, SourceRow);
    Doc.Editor.BlockEnd := Point(SourceCol + Length(FFindText), SourceRow);
    Doc.Editor.SetFocus;
    Exit;
  end;
  if not FileExists(Entry.SubItems[1]) then Exit;
  OpenFile(Entry.SubItems[1]);
  Doc := CurrentDoc;
  if Doc <> nil then
  begin
    if SourceRow < 1 then SourceRow := 1;
    if SourceRow > Doc.Editor.Lines.Count then SourceRow := Doc.Editor.Lines.Count;
    if SourceRow < 1 then Exit;
    SourceText := Doc.Editor.Lines[SourceRow - 1];
    if SourceCol < 1 then SourceCol := 1;
    if SourceCol > Length(SourceText) + 1 then SourceCol := Length(SourceText) + 1;
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
var Dialog: TSaveDialog; SelectedPath: string;
begin
  Result := False;
  if Doc = nil then Exit;
  if Doc.FileName = '' then
  begin
    Dialog := TSaveDialog.Create(Self);
    try
      Dialog.Title := Tr('Save');
      Dialog.Options := Dialog.Options - [ofOverwritePrompt];
      Dialog.DefaultExt := 'cpp';
      Dialog.Filter := Tr('C/C++ source|*.cpp;*.c;*.h;*.hpp|All files|*');
      Dialog.FileName := Doc.UntitledName;
      if ExtractFileExt(Dialog.FileName) = '' then
        Dialog.FileName := Dialog.FileName + '.cpp';
      if not Dialog.Execute then Exit;
      SelectedPath := ExpandFileName(Dialog.FileName);
      if FileExists(SelectedPath) then
        if UiMessageDlg(Format(Tr('File %s already exists. Overwrite?'),
          [SelectedPath]), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
      Doc.FileName := SelectedPath;
    finally Dialog.Free; end;
  end;
  try
    Doc.Editor.Lines.SaveToFile(Doc.FileName);
    Doc.Dirty := False;
    Doc.MissingNotified := False;
    Doc.Editor.Modified := False;
    UpdateTab(Doc);
    Result := True;
  except
    on E: Exception do UiMessageDlg(E.Message, mtError, [mbOK], 0);
  end;
  UpdateStatus;
end;

function TMainForm.SaveAllDocs: Boolean;
var I: Integer;
begin
  Result := False;
  for I := 0 to FDocs.Count - 1 do
    if TDocument(FDocs[I]).Dirty then
    begin
      FPages.ActivePage := TDocument(FDocs[I]).Tab;
      if not SaveDoc(TDocument(FDocs[I])) then Exit;
    end;
  Result := True;
end;

procedure TMainForm.SaveClick(Sender: TObject);
begin SaveDoc(CurrentDoc); end;

procedure TMainForm.SaveAsClick(Sender: TObject);
var Doc: TDocument; OldName, OldUntitled: string;
begin
  Doc := CurrentDoc;
  if Doc = nil then Exit;
  OldName := Doc.FileName;
  OldUntitled := Doc.UntitledName;
  if OldName <> '' then Doc.UntitledName := ExtractFileName(OldName);
  Doc.FileName := '';
  if not SaveDoc(Doc) then Doc.FileName := OldName;
  Doc.UntitledName := OldUntitled;
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
var
  Doc: TDocument;
  FirstRow, LastRow, I: Integer;
begin
  Doc := CurrentDoc;
  if Doc = nil then Exit;
  FirstRow := Doc.Editor.CaretY;
  LastRow := FirstRow;
  if Doc.Editor.SelAvail then
  begin
    FirstRow := Doc.Editor.BlockBegin.Y;
    LastRow := Doc.Editor.BlockEnd.Y;
  end;
  if (LastRow > FirstRow) and (Doc.Editor.BlockEnd.X = 1) then Dec(LastRow);
  for I := FirstRow - 1 to LastRow - 1 do
    Doc.Editor.Lines[I] := '//' + Doc.Editor.Lines[I];
end;

procedure TMainForm.UncommentClick(Sender: TObject);
var
  Doc: TDocument;
  FirstRow, LastRow, I, P: Integer;
  S: string;
begin
  Doc := CurrentDoc;
  if Doc = nil then Exit;
  FirstRow := Doc.Editor.CaretY;
  LastRow := FirstRow;
  if Doc.Editor.SelAvail then
  begin
    FirstRow := Doc.Editor.BlockBegin.Y;
    LastRow := Doc.Editor.BlockEnd.Y;
  end;
  if (LastRow > FirstRow) and (Doc.Editor.BlockEnd.X = 1) then Dec(LastRow);
  for I := FirstRow - 1 to LastRow - 1 do
  begin
    S := Doc.Editor.Lines[I];
    P := 1;
    while (P <= Length(S)) and (S[P] in [' ', #9]) do Inc(P);
    if Copy(S, P, 2) = '//' then
      Doc.Editor.Lines[I] := Copy(S, 1, P - 1) + Copy(S, P + 2, MaxInt);
  end;
end;

procedure TMainForm.ToggleCommentClick(Sender: TObject);
var
  Doc: TDocument;
  FirstRow, LastRow, I, P: Integer;
  S: string;
  AllCommented: Boolean;
begin
  Doc := CurrentDoc;
  if Doc = nil then Exit;
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
  if (Doc = nil) or not Doc.Editor.SelAvail then Exit;
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
  Doc.Editor.SelText := Replacement;
  EndPoint := Doc.Editor.LogicalCaretXY;
  if Wrapped then
  begin
    Inc(StartPoint.X, 2);
    Dec(EndPoint.X, 2);
  end;
  Doc.Editor.BlockBegin := StartPoint;
  Doc.Editor.BlockEnd := EndPoint;
end;

procedure TMainForm.DeleteLineClick(Sender: TObject);
var
  Doc: TDocument;
  Row: Integer;
begin
  Doc := CurrentDoc;
  if Doc = nil then Exit;
  Row := Doc.Editor.CaretY - 1;
  if (Row < 0) or (Row >= Doc.Editor.Lines.Count) then Exit;
  if Doc.Editor.Lines.Count = 1 then
    Doc.Editor.Lines[0] := ''
  else
    Doc.Editor.Lines.Delete(Row);
end;

procedure TMainForm.DuplicateLineClick(Sender: TObject);
var
  Doc: TDocument;
  Row: Integer;
begin
  Doc := CurrentDoc;
  if Doc = nil then Exit;
  Row := Doc.Editor.CaretY - 1;
  if (Row < 0) or (Row >= Doc.Editor.Lines.Count) then Exit;
  Doc.Editor.Lines.Insert(Row + 1, Doc.Editor.Lines[Row]);
  Doc.Editor.CaretY := Row + 2;
end;

procedure TMainForm.SaveAllClick(Sender: TObject);
begin SaveAllDocs; end;

function TMainForm.MayClose(Doc: TDocument): Boolean;
var Answer: Integer;
begin
  Result := True;
  if not Doc.Dirty and not Doc.Editor.Modified then Exit;
  Answer := UiMessageDlg(Format(Tr('Save changes to %s?'), [Doc.Tab.Caption]),
    mtConfirmation, [mbYes, mbNo, mbCancel], 0);
  if Answer = mrCancel then Exit(False);
  if Answer = mrYes then
  begin
    FPages.ActivePage := Doc.Tab;
    Exit(SaveDoc(Doc));
  end;
end;

procedure TMainForm.CloseClick(Sender: TObject);
var Doc: TDocument; Tab: TTabSheet;
begin
  Doc := CurrentDoc;
  if (Doc = nil) or not MayClose(Doc) then Exit;
  HideCompletion;
  HideFunctionTip;
  if FCompletionDoc = Doc then FCompletionDoc := nil;
  if FTipDoc = Doc then FTipDoc := nil;
  Tab := Doc.Tab;
  FDocs.Remove(Doc);
  Tab.Free;
  UpdateStatus;
end;

procedure TMainForm.CloseQueryHandler(Sender: TObject; var CanClose: Boolean);
var I: Integer;
begin
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
begin if CurrentDoc <> nil then CurrentDoc.Editor.Undo; end;
procedure TMainForm.RedoClick(Sender: TObject);
begin if CurrentDoc <> nil then CurrentDoc.Editor.Redo; end;
procedure TMainForm.CutClick(Sender: TObject);
begin if CurrentDoc <> nil then CurrentDoc.Editor.CutToClipboard; end;
procedure TMainForm.CopyClick(Sender: TObject);
begin if CurrentDoc <> nil then CurrentDoc.Editor.CopyToClipboard; end;
procedure TMainForm.PasteClick(Sender: TObject);
begin if CurrentDoc <> nil then CurrentDoc.Editor.PasteFromClipboard; end;
procedure TMainForm.SelectAllClick(Sender: TObject);
begin if CurrentDoc <> nil then CurrentDoc.Editor.SelectAll; end;

procedure TMainForm.CompletionClick(Sender: TObject);
begin ShowCompletion(CurrentDoc, False); end;

procedure TMainForm.FindClick(Sender: TObject);
var Query: string;
begin
  Query := FFindText;
  if UiInputQuery(Tr('Find'), Tr('Find:'), Query) and (Query <> '') then
  begin FFindText := Query; FindNextClick(Self); end;
end;

procedure TMainForm.FindNextClick(Sender: TObject);
var
  Doc: TDocument;
  SourceLine, SearchText: string;
  Pass, Row, Column, StartRow, StartCol, FoundAt, LastRow: Integer;
begin
  Doc := CurrentDoc;
  if (Doc = nil) or (FFindText = '') then Exit;
  StartRow := Doc.Editor.CaretY;
  StartCol := Doc.Editor.LogicalCaretXY.X;
  SearchText := LowerCase(FFindText);
  for Pass := 0 to 1 do
  begin
    if Pass = 0 then LastRow := Doc.Editor.Lines.Count
    else LastRow := StartRow;
    if Pass = 0 then Row := StartRow else Row := 1;
    while Row <= LastRow do
    begin
      SourceLine := LowerCase(Doc.Editor.Lines[Row - 1]);
      if (Pass = 0) and (Row = StartRow) then
      begin
        FoundAt := Pos(SearchText, Copy(SourceLine, StartCol, MaxInt));
        if FoundAt > 0 then Column := FoundAt + StartCol - 1
        else Column := 0;
      end
      else if (Pass = 1) and (Row = StartRow) then
        Column := Pos(SearchText, Copy(SourceLine, 1, StartCol - 1))
      else
        Column := Pos(SearchText, SourceLine);
      if Column > 0 then
      begin
        Doc.Editor.LogicalCaretXY := Point(Column + Length(FFindText), Row);
        Doc.Editor.BlockBegin := Point(Column, Row);
        Doc.Editor.BlockEnd := Point(Column + Length(FFindText), Row);
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
  Query, SourceLine, SearchLine: string;
  Doc: TDocument;
  Entry: TListItem;
  DocIndex, Row, FoundAt, Offset: Integer;
begin
  Query := FFindText;
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
        SearchLine := LowerCase(SourceLine);
        Offset := 1;
        while Offset <= Length(SearchLine) do
        begin
          FoundAt := Pos(LowerCase(Query), Copy(SearchLine, Offset, MaxInt));
          if FoundAt = 0 then Break;
          Inc(FoundAt, Offset - 1);
          Entry := FCompilerList.Items.Add;
          Entry.Caption := IntToStr(Row + 1);
          Entry.SubItems.Add(IntToStr(FoundAt));
          if Doc.FileName <> '' then Entry.SubItems.Add(Doc.FileName)
          else Entry.SubItems.Add(Doc.UntitledName);
          Entry.SubItems.Add(Trim(SourceLine));
          Entry.Data := Pointer(Doc);
          Offset := FoundAt + Length(Query);
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
  SourceLine, SearchText: string;
  Pass, Row, Column, StartRow, StartCol, MaxColumn: Integer;
begin
  Doc := CurrentDoc;
  if (Doc = nil) or (FFindText = '') then Exit;
  StartRow := Doc.Editor.CaretY;
  StartCol := Doc.Editor.LogicalCaretXY.X;
  if Doc.Editor.SelAvail and (Doc.Editor.BlockBegin.Y = StartRow) then
    StartCol := Doc.Editor.BlockBegin.X;
  SearchText := LowerCase(FFindText);
  for Pass := 0 to 1 do
  begin
    if Pass = 0 then Row := StartRow else Row := Doc.Editor.Lines.Count;
    while (Row >= 1) and ((Pass = 1) or (Row <= StartRow)) do
    begin
      SourceLine := LowerCase(Doc.Editor.Lines[Row - 1]);
      MaxColumn := Length(SourceLine) - Length(SearchText) + 1;
      if (Pass = 0) and (Row = StartRow) then
        MaxColumn := Min(MaxColumn, StartCol - 1);
      for Column := MaxColumn downto 1 do
        if Copy(SourceLine, Column, Length(SearchText)) = SearchText then
        begin
          Doc.Editor.LogicalCaretXY := Point(Column + Length(FFindText), Row);
          Doc.Editor.BlockBegin := Point(Column, Row);
          Doc.Editor.BlockEnd := Point(Column + Length(FFindText), Row);
          Doc.Editor.SetFocus;
          Exit;
        end;
      Dec(Row);
      if (Pass = 1) and (Row < StartRow) then Break;
    end;
  end;
  FStatus.SimpleText := Format(Tr('Text not found: %s'), [FFindText]);
end;

procedure TMainForm.ReplaceClick(Sender: TObject);
var
  Doc: TDocument;
  Query, Replacement, LineValue: string;
  Answer, Row: Integer;
begin
  Doc := CurrentDoc;
  if Doc = nil then Exit;
  Query := FFindText;
  if not UiInputQuery(Tr('Replace'), Tr('Find:'), Query) or (Query = '') then Exit;
  Replacement := '';
  if not UiInputQuery(Tr('Replace'), Tr('Replace with:'), Replacement) then Exit;
  FFindText := Query;
  if Sender = nil then Answer := mrYes
  else Answer := UiMessageDlg(Tr('Replace all occurrences?' + LineEnding +
    'Yes: replace all    No: replace next'), mtConfirmation,
    [mbYes, mbNo, mbCancel], 0);
  if Answer = mrCancel then Exit;
  if Answer = mrYes then
  begin
    for Row := 0 to Doc.Editor.Lines.Count - 1 do
    begin
      LineValue := Doc.Editor.Lines[Row];
      if Pos(LowerCase(Query), LowerCase(LineValue)) > 0 then
        Doc.Editor.Lines[Row] := StringReplace(LineValue, Query, Replacement,
          [rfReplaceAll, rfIgnoreCase]);
    end;
    Doc.Editor.SetFocus;
  end
  else
  begin
    if LowerCase(Doc.Editor.SelText) <> LowerCase(Query) then
      FindNextClick(Self);
    if LowerCase(Doc.Editor.SelText) = LowerCase(Query) then
    begin
      Doc.Editor.SelText := Replacement;
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
var OldCount: Integer;
begin
  while FDocs.Count > 0 do
  begin
    FPages.ActivePage := TDocument(FDocs[FDocs.Count - 1]).Tab;
    OldCount := FDocs.Count;
    CloseClick(Self);
    if FDocs.Count = OldCount then Exit;
  end;
end;

procedure TMainForm.CompileCurrent(SyntaxOnly, RunAfter: Boolean);
var
  Doc: TDocument;
  UseProject, IsCpp: Boolean;
  Ini: TIniFile;
  Proc: TProcess;
  Source, CompilerName, OutputFile, Flags, LinkerFlags, ProjectUnitPath: string;
  I, N, Available: Integer;
  ErrorItem: TListItem;
  Buffer: array[0..4095] of Byte;
  Chunk, LogText: RawByteString;
begin
  if FCompileActive then Exit;
  Doc := CurrentDoc;
  if (Doc = nil) and (FProjectPath = '') then Exit;
  if (Doc <> nil) and ((Doc.FileName = '') or Doc.Dirty) then
    if not SaveDoc(Doc) then Exit;
  UseProject := (FProjectPath <> '') and not SyntaxOnly and
    ((Doc = nil) or (FProjectFiles.IndexOf(Doc.FileName) >= 0));
  Proc := TProcess.Create(nil);
  FCompileActive := True;
  FCompileCancelRequested := False;
  try
    Proc.Options := [poUsePipes, poStderrToOutPut];
    LinkerFlags := '';
    if UseProject then
    begin
      if not SaveAllDocs then Exit;
      Ini := TIniFile.Create(FProjectPath);
      try
        if Ini.ReadInteger('Project', 'Type', 1) <> 1 then
        begin
          UiMessageDlg(Tr('Only console projects are currently supported.'), mtError, [mbOK], 0);
          Exit;
        end;
        IsCpp := Ini.ReadBool('Project', 'IsCpp', False);
        for I := 0 to FProjectFiles.Count - 1 do
          if (LowerCase(ExtractFileExt(FProjectFiles[I])) = '.cpp') or
             (LowerCase(ExtractFileExt(FProjectFiles[I])) = '.cc') or
             (LowerCase(ExtractFileExt(FProjectFiles[I])) = '.cxx') then
            IsCpp := True;
        if IsCpp then CompilerName := FCppCompiler else CompilerName := FCCompiler;
        Proc.CurrentDirectory := ExtractFilePath(FProjectPath);
        for I := 1 to Ini.ReadInteger('Project', 'UnitCount', 0) do
        begin
          if not Ini.ReadBool('Unit' + IntToStr(I), 'Compile', True) then Continue;
          ProjectUnitPath := Ini.ReadString('Unit' + IntToStr(I), 'FileName', '');
          if ProjectUnitPath = '' then Continue;
          Source := ExpandFileName(ExtractFilePath(FProjectPath) +
            StringReplace(ProjectUnitPath, '\', DirectorySeparator, [rfReplaceAll]));
          if (LowerCase(ExtractFileExt(Source)) <> '.c') and
             (LowerCase(ExtractFileExt(Source)) <> '.cc') and
             (LowerCase(ExtractFileExt(Source)) <> '.cpp') and
             (LowerCase(ExtractFileExt(Source)) <> '.cxx') then Continue;
          Proc.Parameters.Add(Source);
        end;
        if Proc.Parameters.Count = 0 then
        begin UiMessageDlg(Tr('Project has no C/C++ sources.'), mtError, [mbOK], 0); Exit; end;
        OutputFile := ChangeFileExt(FProjectPath, '');
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
      else if LowerCase(ExtractFileExt(Source)) = '.cpp' then IsCpp := True
      else if LowerCase(ExtractFileExt(Source)) = '.cc' then IsCpp := True
      else if LowerCase(ExtractFileExt(Source)) = '.cxx' then IsCpp := True
      else
      begin UiMessageDlg(Tr('Open a C/C++ source file to compile.'), mtError, [mbOK], 0); Exit; end;
      if IsCpp then CompilerName := FCppCompiler else CompilerName := FCCompiler;
      Proc.CurrentDirectory := ExtractFilePath(Source);
      Proc.Parameters.Add(Source);
      OutputFile := ChangeFileExt(Source, '');
    end;
    if Pos('/', CompilerName) > 0 then
      Proc.Executable := CompilerName
    else
      Proc.Executable := '/usr/bin/' + CompilerName;
    if IsCpp then AddCompilerFlags(Proc.Parameters, FCppFlags)
    else AddCompilerFlags(Proc.Parameters, FCFlags);
    if SyntaxOnly then Proc.Parameters.Add('-fsyntax-only')
    else
    begin Proc.Parameters.Add('-o'); Proc.Parameters.Add(OutputFile); end;
    if not SyntaxOnly then
      AddCompilerFlags(Proc.Parameters, Trim(LinkerFlags + ' ' + FLinkerFlags));
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
    FStatus.SimpleText := Tr('Compiling...');
    Application.ProcessMessages;
    try
      Proc.Execute;
      LogText := '';
      repeat
        if FCompileCancelRequested and Proc.Running then Proc.Terminate(1);
        Available := Proc.Output.NumBytesAvailable;
        if Available > SizeOf(Buffer) then Available := SizeOf(Buffer);
        if Available > 0 then
        begin
          N := Proc.Output.Read(Buffer, Available);
          SetLength(Chunk, N);
          if N > 0 then Move(Buffer[0], Chunk[1], N);
          LogText := LogText + Chunk;
        end
        else if Proc.Running then Sleep(10);
        Application.ProcessMessages;
      until (not Proc.Running) and (Proc.Output.NumBytesAvailable = 0);
      FOutput.Text := FOutput.Text + string(LogText);
      PopulateDiagnostics(string(LogText));
      if FCompileCancelRequested then
      begin
        FStatus.SimpleText := Tr('Compilation aborted');
        FOutput.Lines.Add(Tr('Compilation aborted.'));
      end
      else if Proc.ExitStatus = 0 then
      begin
        FStatus.SimpleText := Tr('Compilation successful');
        FOutput.Lines.Add(Tr('Compilation successful.'));
        if not SyntaxOnly then
        begin
          FLastExecutable := OutputFile;
          if RunAfter then RunExecutable(OutputFile);
        end;
      end
      else
      begin
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
      on E: Exception do UiMessageDlg(Format(Tr('Compile failed: %s'), [E.Message]), mtError, [mbOK], 0);
    end;
  finally
    Proc.Free;
    FCompileActive := False;
    FCompileCancelRequested := False;
  end;
end;

procedure TMainForm.RunExecutable(const FileName: string);
var Proc: TProcess; PauserPath: string;
begin
  if not FileExists(FileName) then
  begin UiMessageDlg(Tr('Compile the program first.'), mtInformation, [mbOK], 0); Exit; end;
  Proc := TProcess.Create(nil);
  try
    PauserPath := ExtractFilePath(ParamStr(0)) + 'console-pauser.sh';
    if not FileExists(PauserPath) then
      raise Exception.Create(Tr('Missing console-pauser.sh beside the application.'));
    if FileExists('/usr/bin/gnome-terminal') then
      Proc.Executable := '/usr/bin/gnome-terminal'
    else
      Proc.Executable := '/usr/bin/xterm';
    Proc.CurrentDirectory := ExtractFilePath(FileName);
    if Proc.Executable = '/usr/bin/gnome-terminal' then
    begin
      Proc.Parameters.Add('--title=' + ExtractFileName(FileName));
      Proc.Parameters.Add('--');
    end
    else
    begin
      Proc.Parameters.Add('-T');
      Proc.Parameters.Add(ExtractFileName(FileName));
      Proc.Parameters.Add('-e');
    end;
    Proc.Parameters.Add('/bin/bash');
    Proc.Parameters.Add(PauserPath);
    Proc.Parameters.Add(FileName);
    Proc.Execute;
  except
    on E: Exception do UiMessageDlg(Format(Tr('Run failed: %s'), [E.Message]), mtError, [mbOK], 0);
  end;
  Proc.Free;
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
var Doc: TDocument; FileName: string;
begin
  Doc := CurrentDoc;
  if (FProjectPath <> '') and ((Doc = nil) or
     (FProjectFiles.IndexOf(Doc.FileName) >= 0)) then
    FileName := ChangeFileExt(FProjectPath, '')
  else if Doc <> nil then FileName := ChangeFileExt(Doc.FileName, '')
  else FileName := FLastExecutable;
  RunExecutable(FileName);
end;

procedure TMainForm.AboutClick(Sender: TObject);
begin
  UiMessageDlg(Tr('Dev-C++ 5.11 - NOI Linux native prototype') + LineEnding +
    Tr('Based on Orwell Dev-C++ 5.11. GPL-2.0-or-later.'), mtInformation, [mbOK], 0);
end;

end.
